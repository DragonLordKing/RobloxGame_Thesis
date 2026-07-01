--[[
Name: CraftingStationConfig
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.CraftingStationConfig
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Requires:
  - local ItemCatalog = require(script.Parent:WaitForChild("Shared"):WaitForChild("ItemCatalog"))
Functions: keyPart, resourceLineFromItem, Config.StationForBuilding, Config.ItemStation, Config.ItemCategory, Config.IsCraftableItem, Config.RecipeFor, Config.RecipeCost, Config.CraftingSkillForItem, Config.CraftingValorFor
Clean source lines: 246
]]
local ItemCatalog = require(script.Parent:WaitForChild("Shared"):WaitForChild("ItemCatalog"))

local Config = {}

Config.InteractDistance = 24
Config.CraftValorPerTier = 80
Config.StudyValorPerTier = 140

Config.Stations = {
	Warrior = {
		DisplayName = "Warrior Forge",
		BuildingKeys = { WarriorForge = true },
		Categories = {
			{ Key = "Weapons", DisplayName = "Weapons" },
			{ Key = "PlateArmor", DisplayName = "Plate Armor" },
		},
	},
	Hunter = {
		DisplayName = "Hunter Lodge",
		BuildingKeys = { WarriorArmory = true },
		Categories = {
			{ Key = "Weapons", DisplayName = "Weapons" },
			{ Key = "LeatherArmor", DisplayName = "Leather" },
		},
	},
	Magic = {
		DisplayName = "Arcane Study",
		BuildingKeys = { WarriorOutfitter = true },
		Categories = {
			{ Key = "Staffs", DisplayName = "Staffs" },
			{ Key = "ClothArmor", DisplayName = "Cloth" },
		},
	},
	Toolmaker = {
		DisplayName = "Toolworks",
		BuildingKeys = { TrailcraftLodge = true },
		Categories = {
			{ Key = "Bags", DisplayName = "Bags" },
			{ Key = "Tools", DisplayName = "Tools" },
			{ Key = "GatheringArmor", DisplayName = "Gathering" },
			{ Key = "Furniture", DisplayName = "Furniture" },
		},
	},
	Stablewright = {
		DisplayName = "Stablewright",
		BuildingKeys = { SpellcraftStudy = true },
		Categories = {
			{ Key = "Mounts", DisplayName = "Mounts" },
		},
	},
	OreRefinery = {
		DisplayName = "Smelter",
		BuildingKeys = { OreRefinery = true },
		Categories = {
			{ Key = "Refining", DisplayName = "Bars" },
		},
	},
	StoneRefinery = {
		DisplayName = "Masonry Kiln",
		BuildingKeys = { StoneRefinery = true },
		Categories = {
			{ Key = "Refining", DisplayName = "Blocks" },
		},
	},
	WoodRefinery = {
		DisplayName = "Sawmill",
		BuildingKeys = { WoodRefinery = true },
		Categories = {
			{ Key = "Refining", DisplayName = "Planks" },
		},
	},
	FiberRefinery = {
		DisplayName = "Loom",
		BuildingKeys = { FiberRefinery = true },
		Categories = {
			{ Key = "Refining", DisplayName = "Cloth" },
		},
	},
	HideRefinery = {
		DisplayName = "Tannery",
		BuildingKeys = { HideRefinery = true },
		Categories = {
			{ Key = "Refining", DisplayName = "Leather" },
		},
	},
}

local function keyPart(value)
	local text = tostring(value or ""):lower()
	text = text:gsub("%s+", "_")
	text = text:gsub("[^%w_]", "")
	return text
end
Config.KeyPart = keyPart

function Config.StationForBuilding(buildingKey, buildingConfig)
	if buildingConfig and buildingConfig.CraftingStationKey and Config.Stations[buildingConfig.CraftingStationKey] then
		return buildingConfig.CraftingStationKey
	end
	for stationKey, station in pairs(Config.Stations) do
		if station.BuildingKeys and station.BuildingKeys[tostring(buildingKey or "")] then
			return stationKey
		end
	end
	return nil
end

function Config.ItemStation(def)
	if type(def) ~= "table" then return nil end
	if def.CraftingStationKey and Config.Stations[def.CraftingStationKey] then
		return def.CraftingStationKey
	end
	local itemType = keyPart(def.Type)
	local weaponType = keyPart(def.WeaponType)
	local armorClass = keyPart(def.ArmorClass or def.WeightClass)
	local slot = keyPart(def.Slot or def.EquipSlot)
	local id = keyPart(def.Id or def.DisplayName)
	if itemType == "mount" or slot == "mount" or id:find("horse", 1, true) or id:find("mount", 1, true) then
		return "Stablewright"
	end
	if itemType == "bag" or itemType == "tool" or itemType == "furniture" or itemType == "gatheringarmor" or slot == "bag" or id:find("tool", 1, true) or id:find("pick", 1, true) or id:find("axe", 1, true) or id:find("chair", 1, true) then
		return "Toolmaker"
	end
	if weaponType:find("staff", 1, true) or armorClass == "cloth" or id:find("staff", 1, true) or id:find("cloth", 1, true) or id:find("robe", 1, true) then
		return "Magic"
	end
	if weaponType == "bow" or weaponType == "dagger" or weaponType == "crossbow" or armorClass == "leather" or id:find("bow", 1, true) or id:find("leather", 1, true) then
		return "Hunter"
	end
	if itemType == "weapon" or armorClass == "plate" or id:find("sword", 1, true) or id:find("plate", 1, true) then
		return "Warrior"
	end
	return nil
end

function Config.ItemCategory(def)
	if type(def) ~= "table" then return "Misc" end
	if def.CraftingCategory then return tostring(def.CraftingCategory) end
	local station = Config.ItemStation(def)
	local itemType = keyPart(def.Type)
	local weaponType = keyPart(def.WeaponType)
	local armorClass = keyPart(def.ArmorClass or def.WeightClass)
	local slot = keyPart(def.Slot or def.EquipSlot)
	local id = keyPart(def.Id or def.DisplayName)
	if station == "Warrior" then
		if itemType == "weapon" or weaponType ~= "" then return "Weapons" end
		return "PlateArmor"
	elseif station == "Hunter" then
		if itemType == "weapon" or weaponType ~= "" then return "Weapons" end
		return "LeatherArmor"
	elseif station == "Magic" then
		if weaponType:find("staff", 1, true) or id:find("staff", 1, true) then return "Staffs" end
		return "ClothArmor"
	elseif station == "Toolmaker" then
		if itemType == "bag" or slot == "bag" then return "Bags" end
		if itemType == "tool" or id:find("pick", 1, true) or id:find("axe", 1, true) or id:find("knife", 1, true) then return "Tools" end
		if itemType == "furniture" then return "Furniture" end
		return "GatheringArmor"
	elseif station == "Stablewright" then
		return "Mounts"
	end
	return "Misc"
end

function Config.IsCraftableItem(def)
	return type(def) == "table" and def.Type ~= "Resource" and type(def.Recipe) == "table" and #def.Recipe > 0 and Config.ItemStation(def) ~= nil
end

function Config.RecipeFor(def, purity)
	if type(def) ~= "table" then return {} end
	return ItemCatalog.RecipeForPurity(def, purity)
end

function Config.RecipeCost(def, amount, purity)
	local cost = { Items = {} }
	amount = math.max(1, math.floor(tonumber(amount) or 1))
	if type(def) ~= "table" or type(def.Recipe) ~= "table" then return cost end
	for _, req in ipairs(Config.RecipeFor(def, purity)) do
		local itemId = tostring(req.Id or req.id or req.ItemId or req.itemId or "")
		local reqAmount = math.max(1, math.floor(tonumber(req.Amount or req.amount or req.Count or req.count) or 1)) * amount
		if itemId ~= "" then
			cost.Items[itemId] = (cost.Items[itemId] or 0) + reqAmount
		end
	end
	return cost
end

local function resourceLineFromItem(def)
	local id = keyPart(def and (def.Id or def.DisplayName))
	local name = keyPart(def and (def.DisplayName or def.Name))
	local text = id .. "_" .. name .. "_" .. keyPart(def and def.ResourceFamily)
	if text:find("stone", 1, true) or text:find("quarry", 1, true) or text:find("rock", 1, true) then return "stone" end
	if text:find("wood", 1, true) or text:find("axe", 1, true) or text:find("log", 1, true) then return "wood" end
	if text:find("fiber", 1, true) or text:find("sickle", 1, true) or text:find("harvest", 1, true) then return "fiber" end
	if text:find("hide", 1, true) or text:find("skin", 1, true) or text:find("knife", 1, true) then return "hide" end
	if text:find("ore", 1, true) or text:find("pick", 1, true) or text:find("mine", 1, true) then return "ore" end
	return nil
end

function Config.CraftingSkillForItem(def)
	if type(def) ~= "table" then return nil end
	if def.RefiningSkillKey then return def.RefiningSkillKey end
	if def.CraftingSkillKey then return def.CraftingSkillKey end
	local station = Config.ItemStation(def)
	local category = Config.ItemCategory(def)
	local weaponType = keyPart(def.WeaponType)
	local slot = keyPart(def.Slot or def.EquipSlot)
	local armorClass = keyPart(def.ArmorClass or def.WeightClass)
	if station == "Warrior" then
		if weaponType == "sword" or keyPart(def.Id):find("sword", 1, true) then return "craft_sword" end
		if slot == "helmet" then return "craft_plate_helmet" end
		if slot == "boots" then return "craft_plate_boots" end
		return "craft_plate_armor"
	elseif station == "Hunter" then
		if weaponType == "bow" or category == "Weapons" then return "craft_bow" end
		if slot == "helmet" then return "craft_leather_helmet" end
		if slot == "boots" then return "craft_leather_boots" end
		return "craft_leather_armor"
	elseif station == "Magic" then
		if weaponType:find("staff", 1, true) or category == "Staffs" then return "craft_fire_staff" end
		if slot == "helmet" then return "craft_cloth_helmet" end
		if slot == "boots" then return "craft_cloth_boots" end
		return "craft_cloth_armor"
	elseif station == "Toolmaker" then
		if category == "Bags" then return "craft_bagmaking" end
		if category == "Furniture" then return "craft_furniture" end
		local resourceLine = resourceLineFromItem(def)
		if category == "GatheringArmor" or armorClass == "gathering" then
			return resourceLine and ("craft_gathering_" .. resourceLine) or "craft_gathering_gear"
		end
		return resourceLine and ("craft_tool_" .. resourceLine) or "craft_toolmaking"
	elseif station == "Stablewright" then
		return "craft_mounts"
	end
	return nil
end

function Config.CraftingValorFor(def, isStudy)
	local tier = math.clamp(math.floor(tonumber(def and def.Tier) or 1), 1, 20)
	local power = math.max(0, math.floor(tonumber(def and (def.Power or def.ItemPower)) or 0))
	local base = (isStudy and Config.StudyValorPerTier or Config.CraftValorPerTier) * tier
	return math.max(1, base + math.floor(power * (isStudy and 0.35 or 0.2)))
end

return Config
