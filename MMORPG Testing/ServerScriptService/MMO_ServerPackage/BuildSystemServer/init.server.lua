--[[
Name: BuildSystemServer
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.BuildSystemServer
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage, ServerScriptService, ServerStorage, Workspace, TextService
Requires:
  - local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("BuildSystemConfig"))
  - local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
  - local InventoryService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("InventoryStorageService"))
Functions: ensureRemote, roundTenth, v3ToTable, tableToV3, defaultBuildingState, cleanStoredCityName, defaultState, copyCountMap, recipeRequirements, normalizeRecipeProgress, recipeComplete, costRequirements, normalizeCostProgress, costProgressComplete, costProgressPercent, getCostDuration, getReservedZone, getReservedMetrics, getMonolith, getActiveRange, levelOneRingBounds, isLevelOneRingSlot, monolithFootprint, slotBlockedByMonolith, makeSlotId, parseSlotId, isSlotActive, getSlotInfo, getActiveSlots, cleanInstanceId, buildingModelName, makeBuildingInstanceId, normalizeBuildingInstance, sortedBuildingInstanceIds, ensureBuildingSummaries, getBuildingInstance, getOccupiedSlots, sanitizeLoadedState, serializeState, makeClientState, saveState, pushState, depositCityTax, loadState, makeLabel, configureCityModel, getCityModel, rebuildCityShell, countBuildSlotPads, ensureCityShell, ensureBuildingModel, updateBuildingLabel, positionBuilding, updateWorldVisualsForPlayer, characterRoot, distanceToPart, isNearMonolith, isNearSlot, isNearCity, ensureClaimPrompts
Signal classes referenced: RemoteEvent, RemoteFunction, BindableEvent
Clean source lines: 1825
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("BuildSystemConfig"))
local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
local InventoryService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("InventoryStorageService"))

local remotesFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("BuildSystemRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "BuildSystemRemotes"
	remotesFolder.Parent = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
end

local function ensureRemote(className, name)
	local remote = remotesFolder:FindFirstChild(name)
	if remote and remote.ClassName == className then
		return remote
	end
	if remote then
		remote:Destroy()
	end
	remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local actionRemote = ensureRemote("RemoteEvent", "Action")
local stateRemote = ensureRemote("RemoteEvent", "State")
local requestStateRemote = ensureRemote("RemoteFunction", "RequestState")
local openMonolithRemote = ensureRemote("RemoteEvent", "OpenMonolithPanel")

local bindableFolder = ServerStorage:WaitForChild("MMO_ServerStoragePackage"):FindFirstChild("BindableEvents")
if not bindableFolder then
	bindableFolder = Instance.new("Folder")
	bindableFolder.Name = "BindableEvents"
	bindableFolder.Parent = ServerStorage:WaitForChild("MMO_ServerStoragePackage")
end

local CityTaxDepositBindable = bindableFolder:FindFirstChild("CityTaxDeposit")
if not CityTaxDepositBindable then
	CityTaxDepositBindable = Instance.new("BindableEvent")
	CityTaxDepositBindable.Name = "CityTaxDeposit"
	CityTaxDepositBindable.Parent = bindableFolder
end

local worldCities = Workspace:FindFirstChild("WorldCities")
if not worldCities then
	worldCities = Instance.new("Folder")
	worldCities.Name = "WorldCities"
	worldCities.Parent = Workspace
end

local VISUAL_VERSION = 9
local CITY_SAVE_RESET_VERSION = 3
local playerStates = {}
local cityModels = {}
local claimPromptConnections = {}
local completingBuildings = {}
local UPGRADE_COIN_ID = "Coin"

local claimCity

local function roundTenth(n)
	return math.floor((tonumber(n) or 0) * 10 + 0.5) / 10
end

local function v3ToTable(v)
	if typeof(v) ~= "Vector3" then
		return nil
	end
	return { x = v.X, y = v.Y, z = v.Z }
end

local function tableToV3(t)
	if typeof(t) == "Vector3" then
		return t
	end
	if type(t) ~= "table" then
		return nil
	end
	local x = tonumber(t.x or t.X or t[1])
	local y = tonumber(t.y or t.Y or t[2])
	local z = tonumber(t.z or t.Z or t[3])
	if not (x and y and z) then
		return nil
	end
	return Vector3.new(x, y, z)
end

local function defaultBuildingState()
	return {
		id = nil,
		buildingKey = nil,
		placed = false,
		slotId = nil,
		tier = 1,
		completed = false,
		placedAt = 0,
		completedAt = 0,
		recipeProgress = {},
		upgradeProgress = {},
		upgradeStartedAt = 0,
		count = 0,
	}
end

local function cleanStoredCityName(value, fallback)
	local text = tostring(value or "")
	text = text:gsub("[%c\r\n\t]", " "):gsub("%s+", " ")
	text = text:match("^%s*(.-)%s*$") or ""
	text = string.sub(text, 1, 32)
	if text == "" then
		return fallback or "Unfounded City"
	end
	return text
end

local function defaultState()
	local buildings = {}
	for key in pairs(Config.Buildings) do
		buildings[key] = defaultBuildingState()
	end
	return {
		version = 3,
		resetVersion = CITY_SAVE_RESET_VERSION,
		cityPlaced = false,
		cityLevel = 0,
		cityPosition = nil,
		cityName = "Unfounded City",
		ownerUserId = nil,
		ownerName = nil,
		upkeepDue = 0,
		upkeepPerDay = 0,
		taxesCollected = 0,
		taxesAvailable = 0,
		cityUpgradeProgress = {},
		cityUpgradeStartedAt = 0,
		buildings = buildings,
		buildingInstances = {},
		nextBuildingInstanceId = 1,
	}
end

local function copyCountMap(src)
	local out = {}
	if type(src) ~= "table" then
		return out
	end
	for itemId, amount in pairs(src) do
		amount = math.max(0, math.floor(tonumber(amount) or 0))
		if amount > 0 then
			out[tostring(itemId)] = amount
		end
	end
	return out
end

local function recipeRequirements(cfg)
	return Config.CopyRecipe((cfg and cfg.Recipe) or {}).Items
end

local function normalizeRecipeProgress(cfg, progress, completed)
	local requirements = recipeRequirements(cfg)
	local source = copyCountMap(progress)
	local out = {}
	for itemId, required in pairs(requirements) do
		out[itemId] = completed and required or math.clamp(source[itemId] or 0, 0, required)
	end
	return out
end

local function recipeComplete(cfg, progress)
	for itemId, required in pairs(recipeRequirements(cfg)) do
		if math.floor(tonumber(progress and progress[itemId]) or 0) < required then
			return false
		end
	end
	return true
end

local function costRequirements(cost)
	local requirements = {}
	cost = Config.CopyCost(cost)
	local coin = math.max(0, math.floor(tonumber(cost.Coin) or 0))
	if coin > 0 then
		requirements[UPGRADE_COIN_ID] = coin
	end
	for itemId, amount in pairs(cost.Items or {}) do
		amount = math.max(0, math.floor(tonumber(amount) or 0))
		if amount > 0 then
			requirements[tostring(itemId)] = (requirements[tostring(itemId)] or 0) + amount
		end
	end
	return requirements
end

local function normalizeCostProgress(cost, progress, completed)
	local requirements = costRequirements(cost)
	local source = copyCountMap(progress)
	local out = {}
	for itemId, required in pairs(requirements) do
		out[itemId] = completed and required or math.clamp(source[itemId] or 0, 0, required)
	end
	return out
end

local function costProgressComplete(cost, progress)
	for itemId, required in pairs(costRequirements(cost)) do
		if math.floor(tonumber(progress and progress[itemId]) or 0) < required then
			return false
		end
	end
	return true
end

local function costProgressPercent(cost, progress)
	local total = 0
	local filled = 0
	progress = progress or {}
	for itemId, required in pairs(costRequirements(cost)) do
		total += required
		filled += math.clamp(math.floor(tonumber(progress[itemId]) or 0), 0, required)
	end
	if total <= 0 then
		return 1
	end
	return math.clamp(filled / total, 0, 1)
end

local function getCostDuration(cost)
	local total = 0
	for _, required in pairs(costRequirements(cost)) do
		total += required
	end
	return math.max(0, total * (Config.City.RecipeSecondsPerItem or 0.02))
end

local function getReservedZone()
	local generatedWorld = Workspace:FindFirstChild("GeneratedWorld")
	local colliders = generatedWorld and generatedWorld:FindFirstChild("Colliders")
	local zone = colliders and colliders:FindFirstChild("CityReservedZone")
	if zone and zone:IsA("BasePart") then
		return zone
	end
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst.Name == "CityReservedZone" and inst:IsA("BasePart") then
			return inst
		end
	end
	return nil
end

local function getReservedMetrics()
	local zone = getReservedZone()
	local size = zone and zone.Size or Vector3.new(1000, 12, 1000)
	local pos = zone and zone.Position or Vector3.new(0, 0, 0)
	local groundY = pos.Y - size.Y * 0.5
	return zone, size, Vector3.new(pos.X, groundY, pos.Z)
end

local function getMonolith()
	local generatedWorld = Workspace:FindFirstChild("GeneratedWorld")
	local structures = generatedWorld and generatedWorld:FindFirstChild("Structures")
	local monolith = structures and structures:FindFirstChild("CityClaimMonolith")
	if monolith then
		return monolith
	end
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst.Name == "CityClaimMonolith" then
			return inst
		end
	end
	return nil
end

local function getActiveRange(level)
	local divisions = Config.City.GridDivisions
	local sizeLevel = Config.GetCitySlotSizeLevel and Config.GetCitySlotSizeLevel(level) or Config.GetCitySizeLevel(level)
	local first = math.floor((divisions - sizeLevel) / 2) + 1
	return first, first + sizeLevel - 1, sizeLevel
end

local function levelOneRingBounds()
	local mid = math.floor(Config.City.GridDivisions / 2)
	return mid, mid + 1
end

local function isLevelOneRingSlot(row, col)
	local first, last = levelOneRingBounds()
	return row >= first and row <= last and col >= first and col <= last
end

local function monolithFootprint()
	local monolith = getMonolith()
	if not monolith then
		return nil, nil
	end
	if monolith:IsA("Model") then
		return monolith:GetPivot().Position, monolith:GetExtentsSize()
	elseif monolith:IsA("BasePart") then
		return monolith.Position, monolith.Size
	end
	return nil, nil
end

local function slotBlockedByMonolith(position, size)
	local monolithPos, monolithSize = monolithFootprint()
	if not (monolithPos and monolithSize and position and size) then
		return false
	end
	local monoRadius = math.max(monolithSize.X, monolithSize.Z) * 0.5
	local slotRadius = math.max(size.X, size.Z) * 0.5
	local clearance = tonumber(Config.City.MonolithSlotClearance) or 0
	local flatDistance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(monolithPos.X, 0, monolithPos.Z)).Magnitude
	return flatDistance < (monoRadius + slotRadius + clearance)
end

local function makeSlotId(row, col)
	return string.format("R%02dC%02d", row, col)
end

local function parseSlotId(slotId)
	local row, col = tostring(slotId or ""):match("^R(%d%d)C(%d%d)$")
	row = tonumber(row)
	col = tonumber(col)
	if not row or not col then
		return nil, nil
	end
	if row < 1 or row > Config.City.GridDivisions or col < 1 or col > Config.City.GridDivisions then
		return nil, nil
	end
	return row, col
end

local function isSlotActive(level, slotId)
	local row, col = parseSlotId(slotId)
	if not row then
		return false
	end
	local first, last = getActiveRange(level)
	return row >= first and row <= last and col >= first and col <= last
end

local function getSlotInfo(level, slotId)
	if not isSlotActive(level, slotId) then
		return nil
	end
	local row, col = parseSlotId(slotId)
	local _, zoneSize, center = getReservedMetrics()
	local divisions = Config.City.GridDivisions
	local padSize = Config.GetSlotPadSize()
	local cellX = zoneSize.X / math.max(1, divisions)
	local cellZ = zoneSize.Z / math.max(1, divisions)
	local x = center.X - zoneSize.X * 0.5 + (col - 0.5) * cellX
	local z = center.Z - zoneSize.Z * 0.5 + (row - 0.5) * cellZ
	local pos = Vector3.new(x, center.Y + padSize.Y * 0.5, z)
	if slotBlockedByMonolith(pos, padSize) then
		return nil
	end
	return { id = slotId, row = row, col = col, position = pos, size = padSize }
end

local function getActiveSlots(level)
	local slots = {}
	local first, last = getActiveRange(level)
	for row = first, last do
		for col = first, last do
			local slot = getSlotInfo(level, makeSlotId(row, col))
			if slot then
				table.insert(slots, slot)
			end
		end
	end
	return slots
end

local function cleanInstanceId(value)
	local text = tostring(value or "")
	text = text:gsub("[^%w_%-]", "_")
	if text == "" then
		return nil
	end
	return text
end

local function buildingModelName(instanceId)
	return "Building_" .. tostring(cleanInstanceId(instanceId) or "Unknown")
end

local function makeBuildingInstanceId(state)
	state.nextBuildingInstanceId = math.max(1, math.floor(tonumber(state.nextBuildingInstanceId) or 1))
	local id
	repeat
		id = "B" .. tostring(state.nextBuildingInstanceId)
		state.nextBuildingInstanceId += 1
	until not (state.buildingInstances and state.buildingInstances[id])
	return id
end

local function normalizeBuildingInstance(state, rawId, src, fallbackKey)
	if type(src) ~= "table" then
		return nil
	end
	local buildingKey = tostring(src.buildingKey or src.BuildingKey or src.key or fallbackKey or "")
	if buildingKey == "" and Config.Buildings[tostring(rawId or "")] then
		buildingKey = tostring(rawId)
	end
	local cfg = Config.Buildings[buildingKey]
	if not cfg then
		return nil
	end
	local slotId = type(src.slotId) == "string" and src.slotId or type(src.SlotId) == "string" and src.SlotId or nil
	local placed = src.placed ~= false and slotId and getSlotInfo(math.max(1, state.cityLevel), slotId) ~= nil
	if not placed then
		return nil
	end
	local instanceId = cleanInstanceId(src.id or src.instanceId or src.BuildingInstanceId or rawId or makeBuildingInstanceId(state))
	if not instanceId then
		instanceId = makeBuildingInstanceId(state)
	end
	local currentTier = math.clamp(math.floor(tonumber(src.tier or src.Tier) or 1), 1, Config.Building.MaxTier)
	local completed = src.completed == true
	local recipeProgress = normalizeRecipeProgress(cfg, src.recipeProgress, completed)
	if recipeComplete(cfg, recipeProgress) then
		completed = true
		recipeProgress = normalizeRecipeProgress(cfg, recipeProgress, true)
	end
	return {
		id = instanceId,
		buildingKey = buildingKey,
		placed = true,
		slotId = slotId,
		tier = currentTier,
		completed = completed == true,
		placedAt = tonumber(src.placedAt) or 0,
		completedAt = tonumber(src.completedAt) or 0,
		recipeProgress = recipeProgress,
		upgradeProgress = normalizeCostProgress(Config.GetBuildingUpgradeCost(currentTier), src.upgradeProgress, false),
		upgradeStartedAt = math.max(0, tonumber(src.upgradeStartedAt) or 0),
	}
end

local function sortedBuildingInstanceIds(state)
	local ids = {}
	for instanceId, building in pairs((state and state.buildingInstances) or {}) do
		if building and building.placed then
			table.insert(ids, tostring(instanceId))
		end
	end
	table.sort(ids, function(a, b)
		local ba = state.buildingInstances[a]
		local bb = state.buildingInstances[b]
		local ca = ba and Config.Buildings[ba.buildingKey]
		local cb = bb and Config.Buildings[bb.buildingKey]
		local oa = ca and ca.Order or 999
		local ob = cb and cb.Order or 999
		if oa == ob then
			return tostring(a) < tostring(b)
		end
		return oa < ob
	end)
	return ids
end

local function ensureBuildingSummaries(state)
	local summaries = {}
	for key in pairs(Config.Buildings) do
		local summary = defaultBuildingState()
		summary.buildingKey = key
		summaries[key] = summary
	end
	for _, instanceId in ipairs(sortedBuildingInstanceIds(state)) do
		local building = state.buildingInstances[instanceId]
		local summary = summaries[building.buildingKey]
		if summary then
			summary.count = (summary.count or 0) + 1
			if not summary.placed or (summary.completed and not building.completed) then
				summary.id = instanceId
				summary.placed = true
				summary.slotId = building.slotId
				summary.tier = building.tier or 1
				summary.completed = building.completed == true
				summary.placedAt = building.placedAt or 0
				summary.completedAt = building.completedAt or 0
				summary.recipeProgress = building.recipeProgress or {}
				summary.upgradeProgress = building.upgradeProgress or {}
				summary.upgradeStartedAt = building.upgradeStartedAt or 0
			end
		end
	end
	state.buildings = summaries
	return summaries
end

local function getBuildingInstance(state, instanceId)
	instanceId = cleanInstanceId(instanceId)
	if not (state and instanceId and state.buildingInstances) then
		return nil
	end
	return state.buildingInstances[instanceId]
end

local function getOccupiedSlots(state)
	local occupied = {}
	for _, building in pairs((state and state.buildingInstances) or {}) do
		if building.placed and building.slotId and getSlotInfo(state.cityLevel, building.slotId) then
			occupied[building.slotId] = true
		end
	end
	return occupied
end

local function sanitizeLoadedState(data)
	local state = defaultState()
	if type(data) ~= "table" then
		return state, false
	end
	if math.floor(tonumber(data.resetVersion) or 0) ~= CITY_SAVE_RESET_VERSION then
		return state, true
	end
	state.cityPlaced = data.cityPlaced == true
	state.cityLevel = math.clamp(math.floor(tonumber(data.cityLevel) or (state.cityPlaced and 1 or 0)), 0, Config.City.MaxLevel)
	if state.cityPlaced and state.cityLevel < 1 then
		state.cityLevel = 1
	end
	state.cityPosition = tableToV3(data.cityPosition)
	state.cityName = cleanStoredCityName(data.cityName, state.cityPlaced and "Founded City" or "Unfounded City")
	state.ownerUserId = data.ownerUserId
	state.ownerName = data.ownerName
	state.upkeepDue = math.max(0, math.floor(tonumber(data.upkeepDue) or 0))
	state.upkeepPerDay = math.max(0, math.floor(tonumber(data.upkeepPerDay) or 0))
	state.taxesCollected = math.max(0, math.floor(tonumber(data.taxesCollected) or 0))
	state.taxesAvailable = math.max(0, math.floor(tonumber(data.taxesAvailable) or 0))
	state.cityUpgradeProgress = normalizeCostProgress(Config.GetCityUpgradeCost(state.cityLevel), data.cityUpgradeProgress, false)
	state.cityUpgradeStartedAt = math.max(0, tonumber(data.cityUpgradeStartedAt) or 0)
	state.nextBuildingInstanceId = math.max(1, math.floor(tonumber(data.nextBuildingInstanceId) or 1))
	if state.cityPlaced then
		local _, _, center = getReservedMetrics()
		state.cityPosition = center
	end
	local loadedAny = false
	if type(data.buildingInstances) == "table" then
		for rawId, src in pairs(data.buildingInstances) do
			local building = normalizeBuildingInstance(state, rawId, src)
			if building then
				state.buildingInstances[building.id] = building
				loadedAny = true
			end
		end
	end
	if not loadedAny and type(data.buildings) == "table" then
		for key in pairs(Config.Buildings) do
			local src = data.buildings[key]
			if type(src) == "table" and src.placed == true then
				local legacy = table.clone(src)
				legacy.id = "Legacy_" .. tostring(key)
				legacy.buildingKey = key
				local building = normalizeBuildingInstance(state, legacy.id, legacy, key)
				if building then
					state.buildingInstances[building.id] = building
				end
			end
		end
	end
	local highestNumeric = state.nextBuildingInstanceId - 1
	for instanceId in pairs(state.buildingInstances) do
		local n = tostring(instanceId):match("^B(%d+)$")
		if n then
			highestNumeric = math.max(highestNumeric, tonumber(n) or 0)
		end
	end
	state.nextBuildingInstanceId = highestNumeric + 1
	ensureBuildingSummaries(state)
	return state, false
end

local function serializeState(state)
	ensureBuildingSummaries(state)
	local out = {
		version = 4,
		resetVersion = CITY_SAVE_RESET_VERSION,
		cityPlaced = state.cityPlaced == true,
		cityLevel = math.clamp(math.floor(tonumber(state.cityLevel) or 0), 0, Config.City.MaxLevel),
		cityPosition = v3ToTable(state.cityPosition),
		cityName = cleanStoredCityName(state.cityName, state.cityPlaced and "Founded City" or "Unfounded City"),
		ownerUserId = state.ownerUserId,
		ownerName = state.ownerName,
		upkeepDue = math.max(0, math.floor(tonumber(state.upkeepDue) or 0)),
		upkeepPerDay = math.max(0, math.floor(tonumber(state.upkeepPerDay) or 0)),
		taxesCollected = math.max(0, math.floor(tonumber(state.taxesCollected) or 0)),
		taxesAvailable = math.max(0, math.floor(tonumber(state.taxesAvailable) or 0)),
		cityUpgradeProgress = normalizeCostProgress(Config.GetCityUpgradeCost(state.cityLevel), state.cityUpgradeProgress, false),
		cityUpgradeStartedAt = math.max(0, tonumber(state.cityUpgradeStartedAt) or 0),
		nextBuildingInstanceId = math.max(1, math.floor(tonumber(state.nextBuildingInstanceId) or 1)),
		buildings = {},
		buildingInstances = {},
	}
	for key in pairs(Config.Buildings) do
		local building = state.buildings[key] or defaultBuildingState()
		out.buildings[key] = {
			placed = building.placed == true,
			slotId = building.slotId,
			tier = math.clamp(math.floor(tonumber(building.tier) or 1), 1, Config.Building.MaxTier),
			completed = building.completed == true,
			placedAt = tonumber(building.placedAt) or 0,
			completedAt = tonumber(building.completedAt) or 0,
			recipeProgress = normalizeRecipeProgress(Config.Buildings[key], building.recipeProgress, building.completed == true),
			upgradeProgress = normalizeCostProgress(Config.GetBuildingUpgradeCost(building.tier or 1), building.upgradeProgress, false),
			upgradeStartedAt = math.max(0, tonumber(building.upgradeStartedAt) or 0),
			count = math.max(0, math.floor(tonumber(building.count) or 0)),
		}
	end
	for _, instanceId in ipairs(sortedBuildingInstanceIds(state)) do
		local building = state.buildingInstances[instanceId]
		local cfg = Config.Buildings[building.buildingKey]
		if cfg then
			out.buildingInstances[instanceId] = {
				id = instanceId,
				buildingKey = building.buildingKey,
				placed = building.placed == true,
				slotId = building.slotId,
				tier = math.clamp(math.floor(tonumber(building.tier) or 1), 1, Config.Building.MaxTier),
				completed = building.completed == true,
				placedAt = tonumber(building.placedAt) or 0,
				completedAt = tonumber(building.completedAt) or 0,
				recipeProgress = normalizeRecipeProgress(cfg, building.recipeProgress, building.completed == true),
				upgradeProgress = normalizeCostProgress(Config.GetBuildingUpgradeCost(building.tier or 1), building.upgradeProgress, false),
				upgradeStartedAt = math.max(0, tonumber(building.upgradeStartedAt) or 0),
			}
		end
	end
	return out
end

local function makeClientState(state, message)
	ensureBuildingSummaries(state)
	local occupied = getOccupiedSlots(state)
	local slots = {}
	if state.cityPlaced then
		for _, slot in ipairs(getActiveSlots(state.cityLevel)) do
			table.insert(slots, {
				id = slot.id,
				row = slot.row,
				col = slot.col,
				position = v3ToTable(slot.position),
				size = v3ToTable(slot.size),
				occupied = occupied[slot.id] == true,
			})
		end
	end
	local buildings = {}
	for key, cfg in pairs(Config.Buildings) do
		local building = state.buildings[key] or defaultBuildingState()
		buildings[key] = {
			key = key,
			displayName = cfg.DisplayName,
			shortName = cfg.ShortName or cfg.DisplayName,
			order = cfg.Order or 999,
			duration = Config.GetRecipeDuration(cfg.Recipe),
			placed = building.placed == true,
			count = math.max(0, math.floor(tonumber(building.count) or 0)),
			slotId = building.slotId,
			tier = math.clamp(math.floor(tonumber(building.tier) or 1), 1, Config.Building.MaxTier),
			completed = building.completed == true,
			costs = Config.CopyCost(cfg.PlaceCost or cfg.Costs),
			upgradeCost = Config.GetBuildingUpgradeCost(building.tier or 1),
			upgradeProgress = normalizeCostProgress(Config.GetBuildingUpgradeCost(building.tier or 1), building.upgradeProgress, false),
			upgradePercent = costProgressPercent(Config.GetBuildingUpgradeCost(building.tier or 1), building.upgradeProgress),
			upgradeStartedAt = math.max(0, tonumber(building.upgradeStartedAt) or 0),
			recipe = Config.CopyRecipe(cfg.Recipe),
			recipeProgress = normalizeRecipeProgress(cfg, building.recipeProgress, building.completed == true),
			size = v3ToTable(cfg.Size),
			color = cfg.Color,
			craftingSkillKey = cfg.CraftingSkillKey,
			craftingStationKey = cfg.CraftingStationKey,
		}
	end
	local instances = {}
	for _, instanceId in ipairs(sortedBuildingInstanceIds(state)) do
		local building = state.buildingInstances[instanceId]
		local cfg = Config.Buildings[building.buildingKey]
		if cfg then
			table.insert(instances, {
				id = instanceId,
				buildingKey = building.buildingKey,
				displayName = cfg.DisplayName,
				shortName = cfg.ShortName or cfg.DisplayName,
				order = cfg.Order or 999,
				duration = Config.GetRecipeDuration(cfg.Recipe),
				slotId = building.slotId,
				tier = math.clamp(math.floor(tonumber(building.tier) or 1), 1, Config.Building.MaxTier),
				maxTier = Config.Building.MaxTier,
				completed = building.completed == true,
				costs = Config.CopyCost(cfg.PlaceCost or cfg.Costs),
				upgradeCost = Config.GetBuildingUpgradeCost(building.tier or 1),
				upgradeProgress = normalizeCostProgress(Config.GetBuildingUpgradeCost(building.tier or 1), building.upgradeProgress, false),
				upgradePercent = costProgressPercent(Config.GetBuildingUpgradeCost(building.tier or 1), building.upgradeProgress),
				upgradeStartedAt = math.max(0, tonumber(building.upgradeStartedAt) or 0),
				recipe = Config.CopyRecipe(cfg.Recipe),
				recipeProgress = normalizeRecipeProgress(cfg, building.recipeProgress, building.completed == true),
				size = v3ToTable(cfg.Size),
				color = cfg.Color,
				craftingSkillKey = cfg.CraftingSkillKey,
				craftingStationKey = cfg.CraftingStationKey,
			})
		end
	end
	return {
		version = 4,
		cityPlaced = state.cityPlaced == true,
		cityLevel = state.cityLevel or 0,
		cityMaxLevel = Config.City.MaxLevel,
		citySizeLevel = Config.GetCitySizeLevel(state.cityLevel),
		cityPosition = v3ToTable(state.cityPosition),
		cityName = cleanStoredCityName(state.cityName, state.cityPlaced and "Founded City" or "Unfounded City"),
		ownerUserId = state.cityPlaced and state.ownerUserId or nil,
		ownerName = state.cityPlaced and state.ownerName or nil,
		claimCost = Config.CopyCost(Config.City.ClaimCost),
		upgradeCost = Config.GetCityUpgradeCost(state.cityLevel),
		upgradeProgress = normalizeCostProgress(Config.GetCityUpgradeCost(state.cityLevel), state.cityUpgradeProgress, false),
		upgradePercent = costProgressPercent(Config.GetCityUpgradeCost(state.cityLevel), state.cityUpgradeProgress),
		upgradeStartedAt = math.max(0, tonumber(state.cityUpgradeStartedAt) or 0),
		buildingMaxTier = Config.Building.MaxTier,
		upkeep = {
			Due = math.max(0, math.floor(tonumber(state.upkeepDue) or 0)),
			PerDay = math.max(0, math.floor(tonumber(state.upkeepPerDay) or 0)),
		},
		taxes = {
			Collected = math.max(0, math.floor(tonumber(state.taxesCollected) or 0)),
			Available = math.max(0, math.floor(tonumber(state.taxesAvailable) or 0)),
		},
		buildings = buildings,
		buildingInstances = instances,
		slots = slots,
		message = message,
	}
end

local function saveState(player)
	local state = playerStates[player]
	if state then
		ProfileService.SetSection(player, "City", serializeState(state))
	end
end

local function pushState(player, message)
	local state = playerStates[player]
	if state then
		stateRemote:FireClient(player, makeClientState(state, message))
	end
end

local function depositCityTax(amount, source)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then return end
	local sourceOwnerId = type(source) == "table" and tonumber(source.OwnerUserId or source.CityOwnerUserId) or nil
	local targetPlayer
	for player, state in pairs(playerStates) do
		if state and state.cityPlaced == true and (not sourceOwnerId or player.UserId == sourceOwnerId or tonumber(state.ownerUserId) == sourceOwnerId) then
			targetPlayer = player
			break
		end
	end
	if not targetPlayer then
		for player, state in pairs(playerStates) do
			if state and state.cityPlaced == true then
				targetPlayer = player
				break
			end
		end
	end
	if not targetPlayer then return end
	local state = playerStates[targetPlayer]
	state.taxesCollected = math.max(0, math.floor(tonumber(state.taxesCollected) or 0)) + amount
	state.taxesAvailable = math.max(0, math.floor(tonumber(state.taxesAvailable) or 0)) + amount
	saveState(targetPlayer)
	pushState(targetPlayer, "Auction taxes collected.")
end

CityTaxDepositBindable.Event:Connect(depositCityTax)

local function loadState(player)
	local data = ProfileService.GetSection(player, "City", function()
		return serializeState(defaultState())
	end)
	local state, reset = sanitizeLoadedState(data)
	if state.cityPlaced then
		state.ownerUserId = player.UserId
		state.ownerName = player.DisplayName ~= "" and player.DisplayName or player.Name
	end
	playerStates[player] = state
	if reset then
		ProfileService.SetSection(player, "City", serializeState(state))
	end
end

local function makeLabel(parent, titleText, subText, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(190, 48)
	gui.StudsOffset = offset or Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent
	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.BackgroundColor3 = Color3.fromRGB(14, 10, 10)
	frame.BackgroundTransparency = 0.08
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(232, 176, 64)
	stroke.Transparency = 0.15
	stroke.Parent = frame
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(6, 2)
	title.Size = UDim2.new(1, -12, 0.52, 0)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(242, 228, 198)
	title.TextScaled = true
	title.Text = titleText or ""
	title.Parent = frame
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.new(0, 6, 0.52, 0)
	sub.Size = UDim2.new(1, -12, 0.42, 0)
	sub.Font = Enum.Font.Gotham
	sub.TextColor3 = Color3.fromRGB(210, 196, 166)
	sub.TextScaled = true
	sub.Text = subText or ""
	sub.Parent = frame
	return gui
end

local function configureCityModel(model)
	if not model then
		return
	end
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
end

local function getCityModel(player)
	local name = "City_" .. player.UserId
	local model = cityModels[player]
	if not model or not model.Parent then
		model = worldCities:FindFirstChild(name)
	end
	if not model then
		model = Instance.new("Model")
		model.Name = name
		model.Parent = worldCities
	end
	configureCityModel(model)
	cityModels[player] = model
	return model
end

local function rebuildCityShell(player, state, model)
	configureCityModel(model)
	model:ClearAllChildren()
	model:SetAttribute("CityVisualVersion", VISUAL_VERSION)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("CityLevel", state.cityLevel)
	model:SetAttribute("CitySizeLevel", Config.GetCitySizeLevel(state.cityLevel))
	model:SetAttribute("CityName", cleanStoredCityName(state.cityName, player.Name .. "'s City"))

	local _, zoneSize, center = getReservedMetrics()
	local size = Config.GetCityLevelSize(zoneSize, state.cityLevel)

	local base = Instance.new("Part")
	base.Name = "CityBase"
	base.Anchored = true
	base.CanCollide = true
	base.Material = Enum.Material.Slate
	base.Color = Color3.fromRGB(62, 69, 72)
	base.Size = size
	base.Position = Vector3.new(center.X, center.Y - size.Y * 0.5, center.Z)
	base:SetAttribute("OwnerUserId", player.UserId)
	base.Parent = model

	local labelHolder = Instance.new("Part")
	labelHolder.Name = "CityLabelHolder"
	labelHolder.Anchored = true
	labelHolder.CanCollide = false
	labelHolder.Transparency = 1
	labelHolder.Size = Vector3.new(1, 1, 1)
	labelHolder.Position = Vector3.new(center.X, center.Y + size.Y + 6, center.Z)
	labelHolder.Parent = model
	makeLabel(labelHolder, cleanStoredCityName(state.cityName, player.Name .. "'s City"), "Level " .. tostring(state.cityLevel), Vector3.new(0, 0, 0))

	local createdSlots = 0
	for _, slot in ipairs(getActiveSlots(state.cityLevel)) do
		local pad = Instance.new("Part")
		pad.Name = "Slot_" .. slot.id
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanQuery = true
		pad.CanTouch = false
		pad.CastShadow = false
		pad.Material = Enum.Material.Neon
		pad.Color = Color3.fromRGB(88, 188, 116)
		pad.Transparency = 0.58
		pad.Size = slot.size
		pad.Position = slot.position
		pad:SetAttribute("BuildSlot", true)
		pad:SetAttribute("CitySlotId", slot.id)
		pad:SetAttribute("OwnerUserId", player.UserId)
		pad.Parent = model
		createdSlots += 1
	end
	model:SetAttribute("BuildSlotCount", createdSlots)
end

local function countBuildSlotPads(model)
	local count = 0
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") and child:GetAttribute("BuildSlot") == true then
			count += 1
		end
	end
	return count
end

local function ensureCityShell(player, state)
	local model = getCityModel(player)
	local expectedSlots = #getActiveSlots(state.cityLevel)
	local actualSlots = countBuildSlotPads(model)
	model:SetAttribute("ExpectedBuildSlotCount", expectedSlots)
	if model:GetAttribute("CityVisualVersion") ~= VISUAL_VERSION
		or model:GetAttribute("CityLevel") ~= state.cityLevel
		or model:GetAttribute("CityName") ~= cleanStoredCityName(state.cityName, player.Name .. "'s City")
		or model:GetAttribute("OwnerUserId") ~= player.UserId
		or actualSlots ~= expectedSlots then
		rebuildCityShell(player, state, model)
	else
		model:SetAttribute("BuildSlotCount", actualSlots)
	end
	return model
end

local function ensureBuildingModel(model, instanceId, buildingKey, cfg)
	local name = buildingModelName(instanceId)
	local building = model:FindFirstChild(name)
	if building then
		building:SetAttribute("BuildingInstanceId", instanceId)
		building:SetAttribute("BuildingKey", buildingKey)
		return building
	end
	building = Instance.new("Model")
	building.Name = name
	building:SetAttribute("BuildingInstanceId", instanceId)
	building:SetAttribute("BuildingKey", buildingKey)
	building.Parent = model

	local foundation = Instance.new("Part")
	foundation.Name = "Foundation"
	foundation.Anchored = true
	foundation.CanCollide = true
	foundation.Material = Enum.Material.Basalt
	foundation.Color = Color3.fromRGB(50, 48, 46)
	foundation.Parent = building

	local main = Instance.new("Part")
	main.Name = "Main"
	main.Anchored = true
	main.CanCollide = true
	main.Material = Enum.Material.SmoothPlastic
	main.Color = cfg.Color or Color3.fromRGB(155, 126, 95)
	main.Parent = building

	local roof = Instance.new("WedgePart")
	roof.Name = "Roof"
	roof.Anchored = true
	roof.CanCollide = true
	roof.Material = Enum.Material.WoodPlanks
	roof.Color = Color3.fromRGB(86, 54, 42)
	roof.Parent = building

	local detector = Instance.new("Part")
	detector.Name = "Detector"
	detector.Anchored = true
	detector.CanCollide = false
	detector.CanQuery = true
	detector.CanTouch = false
	detector.Transparency = 1
	detector.Size = cfg.Size + Vector3.new(5, 5, 5)
	detector:SetAttribute("BuildingInstanceId", instanceId)
	detector:SetAttribute("BuildingKey", buildingKey)
	detector:SetAttribute("CraftingStationKey", cfg.CraftingStationKey)
	detector.Parent = building

	building.PrimaryPart = main
	return building
end

local function updateBuildingLabel(building, cfg, tier, completed)
	local labelHolder = building and building:FindFirstChild("LabelHolder")
	if labelHolder then
		labelHolder:Destroy()
	end
end

local function positionBuilding(model, instanceId, buildingKey, slot, cfg, player, buildingState)
	local building = ensureBuildingModel(model, instanceId, buildingKey, cfg)
	local tier = math.clamp(math.floor(tonumber(buildingState and buildingState.tier) or 1), 1, Config.Building.MaxTier)
	building:SetAttribute("OwnerUserId", player.UserId)
	building:SetAttribute("CitySlotId", slot.id)
	building:SetAttribute("Tier", tier)
	building:SetAttribute("StationTier", tier)
	building:SetAttribute("Completed", buildingState and buildingState.completed == true)

	local isComplete = buildingState and buildingState.completed == true
	local padTop = slot.position.Y + slot.size.Y * 0.5
	local foundation = building:FindFirstChild("Foundation")
	if foundation then
		foundation.Size = Vector3.new(cfg.Size.X, 0.8, cfg.Size.Z)
		foundation.Position = Vector3.new(slot.position.X, padTop + 0.4, slot.position.Z)
		foundation:SetAttribute("BuildingInstanceId", instanceId)
		foundation:SetAttribute("BuildingKey", buildingKey)
	end
	local main = building:FindFirstChild("Main")
	if main then
		main.Size = cfg.Size
		main.Position = Vector3.new(slot.position.X, padTop + cfg.Size.Y * 0.5 + 0.8, slot.position.Z)
		main.Transparency = isComplete and 0 or 0.45
		main:SetAttribute("BuildingInstanceId", instanceId)
		main:SetAttribute("BuildingKey", buildingKey)
	end
	local roof = building:FindFirstChild("Roof")
	if roof then
		roof.Size = Vector3.new(cfg.Size.X, math.max(4, cfg.Size.Y * 0.22), cfg.Size.Z)
		roof.CFrame = CFrame.new(slot.position.X, padTop + cfg.Size.Y + 2.8, slot.position.Z)
		roof.Transparency = isComplete and 0 or 0.45
		roof:SetAttribute("BuildingInstanceId", instanceId)
		roof:SetAttribute("BuildingKey", buildingKey)
	end
	updateBuildingLabel(building, cfg, tier, isComplete)
	local detector = building:FindFirstChild("Detector")
	if detector and detector:IsA("BasePart") then
		detector.Size = cfg.Size + Vector3.new(5, 5, 5)
		detector.Position = Vector3.new(slot.position.X, padTop + cfg.Size.Y * 0.5 + 1.6, slot.position.Z)
		detector:SetAttribute("BuildingInstanceId", instanceId)
		detector:SetAttribute("BuildingKey", buildingKey)
		detector:SetAttribute("CraftingStationKey", cfg.CraftingStationKey)
		detector:SetAttribute("StationTier", tier)
		detector:SetAttribute("Completed", isComplete)
		detector:SetAttribute("OwnerUserId", player.UserId)
	end
end

local function updateWorldVisualsForPlayer(player)
	local state = playerStates[player]
	local existing = cityModels[player] or worldCities:FindFirstChild("City_" .. player.UserId)
	if not state or not state.cityPlaced then
		if existing then
			existing:Destroy()
			cityModels[player] = nil
		end
		return
	end
	local model = ensureCityShell(player, state)
	local occupied = getOccupiedSlots(state)
	for _, pad in ipairs(model:GetDescendants()) do
		if pad:IsA("BasePart") and pad:GetAttribute("BuildSlot") then
			pad.Transparency = occupied[pad:GetAttribute("CitySlotId")] and 0.86 or 0.58
			pad.Color = occupied[pad:GetAttribute("CitySlotId")] and Color3.fromRGB(90, 92, 96) or Color3.fromRGB(88, 188, 116)
		end
	end
	local live = {}
	for _, instanceId in ipairs(sortedBuildingInstanceIds(state)) do
		local building = state.buildingInstances[instanceId]
		local cfg = building and Config.Buildings[building.buildingKey]
		local slot = building and building.slotId and getSlotInfo(state.cityLevel, building.slotId)
		if cfg and slot then
			local name = buildingModelName(instanceId)
			live[name] = true
			positionBuilding(model, instanceId, building.buildingKey, slot, cfg, player, building)
		end
	end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("BuildingKey") and not live[child.Name] then
			child:Destroy()
		end
	end
end

local function characterRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function distanceToPart(position, part)
	local localPoint = part.CFrame:PointToObjectSpace(position)
	local half = part.Size * 0.5
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		math.clamp(localPoint.Y, -half.Y, half.Y),
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	local closest = part.CFrame:PointToWorldSpace(clamped)
	return (position - closest).Magnitude
end

local function isNearMonolith(player)
	local root = characterRoot(player)
	local monolith = getMonolith()
	if not root or not monolith then
		return false
	end
	if monolith:IsA("BasePart") and distanceToPart(root.Position, monolith) <= Config.City.ClaimDistance then
		return true
	end
	for _, inst in ipairs(monolith:GetDescendants()) do
		if inst:IsA("BasePart") and distanceToPart(root.Position, inst) <= Config.City.ClaimDistance then
			return true
		end
	end
	return false
end

local function isNearSlot(player, state, slotId)
	local root = characterRoot(player)
	local slot = getSlotInfo(state.cityLevel, slotId)
	if not root or not slot then
		return false
	end
	return (root.Position - slot.position).Magnitude <= Config.City.BuildPlaceDistance
end

local function isNearCity(player, state)
	local root = characterRoot(player)
	if not root or not state.cityPosition then
		return false
	end
	local _, zoneSize, center = getReservedMetrics()
	local citySize = Config.GetCityLevelSize(zoneSize, state.cityLevel)
	local radius = math.max(citySize.X, citySize.Z) * 0.5 + Config.City.UpgradeDistancePadding
	return (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude <= radius
end

local function ensureClaimPrompts()
	local monolith = getMonolith()
	if not monolith then
		return
	end
	local parts = {}
	if monolith:IsA("BasePart") then
		table.insert(parts, monolith)
	end
	for _, inst in ipairs(monolith:GetDescendants()) do
		if inst:IsA("BasePart") then
			table.insert(parts, inst)
		end
	end
	for _, part in ipairs(parts) do
		local prompt = part:FindFirstChild("CityClaimPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "CityClaimPrompt"
			prompt.Parent = part
		end
		prompt.ActionText = "Open City"
		prompt.ObjectText = "City Monolith"
		prompt.HoldDuration = 0.35
		prompt.MaxActivationDistance = Config.City.ClaimDistance
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Enabled = true
		prompt:SetAttribute("CityClaimPrompt", true)
		prompt:SetAttribute("ClaimCostText", Config.CostToText(Config.City.ClaimCost))
		if not claimPromptConnections[prompt] then
			claimPromptConnections[prompt] = prompt.Triggered:Connect(function(player)
				if isNearMonolith(player) then
					openMonolithRemote:FireClient(player)
				end
			end)
		end
		local click = part:FindFirstChild("CityMonolithClick")
		if not click then
			click = Instance.new("ClickDetector")
			click.Name = "CityMonolithClick"
			click.Parent = part
		end
		click.MaxActivationDistance = Config.City.ClaimDistance
		if not claimPromptConnections[click] then
			claimPromptConnections[click] = click.MouseClick:Connect(function(player)
				if isNearMonolith(player) then
					openMonolithRemote:FireClient(player)
				end
			end)
		end
	end
end

local function spendCost(player, cost)
	local ok, err = InventoryService.SpendCosts(player, Config.CopyCost(cost))
	return ok == true, err
end

local function spendCostContribution(player, cost, progress, itemId)
	itemId = tostring(itemId or "")
	local required = costRequirements(cost)[itemId]
	if not required then
		return 0, "That requirement is not part of this upgrade."
	end
	progress = normalizeCostProgress(cost, progress, false)
	local remaining = required - math.floor(tonumber(progress[itemId]) or 0)
	if remaining <= 0 then
		return 0, "That requirement is already filled."
	end
	local amount = remaining
	if itemId ~= UPGRADE_COIN_ID then
		amount = math.min(InventoryService.CountItem(player, itemId), remaining)
	end
	if amount <= 0 then
		return 0, "You do not have that requirement."
	end
	local spend = itemId == UPGRADE_COIN_ID and { Coin = amount } or { Items = { [itemId] = amount } }
	local ok, err = spendCost(player, spend)
	if not ok then
		return 0, err or "Could not add upgrade requirement."
	end
	return amount
end

local function resolveBuildingFromPayload(state, payload, preferIncomplete)
	payload = type(payload) == "table" and payload or {}
	local instanceId = cleanInstanceId(payload.BuildingInstanceId or payload.InstanceId or payload.instanceId)
	local building = getBuildingInstance(state, instanceId)
	if building then
		return instanceId, building
	end
	local buildingKey = tostring(payload.BuildingKey or payload.buildingKey or "")
	if buildingKey == "" then
		return nil, nil
	end
	local fallbackId, fallbackBuilding
	for _, id in ipairs(sortedBuildingInstanceIds(state)) do
		local candidate = state.buildingInstances[id]
		if candidate and candidate.buildingKey == buildingKey then
			if preferIncomplete and not candidate.completed then
				return id, candidate
			end
			fallbackId = fallbackId or id
			fallbackBuilding = fallbackBuilding or candidate
		end
	end
	return fallbackId, fallbackBuilding
end

local function scheduleBuildingCompletion(player, instanceId)
	local state = playerStates[player]
	local building = getBuildingInstance(state, instanceId)
	local cfg = building and Config.Buildings[building.buildingKey]
	if not (state and cfg and building and building.placed and not building.completed) then
		return
	end
	building.recipeProgress = normalizeRecipeProgress(cfg, building.recipeProgress, false)
	if not recipeComplete(cfg, building.recipeProgress) then
		return
	end
	local key = tostring(player.UserId) .. ":" .. tostring(instanceId)
	if completingBuildings[key] then
		return
	end
	completingBuildings[key] = true
	local delaySeconds = math.max(0, Config.GetRecipeDuration(cfg.Recipe))
	task.delay(delaySeconds, function()
		completingBuildings[key] = nil
		local latestState = playerStates[player]
		local latestBuilding = getBuildingInstance(latestState, instanceId)
		local latestCfg = latestBuilding and Config.Buildings[latestBuilding.buildingKey]
		if latestCfg and latestBuilding and latestBuilding.placed and not latestBuilding.completed then
			latestBuilding.recipeProgress = normalizeRecipeProgress(latestCfg, latestBuilding.recipeProgress, false)
			if recipeComplete(latestCfg, latestBuilding.recipeProgress) then
				latestBuilding.completed = true
				latestBuilding.completedAt = os.time()
				latestBuilding.recipeProgress = normalizeRecipeProgress(latestCfg, latestBuilding.recipeProgress, true)
				ensureBuildingSummaries(latestState)
				updateWorldVisualsForPlayer(player)
				saveState(player)
				pushState(player, latestCfg.DisplayName .. " completed.")
			end
		end
	end)
end

local function scheduleCityUpgrade(player)
	local state = playerStates[player]
	if not (state and state.cityPlaced) then
		return
	end
	local currentLevel = math.clamp(math.floor(tonumber(state.cityLevel) or 0), 0, Config.City.MaxLevel)
	if currentLevel >= Config.City.MaxLevel then
		return
	end
	local cost = Config.GetCityUpgradeCost(currentLevel)
	state.cityUpgradeProgress = normalizeCostProgress(cost, state.cityUpgradeProgress, false)
	if not costProgressComplete(cost, state.cityUpgradeProgress) then
		return
	end
	local key = tostring(player.UserId) .. ":CityUpgrade"
	if completingBuildings[key] then
		return
	end
	completingBuildings[key] = true
	state.cityUpgradeStartedAt = os.time()
	saveState(player)
	pushState(player, "City upgrade started.")
	local delaySeconds = getCostDuration(cost)
	task.delay(delaySeconds, function()
		completingBuildings[key] = nil
		local latestState = playerStates[player]
		if not (latestState and latestState.cityPlaced) then
			return
		end
		local latestLevel = math.clamp(math.floor(tonumber(latestState.cityLevel) or 0), 0, Config.City.MaxLevel)
		if latestLevel ~= currentLevel or latestLevel >= Config.City.MaxLevel then
			return
		end
		local latestCost = Config.GetCityUpgradeCost(latestLevel)
		latestState.cityUpgradeProgress = normalizeCostProgress(latestCost, latestState.cityUpgradeProgress, false)
		if not costProgressComplete(latestCost, latestState.cityUpgradeProgress) then
			latestState.cityUpgradeStartedAt = 0
			saveState(player)
			pushState(player, "City upgrade paused. Fill the missing requirements.")
			return
		end
		latestState.cityLevel = latestLevel + 1
		latestState.cityUpgradeProgress = normalizeCostProgress(Config.GetCityUpgradeCost(latestState.cityLevel), {}, false)
		latestState.cityUpgradeStartedAt = 0
		ensureBuildingSummaries(latestState)
		updateWorldVisualsForPlayer(player)
		saveState(player)
		pushState(player, "City upgraded to level " .. tostring(latestState.cityLevel) .. ".")
	end)
end

local function scheduleBuildingUpgrade(player, instanceId)
	local state = playerStates[player]
	local building = getBuildingInstance(state, instanceId)
	local cfg = building and Config.Buildings[building.buildingKey]
	if not (state and state.cityPlaced and cfg and building and building.placed and building.completed) then
		return
	end
	local currentTier = math.clamp(math.floor(tonumber(building.tier) or 1), 1, Config.Building.MaxTier)
	if currentTier >= Config.Building.MaxTier then
		return
	end
	local cost = Config.GetBuildingUpgradeCost(currentTier)
	building.upgradeProgress = normalizeCostProgress(cost, building.upgradeProgress, false)
	if not costProgressComplete(cost, building.upgradeProgress) then
		return
	end
	local key = tostring(player.UserId) .. ":BuildingUpgrade:" .. tostring(instanceId)
	if completingBuildings[key] then
		return
	end
	completingBuildings[key] = true
	building.upgradeStartedAt = os.time()
	ensureBuildingSummaries(state)
	saveState(player)
	pushState(player, cfg.DisplayName .. " upgrade started.")
	local delaySeconds = getCostDuration(cost)
	task.delay(delaySeconds, function()
		completingBuildings[key] = nil
		local latestState = playerStates[player]
		local latestBuilding = getBuildingInstance(latestState, instanceId)
		local latestCfg = latestBuilding and Config.Buildings[latestBuilding.buildingKey]
		if not (latestState and latestState.cityPlaced and latestCfg and latestBuilding and latestBuilding.placed and latestBuilding.completed) then
			return
		end
		local latestTier = math.clamp(math.floor(tonumber(latestBuilding.tier) or 1), 1, Config.Building.MaxTier)
		if latestTier ~= currentTier or latestTier >= Config.Building.MaxTier then
			return
		end
		local latestCost = Config.GetBuildingUpgradeCost(latestTier)
		latestBuilding.upgradeProgress = normalizeCostProgress(latestCost, latestBuilding.upgradeProgress, false)
		if not costProgressComplete(latestCost, latestBuilding.upgradeProgress) then
			latestBuilding.upgradeStartedAt = 0
			ensureBuildingSummaries(latestState)
			saveState(player)
			pushState(player, latestCfg.DisplayName .. " upgrade paused. Fill the missing requirements.")
			return
		end
		latestBuilding.tier = latestTier + 1
		latestBuilding.upgradeProgress = normalizeCostProgress(Config.GetBuildingUpgradeCost(latestBuilding.tier), {}, false)
		latestBuilding.upgradeStartedAt = 0
		ensureBuildingSummaries(latestState)
		updateWorldVisualsForPlayer(player)
		saveState(player)
		pushState(player, latestCfg.DisplayName .. " upgraded to tier " .. tostring(latestBuilding.tier) .. ".")
	end)
end

function claimCity(player)
	local state = playerStates[player]
	if not state then
		loadState(player)
		state = playerStates[player]
	end
	if state.cityPlaced then
		pushState(player, "You already founded a city.")
		return
	end
	if not isNearMonolith(player) then
		pushState(player, "Move closer to the city monolith.")
		return
	end
	local ok, err = spendCost(player, Config.City.ClaimCost)
	if not ok then
		pushState(player, err or "You need more resources.")
		return
	end
	local _, _, center = getReservedMetrics()
	state.cityPlaced = true
	state.cityLevel = 1
	state.cityPosition = center
	state.cityName = cleanStoredCityName((player.DisplayName ~= "" and player.DisplayName or player.Name) .. "'s City", player.Name .. "'s City")
	state.ownerUserId = player.UserId
	state.ownerName = player.DisplayName ~= "" and player.DisplayName or player.Name
	ensureBuildingSummaries(state)
	updateWorldVisualsForPlayer(player)
	saveState(player)
	pushState(player, "City founded.")
end

local function renameCity(player, payload)
	payload = type(payload) == "table" and payload or {}
	local state = playerStates[player]
	if not state or not state.cityPlaced then
		pushState(player, "Found a city before renaming it.")
		return
	end
	if not isNearCity(player, state) and not isNearMonolith(player) then
		pushState(player, "Move closer to your city to rename it.")
		return
	end
	local rawName = cleanStoredCityName(payload.CityName or payload.Name or payload.name, "")
	if #rawName < 3 then
		pushState(player, "City name must be at least 3 characters.")
		return
	end
	local filtered
	local ok, err = pcall(function()
		local result = TextService:FilterStringAsync(rawName, player.UserId)
		filtered = result:GetNonChatStringForBroadcastAsync()
	end)
	filtered = cleanStoredCityName(filtered, "")
	if not ok or filtered == "" or filtered:gsub("#", "") == "" then
		pushState(player, "That city name could not be used.")
		return
	end
	state.cityName = filtered
	state.ownerUserId = player.UserId
	state.ownerName = player.DisplayName ~= "" and player.DisplayName or player.Name
	local model = getCityModel(player)
	rebuildCityShell(player, state, model)
	updateWorldVisualsForPlayer(player)
	saveState(player)
	pushState(player, "City renamed.")
end

local function claimCityTaxes(player)
	local state = playerStates[player]
	if not state or not state.cityPlaced then
		pushState(player, "Found a city before claiming taxes.")
		return
	end
	if not isNearCity(player, state) and not isNearMonolith(player) then
		pushState(player, "Move closer to your city to claim taxes.")
		return
	end
	local amount = math.max(0, math.floor(tonumber(state.taxesAvailable) or 0))
	if amount <= 0 then
		pushState(player, "No city taxes are available.")
		return
	end
	local ok, err = pcall(function()
		InventoryService.AddCoin(player, amount)
	end)
	if not ok then
		pushState(player, "Could not claim city taxes: " .. tostring(err))
		return
	end
	state.taxesAvailable = 0
	saveState(player)
	pushState(player, "Claimed " .. tostring(amount) .. " Coin in city taxes.")
end

local function upgradeCity(player)
	local state = playerStates[player]
	if not state or not state.cityPlaced then
		pushState(player, "Found a city before upgrading it.")
		return
	end
	if state.cityLevel >= Config.City.MaxLevel then
		pushState(player, "City is already level " .. tostring(Config.City.MaxLevel) .. ".")
		return
	end
	if not isNearCity(player, state) and not isNearMonolith(player) then
		pushState(player, "Move closer to your city to upgrade it.")
		return
	end
	local cost = Config.GetCityUpgradeCost(state.cityLevel)
	state.cityUpgradeProgress = normalizeCostProgress(cost, state.cityUpgradeProgress, false)
	if not costProgressComplete(cost, state.cityUpgradeProgress) then
		saveState(player)
		pushState(player, "Fill every city upgrade requirement first.")
		return
	end
	scheduleCityUpgrade(player)
end

local function contributeCityUpgrade(player, payload)
	payload = type(payload) == "table" and payload or {}
	local state = playerStates[player]
	if not state or not state.cityPlaced then
		pushState(player, "Found a city before upgrading it.")
		return
	end
	if state.cityLevel >= Config.City.MaxLevel then
		pushState(player, "City is already level " .. tostring(Config.City.MaxLevel) .. ".")
		return
	end
	if not isNearCity(player, state) and not isNearMonolith(player) then
		pushState(player, "Move closer to your city to add upgrade requirements.")
		return
	end
	local key = tostring(player.UserId) .. ":CityUpgrade"
	if completingBuildings[key] then
		pushState(player, "City upgrade is already in progress.")
		return
	end
	local itemId = tostring(payload.ItemId or payload.itemId or "")
	local cost = Config.GetCityUpgradeCost(state.cityLevel)
	state.cityUpgradeProgress = normalizeCostProgress(cost, state.cityUpgradeProgress, false)
	local amount, err = spendCostContribution(player, cost, state.cityUpgradeProgress, itemId)
	if amount <= 0 then
		pushState(player, err or "Could not add city upgrade requirement.")
		return
	end
	state.cityUpgradeProgress[itemId] += amount
	state.cityUpgradeStartedAt = 0
	saveState(player)
	if costProgressComplete(cost, state.cityUpgradeProgress) then
		scheduleCityUpgrade(player)
	else
		pushState(player, "Added " .. tostring(amount) .. " city upgrade requirement.")
	end
end

local function placeBuilding(player, payload)
	payload = type(payload) == "table" and payload or {}
	local buildingKey = tostring(payload.BuildingKey or payload.buildingKey or "")
	local slotId = tostring(payload.SlotId or payload.slotId or "")
	local cfg = Config.Buildings[buildingKey]
	local state = playerStates[player]
	if not state or not state.cityPlaced then
		pushState(player, "Found a city before placing buildings.")
		return
	end
	if not cfg then
		pushState(player, "Unknown building.")
		return
	end
	if not getSlotInfo(state.cityLevel, slotId) then
		pushState(player, "Choose an unlocked city slot.")
		return
	end
	if getOccupiedSlots(state)[slotId] then
		pushState(player, "That city slot is occupied.")
		return
	end
	if not isNearSlot(player, state, slotId) then
		pushState(player, "Move closer to that city slot.")
		return
	end
	local ok, err = spendCost(player, cfg.PlaceCost or cfg.Costs)
	if not ok then
		pushState(player, err or "You need more Coin.")
		return
	end
	local instanceId = makeBuildingInstanceId(state)
	state.buildingInstances[instanceId] = {
		id = instanceId,
		buildingKey = buildingKey,
		placed = true,
		slotId = slotId,
		tier = 1,
		completed = false,
		placedAt = os.time(),
		completedAt = 0,
		recipeProgress = normalizeRecipeProgress(cfg, {}, false),
		upgradeProgress = normalizeCostProgress(Config.GetBuildingUpgradeCost(1), {}, false),
		upgradeStartedAt = 0,
	}
	ensureBuildingSummaries(state)
	updateWorldVisualsForPlayer(player)
	saveState(player)
	pushState(player, cfg.DisplayName .. " placed. Manage it to add recipe items.")
end

local function contributeRecipe(player, payload)
	payload = type(payload) == "table" and payload or {}
	local state = playerStates[player]
	local instanceId, building = resolveBuildingFromPayload(state, payload, true)
	local itemId = tostring(payload.ItemId or payload.itemId or "")
	local cfg = building and Config.Buildings[building.buildingKey]
	if not (state and state.cityPlaced and cfg and building) then
		pushState(player, "Unknown building recipe.")
		return
	end
	if not (building.placed and building.slotId) then
		pushState(player, "Place the building before filling its recipe.")
		return
	end
	if building.completed then
		pushState(player, cfg.DisplayName .. " is already ready.")
		return
	end
	if not isNearSlot(player, state, building.slotId) then
		pushState(player, "Move closer to that building.")
		return
	end
	local required = recipeRequirements(cfg)[itemId]
	if not required then
		pushState(player, "That item is not part of this recipe.")
		return
	end
	building.recipeProgress = normalizeRecipeProgress(cfg, building.recipeProgress, false)
	local remaining = required - math.floor(tonumber(building.recipeProgress[itemId]) or 0)
	if remaining <= 0 then
		pushState(player, "That recipe item is already filled.")
		return
	end
	local owned = InventoryService.CountItem(player, itemId)
	local amount = math.min(owned, remaining)
	if amount <= 0 then
		pushState(player, "You do not have that item.")
		return
	end
	local ok, err = spendCost(player, { Items = { [itemId] = amount } })
	if not ok then
		pushState(player, err or "Could not add recipe item.")
		return
	end
	building.recipeProgress[itemId] += amount
	local done = recipeComplete(cfg, building.recipeProgress)
	ensureBuildingSummaries(state)
	updateWorldVisualsForPlayer(player)
	saveState(player)
	if done then
		pushState(player, "Recipe filled. Building will finish shortly.")
		scheduleBuildingCompletion(player, instanceId)
	else
		pushState(player, "Added " .. tostring(amount) .. " recipe item.")
	end
end

local function upgradeBuilding(player, payload)
	payload = type(payload) == "table" and payload or {}
	local state = playerStates[player]
	local instanceId, building = resolveBuildingFromPayload(state, payload, false)
	local cfg = building and Config.Buildings[building.buildingKey]
	if not (state and state.cityPlaced and cfg and building) then
		pushState(player, "Unknown building.")
		return
	end
	if not building.completed then
		pushState(player, "Finish the building before upgrading it.")
		return
	end
	if not isNearSlot(player, state, building.slotId) then
		pushState(player, "Move closer to that building.")
		return
	end
	local currentTier = math.clamp(math.floor(tonumber(building.tier) or 1), 1, Config.Building.MaxTier)
	if currentTier >= Config.Building.MaxTier then
		pushState(player, cfg.DisplayName .. " is already tier " .. tostring(Config.Building.MaxTier) .. ".")
		return
	end
	local cost = Config.GetBuildingUpgradeCost(currentTier)
	building.upgradeProgress = normalizeCostProgress(cost, building.upgradeProgress, false)
	if not costProgressComplete(cost, building.upgradeProgress) then
		ensureBuildingSummaries(state)
		saveState(player)
		pushState(player, "Fill every " .. cfg.DisplayName .. " upgrade requirement first.")
		return
	end
	scheduleBuildingUpgrade(player, instanceId)
end

local function contributeBuildingUpgrade(player, payload)
	payload = type(payload) == "table" and payload or {}
	local state = playerStates[player]
	local instanceId, building = resolveBuildingFromPayload(state, payload, false)
	local cfg = building and Config.Buildings[building.buildingKey]
	if not (state and state.cityPlaced and cfg and building) then
		pushState(player, "Unknown building.")
		return
	end
	if not building.completed then
		pushState(player, "Finish the building before upgrading it.")
		return
	end
	if not isNearSlot(player, state, building.slotId) then
		pushState(player, "Move closer to that building to add upgrade requirements.")
		return
	end
	local currentTier = math.clamp(math.floor(tonumber(building.tier) or 1), 1, Config.Building.MaxTier)
	if currentTier >= Config.Building.MaxTier then
		pushState(player, cfg.DisplayName .. " is already tier " .. tostring(Config.Building.MaxTier) .. ".")
		return
	end
	local key = tostring(player.UserId) .. ":BuildingUpgrade:" .. tostring(instanceId)
	if completingBuildings[key] then
		pushState(player, cfg.DisplayName .. " upgrade is already in progress.")
		return
	end
	local itemId = tostring(payload.ItemId or payload.itemId or "")
	local cost = Config.GetBuildingUpgradeCost(currentTier)
	building.upgradeProgress = normalizeCostProgress(cost, building.upgradeProgress, false)
	local amount, err = spendCostContribution(player, cost, building.upgradeProgress, itemId)
	if amount <= 0 then
		pushState(player, err or "Could not add upgrade requirement.")
		return
	end
	building.upgradeProgress[itemId] += amount
	building.upgradeStartedAt = 0
	ensureBuildingSummaries(state)
	saveState(player)
	if costProgressComplete(cost, building.upgradeProgress) then
		scheduleBuildingUpgrade(player, instanceId)
	else
		pushState(player, "Added " .. tostring(amount) .. " " .. cfg.DisplayName .. " upgrade requirement.")
	end
end

actionRemote.OnServerEvent:Connect(function(player, actionName, payload)
	if actionName == "ClaimCity" or actionName == "FoundCity" then
		claimCity(player)
	elseif actionName == "UpgradeCity" then
		upgradeCity(player)
	elseif actionName == "ClaimCityTaxes" then
		claimCityTaxes(player)
	elseif actionName == "ContributeCityUpgrade" then
		contributeCityUpgrade(player, payload)
	elseif actionName == "RenameCity" then
		renameCity(player, payload)
	elseif actionName == "PlaceBuilding" then
		placeBuilding(player, payload)
	elseif actionName == "ContributeRecipe" then
		contributeRecipe(player, payload)
	elseif actionName == "UpgradeBuilding" then
		upgradeBuilding(player, payload)
	elseif actionName == "ContributeBuildingUpgrade" then
		contributeBuildingUpgrade(player, payload)
	end
end)

requestStateRemote.OnServerInvoke = function(player)
	if not playerStates[player] then
		loadState(player)
		updateWorldVisualsForPlayer(player)
	end
	return makeClientState(playerStates[player])
end

local function onPlayerAdded(player)
	loadState(player)
	updateWorldVisualsForPlayer(player)
	local state = playerStates[player]
	if state and state.cityPlaced then
		scheduleCityUpgrade(player)
		for _, instanceId in ipairs(sortedBuildingInstanceIds(state)) do
			scheduleBuildingUpgrade(player, instanceId)
		end
	end
	pushState(player)
end

local function onPlayerRemoving(player)
	saveState(player)
	local model = cityModels[player]
	if model then
		model:Destroy()
	end
	cityModels[player] = nil
	playerStates[player] = nil
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

ensureClaimPrompts()
task.spawn(function()
	while true do
		ensureClaimPrompts()
		task.wait(3)
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveState(player)
	end
end)
