--[[
Name: WorldTeleportService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.WorldRuntime.WorldTeleportService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: DataStoreService, Players, ReplicatedStorage, RunService, ServerScriptService, ServerStorage, TeleportService, Workspace
Requires:
  - local WorldConfig = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("WorldRuntime"):WaitForChild("WorldPlaceConfig"))
  - local CombatStateService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
  - local LogoutProxyService = require(script.Parent:WaitForChild("WorldLogoutProxyService"))
Functions: ensureRemote, isExitPart, playerFromHit, targetDisplayName, sendNotice, safeExitKey, invokeBindableFunction, getCurrentZoneType, needsDangerPrompt, setTeleportStasis, setBarrierAttributes, clearArrivalBarrier, applyArrivalBarrier, getTransferBarrierState, getMountedTransferState, restoreMountedArrivalState, applyTeleportArrivalState, dataStoreKey, getReservedCode, spawnPosition, findSpawn, applyArrivalSpawn, promptForDanger, canStartTeleport, buildTeleportPayload, teleportPlayer, bindExit, WorldTeleportService.Start
Signal classes referenced: RemoteEvent, BindableFunction
Clean source lines: 522
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("WorldRuntime"):WaitForChild("WorldPlaceConfig"))
local CombatStateService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
local LogoutProxyService = require(script.Parent:WaitForChild("WorldLogoutProxyService"))

local WorldTeleportService = {}
local started = false
local boundExits = {}
local teleportDebounce = {}
local reservedCodeCache = {}
local pendingExitPrompts = {}
local barrierTickets = {}

local TOUCH_DEBOUNCE_SECONDS = 2
local ZONE_COOLDOWN_SECONDS = 8
local ARRIVAL_BARRIER_SECONDS = 30
local ARRIVAL_BARRIER_DISTANCE = 200
local NO_NEW_BARRIER_SECONDS = 60
local ARRIVAL_STASIS_SECONDS = 2.75

local store = DataStoreService:GetDataStore(WorldConfig.ReservedServerStoreName or "MMO_WorldReservedServers_V1")

local remoteFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
end

local function ensureRemote(name)
	local remote = remoteFolder:FindFirstChild(name)
	if not remote or not remote:IsA("RemoteEvent") then
		if remote then remote:Destroy() end
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remoteFolder
	end
	return remote
end

local prepareRemote = ensureRemote("PrepareMapTeleport")
local exitPromptRemote = ensureRemote("WorldExitPrompt")
local exitResponseRemote = ensureRemote("WorldExitResponse")
local travelNoticeRemote = ensureRemote("WorldTravelNotice")
local bindableFunctions = ServerStorage:WaitForChild("MMO_ServerStoragePackage"):WaitForChild("BindableFunctions")

local function isExitPart(inst)
	if not (inst and inst:IsA("BasePart")) then return false end
	if inst:GetAttribute("WorldExit") == true or inst:GetAttribute("MapExit") == true then return true end
	return tostring(inst.Name):match("^Exit") ~= nil
end

local function playerFromHit(hit)
	if not hit or not hit.Parent then return nil end
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return nil end
	return Players:GetPlayerFromCharacter(character)
end

local function targetDisplayName(target)
	local map = target.TargetMapKey and WorldConfig.GetMap(target.TargetMapKey)
	return map and map.DisplayName or target.TargetMapKey or (target.TargetPlaceId and tostring(target.TargetPlaceId)) or "Unknown Map"
end

local function sendNotice(player, text)
	if player and player.Parent == Players then
		travelNoticeRemote:FireClient(player, { Text = tostring(text or "") })
	end
end

local function safeExitKey(exitPart)
	if not exitPart then return "unknown" end
	local explicit = exitPart:GetAttribute("PortalId") or exitPart:GetAttribute("ExitId")
	if explicit ~= nil and tostring(explicit) ~= "" then
		return tostring(explicit)
	end
	return exitPart:GetFullName()
end

local function invokeBindableFunction(name, ...)
	local bindable = bindableFunctions:FindFirstChild(name)
	if not bindable or not bindable:IsA("BindableFunction") then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return bindable:Invoke(table.unpack(args))
	end)
	if not ok then
		warn(("[WorldTeleport] BindableFunction %s failed: %s"):format(name, tostring(result)))
		return nil
	end
	return result
end

local function getCurrentZoneType()
	local map = WorldConfig.GetCurrentMap and WorldConfig.GetCurrentMap() or nil
	return WorldConfig.NormalizeZoneType((map and map.ZoneType) or game:GetAttribute("ZoneType") or "Safe")
end

local function needsDangerPrompt(target)
	local currentZone = getCurrentZoneType()
	local targetZone = WorldConfig.NormalizeZoneType(target.TargetZoneType or "Safe")
	local currentRank = WorldConfig.GetZoneRank(currentZone)
	local targetRank = WorldConfig.GetZoneRank(targetZone)
	return targetRank >= WorldConfig.GetZoneRank("Danger") and targetRank > currentRank, currentZone, targetZone
end

local function setTeleportStasis(player, enabled)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character then
		character:SetAttribute("WorldTeleportStasis", enabled == true)
	end
	if not humanoid then return end
	if enabled then
		humanoid:SetAttribute("PreWorldTeleportWalkSpeed", humanoid.WalkSpeed)
		humanoid:SetAttribute("PreWorldTeleportJumpPower", humanoid.JumpPower)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
		if root then root.Anchored = true end
	else
		if player:GetAttribute("Downed") == true or (character and character:GetAttribute("Downed") == true) then return end
		humanoid.WalkSpeed = tonumber(humanoid:GetAttribute("PreWorldTeleportWalkSpeed")) or humanoid.WalkSpeed or 18
		humanoid.JumpPower = tonumber(humanoid:GetAttribute("PreWorldTeleportJumpPower")) or 50
		humanoid.AutoRotate = true
		if root then root.Anchored = false end
	end
end

local function setBarrierAttributes(player, enabled, untilTime, origin)
	player:SetAttribute("WorldSpawnBarrier", enabled == true)
	player:SetAttribute("WorldBarrierUntil", tonumber(untilTime) or 0)
	if origin then player:SetAttribute("WorldBarrierOrigin", origin) end
	local character = player.Character
	if character then
		character:SetAttribute("WorldSpawnBarrier", enabled == true)
		character:SetAttribute("WorldBarrierUntil", tonumber(untilTime) or 0)
		if origin then character:SetAttribute("WorldBarrierOrigin", origin) end
	end
end

local function clearArrivalBarrier(player)
	barrierTickets[player] = (barrierTickets[player] or 0) + 1
	setBarrierAttributes(player, false, 0, nil)
	local character = player.Character
	local forceField = character and character:FindFirstChild("WorldSpawnBarrierForceField")
	if forceField then forceField:Destroy() end
end

local function applyArrivalBarrier(player, seconds, origin)
	seconds = math.max(0, tonumber(seconds) or 0)
	if seconds <= 0 or not player or not player.Parent then return end
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	origin = origin or (root and root.Position) or Vector3.zero
	local untilTime = os.clock() + seconds
	barrierTickets[player] = (barrierTickets[player] or 0) + 1
	local ticket = barrierTickets[player]
	local forceField = character:FindFirstChild("WorldSpawnBarrierForceField")
	if not forceField then
		forceField = Instance.new("ForceField")
		forceField.Name = "WorldSpawnBarrierForceField"
		forceField.Visible = true
		forceField.Parent = character
	end
	setBarrierAttributes(player, true, untilTime, origin)
	task.spawn(function()
		while player.Parent and barrierTickets[player] == ticket do
			local currentCharacter = player.Character
			local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
			if os.clock() >= untilTime then break end
			if currentRoot and (currentRoot.Position - origin).Magnitude >= ARRIVAL_BARRIER_DISTANCE then break end
			RunService.Heartbeat:Wait()
		end
		if player.Parent and barrierTickets[player] == ticket then
			clearArrivalBarrier(player)
		end
	end)
end

local function getTransferBarrierState(player)
	local now = os.clock()
	local barrierUntil = tonumber(player:GetAttribute("WorldBarrierUntil")) or 0
	local noBarrierUntil = tonumber(player:GetAttribute("WorldNoBarrierUntil")) or 0
	local barrierActive = player:GetAttribute("WorldSpawnBarrier") == true and now < barrierUntil
	return {
		BarrierRemaining = barrierActive and math.max(0, barrierUntil - now) or 0,
		NoBarrierRemaining = math.max(0, noBarrierUntil - now),
	}
end

local function getMountedTransferState(player)
	local result = invokeBindableFunction("GetMountedState", player)
	if type(result) ~= "table" or result.Mounted ~= true then
		return { Mounted = false }
	end
	return {
		Mounted = true,
		MountItemId = result.MountItemId,
		Health = result.Health,
		MaxHealth = result.MaxHealth,
	}
end

local function restoreMountedArrivalState(player, teleportData)
	if type(teleportData) ~= "table" or teleportData.Mounted ~= true then
		return
	end
	local options = {
		MountItemId = teleportData.MountItemId,
		Health = teleportData.MountHealth,
		MaxHealth = teleportData.MountMaxHealth,
		FromWorldTeleport = true,
	}
	task.defer(function()
		task.wait(0.35)
		if player.Parent then
			invokeBindableFunction("RestoreMountedState", player, options)
		end
	end)
end

local function applyTeleportArrivalState(player, teleportData, origin)
	if type(teleportData) ~= "table" or teleportData.FromWorldTeleport ~= true then return end
	local now = os.clock()
	local noBarrierRemaining = math.max(0, tonumber(teleportData.NoBarrierRemaining) or 0)
	if noBarrierRemaining > 0 then
		player:SetAttribute("WorldNoBarrierUntil", now + noBarrierRemaining)
	end
	local barrierRemaining = math.max(0, tonumber(teleportData.BarrierRemaining) or 0)
	if barrierRemaining > 0 then
		applyArrivalBarrier(player, barrierRemaining, origin)
	elseif noBarrierRemaining <= 0 then
		player:SetAttribute("WorldNoBarrierUntil", now + NO_NEW_BARRIER_SECONDS)
		applyArrivalBarrier(player, ARRIVAL_BARRIER_SECONDS, origin)
	else
		clearArrivalBarrier(player)
	end
end

local function dataStoreKey(placeId)
	return string.format("%s_%s", tostring(WorldConfig.Environment or "Dev"), tostring(placeId))
end

local function getReservedCode(placeId)
	placeId = tonumber(placeId)
	if not placeId or placeId <= 0 then
		return nil, "Target place id is not configured."
	end
	local key = dataStoreKey(placeId)
	if reservedCodeCache[key] then return reservedCodeCache[key] end

	local okGet, saved = pcall(function()
		return store:GetAsync(key)
	end)
	if okGet and type(saved) == "string" and saved ~= "" then
		reservedCodeCache[key] = saved
		return saved
	end

	local okReserve, codeOrErr = pcall(function()
		local accessCode = TeleportService:ReserveServerAsync(placeId)
		return accessCode
	end)
	if not okReserve or type(codeOrErr) ~= "string" or codeOrErr == "" then
		return nil, "Could not reserve target map server: " .. tostring(codeOrErr)
	end

	local newCode = codeOrErr
	local okUpdate, committed = pcall(function()
		return store:UpdateAsync(key, function(old)
			if type(old) == "string" and old ~= "" then
				return old
			end
			return newCode
		end)
	end)
	if okUpdate and type(committed) == "string" and committed ~= "" then
		reservedCodeCache[key] = committed
		return committed
	end

	reservedCodeCache[key] = newCode
	return newCode
end

local function spawnPosition(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.CFrame + Vector3.new(0, math.max(4, inst.Size.Y * 0.5 + 3), 0) end
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

local function applyArrivalSpawn(player, character)
	local joinData = player:GetJoinData()
	local teleportData = type(joinData) == "table" and joinData.TeleportData or nil
	if type(teleportData) ~= "table" then return end
	local spawnId = teleportData.TargetSpawnId
	local root = character:WaitForChild("HumanoidRootPart", 8)
	local origin = root and root.Position or Vector3.zero
	if spawnId then
		local spawn = findSpawn(spawnId)
		local cf = spawnPosition(spawn)
		if cf and root then
			character:PivotTo(cf)
			origin = cf.Position
		end
	end
	setTeleportStasis(player, true)
	LogoutProxyService.MarkArrived(player, teleportData)
	applyTeleportArrivalState(player, teleportData, origin)
	restoreMountedArrivalState(player, teleportData)
	task.delay(ARRIVAL_STASIS_SECONDS, function()
		if player.Parent then
			setTeleportStasis(player, false)
		end
	end)
end

local function promptForDanger(player, exitPart, target, currentZone, targetZone)
	local promptId = tostring(player.UserId) .. ":" .. safeExitKey(exitPart) .. ":" .. tostring(math.floor(os.clock() * 1000))
	pendingExitPrompts[player] = {
		Id = promptId,
		ExitPart = exitPart,
		Target = target,
		ExpiresAt = os.clock() + 25,
	}
	exitPromptRemote:FireClient(player, {
		Id = promptId,
		DisplayName = targetDisplayName(target),
		CurrentZoneType = currentZone,
		TargetZoneType = targetZone,
		Message = "The next zone can lead to gear loss and inventory loss. Travel anyway?",
	})
end

local function canStartTeleport(player)
	if CombatStateService.IsDowned and CombatStateService.IsDowned(player) then
		return false, "You cannot travel while downed."
	end
	if CombatStateService.IsAggressiveCombat and CombatStateService.IsAggressiveCombat(player) then
		local remaining = CombatStateService.GetAggressiveCombatRemaining and CombatStateService.GetAggressiveCombatRemaining(player) or 0
		return false, string.format("You attacked recently. You can travel in %ds.", math.max(1, math.ceil(remaining)))
	end
	local cooldownUntil = tonumber(player:GetAttribute("WorldTeleportCooldownUntil")) or 0
	if os.clock() < cooldownUntil then
		return false, string.format("You can travel again in %ds.", math.max(1, math.ceil(cooldownUntil - os.clock())))
	end
	return true
end

local function buildTeleportPayload(player, target, exitPart)
	local targetMap = target.TargetMapKey and WorldConfig.GetMap(target.TargetMapKey)
	local transferState = getTransferBarrierState(player)
	local mountState = getMountedTransferState(player)
	return {
		FromWorldTeleport = true,
		TargetMapKey = target.TargetMapKey,
		TargetPlaceId = target.TargetPlaceId,
		TargetSpawnId = target.TargetSpawnId,
		TargetZoneType = target.TargetZoneType,
		SourceMapKey = WorldConfig.GetCurrentMapKey(),
		SourcePortalId = target.SourcePortalId or exitPart.Name,
		DisplayName = targetDisplayName(target),
		RegionKey = (targetMap and targetMap.RegionKey) or WorldConfig.DefaultLogicalRegion,
		BarrierRemaining = transferState.BarrierRemaining,
		NoBarrierRemaining = transferState.NoBarrierRemaining,
		Mounted = mountState.Mounted == true,
		MountItemId = mountState.MountItemId,
		MountHealth = mountState.Health,
		MountMaxHealth = mountState.MaxHealth,
		TeleportedAt = os.time(),
		LoadingPhases = { "Preparing terrain", "Warming NPC spawns", "Finding arrival spawn", "Opening the road" },
	}
end

local function teleportPlayer(player, exitPart, options)
	options = type(options) == "table" and options or {}
	if not (player and player.Parent == Players and exitPart and exitPart.Parent) then return end
	local target = options.Target or WorldConfig.GetTargetForExit(exitPart)
	if not target or not target.TargetPlaceId or target.TargetPlaceId <= 0 then
		warn("[WorldTeleport] Exit " .. exitPart:GetFullName() .. " has no valid TargetPlaceId/TargetMapKey.")
		sendNotice(player, "This exit is not connected yet.")
		return
	end

	local debounceKey = tostring(player.UserId) .. ":" .. safeExitKey(exitPart)
	if not options.IgnoreTouchDebounce and teleportDebounce[debounceKey] and os.clock() - teleportDebounce[debounceKey] < TOUCH_DEBOUNCE_SECONDS then return end
	teleportDebounce[debounceKey] = os.clock()

	local allowed, reason = canStartTeleport(player)
	if not allowed then
		sendNotice(player, reason)
		return
	end

	local shouldPrompt, currentZone, targetZone = needsDangerPrompt(target)
	if shouldPrompt and not options.ConfirmedDanger then
		promptForDanger(player, exitPart, target, currentZone, targetZone)
		return
	end

	local accessCode, codeErr = getReservedCode(target.TargetPlaceId)
	if not accessCode then
		warn("[WorldTeleport] " .. tostring(codeErr))
		sendNotice(player, tostring(codeErr or "Could not open the next map."))
		return
	end

	local payload = buildTeleportPayload(player, target, exitPart)
	LogoutProxyService.RecordTravelSession(player, payload)
	player:SetAttribute("WorldTeleportCooldownUntil", os.clock() + ZONE_COOLDOWN_SECONDS)
	player:SetAttribute("WorldTeleportInProgress", true)
	setTeleportStasis(player, true)
	prepareRemote:FireClient(player, payload)
	task.wait(0.35)

	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ReservedServerAccessCode = accessCode
	teleportOptions:SetTeleportData(payload)

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(target.TargetPlaceId, { player }, teleportOptions)
	end)
	if not ok then
		warn("[WorldTeleport] Teleport failed: " .. tostring(err))
		setTeleportStasis(player, false)
		player:SetAttribute("WorldTeleportInProgress", false)
		player:SetAttribute("WorldTeleportCooldownUntil", os.clock() + 1)
		sendNotice(player, "Travel failed. Try again in a moment.")
	end
end

local function bindExit(part)
	if not isExitPart(part) or boundExits[part] then return end
	boundExits[part] = true
	part:SetAttribute("WorldExit", true)
	part.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			teleportPlayer(player, part)
		end
	end)
end

function WorldTeleportService.Start()
	if started then return end
	started = true
	exitResponseRemote.OnServerEvent:Connect(function(player, payload)
		local prompt = pendingExitPrompts[player]
		if type(payload) ~= "table" or not prompt then return end
		if payload.Id ~= prompt.Id or os.clock() > (prompt.ExpiresAt or 0) then
			pendingExitPrompts[player] = nil
			return
		end
		pendingExitPrompts[player] = nil
		if payload.Accepted == true then
			teleportPlayer(player, prompt.ExitPart, { Target = prompt.Target, ConfirmedDanger = true, IgnoreTouchDebounce = true })
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pendingExitPrompts[player] = nil
		barrierTickets[player] = nil
	end)
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if isExitPart(inst) then bindExit(inst) end
	end
	Workspace.DescendantAdded:Connect(function(inst)
		task.defer(function()
			if isExitPart(inst) then bindExit(inst) end
		end)
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.defer(applyArrivalSpawn, player, character)
		end)
		if player.Character then task.defer(applyArrivalSpawn, player, player.Character) end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character)
			task.defer(applyArrivalSpawn, player, character)
		end)
		if player.Character then task.defer(applyArrivalSpawn, player, player.Character) end
	end
end

return WorldTeleportService
