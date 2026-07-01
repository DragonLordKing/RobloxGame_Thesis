--[[
Name: GatheringService
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.GatheringService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage, Workspace, HttpService, CollectionService
Requires:
  - local Config = require(ReplicatedPackage:WaitForChild("GatheringConfig"))
  - local DestinyBoardConfig = require(ReplicatedPackage:WaitForChild("DestinyBoardConfig"))
  - local ValorService = require(ServerPackage:WaitForChild("Progression"):WaitForChild("ValorService"))
  - local CombatStateService = require(ServerPackage:WaitForChild("PlayerCombatStateService"))
  - local ProfileService = require(ServerPackage:WaitForChild("PlayerProfileService"))
  - local InventoryService = require(ServerPackage:WaitForChild("InventoryStorageService"))
  - local ItemCatalog = require(ReplicatedPackage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))
Functions: loadInventory, saveInventory, getTemplate, getFirstBasePart, purityEmitterFolder, removeRuntimePurityEmitters, setRuntimePurityEmittersEnabled, applyPurityEmitter, hasNonSurfaceMarker, isHumanoidPart, shouldSkipSurfaceHit, normalizePurityWeightEntries, decodePurityWeightsString, readPurityWeightsModule, purityWeightsForNode, encodePurityEntries, rollPurity, rollNodePurity, setNodeAttributes, getSurfaceCFrame, setNodeAvailable, setNodeTicks, startPurityRerollLoop, startTickRespawnLoop, zoneKeyForMarker, addGatheringMarker, gatherSpawnMarkers, spawnNodeForPart, spawnAllNodes, findGatherNode, getNodePosition, grantItem, handleGatherRequest
Signal classes referenced: RemoteEvent
Clean source lines: 684
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local ReplicatedPackage = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
local ServerPackage = game.ServerScriptService:WaitForChild("MMO_ServerPackage")
local Config = require(ReplicatedPackage:WaitForChild("GatheringConfig"))
local DestinyBoardConfig = require(ReplicatedPackage:WaitForChild("DestinyBoardConfig"))
local ValorService = require(ServerPackage:WaitForChild("Progression"):WaitForChild("ValorService"))
local CombatStateService = require(ServerPackage:WaitForChild("PlayerCombatStateService"))
local ProfileService = require(ServerPackage:WaitForChild("PlayerProfileService"))
local InventoryService = require(ServerPackage:WaitForChild("InventoryStorageService"))
local ItemCatalog = require(ReplicatedPackage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local playerInventories = {}
local nodeLocks = {}
local purityRng = Random.new()

local remoteEvents = ReplicatedPackage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedPackage
end

local gatherRequest = remoteEvents:FindFirstChild("GatherRequest")
if not gatherRequest then
	gatherRequest = Instance.new("RemoteEvent")
	gatherRequest.Name = "GatherRequest"
	gatherRequest.Parent = remoteEvents
end

local gatherResult = remoteEvents:FindFirstChild("GatherResult")
if not gatherResult then
	gatherResult = Instance.new("RemoteEvent")
	gatherResult.Name = "GatherResult"
	gatherResult.Parent = remoteEvents
end

local zonesFolder = Workspace:WaitForChild("GatheringZones")
local GATHERING_MARKER_TAGS = { "GatheringZone", "GatheringSpawn", "MMO_GatheringZone" }
local nodesFolder = Workspace:FindFirstChild("GatheringNodes")
if not nodesFolder then
	nodesFolder = Instance.new("Folder")
	nodesFolder.Name = "GatheringNodes"
	nodesFolder.Parent = Workspace
end

local function loadInventory(player)
	local section = ProfileService.GetSection(player, "Gathering", function()
		return { Inventory = {} }
	end)
	if type(section.Inventory) ~= "table" then
		section.Inventory = {}
		ProfileService.MarkDirty(player)
	end
	playerInventories[player] = section.Inventory
end

local function saveInventory(player)
	local inventory = playerInventories[player]
	if not inventory then
		return
	end

	local section = ProfileService.GetSection(player, "Gathering", function()
		return { Inventory = {} }
	end)
	section.Inventory = inventory
	ProfileService.MarkDirty(player)
end

local function getTemplate(zoneConfig)
	local assets = ReplicatedPackage:FindFirstChild("Assets")
	local nodes = assets and assets:FindFirstChild("Nodes")
	local ores = nodes and nodes:FindFirstChild("Ores")
	if not ores then
		return nil
	end

	return ores:FindFirstChild(zoneConfig.Template or "") or ores:FindFirstChild("Ore1") or ores:FindFirstChildWhichIsA("Model")
end

local function getFirstBasePart(root)
	if root:IsA("BasePart") then
		return root
	end
	return root:FindFirstChildWhichIsA("BasePart", true)
end

local PURITY_EMITTER_NAMES = {
	Faint = "Faint",
	Kindled = "Kindled",
	Ignited = "Ignited",
	["Ashen Forged"] = "AshenForged",
}

local function purityEmitterFolder()
	local assets = ReplicatedPackage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("PurityEmitters") or nil
end

local function removeRuntimePurityEmitters(node)
	for _, inst in ipairs(node:GetDescendants()) do
		if inst:IsA("ParticleEmitter") and inst:GetAttribute("RuntimePurityEmitter") == true then
			inst:Destroy()
		end
	end
end

local function setRuntimePurityEmittersEnabled(node, enabled)
	for _, inst in ipairs(node:GetDescendants()) do
		if inst:IsA("ParticleEmitter") and inst:GetAttribute("RuntimePurityEmitter") == true then
			inst.Enabled = enabled == true
		end
	end
end

local function applyPurityEmitter(node, purity)
	if not node then return end
	removeRuntimePurityEmitters(node)
	purity = ItemCatalog.NormalizePurity(purity or "None")
	local templateName = PURITY_EMITTER_NAMES[purity]
	if not templateName then return end
	local folder = purityEmitterFolder()
	local template = folder and folder:FindFirstChild(templateName)
	local part = getFirstBasePart(node)
	if not (template and template:IsA("ParticleEmitter") and part) then return end
	local emitter = template:Clone()
	emitter:SetAttribute("RuntimePurityEmitter", true)
	emitter.Enabled = node:GetAttribute("Depleted") ~= true
	emitter.Parent = part
end

local NON_SURFACE_NAMES = {
	["Non-Collidable"] = true,
	NonCollidable = true,
	Ignore = true,
}

local NON_SURFACE_GROUPS = {
	["Non-Collidable"] = true,
	NonCollidable = true,
	Walkthrough = true,
	Character = true,
	Horse = true,
	Mobs = true,
}

local function hasNonSurfaceMarker(inst)
	local current = inst
	while current and current ~= Workspace do
		if NON_SURFACE_NAMES[current.Name] then
			return true
		end
		if current:GetAttribute("NonCollidable") == true or current:GetAttribute("Non-Collidable") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isHumanoidPart(inst)
	local model = inst and inst:FindFirstAncestorWhichIsA("Model")
	return model and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function shouldSkipSurfaceHit(inst)
	if not inst or inst == Workspace.Terrain then
		return false
	end
	if hasNonSurfaceMarker(inst) or isHumanoidPart(inst) then
		return true
	end
	if inst:IsA("BasePart") then
		if inst.CanCollide == false then
			return true
		end
		if NON_SURFACE_GROUPS[inst.CollisionGroup] then
			return true
		end
	end
	return false
end

local function normalizePurityWeightEntries(raw)
	local entries = {}
	if type(raw) ~= "table" then return entries end
	if #raw > 0 then
		for _, entry in ipairs(raw) do
			if type(entry) == "table" then
				local name = entry.Name or entry.Purity or entry[1]
				local weight = tonumber(entry.Weight or entry.Chance or entry[2]) or 0
				if name and weight > 0 then
					table.insert(entries, { Name = ItemCatalog.NormalizePurity(name), Weight = weight })
				end
			end
		end
	else
		for name, weight in pairs(raw) do
			weight = tonumber(weight) or 0
			if weight > 0 then
				table.insert(entries, { Name = ItemCatalog.NormalizePurity(name), Weight = weight })
			end
		end
	end
	return entries
end

local function decodePurityWeightsString(raw)
	if type(raw) ~= "string" or raw == "" then return nil end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if ok and type(decoded) == "table" then
		return decoded
	end
	local parsed = {}
	for pair in string.gmatch(raw, "[^,;]+") do
		local name, weight = pair:match("^%s*([^=:]+)%s*[=:]%s*([%d%.]+)%s*$")
		if name and weight then
			name = name:gsub("^%s+", ""):gsub("%s+$", "")
			parsed[name] = tonumber(weight)
		end
	end
	return next(parsed) and parsed or nil
end

local function readPurityWeightsModule(spawnPart)
	local module = spawnPart and (spawnPart:FindFirstChild("PurityWeights") or spawnPart:FindFirstChild("GatherPurityWeights"))
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then return result end
		warn("[Gathering] Failed to read purity weights from " .. module:GetFullName())
	end
	return nil
end

local function purityWeightsForNode(spawnPart, zoneConfig, tier)
	local attrRaw = spawnPart and (spawnPart:GetAttribute("GatherPurityWeights") or spawnPart:GetAttribute("PurityWeights"))
	local raw = readPurityWeightsModule(spawnPart)
		or decodePurityWeightsString(attrRaw)
		or zoneConfig.PurityWeights
		or zoneConfig.PurityRolls
		or (type(Config.PurityRespawnWeightsByTier) == "table" and Config.PurityRespawnWeightsByTier[tier])
		or Config.DefaultPurityRespawnWeights
	local entries = normalizePurityWeightEntries(raw)
	if #entries == 0 then
		entries = { { Name = "None", Weight = 1 } }
	end
	return entries
end

local function encodePurityEntries(entries)
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(entries)
	end)
	return ok and encoded or "[]"
end

local function rollPurity(entries, tier)
	if math.floor(tonumber(tier) or 1) < 4 then
		return "None"
	end
	local total = 0
	for _, entry in ipairs(entries or {}) do
		total += math.max(0, tonumber(entry.Weight) or 0)
	end
	if total <= 0 then return "None" end
	local roll = purityRng:NextNumber(0, total)
	local cursor = 0
	for _, entry in ipairs(entries) do
		cursor += math.max(0, tonumber(entry.Weight) or 0)
		if roll <= cursor then
			return ItemCatalog.NormalizePurity(entry.Name)
		end
	end
	return "None"
end

local function rollNodePurity(node)
	if not node then return "None" end
	local tier = math.floor(tonumber(node:GetAttribute("Tier")) or 1)
	local entries = normalizePurityWeightEntries(decodePurityWeightsString(node:GetAttribute("GatherPurityWeights")) or {})
	local purity = rollPurity(entries, tier)
	node:SetAttribute("GatherPurity", purity)
	local itemId = ItemCatalog.ResourceId(node:GetAttribute("GatherKind"), node:GetAttribute("GatherItem"), tier, purity)
	if itemId then
		node:SetAttribute("GatherItemId", itemId)
		local def = ItemCatalog.Get(itemId)
		node:SetAttribute("GatherDisplayName", def and def.DisplayName or node:GetAttribute("GatherItem") or itemId)
	end
	return purity
end

local function setNodeAttributes(root, spawnPart, zoneName, zoneConfig, nodeId)
	local yield = zoneConfig.Yield or {}
	local itemName = yield.Item or zoneConfig.Kind or "Ore"
	local tier = math.clamp(math.floor(tonumber(zoneConfig.Tier) or 1), 1, DestinyBoardConfig.MaxTier)
	local tickCost = math.max(1, math.floor(tonumber(zoneConfig.TickCost) or tonumber(Config.DefaultTickCost) or 2))
	local maxTicks = math.max(tickCost, math.floor(tonumber(zoneConfig.MaxTicks) or tonumber(Config.DefaultMaxTicks) or (20 * tier)))
	local yieldPerTick = math.max(1, math.floor(tonumber(zoneConfig.YieldPerTick) or tonumber(Config.DefaultYieldPerTick) or 1))
	local amount = math.max(1, math.floor(tickCost * yieldPerTick))
	local duration = tonumber(zoneConfig.GatherSeconds) or tonumber(Config.DefaultGatherSeconds) or Config.DurationFromSpecialization(0)
	local tickRespawnAmount = math.max(1, math.floor(tonumber(zoneConfig.TickRespawnAmount) or tonumber(Config.DefaultTickRespawnAmount) or tickCost))
	local tickRespawnSeconds = math.max(1, tonumber(zoneConfig.TickRespawnSeconds) or tonumber(zoneConfig.RespawnSeconds) or tonumber(Config.DefaultTickRespawnSeconds) or 12)
	local valorSkillKey = zoneConfig.ValorSkillKey or DestinyBoardConfig.SkillKeyForGather(zoneConfig.Kind, itemName, nil, tier)
	local valorAmount = math.max(1, math.floor(tonumber(zoneConfig.ValorPerTick) or tonumber(zoneConfig.Valor) or DestinyBoardConfig.GatherValorForTier(tier)))

	root:SetAttribute("GatheringNode", true)
	root:SetAttribute("GatherNodeId", nodeId)
	root:SetAttribute("GatherZone", zoneName)
	root:SetAttribute("GatherKind", zoneConfig.Kind or "Gatherable")
	root:SetAttribute("GatherItem", itemName)
	root:SetAttribute("GatherAmount", amount)
	root:SetAttribute("GatherDuration", duration)
	root:SetAttribute("GatherRespawnSeconds", tickRespawnSeconds)
	root:SetAttribute("GatherTickRespawnSeconds", tickRespawnSeconds)
	root:SetAttribute("GatherTicks", maxTicks)
	root:SetAttribute("GatherMaxTicks", maxTicks)
	root:SetAttribute("GatherTickCost", tickCost)
	root:SetAttribute("GatherYieldPerTick", yieldPerTick)
	root:SetAttribute("GatherTickRespawnAmount", tickRespawnAmount)
	root:SetAttribute("Tier", tier)
	root:SetAttribute("GatherValorSkillKey", valorSkillKey)
	root:SetAttribute("GatherValorAmount", valorAmount)
	root:SetAttribute("GatherPurityWeights", encodePurityEntries(purityWeightsForNode(spawnPart, zoneConfig, tier)))
	root:SetAttribute("GatherPurity", "None")
	root:SetAttribute("GatherItemId", ItemCatalog.ResourceId(zoneConfig.Kind or itemName, itemName, tier, "None"))
	root:SetAttribute("Depleted", false)

	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst:SetAttribute("GatheringNode", true)
			inst:SetAttribute("GatherNodeId", nodeId)
			inst:SetAttribute("OriginalTransparency", inst.Transparency)
			inst:SetAttribute("OriginalCanCollide", inst.CanCollide)
			inst:SetAttribute("OriginalCanQuery", inst.CanQuery)
		end
	end
end

local function getSurfaceCFrame(spawnPart, node)
	local excludes = {zonesFolder, nodesFolder}
	local origin = spawnPart.Position + Vector3.new(0, (spawnPart.Size.Y * 0.5) + 300, 0)
	local direction = Vector3.new(0, -1, 0)
	local remaining = 1000
	local result = nil

	for _ = 1, 16 do
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = excludes
		rayParams.IgnoreWater = false
		local hit = Workspace:Raycast(origin, direction * remaining, rayParams)
		if not hit then
			break
		end
		if not shouldSkipSurfaceHit(hit.Instance) then
			result = hit
			break
		end
		table.insert(excludes, hit.Instance)
		local travelled = hit.Distance + 0.05
		origin += direction * travelled
		remaining -= travelled
		if remaining <= 0 then
			break
		end
	end

	local hitPosition = spawnPart.Position - Vector3.new(0, spawnPart.Size.Y * 0.5, 0)
	local up = Vector3.yAxis

	if result then
		hitPosition = result.Position
		up = result.Normal.Unit
	end

	local _, size = node:GetBoundingBox()
	local forward = spawnPart.CFrame.LookVector - up * spawnPart.CFrame.LookVector:Dot(up)
	if forward.Magnitude < 0.001 then
		forward = spawnPart.CFrame.RightVector - up * spawnPart.CFrame.RightVector:Dot(up)
	end
	if forward.Magnitude < 0.001 then
		forward = Vector3.zAxis
	end
	forward = forward.Unit

	local right = forward:Cross(up).Unit
	local back = -forward
	local position = hitPosition + up * (size.Y * 0.5)
	return CFrame.fromMatrix(position, right, up, back)
end

local function setNodeAvailable(node, available)
	node:SetAttribute("Depleted", not available)
	setRuntimePurityEmittersEnabled(node, available)

	for _, inst in ipairs(node:GetDescendants()) do
		if inst:IsA("BasePart") then
			if available then
				inst.Transparency = inst:GetAttribute("OriginalTransparency") or 0
				inst.CanCollide = inst:GetAttribute("OriginalCanCollide") ~= false
				inst.CanQuery = inst:GetAttribute("OriginalCanQuery") ~= false
			else
				inst.Transparency = 1
				inst.CanCollide = false
				inst.CanQuery = false
			end
		end
	end
end

local function setNodeTicks(node, ticks)
	local maxTicks = math.max(1, math.floor(tonumber(node:GetAttribute("GatherMaxTicks")) or 1))
	ticks = math.clamp(math.floor(tonumber(ticks) or 0), 0, maxTicks)
	node:SetAttribute("GatherTicks", ticks)
	setNodeAvailable(node, ticks > 0)
end

local function startPurityRerollLoop(node)
	task.spawn(function()
		while node and node.Parent do
			local seconds = math.max(1, tonumber(node:GetAttribute("GatherRerollSeconds")) or tonumber(node:GetAttribute("GatherNodeRespawnSeconds")) or tonumber(node:GetAttribute("GatherRespawnSeconds")) or tonumber(Config.DefaultRerollSeconds) or tonumber(Config.DefaultNodeRespawnSeconds) or 60)
			task.wait(seconds)
			if node and node.Parent then
				node:SetAttribute("GatherRerollActive", true)
				rollNodePurity(node)
				node:SetAttribute("GatherRerollActive", false)
				node:SetAttribute("GatherNodeRespawnActive", false)
			end
		end
	end)
end

local function startTickRespawnLoop(node)
	task.spawn(function()
		while node and node.Parent do
			local seconds = math.max(1, tonumber(node:GetAttribute("GatherTickRespawnSeconds")) or tonumber(Config.DefaultTickRespawnSeconds) or 12)
			task.wait(seconds)
			if node and node.Parent then
				local maxTicks = math.max(1, math.floor(tonumber(node:GetAttribute("GatherMaxTicks")) or tonumber(Config.DefaultMaxTicks) or 20))
				local currentTicks = math.clamp(math.floor(tonumber(node:GetAttribute("GatherTicks")) or maxTicks), 0, maxTicks)
				if currentTicks < maxTicks then
					local amount = math.max(1, math.floor(tonumber(node:GetAttribute("GatherTickRespawnAmount")) or tonumber(Config.DefaultTickRespawnAmount) or 2))
					setNodeTicks(node, math.min(maxTicks, currentTicks + amount))
				end
			end
		end
	end)
end

local function zoneKeyForMarker(marker)
	local key = marker:GetAttribute("GatherZoneKey") or marker:GetAttribute("ZoneKey") or marker:GetAttribute("GatheringZoneKey")
	if key ~= nil and tostring(key) ~= "" then
		return tostring(key)
	end
	return marker.Name
end

local function addGatheringMarker(markers, seen, marker)
	if not marker:IsA("BasePart") or not marker:IsDescendantOf(Workspace) or seen[marker] then
		return
	end
	seen[marker] = true
	table.insert(markers, marker)
end

local function gatherSpawnMarkers()
	local markers = {}
	local seen = {}

	for _, child in ipairs(zonesFolder:GetChildren()) do
		addGatheringMarker(markers, seen, child)
	end

	for _, tagName in ipairs(GATHERING_MARKER_TAGS) do
		for _, marker in ipairs(CollectionService:GetTagged(tagName)) do
			addGatheringMarker(markers, seen, marker)
		end
	end

	table.sort(markers, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	return markers
end

local function spawnNodeForPart(spawnPart, zoneConfig, index, zoneKey)
	local template = getTemplate(zoneConfig)
	if not template then
		warn("[Gathering] Missing node template for zone", zoneKey or spawnPart.Name)
		return
	end

	local node = template:Clone()
	node.Name = string.format("%s_Node_%d", zoneKey or spawnPart.Name, index)
	node.Parent = nodesFolder

	if node:IsA("Model") and not node.PrimaryPart then
		node.PrimaryPart = getFirstBasePart(node)
	end

	local nodeId = HttpService:GenerateGUID(false)
	setNodeAttributes(node, spawnPart, zoneKey or zoneKeyForMarker(spawnPart), zoneConfig, nodeId)

	local targetCFrame = getSurfaceCFrame(spawnPart, node)
	if node:IsA("Model") then
		node:PivotTo(targetCFrame)
	elseif node:IsA("BasePart") then
		node.CFrame = targetCFrame
	end
	rollNodePurity(node)
	setNodeTicks(node, node:GetAttribute("GatherMaxTicks") or Config.DefaultMaxTicks or 20)
	startTickRespawnLoop(node)
	startPurityRerollLoop(node)
end

local function spawnAllNodes()
	for _, child in ipairs(nodesFolder:GetChildren()) do
		if child:GetAttribute("GatheringNode") then
			child:Destroy()
		end
	end

	local index = 0
	for _, spawnPart in ipairs(gatherSpawnMarkers()) do
		local zoneKey = zoneKeyForMarker(spawnPart)
		local zoneConfig = Config.Zones[zoneKey]
		if zoneConfig then
			local count = math.max(1, tonumber(spawnPart:GetAttribute("NodesPerSpawn")) or tonumber(zoneConfig.NodesPerSpawn) or 1)
			for _ = 1, count do
				index += 1
				spawnNodeForPart(spawnPart, zoneConfig, index, zoneKey)
			end
		elseif spawnPart:GetAttribute("RequireGatheringZone") == true then
			warn(("[Gathering] Marker %s has no GatheringConfig.Zones entry for '%s'"):format(spawnPart:GetFullName(), zoneKey))
		end
	end
end

local function findGatherNode(instance)
	if not instance then
		return nil
	end

	local current = instance
	while current and current ~= Workspace do
		if current:GetAttribute("GatheringNode") and current.Parent == nodesFolder then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function getNodePosition(node)
	if node:IsA("Model") then
		return node:GetPivot().Position
	elseif node:IsA("BasePart") then
		return node.Position
	end

	local part = getFirstBasePart(node)
	return part and part.Position or nil
end

local function grantItem(player, itemName, amount, kind, tier, purity)
	local inventory = playerInventories[player]
	if not inventory then
		loadInventory(player)
		inventory = playerInventories[player]
	end

	amount = math.max(1, math.floor(tonumber(amount) or 1))
	local itemId = ItemCatalog.ResourceId(kind or itemName, itemName, tier, purity)
	local added, total = InventoryService.AddItem(player, itemId, amount)
	if added <= 0 then
		return nil, itemId, 0
	end


	inventory[itemName] = math.max(0, tonumber(inventory[itemName]) or 0) + added
	saveInventory(player)
	return total, itemId, added
end

local function handleGatherRequest(player, nodeInstance)
	local node = findGatherNode(nodeInstance)
	if not node or node:GetAttribute("Depleted") or nodeLocks[node] then
		gatherResult:FireClient(player, false, "Unavailable")
		return
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local nodePosition = getNodePosition(node)
	if not hrp or not nodePosition then
		gatherResult:FireClient(player, false, "Too far")
		return
	end

	local maxDistance = (tonumber(Config.InteractDistance) or 8) + 2
	if (hrp.Position - nodePosition).Magnitude > maxDistance then
		gatherResult:FireClient(player, false, "Too far")
		return
	end

	nodeLocks[node] = true
	local maxTicks = math.max(1, math.floor(tonumber(node:GetAttribute("GatherMaxTicks")) or tonumber(Config.DefaultMaxTicks) or 20))
	local currentTicks = math.clamp(math.floor(tonumber(node:GetAttribute("GatherTicks")) or maxTicks), 0, maxTicks)
	local tickCost = math.max(1, math.floor(tonumber(node:GetAttribute("GatherTickCost")) or tonumber(Config.DefaultTickCost) or 2))
	if currentTicks <= 0 then
		nodeLocks[node] = nil
		setNodeTicks(node, 0)
		gatherResult:FireClient(player, false, "Unavailable")
		return
	end

	local ticksSpent = math.min(tickCost, currentTicks)
	local yieldPerTick = math.max(1, math.floor(tonumber(node:GetAttribute("GatherYieldPerTick")) or tonumber(Config.DefaultYieldPerTick) or 1))
	local itemName = node:GetAttribute("GatherItem") or "Ore"
	local amount = math.max(1, math.floor(ticksSpent * yieldPerTick))
	local tier = node:GetAttribute("Tier") or 1
	local purity = node:GetAttribute("GatherPurity") or "None"
	local total, itemId, granted = grantItem(player, itemName, amount, node:GetAttribute("GatherKind"), tier, purity)
	if not total then
		nodeLocks[node] = nil
		gatherResult:FireClient(player, false, "Inventory full")
		return
	end

	local remainingTicks = math.max(0, currentTicks - ticksSpent)
	setNodeTicks(node, remainingTicks)
	local valorSkillKey = node:GetAttribute("GatherValorSkillKey")
	local valorPerTick = math.max(0, math.floor(tonumber(node:GetAttribute("GatherValorAmount")) or 0))
	local valorAmount = valorPerTick * ticksSpent
	local valorSnapshot
	if valorAmount > 0 then
		valorSnapshot = ValorService.GrantGatheringValor(player, node:GetAttribute("GatherKind"), itemName, valorAmount, valorSkillKey, tier, {
			Item = itemName,
			ItemId = itemId,
			Node = node.Name,
			Tier = tier,
			Purity = purity,
			TicksSpent = ticksSpent,
			TicksRemaining = remainingTicks,
			MaxTicks = maxTicks,
			Position = nodePosition,
			NodePosition = nodePosition,
		})
	end
	CombatStateService.GrantHonor(player, math.max(1, math.floor(tonumber(tier) or 1)), "gathering")

	local itemDef = ItemCatalog.Get(itemId)
	nodeLocks[node] = nil
	gatherResult:FireClient(player, true, itemDef and itemDef.DisplayName or itemName, granted, total, valorSkillKey, valorAmount, valorSnapshot and valorSnapshot.Tier, remainingTicks, maxTicks)
end

gatherRequest.OnServerEvent:Connect(handleGatherRequest)

Players.PlayerAdded:Connect(loadInventory)
Players.PlayerRemoving:Connect(function(player)
	saveInventory(player)
	playerInventories[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadInventory, player)
end

spawnAllNodes()

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveInventory(player)
	end
end)