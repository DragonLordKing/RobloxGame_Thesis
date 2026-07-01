--[[
Name: WorldPlaceConfig
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.WorldRuntime.WorldPlaceConfig
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: envPlaceId, Config.NormalizeZoneType, Config.GetZoneRank, Config.GetPlaceId, Config.GetMap, Config.GetCurrentMapKey, Config.GetCurrentMap, Config.GetMaterialColor, Config.GetMapsForClient, Config.GetTargetForExit
Clean source lines: 189
]]
local Config = {}

Config.Environment = "Dev"
Config.TemplatePlaceName = "MMO_WorldZone_Template"
Config.DefaultLogicalRegion = "EU"
Config.RequireReservedServers = true
Config.ReservedServerStoreName = "MMO_WorldReservedServers_V1"
Config.CurrentMapFallback = "testing_grounds"

Config.ZoneDangerRank = {
	Safe = 0,
	Warn = 1,
	Warning = 1,
	Danger = 2,
	Death = 3,
}

Config.ZoneTypeAliases = {
	Warning = "Warn",
}

Config.RegionTimers = {
	EU = {
		{ Id = "eu_yield_1", Type = "Economy", StartUtc = "17:00", DurationMinutes = 120, LootMultiplier = 1.25, GatheringYieldMultiplier = 1.15, PurityMultiplier = 1.10 },
		{ Id = "eu_yield_2", Type = "Economy", StartUtc = "22:00", DurationMinutes = 120, LootMultiplier = 1.25, GatheringYieldMultiplier = 1.15, PurityMultiplier = 1.10 },
		{ Id = "eu_war", Type = "War", StartUtc = "20:00", DurationMinutes = 60 },
	},
	US = {
		{ Id = "us_yield_1", Type = "Economy", StartUtc = "01:00", DurationMinutes = 120, LootMultiplier = 1.25, GatheringYieldMultiplier = 1.15, PurityMultiplier = 1.10 },
		{ Id = "us_yield_2", Type = "Economy", StartUtc = "04:00", DurationMinutes = 120, LootMultiplier = 1.25, GatheringYieldMultiplier = 1.15, PurityMultiplier = 1.10 },
		{ Id = "us_war", Type = "War", StartUtc = "03:00", DurationMinutes = 60 },
	},
	ASIA = {
		{ Id = "asia_yield_1", Type = "Economy", StartUtc = "10:00", DurationMinutes = 120, LootMultiplier = 1.25, GatheringYieldMultiplier = 1.15, PurityMultiplier = 1.10 },
		{ Id = "asia_yield_2", Type = "Economy", StartUtc = "13:00", DurationMinutes = 120, LootMultiplier = 1.25, GatheringYieldMultiplier = 1.15, PurityMultiplier = 1.10 },
		{ Id = "asia_war", Type = "War", StartUtc = "12:00", DurationMinutes = 60 },
	},
}

Config.Maps = {
	testing_grounds = {
		MapKey = "testing_grounds",
		DisplayName = "City Testing / Others",
		PlaceIdDev = 101581464908992,
		PlaceIdProd = 0,
		RegionKey = "EU",
		ZoneType = "Safe",
		WorldX = 0,
		WorldY = 0,
		Biome = "Grass",
		DominantMaterial = "Grass",
		ResourceTierMin = 1,
		ResourceTierMax = 3,
		Ocean = { West = true, East = false, North = false, South = false },
		Mountains = { West = false, East = true, North = true, South = false },
		Desert = { West = false, East = false, North = false, South = true },
		Roads = { East = "template_zone"},
		Features = { AuctionHouse = true, BlackMarket = true, Bank = true, Territories = true, Gathering = true, NPCs = true },
	},
	template_zone = {
		MapKey = "template_zone",
		DisplayName = "Normal Map Testing",
		PlaceIdDev = 94035330439079,
		PlaceIdProd = 0,
		RegionKey = "EU",
		ZoneType = "Danger",
		WorldX = 1,
		WorldY = 0,
		Biome = "Grass",
		DominantMaterial = "Grass",
		ResourceTierMin = 3,
		ResourceTierMax = 5,
		Ocean = { West = false, East = false, North = false, South = false },
		Mountains = { West = true, East = true, North = true, South = true },
		Desert = { West = false, East = false, North = false, South = false },
		Roads = { West = "testing_grounds" },
		Features = { AuctionHouse = false, BlackMarket = false, Bank = false, Territories = true, Gathering = true, NPCs = true },
	},
}

Config.MaterialColors = {
	Grass = Color3.fromRGB(78, 133, 77),
	LeafyGrass = Color3.fromRGB(67, 116, 72),
	Ground = Color3.fromRGB(113, 93, 70),
	Mud = Color3.fromRGB(86, 71, 54),
	Rock = Color3.fromRGB(101, 104, 102),
	Slate = Color3.fromRGB(78, 82, 88),
	Basalt = Color3.fromRGB(51, 54, 58),
	Sand = Color3.fromRGB(190, 174, 116),
	Water = Color3.fromRGB(45, 112, 151),
	Snow = Color3.fromRGB(210, 221, 224),
	Concrete = Color3.fromRGB(120, 124, 121),
	Pavement = Color3.fromRGB(83, 86, 84),
}

function Config.NormalizeZoneType(zoneType)
	local text = tostring(zoneType or "Safe")
	return Config.ZoneTypeAliases[text] or text
end

function Config.GetZoneRank(zoneType)
	return Config.ZoneDangerRank[Config.NormalizeZoneType(zoneType)] or 0
end

local function envPlaceId(map)
	if Config.Environment == "Prod" then
		return tonumber(map.PlaceIdProd) or tonumber(map.PlaceIdDev) or 0
	end
	return tonumber(map.PlaceIdDev) or tonumber(map.PlaceIdProd) or 0
end

function Config.GetPlaceId(mapKey)
	local map = Config.Maps[mapKey]
	return map and envPlaceId(map) or nil
end

function Config.GetMap(mapKey)
	return Config.Maps[mapKey]
end

function Config.GetCurrentMapKey()
	local attr = game:GetAttribute("MapKey") or game:GetAttribute("WorldMapKey")
	if attr and tostring(attr) ~= "" then
		return tostring(attr)
	end
	for key, map in pairs(Config.Maps) do
		local placeId = envPlaceId(map)
		if placeId ~= 0 and placeId == game.PlaceId then
			return key
		end
	end
	return Config.CurrentMapFallback
end

function Config.GetCurrentMap()
	return Config.Maps[Config.GetCurrentMapKey()] or Config.Maps[Config.CurrentMapFallback]
end

function Config.GetMaterialColor(materialName)
	return Config.MaterialColors[tostring(materialName or "")] or Config.MaterialColors.Grass or Color3.fromRGB(78, 133, 77)
end

function Config.GetMapsForClient()
	local maps = {}
	for key, map in pairs(Config.Maps) do
		local copy = {}
		for k, v in pairs(map) do
			copy[k] = v
		end
		copy.MapKey = copy.MapKey or key
		copy.PlaceId = envPlaceId(map)
		maps[key] = copy
	end
	return maps
end

function Config.GetTargetForExit(exitPart)
	if not exitPart then return nil end
	local targetMapKey = exitPart:GetAttribute("TargetMapKey") or exitPart:GetAttribute("TargetMap") or exitPart:GetAttribute("MapKey")
	local targetPlaceId = tonumber(exitPart:GetAttribute("TargetPlaceId"))
	local targetSpawnId = exitPart:GetAttribute("TargetSpawnId") or exitPart:GetAttribute("SpawnId") or exitPart:GetAttribute("TargetSpawn")
	local spawnObjectValue = exitPart:FindFirstChild("TargetSpawn") or exitPart:FindFirstChild("Spawn")
	if not spawnObjectValue then
		for _, child in ipairs(exitPart:GetChildren()) do
			if child:IsA("ObjectValue") then
				spawnObjectValue = child
				break
			end
		end
	end
	if spawnObjectValue and spawnObjectValue:IsA("ObjectValue") then
		local value = spawnObjectValue.Value
		targetSpawnId = targetSpawnId or (value and (value:GetAttribute("SpawnId") or value.Name)) or spawnObjectValue.Name
	end
	if not targetPlaceId and targetMapKey then
		targetPlaceId = Config.GetPlaceId(tostring(targetMapKey))
	end
	local targetMap = targetMapKey and Config.GetMap(tostring(targetMapKey)) or nil
	return {
		TargetMapKey = targetMapKey and tostring(targetMapKey) or nil,
		TargetPlaceId = targetPlaceId,
		TargetSpawnId = targetSpawnId and tostring(targetSpawnId) or nil,
		TargetZoneType = Config.NormalizeZoneType(exitPart:GetAttribute("TargetZoneType") or (targetMap and targetMap.ZoneType) or "Safe"),
		SourcePortalId = exitPart:GetAttribute("PortalId") or exitPart.Name,
	}
end

return Config
