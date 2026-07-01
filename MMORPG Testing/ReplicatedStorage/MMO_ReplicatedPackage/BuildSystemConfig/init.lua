--[[
Name: BuildSystemConfig
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.BuildSystemConfig
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: comma, Config.FormatCurrency, Config.CopyCost, Config.GetCityUpgradePlan, Config.GetCityUpgradeCost, Config.GetCitySizeLevel, Config.GetCitySlotSizeLevel, Config.GetCitySizeFraction, Config.GetCityLevelSize, Config.GetBuildingUpgradeCost, Config.GetSlotPadSize, Config.CopyRecipe, Config.GetRecipeItemCount, Config.GetRecipeDuration, Config.CostToText
Clean source lines: 336
]]
local Config = {}

local ONE_OF_EACH_T1 = {
	T1_Wood = 1,
	T1_Stone = 1,
	T1_Ore = 1,
	T1_Fiber = 1,
	T1_Hide = 1,
}

local STANDARD_BUILDING_RECIPE = {
	T1_Wood = 1,
	T1_Stone = 3,
	T1_Ore = 1,
	T1_Fiber = 1,
	T1_Hide = 1,
}

Config.MenuIcons = {
	FoundCity = "rbxassetid://0",
	UpgradeCity = "rbxassetid://0",
	WarriorForge = "rbxassetid://0",
	WarriorArmory = "rbxassetid://0",
	WarriorOutfitter = "rbxassetid://0",
	TrailcraftLodge = "rbxassetid://0",
	SpellcraftStudy = "rbxassetid://0",
	OreRefinery = "rbxassetid://0",
	StoneRefinery = "rbxassetid://0",
	WoodRefinery = "rbxassetid://0",
	FiberRefinery = "rbxassetid://0",
	HideRefinery = "rbxassetid://0",
}

Config.City = {
	MaxLevel = 20,
	MaxSizeLevel = 10,
	GridDivisions = 10,
	BaseThickness = 2,
	SlotPadHeight = 0.45,
	SlotInsetScale = 0.72,
	BuildingPlaceCoin = 100,
	RecipeSecondsPerItem = 0.02,
	ClaimDistance = 5,
	BuildPlaceDistance = 160,
	UpgradeDistancePadding = 70,
	MonolithSlotClearance = 6,
	ClaimCost = {
		Coin = 10000000,
		Items = {},
	},
	UpgradeCost = {
		Coin = 2,
		Items = ONE_OF_EACH_T1,
	},
	UpgradePlan = {},
}

Config.Building = {
	MaxTier = 20,
	UpgradeCost = {
		Coin = 100,
		Items = ONE_OF_EACH_T1,
	},
}

for level = 1, Config.City.MaxLevel do
	Config.City.UpgradePlan[level] = {
		SizeLevel = math.clamp(level, 1, Config.City.MaxSizeLevel),
		SlotSizeLevel = math.clamp(level + 1, 2, Config.City.MaxSizeLevel),
		Cost = Config.City.UpgradeCost,
	}
end

Config.BuildingSize = Vector3.new(24, 18, 24)
Config.CityBaseSize = Vector3.new(120, Config.City.BaseThickness, 120)

Config.Camera = {
	Height = 170,
	PanSpeed = 120,
}

Config.Buildings = {
	WarriorForge = {
		DisplayName = "Warrior Forge",
		ShortName = "Warrior",
		Duration = 8,
		Order = 10,
		Size = Config.BuildingSize,
		CraftingSkillKey = "craft_sword",
		CraftingStationKey = "Warrior",
		Color = Color3.fromRGB(155, 88, 58),
		Costs = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		PlaceCost = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		Recipe = { Items = STANDARD_BUILDING_RECIPE },
	},
	WarriorArmory = {
		DisplayName = "Hunter Lodge",
		ShortName = "Hunter",
		Duration = 8,
		Order = 20,
		Size = Config.BuildingSize,
		CraftingSkillKey = "craft_bow",
		CraftingStationKey = "Hunter",
		Color = Color3.fromRGB(92, 132, 86),
		Costs = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		PlaceCost = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		Recipe = { Items = STANDARD_BUILDING_RECIPE },
	},
	WarriorOutfitter = {
		DisplayName = "Arcane Study",
		ShortName = "Magic",
		Duration = 8,
		Order = 30,
		Size = Config.BuildingSize,
		CraftingSkillKey = "craft_fire_staff",
		CraftingStationKey = "Magic",
		Color = Color3.fromRGB(96, 86, 150),
		Costs = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		PlaceCost = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		Recipe = { Items = STANDARD_BUILDING_RECIPE },
	},
	TrailcraftLodge = {
		DisplayName = "Toolworks",
		ShortName = "Tools",
		Duration = 8,
		Order = 40,
		Size = Config.BuildingSize,
		CraftingSkillKey = "craft_toolmaking",
		CraftingStationKey = "Toolmaker",
		Color = Color3.fromRGB(126, 112, 82),
		Costs = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		PlaceCost = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		Recipe = { Items = STANDARD_BUILDING_RECIPE },
	},
	SpellcraftStudy = {
		DisplayName = "Stablewright",
		ShortName = "Mounts",
		Duration = 8,
		Order = 50,
		Size = Config.BuildingSize,
		CraftingSkillKey = "craft_mounts",
		CraftingStationKey = "Stablewright",
		Color = Color3.fromRGB(150, 104, 72),
		Costs = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		PlaceCost = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		Recipe = { Items = STANDARD_BUILDING_RECIPE },
	},
	OreRefinery = {
		DisplayName = "Smelter",
		ShortName = "Smelter",
		Duration = 8,
		Order = 60,
		Size = Config.BuildingSize,
		CraftingSkillKey = "craft_refining",
		CraftingStationKey = "OreRefinery",
		Color = Color3.fromRGB(135, 113, 96),
		Costs = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		PlaceCost = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		Recipe = { Items = STANDARD_BUILDING_RECIPE },
	},
	StoneRefinery = {
		DisplayName = "Masonry Kiln",
		ShortName = "Masonry",
		Duration = 8,
		Order = 70,
		Size = Config.BuildingSize,
		CraftingSkillKey = "craft_refining",
		CraftingStationKey = "StoneRefinery",
		Color = Color3.fromRGB(105, 111, 116),
		Costs = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		PlaceCost = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		Recipe = { Items = STANDARD_BUILDING_RECIPE },
	},
	WoodRefinery = {
		DisplayName = "Sawmill",
		ShortName = "Sawmill",
		Duration = 8,
		Order = 80,
		Size = Config.BuildingSize,
		CraftingSkillKey = "craft_refining",
		CraftingStationKey = "WoodRefinery",
		Color = Color3.fromRGB(116, 139, 91),
		Costs = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		PlaceCost = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		Recipe = { Items = STANDARD_BUILDING_RECIPE },
	},
	FiberRefinery = {
		DisplayName = "Loom",
		ShortName = "Loom",
		Duration = 8,
		Order = 90,
		Size = Config.BuildingSize,
		CraftingSkillKey = "craft_refining",
		CraftingStationKey = "FiberRefinery",
		Color = Color3.fromRGB(124, 132, 154),
		Costs = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		PlaceCost = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		Recipe = { Items = STANDARD_BUILDING_RECIPE },
	},
	HideRefinery = {
		DisplayName = "Tannery",
		ShortName = "Tannery",
		Duration = 8,
		Order = 100,
		Size = Config.BuildingSize,
		CraftingSkillKey = "craft_refining",
		CraftingStationKey = "HideRefinery",
		Color = Color3.fromRGB(137, 103, 75),
		Costs = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		PlaceCost = { Coin = Config.City.BuildingPlaceCoin, Items = {} },
		Recipe = { Items = STANDARD_BUILDING_RECIPE },
	},
}

Config.CityBuildRadius = 160
Config.PresetSlots = {}

local function comma(n)
	n = tostring(math.floor(tonumber(n) or 0))
	local left, num, right = n:match("^([^%d]*%d)(%d*)(.-)$")
	if not num then return n end
	return left .. num:reverse():gsub("(%d%d%d)", "%1,"):reverse() .. right
end

function Config.FormatCurrency(value)
	local n = math.max(0, math.floor(tonumber(value) or 0))
	if n < 10000 then
		return comma(n)
	end
	local units = {
		{ value = 1000000000000, suffix = "t" },
		{ value = 1000000000, suffix = "b" },
		{ value = 1000000, suffix = "m" },
		{ value = 1000, suffix = "K" },
	}
	for _, unit in ipairs(units) do
		if n >= unit.value then
			local scaled = n / unit.value
			local text
			if scaled < 10 and math.floor(scaled) ~= scaled then
				text = string.format("%.1f", math.floor(scaled * 10) / 10):gsub("%.0$", "")
			else
				text = tostring(math.floor(scaled))
			end
			return text .. unit.suffix
		end
	end
	return tostring(n)
end

function Config.CopyCost(cost)
	local out = { Coin = math.max(0, math.floor(tonumber(cost and cost.Coin) or 0)), Items = {} }
	for itemId, amount in pairs((cost and cost.Items) or {}) do
		out.Items[itemId] = math.max(1, math.floor(tonumber(amount) or 1))
	end
	return out
end

function Config.GetCityUpgradePlan(level)
	level = math.clamp(math.floor(tonumber(level) or 1), 1, Config.City.MaxLevel)
	return Config.City.UpgradePlan[level] or Config.City.UpgradePlan[1]
end

function Config.GetCityUpgradeCost(currentLevel)
	local nextLevel = math.clamp(math.floor(tonumber(currentLevel) or 0) + 1, 1, Config.City.MaxLevel)
	local plan = Config.GetCityUpgradePlan(nextLevel)
	return Config.CopyCost((plan and plan.Cost) or Config.City.UpgradeCost)
end

function Config.GetCitySizeLevel(level)
	local plan = Config.GetCityUpgradePlan(level)
	return math.clamp(math.floor(tonumber(plan and plan.SizeLevel) or tonumber(level) or 1), 1, Config.City.MaxSizeLevel)
end

function Config.GetCitySlotSizeLevel(level)
	local plan = Config.GetCityUpgradePlan(level)
	return math.clamp(math.floor(tonumber(plan and plan.SlotSizeLevel) or Config.GetCitySizeLevel(level)), 1, Config.City.MaxSizeLevel)
end

function Config.GetCitySizeFraction(level)
	return Config.GetCitySizeLevel(level) / Config.City.MaxSizeLevel
end

function Config.GetCityLevelSize(reservedSize, level)
	local fraction = Config.GetCitySizeFraction(level)
	return Vector3.new(reservedSize.X * fraction, Config.City.BaseThickness, reservedSize.Z * fraction)
end

function Config.GetBuildingUpgradeCost(currentTier)
	local tier = math.clamp(math.floor(tonumber(currentTier) or 1), 1, Config.Building.MaxTier)
	local cost = Config.CopyCost(Config.Building.UpgradeCost)
	cost.Coin = math.max(0, math.floor((cost.Coin or 0) * tier))
	return cost
end

function Config.GetSlotPadSize()
	return Vector3.new(Config.BuildingSize.X, Config.City.SlotPadHeight, Config.BuildingSize.Z)
end

function Config.CopyRecipe(recipe)
	local out = { Items = {} }
	for itemId, amount in pairs((recipe and recipe.Items) or {}) do
		out.Items[itemId] = math.max(1, math.floor(tonumber(amount) or 1))
	end
	return out
end

function Config.GetRecipeItemCount(recipe)
	local total = 0
	for _, amount in pairs((recipe and recipe.Items) or {}) do
		total += math.max(0, math.floor(tonumber(amount) or 0))
	end
	return total
end

function Config.GetRecipeDuration(recipe)
	return Config.GetRecipeItemCount(recipe) * Config.City.RecipeSecondsPerItem
end

function Config.CostToText(cost)
	local parts = {}
	local coin = math.max(0, math.floor(tonumber(cost and cost.Coin) or 0))
	if coin > 0 then
		table.insert(parts, Config.FormatCurrency(coin) .. " Coin")
	end
	local items = (cost and cost.Items) or {}
	local keys = {}
	for itemId in pairs(items) do table.insert(keys, itemId) end
	table.sort(keys)
	for _, itemId in ipairs(keys) do
		table.insert(parts, tostring(items[itemId]) .. " " .. tostring(itemId))
	end
	return (#parts > 0) and table.concat(parts, " + ") or "Free"
end

return Config