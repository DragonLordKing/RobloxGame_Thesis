--[[
Name: DestinyBoardConfig
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.DestinyBoardConfig
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: keyPart, addSkill, addAlias, copyLine, addVariantAlias, wordVariants, addCombatItem, addCraftingItem, addUtilityCraftingItem, registerCraftingLine, levelCost, levelFromTotals, majorBranchForLine, branchLevelRequiredForTier, findLine, variantFor, normalizeSlot, isDebugExpansionNode, Config.ValorRequiredForLevel, Config.MaxValorForSkill, Config.GetLevelForValor, Config.RootUnlockTier, Config.BranchUnlockTier, Config.RequiredMasteryLevelForTier, Config.MasteryUnlockTier, Config.LevelToUnlockTier, Config.GetUnlockTierForSkill, Config.MajorCombatBranchForLine, Config.MajorCraftingBranchForLine, Config.CanProgressLineMastery, Config.RequiredCombatSkillForTier, Config.CanUseCombatTier, Config.RequiredCraftingSkillForTier, Config.CanCraftItemTier, Config.ProgressForValor, Config.BuildSkillSnapshot, Config.SkillKeyForWeapon, Config.CombatLineForWeapon, Config.CombatLineForArmor, Config.CraftingLineForItem, Config.SkillKeyForGather, Config.CanProgressGatherSkill, Config.SkillKeyForRefining, Config.CanProgressRefiningSkill, Config.CanRefineTier, Config.NpcValorForTier, Config.GatherValorForTier
Clean source lines: 1114
]]
local Config = {}

Config.MaxTier = 20
Config.AdventurerMaxLevel = 1000
Config.RootMaxLevel = 3
Config.CombatBranchMaxLevel = 20
Config.CombatMasteryMaxLevel = 1000
Config.VeterancyMaxLevel = 250
Config.GatheringMaxLevel = 200
Config.CraftingBranchMaxLevel = 20
Config.CraftingMasteryMaxLevel = 1000
Config.CraftingVeterancyMaxLevel = 200

Config.ActivityRootKey = "adventurer_t1_3"
Config.CombatRootKey = "combat_t1_3"
Config.GatheringRootKey = "gather_t1_3"
Config.CraftingRootKey = "craft_t1_3"

Config.CombatValorPointsName = "Combat Valor Points"
Config.InsightName = "Insight"
Config.BoardMinZoom = 0.15
Config.BoardMaxZoom = 1.7
Config.BoardDefaultZoom = 0.55

Config.Skills = {}
Config.NodeOrder = {}
Config.CombatLines = {}
Config.CraftingLines = {}
Config.GatheringLines = {}
Config.RefiningLines = {}

local debugOnlyNodes = {}

local function keyPart(value)
	local s = tostring(value or ""):lower()
	s = s:gsub("%s+", "_")
	s = s:gsub("[^%w_]", "")
	return s
end
Config.KeyPart = keyPart

local function addSkill(key, def)
	def.Key = key
	def.IconText = def.IconText or "?"
	def.ShortName = def.ShortName or def.DisplayName or key
	def.Description = def.Description or "No description yet."
	def.MaxLevel = def.MaxLevel or 100
	def.Layout = def.Layout or { X = 0, Y = 0 }
	Config.Skills[key] = def
	table.insert(Config.NodeOrder, key)
	return def
end

local function addAlias(bucket, aliases, data)
	for _, alias in ipairs(aliases or {}) do
		bucket[keyPart(alias)] = data
	end
end

local function copyLine(line)
	if not line then return nil end
	local out = {}
	for k, v in pairs(line) do
		out[k] = v
	end
	return out
end

local function addVariantAlias(lineInfo, aliases, specKey)
	for _, alias in ipairs(aliases or {}) do
		lineInfo.VariantAliases[keyPart(alias)] = specKey
	end
end

local specWords = {
	"Adept", "Soldier", "Guardian", "Knight", "Royal",
	"Mercenary", "Warden", "Duelist", "Ranger", "Mystic",
	"Runed", "Iron", "Steel", "Storm", "Sun",
	"Moon", "Rift", "Ash", "Dawn", "Elder",
}

local function wordVariants(baseName, words)
	local variants = {}
	for _, word in ipairs(words or specWords) do
		table.insert(variants, {
			Name = word .. " " .. baseName,
			ShortName = word,
			Aliases = { word .. " " .. baseName, baseName .. " " .. word },
		})
	end
	return variants
end

local swordVariants = {
	{ Name = "Broadsword", ShortName = "Broad", Aliases = { "broadsword", "test_sword", "testsword", "starter sword" } },
	{ Name = "Claymore", ShortName = "Claymore", Aliases = { "claymore" } },
	{ Name = "Carving Sword", ShortName = "Carve", Aliases = { "carving sword", "carver sword" } },
	{ Name = "Dual Swords", ShortName = "Dual", Aliases = { "dual swords", "dual_swords" } },
	{ Name = "Knight Sword", ShortName = "Knight", Aliases = { "knight sword" } },
	{ Name = "Royal Saber", ShortName = "Saber", Aliases = { "royal saber", "saber" } },
	{ Name = "Twin Blades", ShortName = "Twin", Aliases = { "twin blades" } },
	{ Name = "Greatsword", ShortName = "Great", Aliases = { "greatsword", "great sword" } },
	{ Name = "Duelist Rapier", ShortName = "Rapier", Aliases = { "duelist rapier", "rapier" } },
	{ Name = "Falcon Blade", ShortName = "Falcon", Aliases = { "falcon blade" } },
	{ Name = "Warden Longsword", ShortName = "Warden", Aliases = { "warden longsword", "longsword" } },
	{ Name = "Runed Saber", ShortName = "Runed", Aliases = { "runed saber" } },
	{ Name = "Ironbrand", ShortName = "Iron", Aliases = { "ironbrand" } },
	{ Name = "Mercyblade", ShortName = "Mercy", Aliases = { "mercyblade" } },
	{ Name = "Oath Edge", ShortName = "Oath", Aliases = { "oath edge" } },
	{ Name = "Sunsteel Sword", ShortName = "Sun", Aliases = { "sunsteel sword" } },
	{ Name = "Moonlit Claymore", ShortName = "Moon", Aliases = { "moonlit claymore" } },
	{ Name = "Rift Cutter", ShortName = "Rift", Aliases = { "rift cutter" } },
	{ Name = "Storm Saber", ShortName = "Storm", Aliases = { "storm saber" } },
	{ Name = "Ashen Greatblade", ShortName = "Ash", Aliases = { "ashen greatblade" } },
}

addSkill("adventurer_t1_3", {
	DisplayName = "Novice Adventurer",
	Category = "Adventurer",
	ShortName = "Adventurer",
	IconText = "A",
	NodeType = "Root",
	MaxLevel = Config.AdventurerMaxLevel,
	Description = "The long adventurer path from Tier 1 to Tier 20. Everyone starts at level 1 so Tier 1 is always usable.",
	Layout = { X = 0, Y = 0 },
})

addSkill("combat_t1_3", {
	DisplayName = "Novice Combatant",
	Category = "Combat",
	ShortName = "Combatant",
	IconText = "CB",
	Parent = Config.ActivityRootKey,
	NodeType = "CombatRoot",
	Activity = "Combat",
	MaxLevel = Config.RootMaxLevel,
	Description = "The shared Tier 2-3 combat foundation. Any early fighting feeds this before Vanguard, Pathfinder, and Arcanist open outward.",
	Layout = { X = -3200, Y = 0 },
})

local combatBranches = {
	{ Key = "combat_vanguard", DisplayName = "Vanguard", ShortName = "Vanguard", IconText = "VG", X = -9800, Y = -9000, Description = "Heavy combat identity for plate gear, swords, axes, hammers, and direct fighting roles." },
	{ Key = "combat_pathfinder", DisplayName = "Pathfinder", ShortName = "Pathfinder", IconText = "PF", X = -9800, Y = 0, Description = "Agile combat identity for leather gear, bows, daggers, crossbows, mobility, and precision damage." },
	{ Key = "combat_arcanist", DisplayName = "Arcanist", ShortName = "Arcanist", IconText = "AR", X = -9800, Y = 9000, Description = "Mystic combat identity for cloth gear, fire staffs, frost, arcane, holy, and magical roles." },
}

for _, branch in ipairs(combatBranches) do
	addSkill(branch.Key, {
		DisplayName = branch.DisplayName,
		Category = "Combat",
		ShortName = branch.ShortName,
		IconText = branch.IconText,
		Parent = Config.CombatRootKey,
		NodeType = "CombatBranch",
		Activity = "Combat",
		MaxLevel = Config.CombatBranchMaxLevel,
		Description = branch.Description,
		Layout = { X = branch.X, Y = branch.Y },
	})
end

local combatItems = {
	{ Key = "weapon_sword", DisplayName = "Swords", ShortName = "Swords", IconText = "SW", Parent = "combat_vanguard", Slot = "Weapon", Line = "sword", Kind = "Weapon", Aliases = { "sword", "swords", "testsword", "test_sword", "broadsword", "claymore" }, Variants = swordVariants },
	{ Key = "plate_helmet", DisplayName = "Plate Helmet", ShortName = "Plate Helm", IconText = "PH", Parent = "combat_vanguard", Slot = "Helmet", Line = "plate_helmet", Kind = "Armor", Aliases = { "plate_helmet", "platehelm", "plate helm", "plate head" }, Variants = wordVariants("Plate Helmet") },
	{ Key = "plate_armor", DisplayName = "Plate Armor", ShortName = "Plate Armor", IconText = "PA", Parent = "combat_vanguard", Slot = "Armor", Line = "plate_armor", Kind = "Armor", Aliases = { "plate_armor", "plate chest", "plate armor" }, Variants = wordVariants("Plate Armor") },
	{ Key = "plate_boots", DisplayName = "Plate Boots", ShortName = "Plate Boots", IconText = "PB", Parent = "combat_vanguard", Slot = "Boots", Line = "plate_boots", Kind = "Armor", Aliases = { "plate_boots", "plate boots", "plate feet" }, Variants = wordVariants("Plate Boots") },
	{ Key = "weapon_bow", DisplayName = "Bows", ShortName = "Bows", IconText = "BW", Parent = "combat_pathfinder", Slot = "Weapon", Line = "bow", Kind = "Weapon", Aliases = { "bow", "bows", "longbow", "warbow" }, Variants = wordVariants("Bow") },
	{ Key = "leather_helmet", DisplayName = "Leather Hood", ShortName = "Leather Hood", IconText = "LH", Parent = "combat_pathfinder", Slot = "Helmet", Line = "leather_helmet", Kind = "Armor", Aliases = { "leather_helmet", "leather hood", "leather helm", "leather head" }, Variants = wordVariants("Leather Hood") },
	{ Key = "leather_armor", DisplayName = "Leather Jacket", ShortName = "Leather Jacket", IconText = "LJ", Parent = "combat_pathfinder", Slot = "Armor", Line = "leather_armor", Kind = "Armor", Aliases = { "leather_armor", "leather jacket", "leather chest" }, Variants = wordVariants("Leather Jacket") },
	{ Key = "leather_boots", DisplayName = "Leather Shoes", ShortName = "Leather Shoes", IconText = "LS", Parent = "combat_pathfinder", Slot = "Boots", Line = "leather_boots", Kind = "Armor", Aliases = { "leather_boots", "leather shoes", "leather boots", "leather feet" }, Variants = wordVariants("Leather Shoes") },
	{ Key = "weapon_fire_staff", DisplayName = "Fire Staffs", ShortName = "Fire Staff", IconText = "FS", Parent = "combat_arcanist", Slot = "Weapon", Line = "fire_staff", Kind = "Weapon", Aliases = { "firestaff", "fire_staff", "fire staff", "staff_fire" }, Variants = wordVariants("Fire Staff") },
	{ Key = "cloth_helmet", DisplayName = "Cloth Cowl", ShortName = "Cloth Cowl", IconText = "CH", Parent = "combat_arcanist", Slot = "Helmet", Line = "cloth_helmet", Kind = "Armor", Aliases = { "cloth_helmet", "cloth cowl", "cloth hood", "cloth head" }, Variants = wordVariants("Cloth Cowl") },
	{ Key = "cloth_armor", DisplayName = "Cloth Robe", ShortName = "Cloth Robe", IconText = "CR", Parent = "combat_arcanist", Slot = "Armor", Line = "cloth_armor", Kind = "Armor", Aliases = { "cloth_armor", "cloth robe", "robe", "cloth chest" }, Variants = wordVariants("Cloth Robe") },
	{ Key = "cloth_boots", DisplayName = "Cloth Sandals", ShortName = "Cloth Sandals", IconText = "CS", Parent = "combat_arcanist", Slot = "Boots", Line = "cloth_boots", Kind = "Armor", Aliases = { "cloth_boots", "cloth sandals", "cloth shoes", "cloth feet" }, Variants = wordVariants("Cloth Sandals") },

	{ Key = "weapon_axe", DisplayName = "Axes", ShortName = "Axes", IconText = "AX", Parent = "combat_vanguard", Slot = "Weapon", Line = "axe", Kind = "Weapon", Aliases = { "axe", "axes", "battle axe", "greataxe" }, Variants = wordVariants("Axe") },
	{ Key = "weapon_hammer", DisplayName = "Hammers", ShortName = "Hammers", IconText = "HM", Parent = "combat_vanguard", Slot = "Weapon", Line = "hammer", Kind = "Weapon", Aliases = { "hammer", "hammers", "warhammer", "war hammer" }, Variants = wordVariants("Hammer") },
	{ Key = "weapon_mace", DisplayName = "Maces", ShortName = "Maces", IconText = "MC", Parent = "combat_vanguard", Slot = "Weapon", Line = "mace", Kind = "Weapon", Aliases = { "mace", "maces", "morningstar" }, Variants = wordVariants("Mace") },
	{ Key = "weapon_spear", DisplayName = "Spears", ShortName = "Spears", IconText = "SP", Parent = "combat_vanguard", Slot = "Weapon", Line = "spear", Kind = "Weapon", Aliases = { "spear", "spears", "pike", "halberd" }, Variants = wordVariants("Spear") },
	{ Key = "weapon_shield", DisplayName = "Shields", ShortName = "Shields", IconText = "SH", Parent = "combat_vanguard", Slot = "Weapon", Line = "shield", Kind = "Weapon", Aliases = { "shield", "shields", "tower shield" }, Variants = wordVariants("Shield") },
	{ Key = "weapon_halberd", DisplayName = "Halberds", ShortName = "Halberds", IconText = "HB", Parent = "combat_vanguard", Slot = "Weapon", Line = "halberd", Kind = "Weapon", Aliases = { "halberd", "halberds", "poleaxe" }, Variants = wordVariants("Halberd") },
	{ Key = "weapon_flail", DisplayName = "Flails", ShortName = "Flails", IconText = "FL", Parent = "combat_vanguard", Slot = "Weapon", Line = "flail", Kind = "Weapon", Aliases = { "flail", "flails" }, Variants = wordVariants("Flail") },
	{ Key = "weapon_war_pick", DisplayName = "War Picks", ShortName = "War Picks", IconText = "WP", Parent = "combat_vanguard", Slot = "Weapon", Line = "war_pick", Kind = "Weapon", Aliases = { "war pick", "war_pick", "pick" }, Variants = wordVariants("War Pick") },
	{ Key = "weapon_glaive", DisplayName = "Glaives", ShortName = "Glaives", IconText = "GL", Parent = "combat_vanguard", Slot = "Weapon", Line = "glaive", Kind = "Weapon", Aliases = { "glaive", "glaives" }, Variants = wordVariants("Glaive") },
	{ Key = "weapon_greatclub", DisplayName = "Greatclubs", ShortName = "Greatclubs", IconText = "GC", Parent = "combat_vanguard", Slot = "Weapon", Line = "greatclub", Kind = "Weapon", Aliases = { "greatclub", "great club", "club" }, Variants = wordVariants("Greatclub") },

	{ Key = "weapon_dagger", DisplayName = "Daggers", ShortName = "Daggers", IconText = "DG", Parent = "combat_pathfinder", Slot = "Weapon", Line = "dagger", Kind = "Weapon", Aliases = { "dagger", "daggers", "knife" }, Variants = wordVariants("Dagger") },
	{ Key = "weapon_crossbow", DisplayName = "Crossbows", ShortName = "Crossbows", IconText = "XB", Parent = "combat_pathfinder", Slot = "Weapon", Line = "crossbow", Kind = "Weapon", Aliases = { "crossbow", "crossbows" }, Variants = wordVariants("Crossbow") },
	{ Key = "weapon_quarterstaff", DisplayName = "Quarterstaffs", ShortName = "Staffs", IconText = "QS", Parent = "combat_pathfinder", Slot = "Weapon", Line = "quarterstaff", Kind = "Weapon", Aliases = { "quarterstaff", "quarter staff", "staff" }, Variants = wordVariants("Quarterstaff") },
	{ Key = "weapon_throwing_blade", DisplayName = "Throwing Blades", ShortName = "Throw Blades", IconText = "TB", Parent = "combat_pathfinder", Slot = "Weapon", Line = "throwing_blade", Kind = "Weapon", Aliases = { "throwing blade", "throwing_blade", "throwing knife" }, Variants = wordVariants("Throwing Blade") },
	{ Key = "weapon_war_fan", DisplayName = "War Fans", ShortName = "War Fans", IconText = "WF", Parent = "combat_pathfinder", Slot = "Weapon", Line = "war_fan", Kind = "Weapon", Aliases = { "war fan", "war_fan", "fan" }, Variants = wordVariants("War Fan") },
	{ Key = "weapon_harpoon", DisplayName = "Harpoons", ShortName = "Harpoons", IconText = "HP", Parent = "combat_pathfinder", Slot = "Weapon", Line = "harpoon", Kind = "Weapon", Aliases = { "harpoon", "harpoons" }, Variants = wordVariants("Harpoon") },
	{ Key = "weapon_light_spear", DisplayName = "Light Spears", ShortName = "Light Spears", IconText = "LS", Parent = "combat_pathfinder", Slot = "Weapon", Line = "light_spear", Kind = "Weapon", Aliases = { "light spear", "light_spear", "javelin" }, Variants = wordVariants("Light Spear") },
	{ Key = "weapon_sling", DisplayName = "Slings", ShortName = "Slings", IconText = "SL", Parent = "combat_pathfinder", Slot = "Weapon", Line = "sling", Kind = "Weapon", Aliases = { "sling", "slings" }, Variants = wordVariants("Sling") },
	{ Key = "weapon_repeater", DisplayName = "Repeaters", ShortName = "Repeaters", IconText = "RP", Parent = "combat_pathfinder", Slot = "Weapon", Line = "repeater", Kind = "Weapon", Aliases = { "repeater", "repeaters" }, Variants = wordVariants("Repeater") },
	{ Key = "weapon_twin_dagger", DisplayName = "Twin Daggers", ShortName = "Twin Dg", IconText = "TD", Parent = "combat_pathfinder", Slot = "Weapon", Line = "twin_dagger", Kind = "Weapon", Aliases = { "twin dagger", "twin daggers", "dual daggers" }, Variants = wordVariants("Twin Dagger") },

	{ Key = "weapon_frost_staff", DisplayName = "Frost Staffs", ShortName = "Frost", IconText = "FR", Parent = "combat_arcanist", Slot = "Weapon", Line = "frost_staff", Kind = "Weapon", Aliases = { "frost staff", "frost_staff", "ice staff" }, Variants = wordVariants("Frost Staff") },
	{ Key = "weapon_arcane_staff", DisplayName = "Arcane Staffs", ShortName = "Arcane", IconText = "AS", Parent = "combat_arcanist", Slot = "Weapon", Line = "arcane_staff", Kind = "Weapon", Aliases = { "arcane staff", "arcane_staff" }, Variants = wordVariants("Arcane Staff") },
	{ Key = "weapon_holy_staff", DisplayName = "Holy Staffs", ShortName = "Holy", IconText = "HS", Parent = "combat_arcanist", Slot = "Weapon", Line = "holy_staff", Kind = "Weapon", Aliases = { "holy staff", "holy_staff" }, Variants = wordVariants("Holy Staff") },
	{ Key = "weapon_nature_staff", DisplayName = "Nature Staffs", ShortName = "Nature", IconText = "NS", Parent = "combat_arcanist", Slot = "Weapon", Line = "nature_staff", Kind = "Weapon", Aliases = { "nature staff", "nature_staff" }, Variants = wordVariants("Nature Staff") },
	{ Key = "weapon_lightning_staff", DisplayName = "Lightning Staffs", ShortName = "Storm", IconText = "LT", Parent = "combat_arcanist", Slot = "Weapon", Line = "lightning_staff", Kind = "Weapon", Aliases = { "lightning staff", "lightning_staff", "storm staff" }, Variants = wordVariants("Lightning Staff") },
	{ Key = "weapon_shadow_staff", DisplayName = "Shadow Staffs", ShortName = "Shadow", IconText = "SS", Parent = "combat_arcanist", Slot = "Weapon", Line = "shadow_staff", Kind = "Weapon", Aliases = { "shadow staff", "shadow_staff" }, Variants = wordVariants("Shadow Staff") },
	{ Key = "weapon_crystal_staff", DisplayName = "Crystal Staffs", ShortName = "Crystal", IconText = "CS", Parent = "combat_arcanist", Slot = "Weapon", Line = "crystal_staff", Kind = "Weapon", Aliases = { "crystal staff", "crystal_staff" }, Variants = wordVariants("Crystal Staff") },
	{ Key = "weapon_curse_staff", DisplayName = "Curse Staffs", ShortName = "Curse", IconText = "CU", Parent = "combat_arcanist", Slot = "Weapon", Line = "curse_staff", Kind = "Weapon", Aliases = { "curse staff", "curse_staff", "cursed staff" }, Variants = wordVariants("Curse Staff") },
	{ Key = "weapon_earth_staff", DisplayName = "Earth Staffs", ShortName = "Earth", IconText = "ES", Parent = "combat_arcanist", Slot = "Weapon", Line = "earth_staff", Kind = "Weapon", Aliases = { "earth staff", "earth_staff" }, Variants = wordVariants("Earth Staff") },
	{ Key = "weapon_wind_staff", DisplayName = "Wind Staffs", ShortName = "Wind", IconText = "WS", Parent = "combat_arcanist", Slot = "Weapon", Line = "wind_staff", Kind = "Weapon", Aliases = { "wind staff", "wind_staff" }, Variants = wordVariants("Wind Staff") },
}

local combatBranchY = { combat_vanguard = -9000, combat_pathfinder = 0, combat_arcanist = 9000 }
local craftBranchX = { combat_vanguard = -4200, combat_pathfinder = 0, combat_arcanist = 4200 }
local itemsByBranch = {}
for _, item in ipairs(combatItems) do
	itemsByBranch[item.Parent] = itemsByBranch[item.Parent] or {}
	table.insert(itemsByBranch[item.Parent], item)
end
for branchKey, items in pairs(itemsByBranch) do
	local baseY = combatBranchY[branchKey] or 0
	local craftX = craftBranchX[branchKey] or 0
	for index, item in ipairs(items) do
		local col = math.floor((index - 1) / 7)
		local row = (index - 1) % 7
		item.X = -17600 - (col * 4200)
		item.Y = baseY - 3300 + (row * 1080)
		item.CraftLayout = { X = craftX + ((col == 0) and -850 or 850), Y = -3600 - (row * 1600) }
	end
end

local function addCombatItem(item)
	local masteryKey = item.Key
	addSkill(masteryKey, {
		DisplayName = item.DisplayName,
		Category = "Combat Mastery",
		ShortName = item.ShortName,
		IconText = item.IconText,
		Parent = item.Parent,
		NodeType = "CombatMastery",
		Activity = "Combat",
		Slot = item.Slot,
		Line = item.Line,
		MaxLevel = Config.CombatMasteryMaxLevel,
		Description = "Mastery for using " .. item.DisplayName .. ". After the parent branch reaches level 20, level 1 opens Tier 7 use and higher levels continue toward Tier 20.",
		Layout = { X = item.X, Y = item.Y },
	})
	local lineInfo = { BranchKey = item.Parent, MasteryKey = masteryKey, Slot = item.Slot, Kind = item.Kind, Line = item.Line, VariantAliases = {}, VariantKeys = {} }
	for index, variant in ipairs(item.Variants or {}) do
		local specKey = masteryKey .. "_" .. keyPart(variant.Name) .. "_veterancy"
		if index > 1 then
			debugOnlyNodes[specKey] = true
		end
		if index == 1 then
			lineInfo.DefaultVeterancyKey = specKey
			lineInfo.VeterancyKey = specKey
		end
		lineInfo.VariantKeys[variant.Name] = specKey
		addVariantAlias(lineInfo, variant.Aliases or { variant.Name }, specKey)
		addVariantAlias(lineInfo, { variant.Name, specKey }, specKey)
		addSkill(specKey, {
			DisplayName = variant.Name .. " Veterancy",
			Category = "Combat Veterancy",
			ShortName = variant.ShortName or variant.Name,
			IconText = "V",
			Parent = masteryKey,
			NodeType = "CombatVeterancy",
			Activity = "Combat",
			IsVeterancy = true,
			Slot = item.Slot,
			Line = item.Line,
			MaxLevel = Config.VeterancyMaxLevel,
			Description = "Specific long-term practice for " .. variant.Name .. ". It starts gaining once the parent mastery reaches level 1.",
			Layout = { X = item.X - 620 - (math.floor((index - 1) / 5) * 360), Y = item.Y - 330 + (((index - 1) % 5) * 165) },
		})
	end
	Config.CombatLines[keyPart(item.Key)] = lineInfo
	Config.CombatLines[keyPart(item.Line)] = lineInfo
	addAlias(Config.CombatLines, item.Aliases, lineInfo)
end
for _, item in ipairs(combatItems) do
	addCombatItem(item)
end

addSkill("gather_t1_3", {
	DisplayName = "Novice Gatherer",
	Category = "Gathering",
	ShortName = "Gatherer",
	IconText = "G",
	Parent = Config.ActivityRootKey,
	NodeType = "GatheringRoot",
	Activity = "Gathering",
	MaxLevel = Config.RootMaxLevel,
	Description = "The shared Tier 2-3 gathering foundation. Tier 1 gathering is always intended to be usable before resource lines split.",
	Layout = { X = 0, Y = 700 },
})

local gatherTypes = {
	{ Id = "ore", Display = "Ore Mining", Icon = "OR", X = -1200, Aliases = { "ore", "iron", "copper", "silver", "metal" } },
	{ Id = "stone", Display = "Stone Cutting", Icon = "ST", X = -600, Aliases = { "stone", "rock", "granite", "limestone" } },
	{ Id = "wood", Display = "Woodcutting", Icon = "WD", X = 0, Aliases = { "wood", "tree", "log", "logs" } },
	{ Id = "fiber", Display = "Fiber Harvesting", Icon = "FB", X = 600, Aliases = { "fiber", "plant", "cloth", "flax" } },
	{ Id = "hide", Display = "Hide Skinning", Icon = "HD", X = 1200, Aliases = { "hide", "leather", "skin", "animal" } },
}

for _, gather in ipairs(gatherTypes) do
	local previous = Config.GatheringRootKey
	Config.GatheringLines[gather.Id] = gather
	addAlias(Config.GatheringLines, gather.Aliases, gather)
	for tier = 4, Config.MaxTier do
		local key = string.format("gather_%s_t%d", gather.Id, tier)
		addSkill(key, {
			DisplayName = string.format("T%d %s", tier, gather.Display),
			Category = "Gathering Tier",
			ShortName = string.format("%s T%d", gather.Display, tier),
			IconText = gather.Icon,
			Parent = previous,
			NodeType = "GatheringTier",
			Activity = "Gathering",
			GatherType = gather.Id,
			TierSource = tier,
			MaxLevel = Config.GatheringMaxLevel,
			Description = string.format("Tier %d specialization for %s. This tier starts once the previous tier reaches level 1.", tier, gather.Display),
			Layout = { X = gather.X, Y = 1120 + ((tier - 4) * 280) },
		})
		previous = key
	end
end

addSkill("craft_t1_3", {
	DisplayName = "Novice Artisan",
	Category = "Crafting",
	ShortName = "Artisan",
	IconText = "C",
	Parent = Config.ActivityRootKey,
	NodeType = "CraftingRoot",
	Activity = "Crafting",
	MaxLevel = Config.RootMaxLevel,
	Description = "The shared Tier 2-3 crafting foundation. Tier 1 crafting is always intended to be usable before item families split.",
	Layout = { X = 0, Y = -700 },
})

local craftBranches = {
	{ Key = "craft_vanguard", DisplayName = "Forgecraft", IconText = "FG", X = -4200, Y = -1700, Description = "Crafting route for heavy equipment and frontline weapons." },
	{ Key = "craft_pathfinder", DisplayName = "Trailcraft", IconText = "TR", X = 0, Y = -1700, Description = "Crafting route for leather gear, bows, and agile equipment." },
	{ Key = "craft_arcanist", DisplayName = "Spellcraft", IconText = "SP", X = 4200, Y = -1700, Description = "Crafting route for cloth gear, staves, and magical equipment." },
	{ Key = "craft_toolmaker", DisplayName = "Toolworks", IconText = "TW", X = 8200, Y = -1700, Description = "Crafting route for tools, bags, gathering gear, and furniture." },
	{ Key = "craft_stablewright", DisplayName = "Stablewright", IconText = "ST", X = 12200, Y = -1700, Description = "Crafting route for mounts and mount support items." },
	{ Key = "craft_refining", DisplayName = "Refining", IconText = "RF", X = 16200, Y = -1700, Description = "Refining route for turning raw resources into bars, blocks, planks, cloth, and leather. This foundation controls Tier 4-6 before Tier 7-20 resource trails begin." },
}
for _, branch in ipairs(craftBranches) do
	addSkill(branch.Key, {
		DisplayName = branch.DisplayName,
		Category = "Crafting",
		ShortName = branch.DisplayName,
		IconText = branch.IconText,
		Parent = Config.CraftingRootKey,
		NodeType = "CraftingBranch",
		Activity = "Crafting",
		MaxLevel = Config.CraftingBranchMaxLevel,
		Description = branch.Description,
		Layout = { X = branch.X, Y = branch.Y },
	})
end

local craftParentByCombatParent = { combat_vanguard = "craft_vanguard", combat_pathfinder = "craft_pathfinder", combat_arcanist = "craft_arcanist" }
local function addCraftingItem(sourceItem)
	local sourceDef = Config.Skills[sourceItem.Key]
	local craftKey = "craft_" .. sourceItem.Key:gsub("^weapon_", "")
	local pos = sourceItem.CraftLayout or { X = 0, Y = -3300 }
	local parent = craftParentByCombatParent[sourceItem.Parent] or Config.CraftingRootKey
	addSkill(craftKey, {
		DisplayName = (sourceDef and sourceDef.DisplayName or sourceItem.DisplayName) .. " Crafting",
		Category = "Crafting Mastery",
		ShortName = sourceDef and sourceDef.ShortName or sourceItem.ShortName,
		IconText = sourceDef and sourceDef.IconText or "C",
		Parent = parent,
		NodeType = "CraftingMastery",
		Activity = "Crafting",
		Line = sourceItem.Line,
		MaxLevel = Config.CraftingMasteryMaxLevel,
		Description = "Crafting mastery for this item family. After the parent branch reaches level 20, level 1 opens Tier 7 crafting and Tier 7+ crafts can feed specific veterancy.",
		Layout = pos,
	})
	local lineInfo = { BranchKey = parent, MasteryKey = craftKey, Slot = sourceItem.Slot, Kind = sourceItem.Kind, Line = sourceItem.Line, VariantAliases = {}, VariantKeys = {} }
	for index, variant in ipairs(sourceItem.Variants or {}) do
		local specKey = craftKey .. "_" .. keyPart(variant.Name) .. "_veterancy"
		if index > 1 then
			debugOnlyNodes[specKey] = true
		end
		if index == 1 then
			lineInfo.DefaultVeterancyKey = specKey
			lineInfo.VeterancyKey = specKey
		end
		lineInfo.VariantKeys[variant.Name] = specKey
		addVariantAlias(lineInfo, variant.Aliases or { variant.Name }, specKey)
		addVariantAlias(lineInfo, { variant.Name, specKey }, specKey)
		addSkill(specKey, {
			DisplayName = variant.Name .. " Crafting Veterancy",
			Category = "Crafting Veterancy",
			ShortName = variant.ShortName or variant.Name,
			IconText = "V",
			Parent = craftKey,
			NodeType = "CraftingVeterancy",
			Activity = "Crafting",
			IsVeterancy = true,
			MaxLevel = Config.CraftingVeterancyMaxLevel,
			Description = "Specific long-term crafting practice for " .. variant.Name .. ".",
			Layout = { X = pos.X - 320 + (((index - 1) % 5) * 160), Y = pos.Y - 540 - (math.floor((index - 1) / 5) * 180) },
		})
	end
	Config.CraftingLines[keyPart(craftKey)] = lineInfo
	Config.CraftingLines[keyPart(sourceItem.Key)] = lineInfo
	Config.CraftingLines[keyPart(sourceItem.Line)] = lineInfo
	addAlias(Config.CraftingLines, sourceItem.Aliases, lineInfo)
end
for _, item in ipairs(combatItems) do
	addCraftingItem(item)
end

local utilityCraftingItems = {
	{ Key = "craft_bagmaking", DisplayName = "Bag Making", ShortName = "Bags", IconText = "BG", Parent = "craft_toolmaker", Line = "bagmaking", X = 6500, Y = -5200, Aliases = { "bag", "bags", "satchel", "novicebag", "pristinegathererspack" }, Variant = "Novice Satchels" },
	{ Key = "craft_toolmaking", DisplayName = "Toolmaking", ShortName = "Tools", IconText = "TL", Parent = "craft_toolmaker", Line = "toolmaking", X = 8200, Y = -5200, Aliases = { "tool", "tools", "pickaxe", "wood axe", "novicepickaxe", "novicewoodaxe" }, Variant = "Novice Tools" },
	{ Key = "craft_gathering_gear", DisplayName = "Gathering Gear Crafting", ShortName = "Gather Gear", IconText = "GG", Parent = "craft_toolmaker", Line = "gathering_gear", X = 9900, Y = -5200, Aliases = { "gathering gear", "gathering armor", "novicegatheringgarb" }, Variant = "Novice Gathering Gear" },
	{ Key = "craft_furniture", DisplayName = "Furniture Crafting", ShortName = "Furniture", IconText = "FN", Parent = "craft_toolmaker", Line = "furniture", X = 11600, Y = -5200, Aliases = { "furniture", "chair", "pineworkshopchair" }, Variant = "Workshop Furniture" },
	{ Key = "craft_mounts", DisplayName = "Mount Crafting", ShortName = "Mounts", IconText = "MT", Parent = "craft_stablewright", Line = "mount", X = 12200, Y = -5200, Aliases = { "mount", "mounts", "horse", "riding horse", "brownridinghorse" }, Variant = "Riding Mounts" },
}

local function addUtilityCraftingItem(item)
	addSkill(item.Key, {
		DisplayName = item.DisplayName,
		Category = "Crafting Mastery",
		ShortName = item.ShortName,
		IconText = item.IconText,
		Parent = item.Parent,
		NodeType = "CraftingMastery",
		Activity = "Crafting",
		Line = item.Line,
		MaxLevel = Config.CraftingMasteryMaxLevel,
		Description = "Crafting mastery for " .. item.DisplayName .. ". After the parent branch reaches level 20, level 1 opens Tier 7 crafting and Tier 7+ crafts can feed specific veterancy.",
		Layout = { X = item.X, Y = item.Y },
	})
	local specKey = item.Key .. "_veterancy"
	local lineInfo = { BranchKey = item.Parent, MasteryKey = item.Key, Line = item.Line, Kind = "Utility", VariantAliases = {}, VariantKeys = {}, DefaultVeterancyKey = specKey, VeterancyKey = specKey }
	addVariantAlias(lineInfo, { item.Variant, item.Key, item.Line }, specKey)
	addAlias(Config.CraftingLines, item.Aliases, lineInfo)
	Config.CraftingLines[keyPart(item.Key)] = lineInfo
	Config.CraftingLines[keyPart(item.Line)] = lineInfo
	addSkill(specKey, {
		DisplayName = item.Variant .. " Crafting Veterancy",
		Category = "Crafting Veterancy",
		ShortName = item.ShortName,
		IconText = "V",
		Parent = item.Key,
		NodeType = "CraftingVeterancy",
		Activity = "Crafting",
		IsVeterancy = true,
		MaxLevel = Config.CraftingVeterancyMaxLevel,
		Description = "Specific long-term crafting practice for " .. item.Variant .. ".",
		Layout = { X = item.X, Y = item.Y - 540 },
	})
end

for _, item in ipairs(utilityCraftingItems) do
	addUtilityCraftingItem(item)
end

local toolCraftTypes = {
	{ Id = "ore", Display = "Ore Tools", Tool = "Pickaxe", Icon = "PX", X = 7200, Aliases = { "pickaxe", "novicepickaxe", "ore tool", "mining tool" } },
	{ Id = "stone", Display = "Stone Tools", Tool = "Quarry Hammer", Icon = "QH", X = 7700, Aliases = { "quarry hammer", "stone tool", "rock tool" } },
	{ Id = "wood", Display = "Wood Tools", Tool = "Wood Axe", Icon = "AX", X = 8200, Aliases = { "wood axe", "novicewoodaxe", "woodcutting tool" } },
	{ Id = "fiber", Display = "Fiber Tools", Tool = "Sickle", Icon = "SK", X = 8700, Aliases = { "sickle", "fiber tool", "harvesting tool" } },
	{ Id = "hide", Display = "Hide Tools", Tool = "Skinning Knife", Icon = "KN", X = 9200, Aliases = { "skinning knife", "hide tool", "skinning tool" } },
}

local function registerCraftingLine(lineInfo, aliases)
	Config.CraftingLines[keyPart(lineInfo.MasteryKey)] = lineInfo
	Config.CraftingLines[keyPart(lineInfo.Line)] = lineInfo
	addAlias(Config.CraftingLines, aliases, lineInfo)
end

for index, tool in ipairs(toolCraftTypes) do
	local masteryKey = "craft_tool_" .. tool.Id
	addSkill(masteryKey, {
		DisplayName = tool.Display .. " Crafting",
		Category = "Crafting Mastery",
		ShortName = tool.Display,
		IconText = tool.Icon,
		Parent = "craft_toolmaking",
		NodeType = "CraftingMastery",
		Activity = "Crafting",
		Line = "tool_" .. tool.Id,
		MaxLevel = Config.CraftingMasteryMaxLevel,
		Description = "Crafting mastery for the tool line used with " .. tool.Display .. ". After Toolworks reaches level 20, level 1 opens Tier 7 tools and Tier 7+ crafts can feed normal and Ash tool veterancy.",
		Layout = { X = tool.X, Y = -6600 },
	})
	local lineInfo = { BranchKey = "craft_toolmaking", MasteryKey = masteryKey, Line = "tool_" .. tool.Id, Kind = "Tool", VariantAliases = {}, VariantKeys = {} }
	local variants = {
		{ Name = tool.Tool, ShortName = tool.Tool, Aliases = tool.Aliases },
		{ Name = "Ash " .. tool.Tool, ShortName = "Ash", Aliases = { "ash " .. tool.Tool, "ash" .. tool.Tool:gsub("%s+", ""), "ash_" .. tool.Tool:gsub("%s+", "_") } },
	}
	for variantIndex, variant in ipairs(variants) do
		local specKey = masteryKey .. "_" .. keyPart(variant.Name) .. "_veterancy"
		if variantIndex == 1 then
			lineInfo.DefaultVeterancyKey = specKey
			lineInfo.VeterancyKey = specKey
		end
		lineInfo.VariantKeys[variant.Name] = specKey
		addVariantAlias(lineInfo, variant.Aliases or { variant.Name }, specKey)
		addVariantAlias(lineInfo, { variant.Name, specKey }, specKey)
		addSkill(specKey, {
			DisplayName = variant.Name .. " Crafting Veterancy",
			Category = "Crafting Veterancy",
			ShortName = variant.ShortName,
			IconText = "V",
			Parent = masteryKey,
			NodeType = "CraftingVeterancy",
			Activity = "Crafting",
			IsVeterancy = true,
			MaxLevel = Config.CraftingVeterancyMaxLevel,
			Description = "Specific long-term crafting practice for " .. variant.Name .. ".",
			Layout = { X = tool.X - 120 + ((variantIndex - 1) * 240), Y = -7140 },
		})
	end
	registerCraftingLine(lineInfo, tool.Aliases)
end

local gatheringGearSlots = {
	{ Id = "helmet", Display = "Helmet", Icon = "H" },
	{ Id = "armor", Display = "Armor", Icon = "A" },
	{ Id = "boots", Display = "Boots", Icon = "B" },
	{ Id = "cape", Display = "Cape", Icon = "C" },
	{ Id = "backpack", Display = "Backpack", Icon = "P" },
}

for index, resource in ipairs(toolCraftTypes) do
	local masteryKey = "craft_gathering_" .. resource.Id
	addSkill(masteryKey, {
		DisplayName = resource.Display:gsub(" Tools", " Gathering Gear") .. " Crafting",
		Category = "Crafting Mastery",
		ShortName = resource.Display:gsub(" Tools", " Gear"),
		IconText = "GG",
		Parent = "craft_gathering_gear",
		NodeType = "CraftingMastery",
		Activity = "Crafting",
		Line = "gathering_gear_" .. resource.Id,
		MaxLevel = Config.CraftingMasteryMaxLevel,
		Description = "Crafting mastery for gathering gear tuned to the " .. resource.Id .. " resource path. After Gathering Gear Crafting reaches level 20, level 1 opens Tier 7 gear and Tier 7+ crafts feed slot veterancy.",
		Layout = { X = 9100 + ((index - 1) * 420), Y = -6600 },
	})
	local lineInfo = { BranchKey = "craft_gathering_gear", MasteryKey = masteryKey, Line = "gathering_gear_" .. resource.Id, Kind = "GatheringArmor", VariantAliases = {}, VariantKeys = {} }
	for slotIndex, slot in ipairs(gatheringGearSlots) do
		local variantName = resource.Display:gsub(" Tools", "") .. " " .. slot.Display
		local specKey = masteryKey .. "_" .. slot.Id .. "_veterancy"
		if slotIndex == 1 then
			lineInfo.DefaultVeterancyKey = specKey
			lineInfo.VeterancyKey = specKey
		end
		lineInfo.VariantKeys[variantName] = specKey
		addVariantAlias(lineInfo, { variantName, resource.Id .. " " .. slot.Display, slot.Display, specKey }, specKey)
		addSkill(specKey, {
			DisplayName = variantName .. " Crafting Veterancy",
			Category = "Crafting Veterancy",
			ShortName = slot.Display,
			IconText = slot.Icon,
			Parent = masteryKey,
			NodeType = "CraftingVeterancy",
			Activity = "Crafting",
			IsVeterancy = true,
			MaxLevel = Config.CraftingVeterancyMaxLevel,
			Description = "Specific long-term crafting practice for " .. variantName .. ".",
			Layout = { X = 9100 + ((index - 1) * 420) - 300 + ((slotIndex - 1) * 150), Y = -7140 },
		})
	end
	registerCraftingLine(lineInfo, { "gathering " .. resource.Id, resource.Id .. " gathering gear" })
end

local refiningTypes = {
	{ Id = "ore", Display = "Ore Refining", Icon = "OR", X = 14800, Aliases = { "ore", "metal", "bar", "metal bar" } },
	{ Id = "stone", Display = "Stone Refining", Icon = "ST", X = 15500, Aliases = { "stone", "rock", "block", "stone block" } },
	{ Id = "wood", Display = "Wood Refining", Icon = "WD", X = 16200, Aliases = { "wood", "plank", "log" } },
	{ Id = "fiber", Display = "Fiber Refining", Icon = "FB", X = 16900, Aliases = { "fiber", "cloth", "plant" } },
	{ Id = "hide", Display = "Hide Refining", Icon = "HD", X = 17600, Aliases = { "hide", "leather", "skin" } },
}

for _, refine in ipairs(refiningTypes) do
	local previous = "craft_refining"
	Config.RefiningLines[refine.Id] = refine
	addAlias(Config.RefiningLines, refine.Aliases, refine)
	for tier = 7, Config.MaxTier do
		local key = string.format("refine_%s_t%d", refine.Id, tier)
		addSkill(key, {
			DisplayName = string.format("T%d %s", tier, refine.Display),
			Category = "Refining Tier",
			ShortName = string.format("%s T%d", refine.Display, tier),
			IconText = refine.Icon,
			Parent = previous,
			NodeType = "RefiningTier",
			Activity = "Crafting",
			RefiningType = refine.Id,
			TierSource = tier,
			MaxLevel = Config.CraftingMasteryMaxLevel,
			Description = string.format("Tier %d mastery for %s. The first node starts after Refining reaches level 20; each later node starts once the previous tier reaches level 1.", tier, refine.Display),
			Layout = { X = refine.X, Y = -2300 - ((tier - 7) * 280) },
		})
		previous = key
	end
end

local progressionCache = {}
local function levelCost(level, maxLevel, category)
	if level <= 0 then return 0 end
	if maxLevel <= 3 then return 120 * level end
	local rank = level
	if category == "Gathering Tier" or category == "Refining Tier" then
		return math.floor(95 * (rank ^ 1.42) + rank * 24 + 0.5)
	elseif tostring(category):find("Veterancy") then
		return math.floor(120 * (rank ^ 1.45) + rank * 34 + 0.5)
	elseif maxLevel >= 1000 then
		return math.floor(80 * (rank ^ 1.28) + rank * 22 + 0.5)
	end
	return math.floor(80 * (rank ^ 1.4) + rank * 22 + 0.5)
end

function Config.ValorRequiredForLevel(level, maxLevel, category)
	maxLevel = math.max(0, math.floor(tonumber(maxLevel) or 0))
	level = math.clamp(math.floor(tonumber(level) or 0), 0, maxLevel)
	local cacheKey = tostring(category or "default") .. ":" .. tostring(maxLevel)
	local bucket = progressionCache[cacheKey]
	if not bucket then
		bucket = { [0] = 0, Highest = 0 }
		progressionCache[cacheKey] = bucket
	end
	if bucket[level] then return bucket[level] end
	for step = bucket.Highest + 1, level do
		bucket[step] = bucket[step - 1] + levelCost(step, maxLevel, category)
	end
	bucket.Highest = math.max(bucket.Highest, level)
	return bucket[level]
end

function Config.MaxValorForSkill(skillKey)
	local def = Config.Skills[skillKey]
	local maxLevel = def and def.MaxLevel or Config.CombatMasteryMaxLevel
	return Config.ValorRequiredForLevel(maxLevel, maxLevel, def and def.Category)
end
Config.MaxTotalValor = Config.ValorRequiredForLevel(Config.VeterancyMaxLevel, Config.VeterancyMaxLevel, "Combat Veterancy")

function Config.GetLevelForValor(skillKey, totalValor)
	local def = Config.Skills[skillKey]
	local maxLevel = def and def.MaxLevel or Config.CombatMasteryMaxLevel
	totalValor = math.max(0, math.floor(tonumber(totalValor) or 0))
	local level = 0
	for nextLevel = 1, maxLevel do
		if totalValor >= Config.ValorRequiredForLevel(nextLevel, maxLevel, def and def.Category) then
			level = nextLevel
		else
			break
		end
	end
	return level
end

local function levelFromTotals(skillTotals, skillKey)
	if not (skillTotals and skillKey) then return 0 end
	return Config.GetLevelForValor(skillKey, skillTotals[skillKey] or 0)
end

function Config.RootUnlockTier(level)
	level = math.floor(tonumber(level) or 0)
	if level >= Config.RootMaxLevel then return 3 end
	if level >= 1 then return 2 end
	return 1
end

function Config.BranchUnlockTier(level)
	level = math.floor(tonumber(level) or 0)
	if level >= 18 then return 6 end
	if level >= 5 then return 5 end
	if level >= 1 then return 4 end
	return 3
end

function Config.RequiredMasteryLevelForTier(tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, Config.MaxTier)
	if tier <= 6 then return 0 end
	if tier == 7 then return 1 end
	return math.clamp(math.ceil(1 + ((tier - 7) / math.max(1, Config.MaxTier - 7)) * 999), 1, Config.CraftingMasteryMaxLevel)
end

function Config.MasteryUnlockTier(level)
	level = math.floor(tonumber(level) or 0)
	local unlocked = 6
	for tier = 7, Config.MaxTier do
		if level >= Config.RequiredMasteryLevelForTier(tier) then
			unlocked = tier
		else
			break
		end
	end
	return unlocked
end

function Config.LevelToUnlockTier(level)
	return Config.MasteryUnlockTier(level)
end

function Config.GetUnlockTierForSkill(skillKey, level)
	local def = Config.Skills[skillKey]
	if not def then return Config.LevelToUnlockTier(level) end
	local nodeType = def.NodeType
	if skillKey == Config.ActivityRootKey then
		return 1
	elseif nodeType == "CombatRoot" or nodeType == "CraftingRoot" or nodeType == "GatheringRoot" then
		return Config.RootUnlockTier(level)
	elseif nodeType == "CombatBranch" or nodeType == "CraftingBranch" then
		return Config.BranchUnlockTier(level)
	elseif nodeType == "CombatMastery" or nodeType == "CraftingMastery" or nodeType == "RefiningTier" then
		return Config.MasteryUnlockTier(level)
	elseif nodeType == "GatheringTier" then
		local tierSource = math.clamp(math.floor(tonumber(def.TierSource) or 1), 1, Config.MaxTier)
		return level >= 1 and tierSource or math.max(3, tierSource - 1)
	elseif def.IsVeterancy then
		return Config.MasteryUnlockTier(level)
	end
	return Config.LevelToUnlockTier(level)
end

local function majorBranchForLine(line, activity)
	local wantedType = activity == "Combat" and "CombatBranch" or "CraftingBranch"
	local key = type(line) == "table" and line.BranchKey or nil
	local guard = 0
	while key and guard < 16 do
		local def = Config.Skills[key]
		if not def then return key end
		if def.NodeType == wantedType then return key end
		key = def.Parent
		guard += 1
	end
	return type(line) == "table" and line.BranchKey or nil
end

function Config.MajorCombatBranchForLine(line)
	return majorBranchForLine(line, "Combat")
end

function Config.MajorCraftingBranchForLine(line)
	return majorBranchForLine(line, "Crafting")
end

function Config.CanProgressLineMastery(skillTotals, line)
	if type(line) ~= "table" or not (line.MasteryKey and Config.Skills[line.MasteryKey]) then
		return false
	end
	local masteryDef = Config.Skills[line.MasteryKey]
	local activity = masteryDef and masteryDef.Activity or "Crafting"
	local majorBranch = majorBranchForLine(line, activity)
	if majorBranch and Config.Skills[majorBranch] then
		local branchDef = Config.Skills[majorBranch]
		if levelFromTotals(skillTotals, majorBranch) < (branchDef.MaxLevel or Config.CraftingBranchMaxLevel) then
			return false
		end
	end
	if line.BranchKey and line.BranchKey ~= majorBranch and Config.Skills[line.BranchKey] then
		return levelFromTotals(skillTotals, line.BranchKey) >= 1
	end
	local rootKey = activity == "Combat" and Config.CombatRootKey or Config.CraftingRootKey
	return levelFromTotals(skillTotals, rootKey) >= Config.RootMaxLevel
end

local function branchLevelRequiredForTier(tier)
	if tier <= 4 then return 1 end
	if tier <= 5 then return 5 end
	return 18
end

function Config.RequiredCombatSkillForTier(line, tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, Config.MaxTier)
	if tier <= 1 then return nil, 0 end
	if tier <= 3 then return Config.CombatRootKey, (tier == 2 and 1 or Config.RootMaxLevel) end
	if type(line) ~= "table" then return nil, 0 end
	if tier <= 6 then return Config.MajorCombatBranchForLine(line), branchLevelRequiredForTier(tier) end
	return line.MasteryKey, Config.RequiredMasteryLevelForTier(tier)
end

function Config.CanUseCombatTier(skillTotals, line, tier)
	local skillKey, requiredLevel = Config.RequiredCombatSkillForTier(line, tier)
	if not skillKey then return (tonumber(tier) or 1) <= 1, nil, requiredLevel, 0 end
	local currentLevel = levelFromTotals(skillTotals, skillKey)
	return currentLevel >= requiredLevel, skillKey, requiredLevel, currentLevel
end

function Config.RequiredCraftingSkillForTier(line, tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, Config.MaxTier)
	if tier <= 1 then return nil, 0 end
	if tier <= 3 then return Config.CraftingRootKey, (tier == 2 and 1 or Config.RootMaxLevel) end
	if type(line) ~= "table" then return nil, 0 end
	if tier <= 6 then return Config.MajorCraftingBranchForLine(line), branchLevelRequiredForTier(tier) end
	return line.MasteryKey, Config.RequiredMasteryLevelForTier(tier)
end

function Config.CanCraftItemTier(skillTotals, line, tier)
	local skillKey, requiredLevel = Config.RequiredCraftingSkillForTier(line, tier)
	if not skillKey then return (tonumber(tier) or 1) <= 1, nil, requiredLevel, 0 end
	local currentLevel = levelFromTotals(skillTotals, skillKey)
	return currentLevel >= requiredLevel, skillKey, requiredLevel, currentLevel
end

function Config.ProgressForValor(skillKey, totalValor)
	local def = Config.Skills[skillKey]
	local maxLevel = def and def.MaxLevel or Config.CombatMasteryMaxLevel
	totalValor = math.max(0, math.floor(tonumber(totalValor) or 0))
	local level = Config.GetLevelForValor(skillKey, totalValor)
	local currentLevelValor = Config.ValorRequiredForLevel(level, maxLevel, def and def.Category)
	local nextLevelValor = (level < maxLevel) and Config.ValorRequiredForLevel(level + 1, maxLevel, def and def.Category) or currentLevelValor
	local needed = math.max(0, nextLevelValor - currentLevelValor)
	local intoLevel = math.max(0, totalValor - currentLevelValor)
	local progress = (level >= maxLevel or needed <= 0) and 1 or math.clamp(intoLevel / needed, 0, 1)
	return {
		Level = level,
		MaxLevel = maxLevel,
		Tier = level,
		MaxTier = maxLevel,
		CurrentLevelValor = currentLevelValor,
		NextLevelValor = nextLevelValor,
		CurrentTierValor = currentLevelValor,
		NextTierValor = nextLevelValor,
		ValorIntoLevel = intoLevel,
		ValorIntoTier = intoLevel,
		ValorForNext = needed,
		Progress = progress,
	}
end

function Config.BuildSkillSnapshot(skillKey, totalValor)
	local def = Config.Skills[skillKey]
	local maxValor = Config.MaxValorForSkill(skillKey)
	totalValor = math.floor(tonumber(totalValor) or 0)
	if skillKey == Config.ActivityRootKey then
		totalValor = math.max(totalValor, Config.ValorRequiredForLevel(1, def and def.MaxLevel or Config.AdventurerMaxLevel, def and def.Category))
	end
	totalValor = math.clamp(totalValor, 0, maxValor)
	local progress = Config.ProgressForValor(skillKey, totalValor)
	return {
		Key = skillKey,
		DisplayName = def and def.DisplayName or tostring(skillKey),
		Category = def and def.Category or "Unknown",
		ShortName = def and def.ShortName or tostring(skillKey),
		IconText = def and def.IconText or "?",
		Description = def and def.Description or "No description yet.",
		NodeType = def and def.NodeType or "Unknown",
		Parent = def and def.Parent or nil,
		Activity = def and def.Activity or nil,
		IsVeterancy = def and def.IsVeterancy or false,
		Line = def and def.Line or nil,
		Slot = def and def.Slot or nil,
		TierSource = def and def.TierSource or nil,
		TotalValor = totalValor,
		Level = progress.Level,
		MaxLevel = progress.MaxLevel,
		Tier = progress.Tier,
		MaxTier = progress.MaxTier,
		UnlockTier = Config.GetUnlockTierForSkill(skillKey, progress.Level),
		CurrentLevelValor = progress.CurrentLevelValor,
		NextLevelValor = progress.NextLevelValor,
		CurrentTierValor = progress.CurrentTierValor,
		NextTierValor = progress.NextTierValor,
		ValorIntoLevel = progress.ValorIntoLevel,
		ValorIntoTier = progress.ValorIntoTier,
		ValorForNext = progress.ValorForNext,
		Progress = progress.Progress,
		Layout = def and def.Layout or { X = 0, Y = 0 },
	}
end

local function findLine(bucket, candidates)
	for _, candidate in pairs(candidates) do
		local line = bucket[keyPart(candidate)]
		if line then return line end
	end
	return nil
end

local function variantFor(line, candidates)
	if not line or not line.VariantAliases then return nil end
	for _, candidate in pairs(candidates) do
		local key = line.VariantAliases[keyPart(candidate)]
		if key then return key end
	end
	return line.DefaultVeterancyKey
end

function Config.SkillKeyForWeapon(weaponType)
	local line = findLine(Config.CombatLines, { weaponType })
	return (line and line.MasteryKey) or ("weapon_" .. keyPart(weaponType))
end

function Config.CombatLineForWeapon(weaponType, itemId, module)
	local candidates = {
		module and module.VeterancyKey,
		module and module.ItemId,
		module and module.Id,
		module and module.DisplayName,
		module and module.Name,
		itemId,
		module and (module.WeaponType or module.WeaponClass or module.ItemType),
		weaponType,
	}
	local line = findLine(Config.CombatLines, candidates)
	if not line then return nil end
	local out = copyLine(line)
	out.VeterancyKey = variantFor(line, candidates)
	return out
end

local function normalizeSlot(slotName)
	local slotKey = keyPart(slotName)
	if slotKey == "head" or slotKey == "helm" then return "helmet" end
	if slotKey == "chest" or slotKey == "body" then return "armor" end
	if slotKey == "feet" or slotKey == "shoes" then return "boots" end
	return slotKey
end

function Config.CombatLineForArmor(slotName, itemId, module)
	local armorClass = module and (module.ArmorClass or module.ArmorType or module.WeightClass)
	local itemKey = keyPart(itemId)
	local classKey = keyPart(armorClass)
	local slotKey = normalizeSlot(slotName)
	local family
	if classKey == "plate" or itemKey:find("plate", 1, true) then
		family = "plate"
	elseif classKey == "leather" or itemKey:find("leather", 1, true) then
		family = "leather"
	elseif classKey == "cloth" or itemKey:find("cloth", 1, true) or itemKey:find("robe", 1, true) then
		family = "cloth"
	else
		return nil
	end
	local line = Config.CombatLines[family .. "_" .. slotKey]
	if not line then return nil end
	local candidates = { module and module.VeterancyKey, module and module.ItemId, module and module.Id, module and module.DisplayName, module and module.Name, itemId }
	local out = copyLine(line)
	out.VeterancyKey = variantFor(line, candidates)
	return out
end

function Config.CraftingLineForItem(itemId, module, explicitSkillKey)
	local candidates = {
		explicitSkillKey,
		module and module.CraftingSkillKey,
		module and module.VeterancyKey,
		module and module.ItemId,
		module and module.Id,
		module and module.DisplayName,
		module and module.Name,
		itemId,
		module and (module.WeaponType or module.WeaponClass or module.ItemType),
	}
	if explicitSkillKey and Config.Skills[explicitSkillKey] then
		local explicitLine = Config.CraftingLines[keyPart(explicitSkillKey)]
		if explicitLine then
			local out = copyLine(explicitLine)
			out.VeterancyKey = variantFor(explicitLine, candidates)
			return out
		end
		local explicitDef = Config.Skills[explicitSkillKey]
		return { BranchKey = explicitDef and explicitDef.Parent or Config.CraftingRootKey, MasteryKey = explicitSkillKey }
	end
	local line = findLine(Config.CraftingLines, candidates)
	if not line then return nil end
	local out = copyLine(line)
	out.VeterancyKey = variantFor(line, candidates)
	return out
end

function Config.SkillKeyForGather(kind, itemName, explicitKey, tier)
	if explicitKey and Config.Skills[explicitKey] then return explicitKey end
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, Config.MaxTier)
	if tier <= 3 then return Config.GatheringRootKey end
	local gather = Config.GatheringLines[keyPart(itemName)] or Config.GatheringLines[keyPart(kind)]
	if not gather then return Config.GatheringRootKey end
	local key = string.format("gather_%s_t%d", gather.Id, tier)
	return Config.Skills[key] and key or Config.GatheringRootKey
end

function Config.CanProgressGatherSkill(skillTotals, skillKey)
	local def = Config.Skills[skillKey]
	if not def then return false end
	if skillKey == Config.GatheringRootKey then return true end
	if def.Activity ~= "Gathering" then return true end
	if def.Parent == Config.GatheringRootKey then
		return Config.GetLevelForValor(Config.GatheringRootKey, skillTotals[Config.GatheringRootKey] or 0) >= Config.RootMaxLevel
	end
	local parentKey = def.Parent
	return parentKey and Config.GetLevelForValor(parentKey, skillTotals[parentKey] or 0) >= 1 or false
end

function Config.SkillKeyForRefining(kind, itemName, explicitKey, tier)
	if explicitKey and Config.Skills[explicitKey] then return explicitKey end
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, Config.MaxTier)
	if tier <= 6 then return "craft_refining" end
	local refine = Config.RefiningLines[keyPart(itemName)] or Config.RefiningLines[keyPart(kind)]
	if not refine then return "craft_refining" end
	local key = string.format("refine_%s_t%d", refine.Id, tier)
	return Config.Skills[key] and key or "craft_refining"
end

function Config.CanProgressRefiningSkill(skillTotals, skillKey)
	local def = Config.Skills[skillKey]
	if not def then return false end
	if skillKey == "craft_refining" then return true end
	if def.NodeType ~= "RefiningTier" then return true end
	if def.Parent == "craft_refining" then
		local branchDef = Config.Skills["craft_refining"]
		return Config.GetLevelForValor("craft_refining", skillTotals["craft_refining"] or 0) >= (branchDef and branchDef.MaxLevel or Config.CraftingBranchMaxLevel)
	end
	local parentKey = def.Parent
	return parentKey and Config.GetLevelForValor(parentKey, skillTotals[parentKey] or 0) >= 1 or false
end

function Config.CanRefineTier(skillTotals, kind, itemName, explicitKey, tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, Config.MaxTier)
	if tier <= 1 then return true, nil, 0, 0 end
	if tier <= 3 then
		local currentLevel = levelFromTotals(skillTotals, Config.CraftingRootKey)
		local requiredLevel = (tier == 2 and 1 or Config.RootMaxLevel)
		return currentLevel >= requiredLevel, Config.CraftingRootKey, requiredLevel, currentLevel
	end
	if tier <= 6 then
		local currentLevel = levelFromTotals(skillTotals, "craft_refining")
		local requiredLevel = branchLevelRequiredForTier(tier)
		return currentLevel >= requiredLevel, "craft_refining", requiredLevel, currentLevel
	end
	local skillKey = Config.SkillKeyForRefining(kind, itemName, explicitKey, tier)
	if not skillKey or skillKey == "craft_refining" then
		return false, nil, Config.RequiredMasteryLevelForTier(tier), 0
	end
	local requiredLevel = Config.RequiredMasteryLevelForTier(tier)
	local currentLevel = levelFromTotals(skillTotals, skillKey)
	return currentLevel >= requiredLevel, skillKey, requiredLevel, currentLevel
end

local debugExpansionMasteries = {
	weapon_axe = true,
	weapon_hammer = true,
	weapon_mace = true,
	weapon_spear = true,
	weapon_shield = true,
	weapon_halberd = true,
	weapon_flail = true,
	weapon_war_pick = true,
	weapon_glaive = true,
	weapon_greatclub = true,
	weapon_dagger = true,
	weapon_crossbow = true,
	weapon_quarterstaff = true,
	weapon_throwing_blade = true,
	weapon_war_fan = true,
	weapon_harpoon = true,
	weapon_light_spear = true,
	weapon_sling = true,
	weapon_repeater = true,
	weapon_twin_dagger = true,
	weapon_frost_staff = true,
	weapon_arcane_staff = true,
	weapon_holy_staff = true,
	weapon_nature_staff = true,
	weapon_lightning_staff = true,
	weapon_shadow_staff = true,
	weapon_crystal_staff = true,
	weapon_curse_staff = true,
	weapon_earth_staff = true,
	weapon_wind_staff = true,
}

local debugExpansionCrafting = {}
for masteryKey in pairs(debugExpansionMasteries) do
	debugExpansionCrafting["craft_" .. masteryKey:gsub("^weapon_", "")] = true
end

local function isDebugExpansionNode(key)
	if debugOnlyNodes[key] then
		return true
	end
	if debugExpansionMasteries[key] or debugExpansionCrafting[key] then
		return true
	end
	local def = Config.Skills[key]
	while def and def.Parent do
		if debugExpansionMasteries[def.Parent] or debugExpansionCrafting[def.Parent] then
			return true
		end
		def = Config.Skills[def.Parent]
	end
	return false
end

Config.NormalNodeOrder = {}
Config.DebugNodeOrder = Config.NodeOrder
for _, key in ipairs(Config.NodeOrder) do
	if not isDebugExpansionNode(key) then
		table.insert(Config.NormalNodeOrder, key)
	end
end

function Config.NpcValorForTier(tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, Config.MaxTier)
	return math.floor(18 + (tier * 9) + (tier ^ 1.35) * 4)
end

function Config.GatherValorForTier(tier)
	tier = math.clamp(math.floor(tonumber(tier) or 1), 1, Config.MaxTier)
	return math.floor(5 + tier * 3)
end

return Config
