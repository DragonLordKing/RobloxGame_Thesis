--[[
Name: WorldLogoutProxyService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.WorldRuntime.WorldLogoutProxyService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: DataStoreService, HttpService, MemoryStoreService, Players, ReplicatedStorage, ServerScriptService, ServerStorage, Workspace
Requires:
  - local WorldConfig = require(ReplicatedPackage:WaitForChild("WorldRuntime"):WaitForChild("WorldPlaceConfig"))
  - local ProfileService = require(ServerPackage:WaitForChild("PlayerProfileService"))
  - local InventoryStorageService = require(ServerPackage:WaitForChild("InventoryStorageService"))
  - local CombatStateService = require(ServerPackage:WaitForChild("PlayerCombatStateService"))
  - local HumanoidStats = require(ServerPackage:WaitForChild("HumanoidStats"))
  - local SpatialGrid = require(ServerPackage:WaitForChild("SpatialGrid"))
  - local ItemCatalog = require(ReplicatedPackage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))
  - return require(ServerPackage:WaitForChild("EconomyMarketService"))
Functions: profileKey, dangerousRank, isDangerous, safeLogoutSeconds, currentZoneType, proxyFolder, spawnPosition, findSpawn, cleanupProxyParts, createSimpleProxy, clonePlayerCharacter, forceFieldFor, applyProxyBarrier, setProxyAttributes, registerProxyStats, destroyProxy, getEconomyMarketService, releaseSession, normalizeStack, setProfileSlot, extractDeathLootFromProfile, createDeathSackForSession, killSession, createProxySession, createLocalLogoutProxy, memoryMapName, getTravelMap, pollTravelSessions, onPlayerAdded, WorldLogoutProxyService.RecordTravelSession, WorldLogoutProxyService.MarkArrived, WorldLogoutProxyService.Start
Signal classes referenced: BindableEvent
Clean source lines: 569
]]
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ServerPackage = ServerScriptService:WaitForChild("MMO_ServerPackage")
local ReplicatedPackage = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")

local WorldConfig = require(ReplicatedPackage:WaitForChild("WorldRuntime"):WaitForChild("WorldPlaceConfig"))
local ProfileService = require(ServerPackage:WaitForChild("PlayerProfileService"))
local InventoryStorageService = require(ServerPackage:WaitForChild("InventoryStorageService"))
local CombatStateService = require(ServerPackage:WaitForChild("PlayerCombatStateService"))
local HumanoidStats = require(ServerPackage:WaitForChild("HumanoidStats"))
local SpatialGrid = require(ServerPackage:WaitForChild("SpatialGrid"))
local ItemCatalog = require(ReplicatedPackage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))

local WorldLogoutProxyService = {}

local PROFILE_STORE_NAME = "MMO_PlayerProfile_V1"
local RELEASE_TOKEN = "WorldLogoutProxy"
local TRAVEL_SESSION_TTL_SECONDS = 300
local FAILED_LOAD_PROXY_DELAY_SECONDS = 15
local POLL_INTERVAL_SECONDS = 5
local DANGER_SAFE_LOGOUT_SECONDS = 120
local DEATH_SAFE_LOGOUT_SECONDS = 180
local EQUIPMENT_SLOT_NAMES = { "Cape", "Helmet", "Bag", "Weapon", "Armor", "Offhand", "Food", "Boots", "Potion", "Mount" }

local started = false
local activeByProxy = {}
local activeByUserId = {}
local resumePositionsByUserId = {}
local profileStore = DataStoreService:GetDataStore(PROFILE_STORE_NAME)

local beFolder = ServerStorage:WaitForChild("MMO_ServerStoragePackage"):FindFirstChild("BindableEvents")
if not beFolder then
	beFolder = Instance.new("Folder")
	beFolder.Name = "BindableEvents"
	beFolder.Parent = ServerStorage:WaitForChild("MMO_ServerStoragePackage")
end
local LogoutProxyKilled = beFolder:FindFirstChild("LogoutProxyKilled")
if not LogoutProxyKilled then
	LogoutProxyKilled = Instance.new("BindableEvent")
	LogoutProxyKilled.Name = "LogoutProxyKilled"
	LogoutProxyKilled.Parent = beFolder
end

local function profileKey(userId)
	return "player:" .. tostring(userId)
end

local function dangerousRank(zoneType)
	return WorldConfig.GetZoneRank(WorldConfig.NormalizeZoneType(zoneType or "Safe"))
end

local function isDangerous(zoneType)
	return dangerousRank(zoneType) >= WorldConfig.GetZoneRank("Danger")
end

local function safeLogoutSeconds(zoneType)
	zoneType = WorldConfig.NormalizeZoneType(zoneType)
	if zoneType == "Death" then return DEATH_SAFE_LOGOUT_SECONDS end
	return DANGER_SAFE_LOGOUT_SECONDS
end

local function currentZoneType()
	local ok, zone = pcall(function()
		return CombatStateService.GetZoneType()
	end)
	if ok and zone then return WorldConfig.NormalizeZoneType(zone) end
	local map = WorldConfig.GetCurrentMap and WorldConfig.GetCurrentMap() or nil
	return WorldConfig.NormalizeZoneType(game:GetAttribute("ZoneType") or (map and map.ZoneType) or "Safe")
end

local function proxyFolder()
	local folder = Workspace:FindFirstChild("WorldLogoutProxies")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WorldLogoutProxies"
		folder.Parent = Workspace
	end
	return folder
end

local function spawnPosition(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then
		return inst.CFrame + Vector3.new(0, math.max(4, inst.Size.Y * 0.5 + 3), 0)
	end
	if inst:IsA("Model") then
		local ok, pivot = pcall(function() return inst:GetPivot() end)
		if ok then return pivot + Vector3.new(0, 5, 0) end
	end
	local part = inst:FindFirstChildWhichIsA("BasePart", true)
	return part and (part.CFrame + Vector3.new(0, math.max(4, part.Size.Y * 0.5 + 3), 0)) or nil
end

local function findSpawn(spawnId)
	spawnId = tostring(spawnId or "")
	if spawnId == "" then return nil end
	local folders = { Workspace:FindFirstChild("WorldSpawns"), Workspace:FindFirstChild("SpawnLocations"), Workspace:FindFirstChild("Spawns") }
	for _, folder in ipairs(folders) do
		if folder then
			local direct = folder:FindFirstChild(spawnId, true) or folder:FindFirstChild("Spawn_" .. spawnId, true)
			if direct then return direct end
		end
	end
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if (inst:IsA("BasePart") or inst:IsA("Model")) and (inst.Name == spawnId or inst.Name == "Spawn_" .. spawnId or tostring(inst:GetAttribute("SpawnId") or "") == spawnId) then
			return inst
		end
	end
	return nil
end

local function cleanupProxyParts(model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("Script") or inst:IsA("LocalScript") then
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanTouch = true
			inst.CanQuery = true
			inst.Massless = true
		end
	end
end

local function createSimpleProxy(displayName, cf)
	local model = Instance.new("Model")
	model.Name = "LogoutProxy_" .. tostring(displayName or "Player")

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 0.35
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = cf or CFrame.new(0, 8, 0)
	root.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 3, 1)
	torso.Color = Color3.fromRGB(95, 95, 95)
	torso.Anchored = true
	torso.CanCollide = false
	torso.CFrame = root.CFrame + Vector3.new(0, 1.5, 0)
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Shape = Enum.PartType.Ball
	head.Color = Color3.fromRGB(150, 126, 96)
	head.Anchored = true
	head.CanCollide = false
	head.CFrame = root.CFrame + Vector3.new(0, 3.6, 0)
	head.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.DisplayName = tostring(displayName or "Disconnected")
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

local function clonePlayerCharacter(player)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root) then return nil end
	local oldArchivable = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function() return character:Clone() end)
	character.Archivable = oldArchivable
	if not ok or not clone then return nil end
	clone.Name = "LogoutProxy_" .. player.Name
	clone:PivotTo(root.CFrame)
	cleanupProxyParts(clone)
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = player.DisplayName or player.Name
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	end
	return clone
end

local function forceFieldFor(model)
	local ff = model:FindFirstChild("WorldSpawnBarrierForceField")
	if not ff then
		ff = Instance.new("ForceField")
		ff.Name = "WorldSpawnBarrierForceField"
		ff.Visible = true
		ff.Parent = model
	end
	return ff
end

local function applyProxyBarrier(model, seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	if seconds <= 0 then return end
	model:SetAttribute("WorldSpawnBarrier", true)
	model:SetAttribute("WorldBarrierUntil", os.clock() + seconds)
	forceFieldFor(model)
	task.delay(seconds, function()
		if model.Parent then
			model:SetAttribute("WorldSpawnBarrier", false)
			model:SetAttribute("WorldBarrierUntil", 0)
			local ff = model:FindFirstChild("WorldSpawnBarrierForceField")
			if ff then ff:Destroy() end
		end
	end)
end

local function setProxyAttributes(model, session)
	model:SetAttribute("LogoutProxy", true)
	model:SetAttribute("OwnerUserId", session.UserId)
	model:SetAttribute("OwnerName", session.PlayerName or "")
	model:SetAttribute("OwnerDisplayName", session.DisplayName or session.PlayerName or "")
	model:SetAttribute("ZoneType", session.ZoneType)
	model:SetAttribute("SafeLogoutAt", session.SafeLogoutAt or 0)
	model:SetAttribute("TravelSessionId", session.TravelSessionId or "")
	model:SetAttribute("ProxyReason", session.Reason or "Logout")
end

local function registerProxyStats(model, session)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local health = math.max(1, math.floor(tonumber(session.Health) or tonumber(model:GetAttribute("Health")) or humanoid.Health or 100))
	local maxHealth = math.max(health, math.floor(tonumber(session.MaxHealth) or tonumber(model:GetAttribute("MaxHealth")) or humanoid.MaxHealth or health))
	humanoid.MaxHealth = maxHealth
	humanoid.Health = health
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", maxHealth)
	HumanoidStats.humanoidStats[model] = {
		Model = model,
		Humanoid = humanoid,
		IsPlayer = false,
		IsNPC = false,
		IsLogoutProxy = true,
		Health = health,
		MaxHealth = maxHealth,
		Speed = 0,
	}
	pcall(function() SpatialGrid.Add(model) end)
end

local function destroyProxy(model)
	if not model then return end
	pcall(function() SpatialGrid.Remove(model) end)
	HumanoidStats.humanoidStats[model] = nil
	if model.Parent then model:Destroy() end
end

local function getEconomyMarketService()
	local ok, service = pcall(function()
		return require(ServerPackage:WaitForChild("EconomyMarketService"))
	end)
	return ok and service or nil
end

local function releaseSession(session, saveOnly)
	if not session or session.Released then return end
	session.Released = true
	activeByProxy[session.Proxy] = nil
	if session.UserId then activeByUserId[session.UserId] = nil end
	if session.Player then
		ProfileService.ReleaseHold(session.Player, RELEASE_TOKEN)
	elseif session.UserId and saveOnly then

	end
	destroyProxy(session.Proxy)
end

local function normalizeStack(stack)
	if type(stack) ~= "table" then return nil end
	local id = ItemCatalog.NormalizeId(stack.Id or stack.id)
	if not id then return nil end
	return {
		Id = id,
		Amount = math.max(1, math.floor(tonumber(stack.Amount or stack.amount) or 1)),
		Quality = ItemCatalog.NormalizeQuality(stack.Quality or stack.quality),
		Purity = ItemCatalog.NormalizePurity(stack.Purity or stack.purity),
		CraftedBy = stack.CraftedBy,
	}
end

local function setProfileSlot(slots, slotKey, stack)
	if stack then
		slots[tostring(slotKey)] = {
			Id = stack.Id,
			Amount = stack.Amount,
			Quality = stack.Quality,
			Purity = stack.Purity,
			CraftedBy = stack.CraftedBy,
		}
	else
		slots[tostring(slotKey)] = nil
	end
end

local function extractDeathLootFromProfile(userId)
	local loot = {}
	local rng = Random.new((math.floor(os.clock() * 100000) + tonumber(userId) or 0) % 2147483647)
	local ok, err = pcall(function()
		profileStore:UpdateAsync(profileKey(userId), function(raw)
			local profile = type(raw) == "table" and raw or {}
			local inventory = type(profile.Inventory) == "table" and profile.Inventory or { Version = 5, Slots = {} }
			local slots = type(inventory.Slots) == "table" and inventory.Slots or {}
			local preservedSlots = {}
			for slotName, rawStack in pairs(slots) do
				local stack = normalizeStack(rawStack)
				if stack then
					local def = ItemCatalog.Get(stack.Id)
					if def and def.Type == "CoinSack" then
						setProfileSlot(preservedSlots, slotName, stack)
					else
						local amount = math.max(1, math.floor(tonumber(stack.Amount) or 1))
						local kept = amount <= 1 and (rng:NextNumber() > 0.30 and 1 or 0) or math.max(1, math.floor(amount * 0.80 + 0.5))
						if kept > 0 then
							table.insert(loot, { Id = stack.Id, Amount = kept, Quality = stack.Quality, Purity = stack.Purity, CraftedBy = stack.CraftedBy })
						end
					end
				end
			end
			inventory.Slots = preservedSlots
			profile.Inventory = inventory
			local equipmentSection = type(profile.Equipment) == "table" and profile.Equipment or { Equipment = {}, Slots = {} }
			local equipment = type(equipmentSection.Equipment) == "table" and equipmentSection.Equipment or {}
			for _, slotName in ipairs(EQUIPMENT_SLOT_NAMES) do
				local itemId = equipment[slotName]
				if itemId and rng:NextNumber() > 0.20 then
					table.insert(loot, { Id = tostring(itemId), Amount = 1, Quality = "Normal", Purity = "None" })
				end
				equipment[slotName] = nil
			end
			equipmentSection.Equipment = equipment
			equipmentSection.Mount = nil
			profile.Equipment = equipmentSection
			profile.LastOfflineProxyDeathAt = os.time()
			return profile
		end)
	end)
	if not ok then
		warn("[WorldLogoutProxy] Offline death profile update failed: " .. tostring(err))
	end
	return ok and loot or {}
end

local function createDeathSackForSession(session, killer, loot)
	if type(loot) ~= "table" or #loot <= 0 then return end
	local economy = getEconomyMarketService()
	if not (economy and type(economy.CreateDeathSack) == "function") then return end
	local position = session.Position or (session.Proxy and session.Proxy:GetPivot().Position) or Vector3.new(0, 5, 0)
	local victim = session.Player or { UserId = session.UserId, Character = nil }
	pcall(function()
		economy.CreateDeathSack(victim, killer, loot, position)
	end)
end

local function killSession(session, killer)
	if not session or session.Released then return end
	local loot = {}
	if session.Player then
		local ok, extracted = pcall(function()
			return InventoryStorageService.ExtractDeathLoot(session.Player)
		end)
		loot = ok and type(extracted) == "table" and extracted or {}
	else
		loot = extractDeathLootFromProfile(session.UserId)
	end
	createDeathSackForSession(session, killer, loot)
	releaseSession(session, true)
end

local function createProxySession(session)
	if not session or not session.UserId then return nil end
	local existing = activeByUserId[session.UserId]
	if existing then releaseSession(existing, true) end

	local proxy = session.Proxy
	if not proxy then
		local spawn = findSpawn(session.TargetSpawnId)
		local cf = spawnPosition(spawn) or CFrame.new(0, 8, 0)
		proxy = createSimpleProxy(session.DisplayName or session.PlayerName or session.UserId, cf)
	end

	session.Proxy = proxy
	session.ZoneType = WorldConfig.NormalizeZoneType(session.ZoneType or session.TargetZoneType or currentZoneType())
	session.SafeLogoutAt = os.time() + safeLogoutSeconds(session.ZoneType)
	session.Position = proxy:GetPivot().Position
	setProxyAttributes(proxy, session)
	proxy.Parent = proxyFolder()
	registerProxyStats(proxy, session)
	if (tonumber(session.BarrierRemaining) or 0) > 0 then
		applyProxyBarrier(proxy, tonumber(session.BarrierRemaining) or 0)
	end
	activeByProxy[proxy] = session
	activeByUserId[session.UserId] = session
	task.delay(math.max(1, session.SafeLogoutAt - os.time()), function()
		if activeByProxy[proxy] == session then
			releaseSession(session, true)
		end
	end)
	return session
end

local function createLocalLogoutProxy(player)
	if player:GetAttribute("WorldTeleportInProgress") == true then return end
	local zoneType = currentZoneType()
	if not isDangerous(zoneType) then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	ProfileService.HoldRelease(player, RELEASE_TOKEN)
	local proxy = clonePlayerCharacter(player)
	if not proxy then
		proxy = createSimpleProxy(player.DisplayName or player.Name, root.CFrame)
	end
	local health = character:GetAttribute("Health") or (character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid").Health) or 100
	local maxHealth = character:GetAttribute("MaxHealth") or (character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid").MaxHealth) or health
	local barrierUntil = tonumber(player:GetAttribute("WorldBarrierUntil")) or 0
	return createProxySession({
		Player = player,
		UserId = player.UserId,
		PlayerName = player.Name,
		DisplayName = player.DisplayName or player.Name,
		Proxy = proxy,
		ZoneType = zoneType,
		Reason = "Logout",
		Health = health,
		MaxHealth = maxHealth,
		Position = root.Position,
		BarrierRemaining = player:GetAttribute("WorldSpawnBarrier") == true and math.max(0, barrierUntil - os.clock()) or 0,
	})
end

local function memoryMapName(mapKey)
	return "MMO_WorldTravel_" .. tostring(mapKey or "unknown")
end

local function getTravelMap(mapKey)
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(memoryMapName(mapKey))
	end)
	return ok and map or nil
end

function WorldLogoutProxyService.RecordTravelSession(player, payload)
	if not (player and type(payload) == "table") then return nil end
	local targetZone = WorldConfig.NormalizeZoneType(payload.TargetZoneType or "Safe")
	if not isDangerous(targetZone) then return nil end
	local targetMapKey = payload.TargetMapKey
	if not targetMapKey then return nil end
	local sessionId = payload.TravelSessionId or HttpService:GenerateGUID(false)
	payload.TravelSessionId = sessionId
	local record = {
		TravelSessionId = sessionId,
		UserId = player.UserId,
		PlayerName = player.Name,
		DisplayName = player.DisplayName or player.Name,
		TargetMapKey = targetMapKey,
		TargetSpawnId = payload.TargetSpawnId,
		TargetZoneType = targetZone,
		ZoneType = targetZone,
		BarrierRemaining = payload.BarrierRemaining or 0,
		NoBarrierRemaining = payload.NoBarrierRemaining or 0,
		Reason = "FailedLoad",
		CreatedAt = os.time(),
		DueAt = os.time() + FAILED_LOAD_PROXY_DELAY_SECONDS,
	}
	local map = getTravelMap(targetMapKey)
	if not map then return sessionId end
	local ok, err = pcall(function()
		map:SetAsync(sessionId, record, TRAVEL_SESSION_TTL_SECONDS, record.DueAt)
	end)
	if not ok then
		warn("[WorldLogoutProxy] Could not record travel session: " .. tostring(err))
	end
	return sessionId
end

function WorldLogoutProxyService.MarkArrived(player, teleportData)
	if type(teleportData) ~= "table" then return end
	local sessionId = teleportData.TravelSessionId
	local mapKey = teleportData.TargetMapKey or WorldConfig.GetCurrentMapKey()
	if not sessionId or not mapKey then return end
	local map = getTravelMap(mapKey)
	if map then
		pcall(function() map:RemoveAsync(sessionId) end)
	end
	local session = activeByUserId[player.UserId]
	if session then
		resumePositionsByUserId[player.UserId] = session.Proxy and session.Proxy:GetPivot() or nil
		releaseSession(session, true)
	end
end

local function pollTravelSessions()
	local mapKey = WorldConfig.GetCurrentMapKey()
	local map = getTravelMap(mapKey)
	if not map then return end
	local ok, items = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, 20, nil, { sortKey = os.time() + 1 })
	end)
	if not ok or type(items) ~= "table" then return end
	for _, item in ipairs(items) do
		local record = item.value
		if type(record) == "table" and tonumber(record.UserId) and not Players:GetPlayerByUserId(record.UserId) and not activeByUserId[record.UserId] then
			pcall(function() map:RemoveAsync(item.key) end)
			createProxySession(record)
		end
	end
end

local function onPlayerAdded(player)
	local session = activeByUserId[player.UserId]
	if session then
		resumePositionsByUserId[player.UserId] = session.Proxy and session.Proxy:GetPivot() or nil
		releaseSession(session, true)
	end
	player.CharacterAdded:Connect(function(character)
		local cf = resumePositionsByUserId[player.UserId]
		if not cf then return end
		resumePositionsByUserId[player.UserId] = nil
		local root = character:WaitForChild("HumanoidRootPart", 8)
		if root then
			character:PivotTo(cf + Vector3.new(0, 2, 0))
		end
	end)
end

function WorldLogoutProxyService.Start()
	if started then return end
	started = true
	Players.PlayerRemoving:Connect(createLocalLogoutProxy)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(onPlayerAdded, player)
	end
	LogoutProxyKilled.Event:Connect(function(model, source, meta)
		local session = model and activeByProxy[model]
		if not session then return end
		local killer = type(meta) == "table" and meta.KillerPlayer or nil
		if not killer and typeof(source) == "Instance" then
			killer = source:IsA("Player") and source or Players:GetPlayerFromCharacter(source)
		end
		killSession(session, killer)
	end)
	task.spawn(function()
		while started do
			pollTravelSessions()
			task.wait(POLL_INTERVAL_SECONDS)
		end
	end)
end

return WorldLogoutProxyService
