--[[
Name: ItemCatalog
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Shared.ItemCatalog
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: copyArray, comma, addItem, cloneAbility, swordAbilities, recipeResourceId, basicRecipe, resourceFamilyKey, purityIdPart, purityDisplay, refiningSkillKey, valueWithPurity, addAbilityButton, ItemCatalog.NormalizeQuality, ItemCatalog.NormalizePurity, ItemCatalog.QualityBonus, ItemCatalog.PurityBonus, ItemCatalog.RawResourceId, ItemCatalog.RefinedResourceId, ItemCatalog.PurifiedIngredientId, ItemCatalog.RecipeForPurity, ItemCatalog.CraftablePuritiesFor, ItemCatalog.NormalizeId, ItemCatalog.Get, ItemCatalog.Exists, ItemCatalog.IsStackable, ItemCatalog.MaxStack, ItemCatalog.UnitWeight, ItemCatalog.StackWeight, ItemCatalog.CanEquipTo, ItemCatalog.ResourceId, ItemCatalog.MakeStack, ItemCatalog.ItemPower, ItemCatalog.RecipeValue, ItemCatalog.BuildDetail, ItemCatalog.GetClientCatalog
Clean source lines: 1368
]]
local ItemCatalog = {}

local DEFAULT_ICON = "Default"

ItemCatalog.QualityPowerBonus = {
	Dull = -35,
	Normal = 0,
	Fine = 35,
	Refined = 70,
	Superior = 105,
	Exceptional = 150,
	Legendary = 250,
	Artifact = 400,
}

ItemCatalog.PurityPowerBonus = {
	None = 0,
	Faint = 120,
	Kindled = 240,
	Ignited = 400,
	["Ashen Forged"] = 700,
}

ItemCatalog.QualityOrder = { "Dull", "Normal", "Fine", "Refined", "Superior", "Exceptional", "Legendary", "Artifact" }
ItemCatalog.PurityOrder = { "None", "Faint", "Kindled", "Ignited", "Ashen Forged" }

local QUALITY_ALIASES = {
	Poor = "Dull",
	Excellent = "Refined",
	Outstanding = "Superior",
	Masterpiece = "Legendary",
}

local PURITY_ALIASES = {
	Low = "Faint",
	Medium = "Kindled",
	High = "Ignited",
	Glowing = "Faint",
	Pure = "Kindled",
	Radiant = "Ignited",
	Transcendent = "Ashen Forged",
	AshenForged = "Ashen Forged",
}

function ItemCatalog.NormalizeQuality(quality)
	local text = tostring(quality or "Normal")
	return ItemCatalog.QualityPowerBonus[text] ~= nil and text or QUALITY_ALIASES[text] or "Normal"
end

function ItemCatalog.NormalizePurity(purity)
	local text = tostring(purity or "None")
	return ItemCatalog.PurityPowerBonus[text] ~= nil and text or PURITY_ALIASES[text] or "None"
end

function ItemCatalog.QualityBonus(quality)
	return ItemCatalog.QualityPowerBonus[ItemCatalog.NormalizeQuality(quality)] or 0
end

function ItemCatalog.PurityBonus(purity)
	return ItemCatalog.PurityPowerBonus[ItemCatalog.NormalizePurity(purity)] or 0
end

ItemCatalog.Items = {}
ItemCatalog.Aliases = {}
ItemCatalog.ResourceFamilies = {
	ore = {
		Display = "Ore",
		Plural = "Ore",
		Kind = "Ore",
		Description = "Raw metal-bearing ore used by smiths and refiners.",
		Weight = 0.32,
		Value = 3,
		Icon = "Ore",
	},
	stone = {
		Display = "Stone",
		Plural = "Stone",
		Kind = "Stone",
		Description = "Dense building stone used for masonry and crafting stations.",
		Weight = 0.45,
		Value = 2,
		Icon = "Stone",
	},
	wood = {
		Display = "Wood",
		Plural = "Wood",
		Kind = "Wood",
		Description = "Freshly cut timber used for tools, bows, buildings, and furniture.",
		Weight = 0.26,
		Value = 2,
		Icon = "Wood",
	},
	fiber = {
		Display = "Fiber",
		Plural = "Fiber",
		Kind = "Fiber",
		Description = "Plant fiber used by tailors, leatherworkers, and arcane crafters.",
		Weight = 0.12,
		Value = 2,
		Icon = "Fiber",
	},
	hide = {
		Display = "Hide",
		Plural = "Hide",
		Kind = "Hide",
		Description = "Cured animal hide used for leather gear and bags.",
		Weight = 0.22,
		Value = 3,
		Icon = "Hide",
	},
}

local function copyArray(source)
	local out = {}
	for i, value in ipairs(source or {}) do
		out[i] = value
	end
	return out
end

local function comma(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	local left, num, right = text:match("^([^%d]*%d)(%d*)(.-)$")
	if not num then return text end
	return left .. num:reverse():gsub("(%d%d%d)", "%1,"):reverse() .. right
end

local function addItem(def)
	def.Id = def.Id or def.id
	if not def.Id then
		error("Item definition is missing Id")
	end
	def.DisplayName = def.DisplayName or def.Name or def.Id
	def.Type = def.Type or def.Kind or "Item"
	def.Icon = def.Icon or DEFAULT_ICON
	def.Weight = tonumber(def.Weight) or 0
	def.Stackable = def.Stackable == true
	def.MaxStack = math.max(1, math.floor(tonumber(def.MaxStack) or (def.Stackable and 999 or 1)))
	def.Quality = ItemCatalog.NormalizeQuality(def.Quality or "Normal")
	def.Purity = ItemCatalog.NormalizePurity(def.Purity or "None")
	def.Value = math.max(0, math.floor(tonumber(def.Value) or 0))
	ItemCatalog.Items[def.Id] = def
	ItemCatalog.Aliases[string.lower(def.Id)] = def.Id
	ItemCatalog.Aliases[string.lower(def.DisplayName)] = def.Id
	for _, alias in ipairs(def.Aliases or {}) do
		ItemCatalog.Aliases[string.lower(alias)] = def.Id
	end
	return def
end

local SWORD_COMMON_ABILITIES = {
	{ Key = "Q", Index = 1, Name = "Cleave", Description = "Slash a short line in front of you.", Cooldown = 0.1, Range = 12, ManaCost = 0, Damage = 25, Icon = "Default" },
	{ Key = "Q", Index = 2, Name = "Whirlcut", Description = "Spin in place and hit enemies around you.", Cooldown = 3, Range = 7, ManaCost = 6, Damage = 18, Icon = "Default" },
	{ Key = "Q", Index = 3, Name = "Rending Sweep", Description = "Sweep a wider arc forward for a heavier melee hit.", Cooldown = 4, Range = 14, ManaCost = 8, Damage = 30, Icon = "Default" },
	{ Key = "W", Index = 1, Name = "Line Strike", Description = "Send a fast, broad sword line toward your aim direction.", Cooldown = 0.2, Range = 50, ManaCost = 0, Damage = 35, Icon = "Default" },
	{ Key = "W", Index = 2, Name = "Piercing Thrust", Description = "Thrust a narrow line that reaches farther than a normal slash.", Cooldown = 3.5, Range = 24, ManaCost = 10, Damage = 32, Icon = "Default" },
	{ Key = "W", Index = 3, Name = "Blade Wave", Description = "Launch a rolling wave of force along your aim direction.", Cooldown = 5, Range = 36, ManaCost = 14, Damage = 26, Icon = "Default" },
}

local function cloneAbility(def)
	local out = {}
	for key, value in pairs(def) do out[key] = value end
	return out
end

local function swordAbilities(uniqueName, uniqueDescription, uniqueCooldown, uniqueRange, uniqueManaCost, uniqueDamage)
	local abilities = {}
	for _, ability in ipairs(SWORD_COMMON_ABILITIES) do
		table.insert(abilities, cloneAbility(ability))
	end
	table.insert(abilities, {
		Key = "E",
		Index = 1,
		Name = uniqueName,
		Description = uniqueDescription,
		Cooldown = uniqueCooldown or 1,
		Range = uniqueRange or 30,
		ManaCost = uniqueManaCost or 0,
		Damage = uniqueDamage or 50,
		Icon = "Default",
	})
	return abilities
end

addItem({
	Id = "TestSword",
	Aliases = { "Weapons/Swords/TestSword", "Starter Sword", "Broadsword" },
	DisplayName = "Starter Broadsword",
	Type = "Weapon",
	Slot = "Weapon",
	EquipSlot = "Weapon",
	WeaponType = "Sword",
	Tier = 1,
	Stackable = false,
	Weight = 4.8,
	Value = 25,
	Icon = "Default",
	Power = 120,
	Description = "A simple iron broadsword. Plain, reliable, and good enough to start carving a path.",
	Stats = {
		"Physical attack bonus +95",
		"Attack speed +5%",
		"Basic range 10 studs",
	},
	Abilities = swordAbilities("Jump Impact", "Leap to a target point and hit enemies around the landing area.", 1, 30, 0),
	Recipe = {
		{ Id = "T1_Ore", Amount = 8 },
		{ Id = "T1_Wood", Amount = 2 },
	},
})

addItem({
	Id = "NoviceBag",
	DisplayName = "Novice Satchel",
	Type = "Bag",
	Slot = "Bag",
	EquipSlot = "Bag",
	Tier = 1,
	Stackable = false,
	Weight = 1.2,
	Value = 15,
	CarryCapacity = 20,
	Icon = "Default",
	Description = "A plain satchel that increases practical carry capacity.",
	Stats = { "Carry capacity +20 kg" },
	Recipe = {
		{ Id = "T1_Hide", Amount = 6 },
		{ Id = "T1_Fiber", Amount = 4 },
	},
})

addItem({
	Id = "SimpleTokenPouch",
	DisplayName = "Simple Token Pouch",
	Type = "Utility",
	Slot = "Bag",
	Tier = 1,
	Stackable = false,
	Weight = 0.4,
	Value = 20,
	Icon = "Default",
	Description = "A small pouch used to hold trade tokens and market slips.",
	Recipe = {
		{ Id = "T1_Hide", Amount = 2 },
		{ Id = "T1_Fiber", Amount = 2 },
	},
})

addItem({
	Id = "AshForgedBroadsword",
	Aliases = { "Ash Forged Broadsword", "Quality Test Sword", "Purity Test Sword" },
	DisplayName = "Ash-Forged Broadsword",
	Type = "Weapon",
	Slot = "Weapon",
	EquipSlot = "Weapon",
	WeaponType = "Sword",
	Tier = 3,
	Stackable = false,
	Weight = 5.1,
	Value = 180,
	Icon = "Default",
	Power = 260,
	Quality = "Excellent",
	Purity = "Glowing",
	Description = "A test broadsword carrying visible quality and purity metadata for inventory and detail UI checks.",
	Stats = {
		"Physical attack bonus +140",
		"Quality effect: Excellent item power display",
		"Purity effect: Glowing metadata display",
	},
	Abilities = swordAbilities("Ash Impact", "A focused leap strike used to verify ability rows still render.", 1, 30, 0),
	Recipe = {
		{ Id = "T3_Ore", Amount = 12 },
		{ Id = "T2_Wood", Amount = 4 },
	},
})

addItem({
	Id = "StormstepSaber",
	Aliases = { "Stormstep Saber", "Blink Test Sword", "Storm Sword" },
	DisplayName = "Stormstep Saber",
	Type = "Weapon",
	Slot = "Weapon",
	EquipSlot = "Weapon",
	WeaponType = "Sword",
	Tier = 3,
	Stackable = false,
	Weight = 4.9,
	Value = 300,
	Icon = "Default",
	Power = 300,
	Quality = "Excellent",
	Purity = "Glowing",
	Description = "A test saber with a blink-burst E ability for checking item-specific sword specials.",
	Stats = {
		"Item power 300",
		"Physical attack scales from item power",
		"Ability damage scales from item power",
	},
	Abilities = swordAbilities("Stormstep Burst", "Blink to a target point and burst on arrival.", 4, 34, 12, 42),
	Recipe = {
		{ Id = "T3_Ore", Amount = 10 },
		{ Id = "T2_Fiber", Amount = 3 },
	},
})

addItem({
	Id = "EarthsplitterGreatsword",
	Aliases = { "Earthsplitter Greatsword", "Rupture Test Sword", "Earth Sword" },
	DisplayName = "Earthsplitter Greatsword",
	Type = "Weapon",
	Slot = "Weapon",
	EquipSlot = "Weapon",
	WeaponType = "Sword",
	Tier = 3,
	Stackable = false,
	Weight = 6.2,
	Value = 360,
	Icon = "Default",
	Power = 360,
	Quality = "Outstanding",
	Purity = "Pure",
	Description = "A test greatsword with a delayed ground rupture E ability.",
	Stats = {
		"Item power 360",
		"Physical attack scales from item power",
		"Ability damage scales from item power",
	},
	Abilities = swordAbilities("Earthsplitter Rupture", "Mark a ground circle, then rupture it after a short warning.", 6, 32, 18, 64),
	Recipe = {
		{ Id = "T3_Ore", Amount = 14 },
		{ Id = "T3_Stone", Amount = 4 },
	},
})

addItem({
	Id = "GuardianLongsword",
	Aliases = { "Guardian Longsword", "Rush Test Sword", "Guardian Sword" },
	DisplayName = "Guardian Longsword",
	Type = "Weapon",
	Slot = "Weapon",
	EquipSlot = "Weapon",
	WeaponType = "Sword",
	Tier = 3,
	Stackable = false,
	Weight = 5.3,
	Value = 330,
	Icon = "Default",
	Power = 330,
	Quality = "Excellent",
	Purity = "Pure",
	Description = "A test longsword with a rushing E ability that knocks enemies away at the endpoint.",
	Stats = {
		"Item power 330",
		"Physical attack scales from item power",
		"Ability damage and armor scale from item power",
	},
	Abilities = swordAbilities("Guardian Rush", "Rush toward a point, damaging the path and knocking enemies away at the end.", 5, 28, 14, 38),
	Recipe = {
		{ Id = "T3_Ore", Amount = 12 },
		{ Id = "T2_Hide", Amount = 4 },
	},
})

addItem({
	Id = "PristineGatherersPack",
	DisplayName = "Pristine Gatherer's Pack",
	Type = "Bag",
	Slot = "Bag",
	EquipSlot = "Bag",
	Tier = 2,
	Stackable = false,
	Weight = 1.4,
	Value = 95,
	CarryCapacity = 35,
	Icon = "Default",
	Quality = "Outstanding",
	Purity = "Pure",
	Description = "A test pack with strong quality and purity values, used to verify inventory badges and item detail labels.",
	Stats = {
		"Carry capacity +35 kg",
		"Quality effect: Outstanding test display",
		"Purity effect: Pure test display",
	},
	Recipe = {
		{ Id = "T2_Hide", Amount = 8 },
		{ Id = "T2_Fiber", Amount = 6 },
	},
})

addItem({
	Id = "MasterpieceQualityBlade",
	Aliases = { "Quality Max Blade", "Masterpiece Blade", "Max Quality Sword" },
	DisplayName = "Masterpiece Quality Blade",
	Type = "Weapon",
	Slot = "Weapon",
	EquipSlot = "Weapon",
	WeaponType = "Sword",
	Tier = 4,
	Stackable = false,
	Weight = 5.4,
	Value = 420,
	Icon = "Default",
	Power = 420,
	Quality = "Masterpiece",
	Purity = "Transcendent",
	Description = "A max-quality test sword for checking quality display, details, equipment slots, and stat refresh.",
	Stats = {
		"Physical attack bonus +175",
		"Attack speed +10%",
		"Quality effect: Masterpiece max quality",
	},
	Abilities = swordAbilities("Masterpiece Impact", "A quality test leap strike used to verify max-quality equipment still keeps abilities working.", 1, 30, 0),
	Recipe = {
		{ Id = "T4_Ore", Amount = 14 },
		{ Id = "T3_Wood", Amount = 4 },
	},
})

addItem({
	Id = "RadiantPurityBlade",
	Aliases = { "Purity Before Max Blade", "Radiant Blade", "Before Max Purity Sword" },
	DisplayName = "Radiant Purity Blade",
	Type = "Weapon",
	Slot = "Weapon",
	EquipSlot = "Weapon",
	WeaponType = "Sword",
	Tier = 4,
	Stackable = false,
	Weight = 5.5,
	Value = 460,
	Icon = "Default",
	Power = 440,
	Quality = "Excellent",
	Purity = "Radiant",
	Description = "A before-max-purity test sword for checking purity badges and detail labels.",
	Stats = {
		"Physical attack bonus +165",
		"Attack speed +8%",
		"Purity effect: Radiant before max purity",
	},
	Abilities = swordAbilities("Radiant Impact", "A radiant test leap strike used to verify before-max purity keeps ability rows visible.", 1, 30, 0),
	Recipe = {
		{ Id = "T4_Ore", Amount = 12 },
		{ Id = "T4_Fiber", Amount = 3 },
	},
})

addItem({
	Id = "TranscendentPurityBlade",
	Aliases = { "Purity Max Blade", "Transcendent Blade", "Max Purity Sword" },
	DisplayName = "Transcendent Purity Blade",
	Type = "Weapon",
	Slot = "Weapon",
	EquipSlot = "Weapon",
	WeaponType = "Sword",
	Tier = 5,
	Stackable = false,
	Weight = 5.7,
	Value = 620,
	Icon = "Default",
	Power = 520,
	Quality = "Excellent",
	Purity = "Transcendent",
	Description = "A max-purity test sword for checking the highest purity state through inventory, details, storage, and equipment.",
	Stats = {
		"Physical attack bonus +195",
		"Attack speed +12%",
		"Purity effect: Transcendent max purity",
	},
	Abilities = swordAbilities("Transcendent Impact", "A high-purity test leap strike used to verify max-purity equipment still keeps abilities working.", 1, 30, 0),
	Recipe = {
		{ Id = "T5_Ore", Amount = 16 },
		{ Id = "T4_Fiber", Amount = 4 },
	},
})

local function recipeResourceId(kind, tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, 20)
	local key = tostring(kind or "Ore"):lower()
	if key:find("stone") or key:find("rock") then
		return "T" .. tostring(tier) .. "_Stone"
	elseif key:find("wood") or key:find("tree") or key:find("log") then
		return "T" .. tostring(tier) .. "_Wood"
	elseif key:find("fiber") or key:find("plant") or key:find("cloth") then
		return "T" .. tostring(tier) .. "_Fiber"
	elseif key:find("hide") or key:find("leather") or key:find("skin") then
		return "T" .. tostring(tier) .. "_Hide"
	end
	return "T" .. tostring(tier) .. "_Ore"
end

local function basicRecipe(mainKind, tier, mainAmount, extraKind, extraAmount)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, 20)
	local recipe = {
		{ Id = recipeResourceId(mainKind, tier), Amount = mainAmount or 1 },
	}
	if extraKind and extraAmount and extraAmount > 0 then
		table.insert(recipe, { Id = recipeResourceId(extraKind, tier), Amount = extraAmount })
	end
	return recipe
end

addItem({
	Id = "NovicePlateHelm",
	DisplayName = "Novice Plate Helm",
	Type = "Armor",
	Slot = "Helmet",
	EquipSlot = "Helmet",
	ArmorClass = "Plate",
	CraftingStationKey = "Warrior",
	CraftingCategory = "PlateArmor",
	Tier = 1,
	Weight = 2.1,
	Value = 40,
	Icon = "Default",
	Power = 100,
	Description = "A basic plate helmet made for frontline fighters.",
	Stats = { "Armor scales from item power", "Plate defense +10" },
	Recipe = basicRecipe("Ore", 1, 5, "Fiber", 1),
})

addItem({
	Id = "NovicePlateArmor",
	DisplayName = "Novice Plate Armor",
	Type = "Armor",
	Slot = "Armor",
	EquipSlot = "Armor",
	ArmorClass = "Plate",
	CraftingStationKey = "Warrior",
	CraftingCategory = "PlateArmor",
	Tier = 1,
	Weight = 6.6,
	Value = 70,
	Icon = "Default",
	Power = 120,
	Description = "A starter plate chestpiece for testing warrior armor crafting.",
	Stats = { "Armor scales from item power", "Plate defense +18" },
	Recipe = basicRecipe("Ore", 1, 8, "Hide", 2),
})

addItem({
	Id = "NovicePlateBoots",
	DisplayName = "Novice Plate Boots",
	Type = "Armor",
	Slot = "Boots",
	EquipSlot = "Boots",
	ArmorClass = "Plate",
	CraftingStationKey = "Warrior",
	CraftingCategory = "PlateArmor",
	Tier = 1,
	Weight = 2.8,
	Value = 38,
	Icon = "Default",
	Power = 100,
	Description = "Simple plated boots for the warrior line.",
	Stats = { "Armor scales from item power", "Plate defense +8" },
	Recipe = basicRecipe("Ore", 1, 4, "Hide", 1),
})

addItem({
	Id = "NoviceHuntingBow",
	DisplayName = "Novice Hunting Bow",
	Type = "Weapon",
	Slot = "Weapon",
	EquipSlot = "Weapon",
	WeaponType = "Bow",
	CraftingStationKey = "Hunter",
	CraftingCategory = "Weapons",
	Tier = 1,
	Weight = 3.2,
	Value = 45,
	Icon = "Default",
	Power = 115,
	Description = "A simple bow for hunter crafting and destiny board testing.",
	Stats = { "Ranged attack scales from item power" },
	Recipe = basicRecipe("Wood", 1, 7, "Fiber", 3),
})

addItem({
	Id = "NoviceLeatherJacket",
	DisplayName = "Novice Leather Jacket",
	Type = "Armor",
	Slot = "Armor",
	EquipSlot = "Armor",
	ArmorClass = "Leather",
	CraftingStationKey = "Hunter",
	CraftingCategory = "LeatherArmor",
	Tier = 1,
	Weight = 3.5,
	Value = 58,
	Icon = "Default",
	Power = 110,
	Description = "Light armor for hunter crafting tests.",
	Stats = { "Leather defense +12", "Mobility bonus +2%" },
	Recipe = basicRecipe("Hide", 1, 7, "Fiber", 3),
})

addItem({
	Id = "NoviceFireStaff",
	DisplayName = "Novice Fire Staff",
	Type = "Weapon",
	Slot = "Weapon",
	EquipSlot = "Weapon",
	WeaponType = "Fire Staff",
	CraftingStationKey = "Magic",
	CraftingCategory = "Staffs",
	Tier = 1,
	Weight = 3.8,
	Value = 50,
	Icon = "Default",
	Power = 120,
	Description = "A basic staff for magic station crafting and study tests.",
	Stats = { "Magic damage scales from item power" },
	Recipe = basicRecipe("Wood", 1, 5, "Fiber", 5),
})

addItem({
	Id = "NoviceClothRobe",
	DisplayName = "Novice Cloth Robe",
	Type = "Armor",
	Slot = "Armor",
	EquipSlot = "Armor",
	ArmorClass = "Cloth",
	CraftingStationKey = "Magic",
	CraftingCategory = "ClothArmor",
	Tier = 1,
	Weight = 1.9,
	Value = 52,
	Icon = "Default",
	Power = 105,
	Description = "A simple robe for the cloth crafting line.",
	Stats = { "Cloth defense +8", "Mana focus +5" },
	Recipe = basicRecipe("Fiber", 1, 9, "Hide", 1),
})

addItem({
	Id = "NovicePickaxe",
	DisplayName = "Novice Pickaxe",
	Type = "Tool",
	Slot = "Tool",
	CraftingStationKey = "Toolmaker",
	CraftingCategory = "Tools",
	Tier = 1,
	Weight = 2.4,
	Value = 35,
	Icon = "Default",
	Power = 90,
	Description = "A basic pickaxe for mining and toolmaker crafting tests.",
	Stats = { "Mining tool", "Tool power scales from item power" },
	Recipe = basicRecipe("Ore", 1, 3, "Wood", 3),
})

addItem({
	Id = "NoviceWoodAxe",
	DisplayName = "Novice Wood Axe",
	Type = "Tool",
	Slot = "Tool",
	CraftingStationKey = "Toolmaker",
	CraftingCategory = "Tools",
	Tier = 1,
	Weight = 2.2,
	Value = 35,
	Icon = "Default",
	Power = 90,
	Description = "A basic axe for woodcutting and toolmaker crafting tests.",
	Stats = { "Woodcutting tool", "Tool power scales from item power" },
	Recipe = basicRecipe("Ore", 1, 2, "Wood", 4),
})

local temporaryTools = {
	{ Id = "NoviceQuarryHammer", DisplayName = "Novice Quarry Hammer", Skill = "craft_tool_stone", Stat = "Stone gathering tool", Main = "Stone", Extra = "Wood" },
	{ Id = "NoviceSickle", DisplayName = "Novice Sickle", Skill = "craft_tool_fiber", Stat = "Fiber gathering tool", Main = "Fiber", Extra = "Ore" },
	{ Id = "NoviceSkinningKnife", DisplayName = "Novice Skinning Knife", Skill = "craft_tool_hide", Stat = "Hide gathering tool", Main = "Hide", Extra = "Ore" },
}
for _, tool in ipairs(temporaryTools) do
	addItem({
		Id = tool.Id,
		DisplayName = tool.DisplayName,
		Type = "Tool",
		Slot = "Tool",
		CraftingStationKey = "Toolmaker",
		CraftingCategory = "Tools",
		CraftingSkillKey = tool.Skill,
		Tier = 1,
		Weight = 2.2,
		Value = 35,
		Icon = "Default",
		Power = 90,
		Description = "",
		Stats = { tool.Stat, "Tool power scales from item power" },
		Recipe = basicRecipe(tool.Main, 1, 3, tool.Extra, 3),
	})
end

local ashTools = {
	{ Id = "AshPickaxe", DisplayName = "Ash Pickaxe", Skill = "craft_tool_ore", Stat = "Ore gathering tool", Main = "Ore", Extra = "Wood" },
	{ Id = "AshQuarryHammer", DisplayName = "Ash Quarry Hammer", Skill = "craft_tool_stone", Stat = "Stone gathering tool", Main = "Stone", Extra = "Wood" },
	{ Id = "AshWoodAxe", DisplayName = "Ash Wood Axe", Skill = "craft_tool_wood", Stat = "Wood gathering tool", Main = "Wood", Extra = "Ore" },
	{ Id = "AshSickle", DisplayName = "Ash Sickle", Skill = "craft_tool_fiber", Stat = "Fiber gathering tool", Main = "Fiber", Extra = "Ore" },
	{ Id = "AshSkinningKnife", DisplayName = "Ash Skinning Knife", Skill = "craft_tool_hide", Stat = "Hide gathering tool", Main = "Hide", Extra = "Ore" },
}
for _, tool in ipairs(ashTools) do
	addItem({
		Id = tool.Id,
		DisplayName = tool.DisplayName,
		Type = "Tool",
		Slot = "Tool",
		CraftingStationKey = "Toolmaker",
		CraftingCategory = "Tools",
		CraftingSkillKey = tool.Skill,
		Tier = 4,
		Weight = 2.8,
		Value = 180,
		Icon = "Default",
		Power = 420,
		Description = "",
		Stats = { tool.Stat, "Ash tool power scales from item power" },
		Recipe = basicRecipe(tool.Main, 4, 6, tool.Extra, 4),
	})
end

addItem({
	Id = "NoviceGatheringGarb",
	DisplayName = "Novice Gathering Garb",
	Type = "GatheringArmor",
	Slot = "Armor",
	EquipSlot = "Armor",
	CraftingStationKey = "Toolmaker",
	CraftingCategory = "GatheringArmor",
	Tier = 1,
	Weight = 2.5,
	Value = 55,
	Icon = "Default",
	Power = 105,
	Description = "Light gathering gear made by the toolmaker line.",
	Stats = { "Gathering carry +5 kg", "Gathering focus +3" },
	Recipe = basicRecipe("Fiber", 1, 5, "Hide", 5),
})

addItem({
	Id = "PineWorkshopChair",
	DisplayName = "Pine Workshop Chair",
	Type = "Furniture",
	CraftingStationKey = "Toolmaker",
	CraftingCategory = "Furniture",
	Tier = 1,
	Stackable = false,
	Weight = 3.0,
	Value = 28,
	Icon = "Default",
	Description = "A simple furniture item for station category testing.",
	Recipe = basicRecipe("Wood", 1, 6, "Fiber", 1),
})

addItem({
	Id = "BrownRidingHorse",
	Aliases = { "Horse", "NoviceHorse", "Novice Horse", "Mounts/Horses/BrownRidingHorse" },
	DisplayName = "Brown Riding Horse",
	Type = "Mount",
	Slot = "Mount",
	EquipSlot = "Mount",
	MountCategory = "Horses",
	MountTemplatePath = "Mounts/Horses/BrownRidingHorse",
	BaseSpeed = 16,
	MaxSpeed = 40,
	MountHealth = 300,
	CraftingStationKey = "Stablewright",
	CraftingCategory = "Mounts",
	Tier = 1,
	Weight = 0,
	Value = 120,
	Icon = "Default",
	Power = 100,
	Description = "A starter horse that can be equipped in the Mount slot.",
	Stats = { "Base speed 16", "Gallop speed 40" },
	Recipe = basicRecipe("Hide", 1, 6, "Wood", 4),
})

ItemCatalog.ResourceFamilyOrder = { "ore", "stone", "wood", "fiber", "hide" }
ItemCatalog.PurityMaterialOrder = { "Faint", "Kindled", "Ignited", "Ashen Forged" }
ItemCatalog.PurityIdParts = {
	Faint = "Faint",
	Kindled = "Kindled",
	Ignited = "Ignited",
	["Ashen Forged"] = "AshenForged",
}
ItemCatalog.PurityDisplayNames = {
	Faint = "Faint",
	Kindled = "Kindled",
	Ignited = "Ignited",
	["Ashen Forged"] = "Ashen-Forged",
}
ItemCatalog.RefinedResourceFamilies = {
	ore = { Display = "Metal Bar", IdPart = "MetalBar", Kind = "Metal Bar", RawDisplay = "Ore", Icon = "Ore", Weight = 0.24, Value = 5, StationKey = "OreRefinery", StationDisplay = "Smelter" },
	stone = { Display = "Stone Block", IdPart = "StoneBlock", Kind = "Stone Block", RawDisplay = "Stone", Icon = "Stone", Weight = 0.34, Value = 4, StationKey = "StoneRefinery", StationDisplay = "Masonry Kiln" },
	wood = { Display = "Plank", IdPart = "Plank", Kind = "Plank", RawDisplay = "Wood", Icon = "Wood", Weight = 0.18, Value = 4, StationKey = "WoodRefinery", StationDisplay = "Sawmill" },
	fiber = { Display = "Cloth", IdPart = "Cloth", Kind = "Cloth", RawDisplay = "Fiber", Icon = "Fiber", Weight = 0.09, Value = 4, StationKey = "FiberRefinery", StationDisplay = "Loom" },
	hide = { Display = "Leather", IdPart = "Leather", Kind = "Leather", RawDisplay = "Hide", Icon = "Hide", Weight = 0.16, Value = 5, StationKey = "HideRefinery", StationDisplay = "Tannery" },
}

ItemCatalog.RefiningRecipeAmounts = {
	[1] = { Raw = 1, Previous = 0 },
	[2] = { Raw = 1, Previous = 1 },
	[3] = { Raw = 2, Previous = 1 },
	[4] = { Raw = 2, Previous = 1 },
	[5] = { Raw = 3, Previous = 1 },
	[6] = { Raw = 3, Previous = 1 },
	[7] = { Raw = 4, Previous = 1 },
	[8] = { Raw = 4, Previous = 1 },
	[9] = { Raw = 4, Previous = 1 },
	[10] = { Raw = 5, Previous = 2 },
	[11] = { Raw = 5, Previous = 2 },
	[12] = { Raw = 5, Previous = 2 },
	[13] = { Raw = 5, Previous = 2 },
	[14] = { Raw = 6, Previous = 2 },
	[15] = { Raw = 6, Previous = 2 },
	[16] = { Raw = 6, Previous = 2 },
	[17] = { Raw = 7, Previous = 3 },
	[18] = { Raw = 8, Previous = 3 },
	[19] = { Raw = 9, Previous = 3 },
	[20] = { Raw = 10, Previous = 4 },
}

local function resourceFamilyKey(value)
	local key = tostring(value or ""):lower()
	if key:find("stone") or key:find("rock") then return "stone" end
	if key:find("wood") or key:find("tree") or key:find("log") or key:find("plank") then return "wood" end
	if key:find("fiber") or key:find("plant") or key:find("cloth") or key:find("flax") then return "fiber" end
	if key:find("hide") or key:find("leather") or key:find("skin") then return "hide" end
	return "ore"
end
ItemCatalog.ResourceFamilyKey = resourceFamilyKey

local function purityIdPart(purity)
	local normalized = ItemCatalog.NormalizePurity(purity)
	return ItemCatalog.PurityIdParts[normalized], normalized
end

local function purityDisplay(purity)
	local normalized = ItemCatalog.NormalizePurity(purity)
	return ItemCatalog.PurityDisplayNames[normalized] or normalized
end
ItemCatalog.PurityDisplayName = purityDisplay

function ItemCatalog.RawResourceId(kind, tier, purity)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, 20)
	local familyId = resourceFamilyKey(kind)
	local family = ItemCatalog.ResourceFamilies[familyId]
	if not family then return nil end
	local part, normalizedPurity = purityIdPart(purity)
	if normalizedPurity ~= "None" and tier >= 4 then
		return string.format("T%d_%s_%s", tier, part, family.Display)
	end
	return string.format("T%d_%s", tier, family.Display)
end

function ItemCatalog.RefinedResourceId(kind, tier, purity)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, 20)
	local familyId = resourceFamilyKey(kind)
	local family = ItemCatalog.RefinedResourceFamilies[familyId]
	if not family then return nil end
	local part, normalizedPurity = purityIdPart(purity)
	if normalizedPurity ~= "None" and tier >= 4 then
		return string.format("T%d_%s_%s", tier, part, family.IdPart)
	end
	return string.format("T%d_%s", tier, family.IdPart)
end

local function refiningSkillKey(familyId, tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, 20)
	if tier <= 3 then
		return "craft_refining"
	end
	return string.format("refine_%s_t%d", tostring(familyId or "ore"), tier)
end
ItemCatalog.RefiningSkillKey = refiningSkillKey

local function valueWithPurity(baseValue, purity)
	local normalized = ItemCatalog.NormalizePurity(purity)
	local multiplier = ({ None = 1, Faint = 1.35, Kindled = 1.8, Ignited = 2.5, ["Ashen Forged"] = 4.2 })[normalized] or 1
	return math.max(1, math.floor((tonumber(baseValue) or 1) * multiplier + 0.5))
end

for tier = 1, 20 do
	for _, familyId in ipairs(ItemCatalog.ResourceFamilyOrder) do
		local family = ItemCatalog.ResourceFamilies[familyId]
		local id = string.format("T%d_%s", tier, family.Display)
		local display = string.format("Tier %d %s", tier, family.Display)
		local weight = family.Weight * (1 + (tier - 1) * 0.045)
		local value = family.Value + math.floor((tier - 1) ^ 1.25)
		addItem({
			Id = id,
			Aliases = (tier == 1) and {
				string.format("T%d %s", tier, family.Display),
				string.format("Tier %d %s", tier, family.Display),
				string.format("%s T%d", family.Display, tier),
				family.Display,
				family.Kind,
			} or {
				string.format("T%d %s", tier, family.Display),
				string.format("Tier %d %s", tier, family.Display),
				string.format("%s T%d", family.Display, tier),
			},
			DisplayName = display,
			Type = "Resource",
			ResourceKind = family.Kind,
			ResourceFamily = familyId,
			Tier = tier,
			Stackable = true,
			MaxStack = 999,
			Weight = weight,
			Value = value,
			Icon = family.Icon,
			NonLosable = tier <= 3,
			Description = string.format("%s Tier %d material. Used by crafting, refining, and progression systems.", family.Description, tier),
		})
		if tier >= 4 then
			for _, purity in ipairs(ItemCatalog.PurityMaterialOrder) do
				local purityId = ItemCatalog.RawResourceId(familyId, tier, purity)
				addItem({
					Id = purityId,
					Aliases = {
						string.format("T%d %s %s", tier, purityDisplay(purity), family.Display),
						string.format("Tier %d %s %s", tier, purityDisplay(purity), family.Display),
					},
					DisplayName = string.format("Tier %d %s %s", tier, purityDisplay(purity), family.Display),
					Type = "Resource",
					ResourceKind = family.Kind,
					ResourceFamily = familyId,
					Tier = tier,
					Purity = purity,
					Stackable = true,
					MaxStack = 999,
					Weight = weight,
					Value = valueWithPurity(value, purity),
					Icon = family.Icon,
					Description = "",
				})
			end
		end
	end
end

for tier = 1, 20 do
	for _, familyId in ipairs(ItemCatalog.ResourceFamilyOrder) do
		local family = ItemCatalog.RefinedResourceFamilies[familyId]
		local amounts = ItemCatalog.RefiningRecipeAmounts[tier] or ItemCatalog.RefiningRecipeAmounts[1]
		local recipe = {
			{ Id = ItemCatalog.RawResourceId(familyId, tier, "None"), Amount = amounts.Raw },
		}
		if tier > 1 and amounts.Previous > 0 then
			table.insert(recipe, { Id = ItemCatalog.RefinedResourceId(familyId, tier - 1, "None"), Amount = amounts.Previous })
		end
		local baseValue = family.Value + math.floor((tier - 1) ^ 1.35) + (amounts.Raw * 2) + (amounts.Previous * 2)
		addItem({
			Id = ItemCatalog.RefinedResourceId(familyId, tier, "None"),
			Aliases = {
				string.format("T%d %s", tier, family.Display),
				string.format("Tier %d %s", tier, family.Display),
				string.format("%s T%d", family.Display, tier),
			},
			DisplayName = string.format("Tier %d %s", tier, family.Display),
			Type = "RefinedResource",
			ResourceKind = family.RawDisplay,
			ResourceFamily = familyId,
			RefinedKind = family.Kind,
			Tier = tier,
			Stackable = true,
			MaxStack = 999,
			Weight = family.Weight * (1 + (tier - 1) * 0.04),
			Value = baseValue,
			Icon = family.Icon,
			CraftingStationKey = family.StationKey,
			CraftingCategory = "Refining",
			RefiningSkillKey = refiningSkillKey(familyId, tier),
			Description = "",
			Recipe = recipe,
		})
		if tier >= 4 then
			for _, purity in ipairs(ItemCatalog.PurityMaterialOrder) do
				local purityRecipe = {
					{ Id = ItemCatalog.RawResourceId(familyId, tier, purity), Amount = amounts.Raw },
				}
				if amounts.Previous > 0 then
					local previousPurity = tier == 4 and "None" or purity
					table.insert(purityRecipe, { Id = ItemCatalog.RefinedResourceId(familyId, tier - 1, previousPurity), Amount = amounts.Previous })
				end
				addItem({
					Id = ItemCatalog.RefinedResourceId(familyId, tier, purity),
					Aliases = {
						string.format("T%d %s %s", tier, purityDisplay(purity), family.Display),
						string.format("Tier %d %s %s", tier, purityDisplay(purity), family.Display),
					},
					DisplayName = string.format("Tier %d %s %s", tier, purityDisplay(purity), family.Display),
					Type = "RefinedResource",
					ResourceKind = family.RawDisplay,
					ResourceFamily = familyId,
					RefinedKind = family.Kind,
					Tier = tier,
					Purity = purity,
					Stackable = true,
					MaxStack = 999,
					Weight = family.Weight * (1 + (tier - 1) * 0.04),
					Value = valueWithPurity(baseValue, purity),
					Icon = family.Icon,
					CraftingStationKey = family.StationKey,
					CraftingCategory = "Refining",
					RefiningSkillKey = refiningSkillKey(familyId, tier),
					Description = "",
					Recipe = purityRecipe,
				})
			end
		end
	end
end

function ItemCatalog.PurifiedIngredientId(itemId, purity)
	local normalizedPurity = ItemCatalog.NormalizePurity(purity)
	if normalizedPurity == "None" then
		return ItemCatalog.NormalizeId(itemId)
	end
	local id = ItemCatalog.NormalizeId(itemId)
	local def = id and ItemCatalog.Get(id)
	local tier = math.clamp(math.floor(tonumber(def and def.Tier) or 1), 1, 20)
	if not def or tier < 4 then
		return id
	end
	local candidate
	if def.Type == "Resource" and def.ResourceKind then
		candidate = ItemCatalog.RawResourceId(def.ResourceFamily or def.ResourceKind, tier, normalizedPurity)
	elseif def.Type == "RefinedResource" and def.ResourceKind then
		candidate = ItemCatalog.RefinedResourceId(def.ResourceFamily or def.ResourceKind, tier, normalizedPurity)
	end
	return (candidate and ItemCatalog.Items[candidate] and candidate) or id
end

function ItemCatalog.RecipeForPurity(def, purity)
	local normalizedPurity = ItemCatalog.NormalizePurity(purity)
	local out = {}
	for _, req in ipairs((def and def.Recipe) or {}) do
		local itemId = req.Id or req.id or req.ItemId or req.itemId
		local amount = math.max(1, math.floor(tonumber(req.Amount or req.amount or req.Count or req.count) or 1))
		if normalizedPurity ~= "None" and math.floor(tonumber(def and def.Tier) or 1) >= 4 then
			itemId = ItemCatalog.PurifiedIngredientId(itemId, normalizedPurity)
		end
		table.insert(out, { Id = itemId, Amount = amount })
	end
	return out
end

function ItemCatalog.CraftablePuritiesFor(def)
	local tier = math.floor(tonumber(def and def.Tier) or 1)
	if tier < 4 or type(def) ~= "table" or def.Type == "Resource" or def.Type == "RefinedResource" then
		return { "None" }
	end
	return { "None", "Faint", "Kindled", "Ignited", "Ashen Forged" }
end

ItemCatalog.CoinSackValues = { 10, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 75000, 100000, 150000, 200000, 300000, 400000, 600000, 800000, 1000000 }
for tier, value in ipairs(ItemCatalog.CoinSackValues) do
	addItem({
		Id = string.format("T%d_CoinSack", tier),
		DisplayName = string.format("Tier %d Coin Sack", tier),
		Type = "CoinSack",
		Tier = tier,
		Stackable = true,
		MaxStack = 999,
		NotAuctionable = true,
		Tags = { NotAuctionable = true },
		Weight = 0.02,
		Value = value,
		Icon = "Default",
		Description = string.format("A sealed coin sack worth %s Coin when paid out by loot systems.", tostring(value)),
	})
end

ItemCatalog.PurityCatalystFamilies = {
	{ IdPrefix = "EmberRune", Display = "Ember Rune", Type = "PurityCatalyst", Purity = "Faint" },
	{ IdPrefix = "KindledSoul", Display = "Kindled Soul", Type = "PurityCatalyst", Purity = "Kindled" },
	{ IdPrefix = "CinderRelic", Display = "Cinder Relic", Type = "PurityCatalyst", Purity = "Ignited" },
	{ IdPrefix = "AshenRelic", Display = "Ashen Relic", Type = "PurityCatalyst", Purity = "Ashen Forged" },
}
for tier = 1, 20 do
	for _, family in ipairs(ItemCatalog.PurityCatalystFamilies) do
		addItem({
			Id = string.format("T%d_%s", tier, family.IdPrefix),
			DisplayName = string.format("Tier %d %s", tier, family.Display),
			Type = family.Type,
			CatalystPurity = family.Purity,
			Tier = tier,
			Stackable = true,
			MaxStack = 999,
			Weight = 0.04,
			Value = math.max(4, tier * tier * ({ Faint = 6, Kindled = 15, Ignited = 38, ["Ashen Forged"] = 90 })[family.Purity]),
			Icon = "Default",
			Description = string.format("A %s catalyst used by future purity upgrade flows.", family.Display),
		})
	end
end

ItemCatalog.PurityUpgradeRequirements = {
	Faint = { EmberRune = 8 },
	Kindled = { EmberRune = 16, KindledSoul = 4 },
	Ignited = { EmberRune = 24, KindledSoul = 8, CinderRelic = 2 },
	["Ashen Forged"] = { EmberRune = 40, KindledSoul = 16, CinderRelic = 6, AshenRelic = 1 },
}

local DESCRIPTION_TYPES = {
	CoinSack = true,
	PurityCatalyst = true,
}

for _, def in pairs(ItemCatalog.Items) do
	if not DESCRIPTION_TYPES[def.Type] then
		def.Description = ""
	end
end

function ItemCatalog.NormalizeId(id)
	if id == nil then
		return nil
	end
	local raw = tostring(id)
	if ItemCatalog.Items[raw] then
		return raw
	end
	return ItemCatalog.Aliases[string.lower(raw)]
end

function ItemCatalog.Get(id)
	local normalized = ItemCatalog.NormalizeId(id)
	return normalized and ItemCatalog.Items[normalized] or nil
end

function ItemCatalog.Exists(id)
	return ItemCatalog.Get(id) ~= nil
end

function ItemCatalog.IsStackable(id)
	local def = ItemCatalog.Get(id)
	return def and def.Stackable == true or false
end

function ItemCatalog.MaxStack(id)
	local def = ItemCatalog.Get(id)
	return def and def.MaxStack or 1
end

function ItemCatalog.UnitWeight(id)
	local def = ItemCatalog.Get(id)
	return def and def.Weight or 0
end

function ItemCatalog.StackWeight(stack)
	if type(stack) ~= "table" then
		return 0
	end
	return ItemCatalog.UnitWeight(stack.Id or stack.id) * math.max(1, tonumber(stack.Amount or stack.amount) or 1)
end

function ItemCatalog.CanEquipTo(id, equipSlot)
	local def = ItemCatalog.Get(id)
	if not def or not equipSlot then
		return false
	end
	if def.EquipSlot == equipSlot or def.Slot == equipSlot then
		return true
	end
	if type(def.EquipSlots) == "table" then
		for _, slot in ipairs(def.EquipSlots) do
			if slot == equipSlot then
				return true
			end
		end
	end
	return false
end

function ItemCatalog.ResourceId(kind, itemName, tier, purity)
	return ItemCatalog.RawResourceId(kind or itemName or "ore", tier, purity)
end

function ItemCatalog.MakeStack(id, amount, quality, purity, craftedBy)
	local normalized = ItemCatalog.NormalizeId(id)
	if not normalized then
		return nil
	end
	local def = ItemCatalog.Items[normalized]
	return {
		Id = normalized,
		Amount = math.max(1, math.floor(tonumber(amount) or 1)),
		Quality = ItemCatalog.NormalizeQuality(quality or def.Quality or "Normal"),
		Purity = ItemCatalog.NormalizePurity(purity or def.Purity or "None"),
		CraftedBy = craftedBy,
	}
end

function ItemCatalog.ItemPower(id, quality, purity)
	local def = ItemCatalog.Get(id)
	local base = def and (tonumber(def.Power or def.ItemPower) or ((tonumber(def.Tier) or 1) * 100)) or 0
	return math.max(0, math.floor(base + ItemCatalog.QualityBonus(quality or (def and def.Quality)) + ItemCatalog.PurityBonus(purity or (def and def.Purity))))
end

function ItemCatalog.RecipeValue(id)
	local def = ItemCatalog.Get(id)
	if not def then return 0 end
	local total = 0
	for _, req in ipairs(def.Recipe or {}) do
		local reqDef = ItemCatalog.Get(req.Id or req.id)
		local amount = math.max(1, math.floor(tonumber(req.Amount or req.amount) or 1))
		if reqDef then total += (tonumber(reqDef.Value) or 0) * amount end
	end
	return math.max(total, tonumber(def.Value) or 0)
end

function ItemCatalog.BuildDetail(stack, context)
	if type(stack) ~= "table" then
		return nil
	end
	local id = stack.Id or stack.id
	local def = ItemCatalog.Get(id)
	if not def then
		return nil
	end
	local amount = math.max(1, math.floor(tonumber(stack.Amount or stack.amount) or 1))
	local recipeGrid = {}
	for _, req in ipairs(def.Recipe or {}) do
		local reqDef = ItemCatalog.Get(req.Id or req.id)
		table.insert(recipeGrid, {
			id = req.Id or req.id,
			imageId = reqDef and reqDef.Icon or DEFAULT_ICON,
			name = string.format("%s x%d", reqDef and reqDef.DisplayName or tostring(req.Id or req.id), math.max(1, tonumber(req.Amount or req.amount) or 1)),
		})
	end
	local abilities = {}
	local abilitiesGrid = {}
	local abilityIcons = {}
	local function addAbilityButton(key, iconId, meta)
		key = tostring(key or "Passive")
		abilitiesGrid[key] = abilitiesGrid[key] or {}
		table.insert(abilitiesGrid[key], {
			id = iconId or DEFAULT_ICON,
			imageId = iconId or DEFAULT_ICON,
			selectable = true,
			meta = meta,
		})
		abilityIcons[key] = abilityIcons[key] or iconId or DEFAULT_ICON
	end
	for _, ability in ipairs(def.Abilities or {}) do
		if type(ability) == "table" then
			local key = tostring(ability.Key or ability.key or ability.Row or ability.row or "Passive")
			local name = tostring(ability.Name or ability.name or key or "Ability")
			local description = tostring(ability.Description or ability.description or "")
			local iconId = ability.Icon or ability.icon or ability.ImageId or ability.imageId or ability.Id or ability.id or DEFAULT_ICON
			table.insert(abilities, string.format("%s - %s", name, description))
			addAbilityButton(key, iconId, {
				key = key,
				index = ability.Index or ability.index,
				name = name,
				description = description,
				id = ability.Id or ability.id,
				cooldown = ability.Cooldown or ability.cooldown,
				range = ability.Range or ability.range,
				manaCost = ability.ManaCost or ability.manaCost or ability.Mana or ability.mana,
				damage = ability.Damage or ability.damage or ability.BaseDamage or ability.baseDamage,
				targetType = ability.TargetType or ability.targetType,
			})
		else
			local text = tostring(ability)
			local key = text:match("^([%w%d]+)%s*[%-%:]") or "Passive"
			table.insert(abilities, text)
			addAbilityButton(key, DEFAULT_ICON, text)
		end
	end
	local quality = ItemCatalog.NormalizeQuality(stack.Quality or stack.quality or def.Quality or "Normal")
	local purity = ItemCatalog.NormalizePurity(stack.Purity or stack.purity or def.Purity or "None")
	local itemType = def.Type or "Item"
	local craftedBy = stack.CraftedBy or stack.craftedBy or def.CraftedBy
	local foundBy = stack.FoundBy or stack.foundBy or def.FoundBy or "World"
	local isCraftedItem = craftedBy and itemType ~= "CoinSack" and itemType ~= "PurityCatalyst"
	local marketEach = tonumber(stack.UnitValue or stack.MarketValueEach or stack.EstimatedUnitValue or (context and (context.MarketValueEach or context.UnitValue)))
	local marketStack = tonumber(stack.EstimatedValue or stack.MarketValueStack or (context and (context.MarketValueStack or context.EstimatedValue)))
	if not marketEach and marketStack and amount > 0 then
		marketEach = math.max(1, math.floor((marketStack / amount) + 0.5))
	end
	if not marketEach then
		marketEach = math.max(0, math.floor(tonumber(def.Value) or 0), ItemCatalog.RecipeValue(def.Id))
	end
	marketStack = marketStack or (marketEach * amount)
	local info = {
		string.format("Market value (per one): %s Coin", comma(marketEach)),
	}
	if amount > 1 then
		table.insert(info, string.format("Market value (Stack): %s Coin", comma(marketStack)))
	end
	return {
		id = def.Id,
		imageId = def.Icon,
		amount = amount,
		qualityName = quality,
		purity = purity,
		weightTotal = ItemCatalog.UnitWeight(def.Id) * amount,
		weightPercent = context and context.WeightPercent or 0,
		byType = isCraftedItem and "Crafted" or "Found",
		byName = isCraftedItem and craftedBy or foundBy,
		itemName = def.DisplayName,
		power = ItemCatalog.ItemPower(def.Id, quality, purity),
		description = def.Description or "",
		slot = def.Slot,
		inventorySlot = stack.Slot or stack.slot or (context and (context.Slot or context.InventorySlot)),
		value = def.Value and (tostring(def.Value) .. " Coin") or "-",
		marketValueEach = marketEach,
		marketValueStack = marketStack,
		info = info,
		Info = info,
		itemType = itemType,
		type = itemType,
		stats = copyArray(def.Stats),
		abilities = abilities,
		abilityIcons = abilityIcons,
		abilitiesGrid = abilitiesGrid,
		abilityRows = abilitiesGrid,
		recipeGrid = recipeGrid,
		recipe = {},
	}
end

function ItemCatalog.GetClientCatalog()
	local out = {}
	for id, def in pairs(ItemCatalog.Items) do
		out[id] = {
			Id = id,
			DisplayName = def.DisplayName,
			Type = def.Type,
			Slot = def.Slot,
			EquipSlot = def.EquipSlot,
			Tier = def.Tier,
			Stackable = def.Stackable,
			MaxStack = def.MaxStack,
			Weight = def.Weight,
			Value = def.Value,
			Icon = def.Icon,
			Quality = def.Quality,
			Purity = def.Purity,
			QualityPowerBonus = ItemCatalog.QualityBonus(def.Quality),
			PurityPowerBonus = ItemCatalog.PurityBonus(def.Purity),
			Description = def.Description,
			Stats = copyArray(def.Stats),
			Abilities = copyArray(def.Abilities),
			Recipe = copyArray(def.Recipe),
			WeaponType = def.WeaponType,
			ArmorClass = def.ArmorClass,
			CraftingStationKey = def.CraftingStationKey,
			CraftingCategory = def.CraftingCategory,
			CraftingSkillKey = def.CraftingSkillKey,
			RefiningSkillKey = def.RefiningSkillKey,
			ResourceKind = def.ResourceKind,
			ResourceFamily = def.ResourceFamily,
			RefinedKind = def.RefinedKind,
			Power = def.Power,
		}
	end
	return out
end

return ItemCatalog
