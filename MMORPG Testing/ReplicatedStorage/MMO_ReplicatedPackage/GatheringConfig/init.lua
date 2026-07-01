--[[
Name: GatheringConfig
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.GatheringConfig
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: addDefaultTierZone, GatheringConfig.DurationFromSpecialization
Clean source lines: 154
]]
local GatheringConfig = {}

GatheringConfig.InteractDistance = 8
GatheringConfig.SpecializationKey = Enum.KeyCode.RightBracket
GatheringConfig.DefaultGatherSeconds = 6
GatheringConfig.DefaultMaxTicks = 20
GatheringConfig.DefaultTickCost = 2
GatheringConfig.DefaultTickRespawnAmount = 2
GatheringConfig.DefaultTickRespawnSeconds = 12
GatheringConfig.DefaultRerollSeconds = 60
GatheringConfig.DefaultNodeRespawnSeconds = GatheringConfig.DefaultRerollSeconds
GatheringConfig.DefaultYieldPerTick = 1
GatheringConfig.DefaultPurityRespawnWeights = {
	{ Name = "None", Weight = 90 },
	{ Name = "Faint", Weight = 7 },
	{ Name = "Kindled", Weight = 2 },
	{ Name = "Ignited", Weight = 1 },
}
GatheringConfig.PurityRespawnWeightsByTier = {
	[4] = {
		{ Name = "None", Weight = 90 },
		{ Name = "Faint", Weight = 7 },
		{ Name = "Kindled", Weight = 2 },
		{ Name = "Ignited", Weight = 1 },
	},
	[5] = {
		{ Name = "None", Weight = 84 },
		{ Name = "Faint", Weight = 10 },
		{ Name = "Kindled", Weight = 4 },
		{ Name = "Ignited", Weight = 2 },
	},
}
GatheringConfig.SpecialPurityRespawnWeights = {
	{ Name = "None", Weight = 80 },
	{ Name = "Faint", Weight = 10 },
	{ Name = "Kindled", Weight = 5 },
	{ Name = "Ignited", Weight = 3 },
	{ Name = "Ashen Forged", Weight = 2 },
}

GatheringConfig.Zones = {
	Spawn1 = {
		Kind = "Ore",
		Template = "Ore1",
		Tier = 1,
		ValorSkillKey = "gather_ore_mining",
		Valor = 8,
		NodesPerSpawn = 1,
		RespawnSeconds = 12,
		GatherSeconds = 6,
		MaxTicks = 20,
		TickCost = 2,
		TickRespawnAmount = 2,
		YieldPerTick = 1,
		Yield = { Item = "Ore", Min = 2, Max = 2 },
		NodeSize = Vector3.new(3, 3, 3),
	},
	WoodSpawn1 = {
		Kind = "Wood",
		Template = "Ore1",
		Tier = 1,
		ValorSkillKey = "gather_woodcutting",
		Valor = 8,
		NodesPerSpawn = 1,
		RespawnSeconds = 12,
		GatherSeconds = 6,
		MaxTicks = 20,
		TickCost = 2,
		TickRespawnAmount = 2,
		YieldPerTick = 1,
		Yield = { Item = "Wood", Min = 2, Max = 2 },
		NodeSize = Vector3.new(3, 3, 3),
	},
	StoneSpawn1 = {
		Kind = "Stone",
		Template = "Ore1",
		Tier = 1,
		ValorSkillKey = "gather_stone_cutting",
		Valor = 8,
		NodesPerSpawn = 1,
		RespawnSeconds = 12,
		GatherSeconds = 6,
		MaxTicks = 20,
		TickCost = 2,
		TickRespawnAmount = 2,
		YieldPerTick = 1,
		Yield = { Item = "Stone", Min = 2, Max = 2 },
		NodeSize = Vector3.new(3, 3, 3),
	},
	FiberSpawn1 = {
		Kind = "Fiber",
		Template = "Ore1",
		Tier = 1,
		ValorSkillKey = "gather_fiber_harvesting",
		Valor = 8,
		NodesPerSpawn = 1,
		RespawnSeconds = 12,
		GatherSeconds = 6,
		MaxTicks = 20,
		TickCost = 2,
		TickRespawnAmount = 2,
		YieldPerTick = 1,
		Yield = { Item = "Fiber", Min = 2, Max = 2 },
		NodeSize = Vector3.new(3, 3, 3),
	},
	HideSpawn1 = {
		Kind = "Hide",
		Template = "Ore1",
		Tier = 1,
		ValorSkillKey = "gather_hide_skinning",
		Valor = 8,
		NodesPerSpawn = 1,
		RespawnSeconds = 12,
		GatherSeconds = 6,
		MaxTicks = 20,
		TickCost = 2,
		TickRespawnAmount = 2,
		YieldPerTick = 1,
		Yield = { Item = "Hide", Min = 2, Max = 2 },
		NodeSize = Vector3.new(3, 3, 3),
	},
}

local function addDefaultTierZone(name, kind, tier)
	if GatheringConfig.Zones[name] then return end
	GatheringConfig.Zones[name] = {
		Kind = kind,
		Template = "Ore1",
		Tier = tier,
		NodesPerSpawn = 1,
		RespawnSeconds = 12,
		GatherSeconds = 6,
		MaxTicks = 20,
		TickCost = 2,
		TickRespawnAmount = 2,
		YieldPerTick = 1,
		Yield = { Item = kind, Min = 2, Max = 2 },
		NodeSize = Vector3.new(3, 3, 3),
	}
end

for tier = 3, 5 do
	addDefaultTierZone("OreT" .. tier .. "Spawn1", "Ore", tier)
	addDefaultTierZone("WoodT" .. tier .. "Spawn1", "Wood", tier)
	addDefaultTierZone("StoneT" .. tier .. "Spawn1", "Stone", tier)
	addDefaultTierZone("FiberT" .. tier .. "Spawn1", "Fiber", tier)
	addDefaultTierZone("HideT" .. tier .. "Spawn1", "Hide", tier)
end

function GatheringConfig.DurationFromSpecialization(_level)
	return GatheringConfig.DefaultGatherSeconds
end

return GatheringConfig