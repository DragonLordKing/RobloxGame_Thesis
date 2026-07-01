--[[
Name: MarketEconomyConfig
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Shared.MarketEconomyConfig
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: Config.CopyProfile, Config.ProfileForChestType
Clean source lines: 128
]]
local Config = {}

Config.PromptDistance = 5
Config.MarketDistance = 6
Config.ChestOpenSeconds = 2
Config.ChestRespawnSeconds = 30
Config.ChestGridSlots = 24
Config.DeathSackProtectionSeconds = 180
Config.DeathSackDespawnSeconds = 1800
Config.MaxOrderAmount = 999
Config.MaxSellOrderAmount = 999
Config.MaxBuyOrderAmount = 9999
Config.MaxOrderPrice = 1000000000
Config.EconomyDataStoreName = "MMO_EconomyMarket_V1"
Config.MarketSaveIntervalSeconds = 300
Config.BlackMarketSeedVersion = 1
Config.BlackMarketSeedCopiesPerItem = 2

Config.CoinSackValues = { 10, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 75000, 100000, 150000, 200000, 300000, 400000, 600000, 800000, 1000000 }

Config.QualityRolls = {
	{ Name = "Dull", Weight = 10 },
	{ Name = "Normal", Weight = 60 },
	{ Name = "Fine", Weight = 18 },
	{ Name = "Refined", Weight = 7 },
	{ Name = "Superior", Weight = 3 },
	{ Name = "Exceptional", Weight = 1.4 },
	{ Name = "Legendary", Weight = 0.6 },
}

Config.PurityRolls = {
	{ Name = "None", Weight = 90 },
	{ Name = "Faint", Weight = 7 },
	{ Name = "Kindled", Weight = 2 },
	{ Name = "Ignited", Weight = 1 },
}

Config.BlackMarketPriceRoll = {
	MaxPremium = 1.5,
	MinPremium = -2,
	MinChance = 0.05,
	MaxChance = 0.95,
	ChanceAtZero = 0.465,
	ChanceSlope = -0.47,
	DemandIncrease = 0.10,
	CompensationFactor = 0.50,
}

Config.ExcludedChestTypes = {
	Resource = true,
	Mount = true,
	Tool = true,
	GatheringArmor = true,
	CoinSack = true,
	PurityCatalyst = true,
}

Config.Categories = {
	Weapons = { Types = { Weapon = true } },
	Armor = { Types = { Armor = true, Bag = true } },
	Utility = { Types = { Utility = true, Furniture = true } },
}

Config.DefaultChestProfile = {
	Tier = 1,
	Quality = "Normal",
	Type = "Testing",
	ItemRollChance = 0.35,
	MinItemRolls = 0,
	MaxItemRolls = 1,
	CoinRolls = 2,
	CatalystRolls = 1,
	Categories = { "Weapons", "Armor", "Utility" },
	SpecificItems = {},
}

Config.ChestProfiles = {
	Testing = {
		Tier = 1,
		Quality = "Normal",
		Type = "Testing",
		ItemRollChance = 0.75,
		MinItemRolls = 1,
		MaxItemRolls = 2,
		CoinRolls = 3,
		CatalystRolls = 2,
		Categories = { "Weapons", "Armor", "Utility" },
		SpecificItems = { "TestSword", "NovicePlateHelm", "NovicePlateArmor", "NoviceHuntingBow", "NoviceLeatherJacket", "NoviceFireStaff", "NoviceClothRobe", "SimpleTokenPouch" },
	},
}

Config.ChestQualityMultiplier = {
	Dull = 0.75,
	Normal = 1,
	Fine = 1.12,
	Refined = 1.25,
	Superior = 1.4,
	Exceptional = 1.65,
	Legendary = 2,
	Artifact = 2.6,
}

Config.PurityCatalystPrefixes = {
	"EmberRune",
	"KindledSoul",
	"CinderRelic",
	"AshenRelic",
}

function Config.CopyProfile(profile)
	local out = {}
	for key, value in pairs(profile or Config.DefaultChestProfile) do
		if type(value) == "table" then
			local copy = {}
			for k, v in pairs(value) do copy[k] = v end
			out[key] = copy
		else
			out[key] = value
		end
	end
	return out
end

function Config.ProfileForChestType(chestType)
	return Config.CopyProfile(Config.ChestProfiles[tostring(chestType or "")] or Config.DefaultChestProfile)
end

return Config