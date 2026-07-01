--[[
Name: CraftingStationService
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.CraftingStationService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage, ServerScriptService, Workspace
Requires:
  - local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
  - local BuildConfig = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("BuildSystemConfig"))
  - local CraftingConfig = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("CraftingStationConfig"))
  - local DestinyBoardConfig = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("DestinyBoardConfig"))
  - local InventoryService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("InventoryStorageService"))
  - local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
  - local ValorService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("Progression"):WaitForChild("ValorService"))
Functions: characterRoot, distanceToPart, worldCitiesFolder, playerCityModel, findBuildingModel, findBuildingModelInAnyCity, stationForBuilding, recipeRows, maxCraftableForRecipe, canCraftRecipe, getValorSkills, skillRequirementMessage, validateCraftingTier, recipeVariantPayload, itemPayload, buildStationSnapshot, purityAllowed, refundRecipe, craftItem, studyItem, requestRemote.OnServerInvoke
Signal classes referenced: RemoteFunction
Clean source lines: 451
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local BuildConfig = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("BuildSystemConfig"))
local CraftingConfig = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("CraftingStationConfig"))
local DestinyBoardConfig = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("DestinyBoardConfig"))
local InventoryService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("InventoryStorageService"))
local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
local ValorService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("Progression"):WaitForChild("ValorService"))

local remotesFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("CraftingStationRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "CraftingStationRemotes"
	remotesFolder.Parent = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
end

local requestRemote = remotesFolder:FindFirstChild("Request")
if not requestRemote or not requestRemote:IsA("RemoteFunction") then
	if requestRemote then requestRemote:Destroy() end
	requestRemote = Instance.new("RemoteFunction")
	requestRemote.Name = "Request"
	requestRemote.Parent = remotesFolder
end

local function characterRoot(player)
	local character = player and player.Character
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

local function worldCitiesFolder()
	return Workspace:FindFirstChild("WorldCities")
end

local function playerCityModel(player)
	local cities = worldCitiesFolder()
	return cities and cities:FindFirstChild("City_" .. tostring(player.UserId)) or nil
end

local function findBuildingModel(city, instanceId, buildingKey)
	if not city then
		return nil
	end
	instanceId = tostring(instanceId or "")
	buildingKey = tostring(buildingKey or "")
	if instanceId ~= "" then
		for _, child in ipairs(city:GetChildren()) do
			if child:IsA("Model") and tostring(child:GetAttribute("BuildingInstanceId") or "") == instanceId then
				return child
			end
		end
	end
	if buildingKey ~= "" then
		local legacy = city:FindFirstChild(buildingKey)
		if legacy and legacy:IsA("Model") then
			return legacy
		end
		for _, child in ipairs(city:GetChildren()) do
			if child:IsA("Model") and tostring(child:GetAttribute("BuildingKey") or "") == buildingKey then
				return child
			end
		end
	end
	return nil
end

local function findBuildingModelInAnyCity(instanceId, buildingKey)
	local cities = worldCitiesFolder()
	if not cities then
		return nil
	end
	for _, city in ipairs(cities:GetChildren()) do
		local building = findBuildingModel(city, instanceId, buildingKey)
		if building then
			return building
		end
	end
	return nil
end

local function stationForBuilding(player, request)
	local payload = type(request) == "table" and request or { BuildingKey = request }
	local instanceId = tostring(payload.BuildingInstanceId or payload.InstanceId or payload.instanceId or "")
	local buildingKey = tostring(payload.BuildingKey or payload.buildingKey or "")
	local city = playerCityModel(player)
	local building = findBuildingModel(city, instanceId, buildingKey) or findBuildingModelInAnyCity(instanceId, buildingKey)
	if building then
		buildingKey = tostring(building:GetAttribute("BuildingKey") or buildingKey)
		instanceId = tostring(building:GetAttribute("BuildingInstanceId") or instanceId)
	end
	local cfg = BuildConfig.Buildings[buildingKey]
	local stationKey = CraftingConfig.StationForBuilding(buildingKey, cfg)
	local station = stationKey and CraftingConfig.Stations[stationKey]
	local detector = building and building:FindFirstChild("Detector")
	if not (cfg and station and building and detector and detector:IsA("BasePart")) then
		return nil, "Crafting station not found."
	end
	if detector:GetAttribute("Completed") ~= true then
		return nil, "Finish this building before crafting."
	end
	local root = characterRoot(player)
	if not root then
		return nil, "Character is not ready."
	end
	local range = (tonumber(CraftingConfig.InteractDistance) or 24) + math.max(detector.Size.X, detector.Size.Z) * 0.5
	if distanceToPart(root.Position, detector) > range then
		return nil, "Move closer to the crafting station."
	end
	local stationTier = math.clamp(math.floor(tonumber(detector:GetAttribute("StationTier") or building:GetAttribute("Tier") or 1) or 1), 1, BuildConfig.Building.MaxTier)
	return {
		BuildingKey = buildingKey,
		BuildingInstanceId = instanceId,
		Building = building,
		Detector = detector,
		StationKey = stationKey,
		Station = station,
		StationTier = stationTier,
		Config = cfg,
	}
end

local function recipeRows(player, recipe)
	local rows = {}
	for _, req in ipairs(recipe or {}) do
		local itemId = tostring(req.Id or req.id or req.ItemId or "")
		local amount = math.max(1, math.floor(tonumber(req.Amount or req.amount or req.Count or req.count) or 1))
		local reqDef = ItemCatalog.Get(itemId)
		table.insert(rows, {
			ItemId = itemId,
			DisplayName = reqDef and reqDef.DisplayName or itemId,
			Amount = amount,
			Owned = InventoryService.CountItem(player, itemId),
			Icon = reqDef and reqDef.Icon or "Default",
		})
	end
	table.sort(rows, function(a, b)
		return tostring(a.DisplayName) < tostring(b.DisplayName)
	end)
	return rows
end

local function maxCraftableForRecipe(player, recipe)
	local maxAmount = 9999
	local hasCost = false
	for _, req in ipairs(recipe or {}) do
		local itemId = req.Id or req.id or req.ItemId
		local amount = math.max(1, math.floor(tonumber(req.Amount or req.amount or req.Count or req.count) or 1))
		if itemId and amount > 0 then
			hasCost = true
			maxAmount = math.min(maxAmount, math.floor(InventoryService.CountItem(player, itemId) / amount))
		end
	end
	return hasCost and math.max(0, maxAmount) or 9999
end

local function canCraftRecipe(player, recipe, amount)
	amount = math.max(1, math.floor(tonumber(amount) or 1))
	return maxCraftableForRecipe(player, recipe) >= amount
end

local function getValorSkills(player)
	local section = ProfileService.GetSection(player, "Valor", function()
		return { Version = 1, Skills = {} }
	end)
	if type(section.Skills) ~= "table" then
		section.Skills = {}
		ProfileService.MarkDirty(player)
	end
	return section.Skills
end

local function skillRequirementMessage(skillKey, requiredLevel, currentLevel, tier, fallback)
	if not skillKey then
		return fallback or string.format("No Destiny Board unlock exists for Tier %d crafting yet.", tier)
	end
	local skill = DestinyBoardConfig.Skills[skillKey]
	local name = skill and skill.DisplayName or skillKey
	return string.format("Requires %s level %d to craft T%d. Current level: %d.", name, requiredLevel, tier, currentLevel)
end

local function validateCraftingTier(player, itemId, def)
	local tier = math.clamp(math.floor(tonumber(def and def.Tier) or 1), 1, DestinyBoardConfig.MaxTier)
	if tier <= 1 then return true end
	local skills = getValorSkills(player)
	if def.Type == "RefinedResource" then
		local ok, skillKey, requiredLevel, currentLevel = DestinyBoardConfig.CanRefineTier(skills, def.ResourceFamily or def.ResourceKind, itemId, CraftingConfig.CraftingSkillForItem(def), tier)
		if ok then return true end
		return false, skillRequirementMessage(skillKey, requiredLevel, currentLevel, tier, "No Destiny Board refining path exists for this resource.")
	end
	local line = DestinyBoardConfig.CraftingLineForItem(itemId, def, CraftingConfig.CraftingSkillForItem(def))
	local ok, skillKey, requiredLevel, currentLevel = DestinyBoardConfig.CanCraftItemTier(skills, line, tier)
	if ok then return true end
	return false, skillRequirementMessage(skillKey, requiredLevel, currentLevel, tier, "No Destiny Board crafting path exists for this item.")
end

local function recipeVariantPayload(player, def, purity)
	local recipe = CraftingConfig.RecipeFor(def, purity)
	return recipeRows(player, recipe), maxCraftableForRecipe(player, recipe)
end

local function itemPayload(player, itemId, def)
	local category = CraftingConfig.ItemCategory(def)
	local purityOptions = ItemCatalog.CraftablePuritiesFor(def)
	local recipeVariants = {}
	local maxByPurity = {}
	local anyCraftable = false
	for _, purity in ipairs(purityOptions) do
		local rows, maxAmount = recipeVariantPayload(player, def, purity)
		recipeVariants[purity] = rows
		maxByPurity[purity] = maxAmount
		if maxAmount > 0 then
			anyCraftable = true
		end
	end
	local baseRecipe = recipeVariants.None or recipeVariants["None"] or recipeRows(player, def.Recipe)
	local baseMax = maxByPurity.None or maxByPurity["None"] or maxCraftableForRecipe(player, def.Recipe)
	local destinyOk, destinyError = validateCraftingTier(player, itemId, def)
	return {
		ItemId = itemId,
		DisplayName = def.DisplayName or itemId,
		Type = def.Type or "Item",
		Category = category,
		Tier = def.Tier or 1,
		Power = def.Power or def.ItemPower or def.Tier or 0,
		Icon = def.Icon or "Default",
		Description = def.Description or "",
		Recipe = baseRecipe,
		RecipeVariants = recipeVariants,
		PurityOptions = purityOptions,
		MaxCraftable = baseMax,
		MaxCraftableByPurity = maxByPurity,
		Craftable = destinyOk and baseMax > 0 and canCraftRecipe(player, CraftingConfig.RecipeFor(def, "None"), 1),
		AnyCraftable = destinyOk and anyCraftable,
		DestinyUnlocked = destinyOk,
		LockedReason = destinyOk and nil or destinyError,
		Owned = InventoryService.CountItem(player, itemId),
		CraftingSkillKey = CraftingConfig.CraftingSkillForItem(def),
	}
end

local function buildStationSnapshot(player, stationInfo, message)
	local station = stationInfo.Station
	local stationKey = stationInfo.StationKey
	local categoryOrder = {}
	local categoryMap = {}
	for _, category in ipairs(station.Categories or {}) do
		local entry = { Key = category.Key, DisplayName = category.DisplayName or category.Key, Items = {} }
		categoryMap[entry.Key] = entry
		table.insert(categoryOrder, entry)
	end
	local stationTier = math.clamp(math.floor(tonumber(stationInfo.StationTier) or 1), 1, BuildConfig.Building.MaxTier)
	for itemId, def in pairs(ItemCatalog.Items) do
		local itemTier = math.clamp(math.floor(tonumber(def and def.Tier) or 1), 1, BuildConfig.Building.MaxTier)
		if itemTier <= stationTier and CraftingConfig.IsCraftableItem(def) and CraftingConfig.ItemStation(def) == stationKey then
			local categoryKey = CraftingConfig.ItemCategory(def)
			local bucket = categoryMap[categoryKey]
			if not bucket then
				bucket = { Key = categoryKey, DisplayName = categoryKey, Items = {} }
				categoryMap[categoryKey] = bucket
				table.insert(categoryOrder, bucket)
			end
			table.insert(bucket.Items, itemPayload(player, itemId, def))
		end
	end
	for _, category in ipairs(categoryOrder) do
		table.sort(category.Items, function(a, b)
			local ta = tonumber(a.Tier) or 1
			local tb = tonumber(b.Tier) or 1
			if ta == tb then return tostring(a.DisplayName) < tostring(b.DisplayName) end
			return ta < tb
		end)
	end
	local inspectItems = {}
	for itemId, def in pairs(ItemCatalog.Items) do
		local itemTier = math.clamp(math.floor(tonumber(def and def.Tier) or 1), 1, BuildConfig.Building.MaxTier)
		if itemTier <= stationTier and def.Type ~= "Resource" and CraftingConfig.ItemStation(def) == stationKey then
			local owned = InventoryService.CountItem(player, itemId)
			if owned > 0 then
				table.insert(inspectItems, {
					ItemId = itemId,
					DisplayName = def.DisplayName or itemId,
					Type = def.Type or "Item",
					Tier = def.Tier or 1,
					Power = def.Power or def.ItemPower or def.Tier or 0,
					Icon = def.Icon or "Default",
					Owned = owned,
					CraftingSkillKey = CraftingConfig.CraftingSkillForItem(def),
				})
			end
		end
	end
	table.sort(inspectItems, function(a, b)
		local ta = tonumber(a.Tier) or 1
		local tb = tonumber(b.Tier) or 1
		if ta == tb then return tostring(a.DisplayName) < tostring(b.DisplayName) end
		return ta < tb
	end)
	return {
		Ok = true,
		Message = message,
		BuildingKey = stationInfo.BuildingKey,
		BuildingInstanceId = stationInfo.BuildingInstanceId,
		StationKey = stationKey,
		StationTier = stationTier,
		DisplayName = station.DisplayName .. " T" .. tostring(stationTier),
		Categories = categoryOrder,
		InspectItems = inspectItems,
	}
end

local function purityAllowed(def, purity)
	purity = ItemCatalog.NormalizePurity(purity)
	for _, option in ipairs(ItemCatalog.CraftablePuritiesFor(def)) do
		if ItemCatalog.NormalizePurity(option) == purity then
			return true
		end
	end
	return false
end

local function refundRecipe(player, recipe, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then return end
	for _, req in ipairs(recipe or {}) do
		local itemId = req.Id or req.id or req.ItemId
		local reqAmount = math.max(1, math.floor(tonumber(req.Amount or req.amount or req.Count or req.count) or 1)) * amount
		if itemId and reqAmount > 0 then
			InventoryService.AddItem(player, itemId, reqAmount)
		end
	end
end

local function craftItem(player, payload)
	local stationInfo, err = stationForBuilding(player, payload)
	if not stationInfo then return { Ok = false, Error = err } end
	local itemId = ItemCatalog.NormalizeId(payload and payload.ItemId)
	local def = itemId and ItemCatalog.Get(itemId)
	if not (def and CraftingConfig.IsCraftableItem(def)) then
		return { Ok = false, Error = "Unknown craftable item." }
	end
	if CraftingConfig.ItemStation(def) ~= stationInfo.StationKey then
		return { Ok = false, Error = "That station cannot craft this item." }
	end
	if math.clamp(math.floor(tonumber(def.Tier) or 1), 1, BuildConfig.Building.MaxTier) > stationInfo.StationTier then
		return { Ok = false, Error = "Upgrade this station to craft that tier." }
	end
	local destinyOk, destinyErr = validateCraftingTier(player, itemId, def)
	if not destinyOk then
		return { Ok = false, Error = destinyErr or "Destiny Board tier is not unlocked." }
	end
	local amount = math.clamp(math.floor(tonumber(payload and payload.Amount) or 1), 1, 9999)
	local purity = ItemCatalog.NormalizePurity(payload and payload.Purity or def.Purity or "None")
	if not purityAllowed(def, purity) then
		return { Ok = false, Error = "That purity is not available for this craft." }
	end
	local recipe = CraftingConfig.RecipeFor(def, purity)
	local maxCraftable = maxCraftableForRecipe(player, recipe)
	if maxCraftable <= 0 then
		return { Ok = false, Error = "Missing recipe items." }
	end
	amount = math.min(amount, maxCraftable)
	local ok, spendErr = InventoryService.SpendCosts(player, CraftingConfig.RecipeCost(def, amount, purity))
	if not ok then
		return { Ok = false, Error = spendErr or "Missing recipe items." }
	end
	local outputPurity = purity ~= "None" and purity or nil
	if def.Type == "RefinedResource" then
		outputPurity = nil
	end
	local craftedBy = (def.Type ~= "Resource" and def.Type ~= "RefinedResource" and def.Stackable ~= true) and ((player.DisplayName ~= "" and player.DisplayName) or player.Name) or nil
	local added = InventoryService.AddItem(player, itemId, amount, nil, nil, outputPurity, craftedBy)
	if added < amount then
		refundRecipe(player, recipe, amount - math.max(0, added))
	end
	if added <= 0 then
		return { Ok = false, Error = "No inventory space for crafted item." }
	end
	local valor = CraftingConfig.CraftingValorFor(def, false) * added
	local stationPosition = stationInfo.Detector and stationInfo.Detector.Position or nil
	if def.Type == "RefinedResource" and type(ValorService.GrantRefiningValor) == "function" then
		ValorService.GrantRefiningValor(player, def.ResourceFamily or def.ResourceKind, def.Tier, valor, CraftingConfig.CraftingSkillForItem(def), { Item = itemId, Source = "refining_station", Station = stationInfo.StationKey, Purity = def.Purity or purity, Tier = def.Tier, ItemTier = def.Tier, Position = stationPosition, StationPosition = stationPosition })
	else
		ValorService.GrantCraftingValor(player, itemId, valor, CraftingConfig.CraftingSkillForItem(def), { Item = itemId, Source = "crafting_station", Station = stationInfo.StationKey, Purity = purity, Tier = def.Tier, ItemTier = def.Tier, Position = stationPosition, StationPosition = stationPosition })
	end
	local suffix = added > 1 and (" x" .. tostring(added)) or ""
	local message = "Crafted " .. tostring(def.DisplayName or itemId) .. suffix .. "."
	if added < amount then
		message = message .. " Inventory filled before the full batch finished."
	end
	return buildStationSnapshot(player, stationInfo, message)
end

local function studyItem(player, payload)
	local stationInfo, err = stationForBuilding(player, payload)
	if not stationInfo then return { Ok = false, Error = err } end
	local itemId = ItemCatalog.NormalizeId(payload and payload.ItemId)
	local def = itemId and ItemCatalog.Get(itemId)
	if not def or def.Type == "Resource" then
		return { Ok = false, Error = "That item cannot be studied." }
	end
	if CraftingConfig.ItemStation(def) ~= stationInfo.StationKey then
		return { Ok = false, Error = "Study this item at its matching station." }
	end
	if math.clamp(math.floor(tonumber(def.Tier) or 1), 1, BuildConfig.Building.MaxTier) > stationInfo.StationTier then
		return { Ok = false, Error = "Upgrade this station before studying that tier." }
	end
	local ok, spendErr = InventoryService.SpendCosts(player, { Items = { [itemId] = 1 } })
	if not ok then
		return { Ok = false, Error = spendErr or "You do not have that item." }
	end
	local valor = CraftingConfig.CraftingValorFor(def, true)
	local stationPosition = stationInfo.Detector and stationInfo.Detector.Position or nil
	ValorService.GrantCraftingValor(player, itemId, valor, CraftingConfig.CraftingSkillForItem(def), { Item = itemId, Source = "inspect_study", Station = stationInfo.StationKey, Tier = def.Tier, ItemTier = def.Tier, Position = stationPosition, StationPosition = stationPosition })
	return buildStationSnapshot(player, stationInfo, "Studied " .. tostring(def.DisplayName or itemId) .. ".")
end

requestRemote.OnServerInvoke = function(player, actionName, payload)
	if not (player and player:IsA("Player")) then
		return { Ok = false, Error = "Invalid player." }
	end
	payload = type(payload) == "table" and payload or {}
	if actionName == "GetStation" then
		local stationInfo, err = stationForBuilding(player, payload)
		if not stationInfo then return { Ok = false, Error = err } end
		return buildStationSnapshot(player, stationInfo)
	elseif actionName == "CraftItem" then
		return craftItem(player, payload)
	elseif actionName == "StudyItem" then
		return studyItem(player, payload)
	end
	return { Ok = false, Error = "Unknown crafting action." }
end

Players.PlayerRemoving:Connect(function(_player)
end)
