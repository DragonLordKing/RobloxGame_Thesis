--[[
Name: WorldGenConfig
Class: ModuleScript
Original path: game.ServerScriptService.GenerationStudioPlugin.GenerationRuntimeTemplate.ServerScriptService.WorldGen.WorldGenConfig
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ServerStorage, ReplicatedStorage
Functions: getSeedValue, normalizeProfile, isOptionsTable, coerceOptions, readNumber, setCountIfPresent, setBoolIfPresent, setNumberIfPresent, setTextIfPresent, setBorderSideIfPresent, getStructureTemplateNames, readStructureCounts, buildBase, applySharedOverrides, buildMain, buildCity, M.Build, M.GetDefaultOptions
Clean source lines: 622
]]
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local M = {}

local MAP_SCALE = 2.25
local BASE_PLAYABLE_RADIUS = 1400
local BASE_DECO_RADIUS = 1750
local BASE_BORDER_WIDTH = 350

local DEFAULT_PROFILE = "City"
local MAIN_MAP_SCALE = MAP_SCALE
local CITY_MAP_SCALE = MAIN_MAP_SCALE / 3.5
local CITY_EDGE_DECORATION_WIDTH = 340

local DEFAULT_SEED = 348975789345870

local function getSeedValue()
	local seedValue = ServerStorage:FindFirstChild("WorldGenSeed")
	if seedValue and seedValue:IsA("IntValue") then
		return seedValue.Value
	end
	return DEFAULT_SEED
end

local function normalizeProfile(value)
	local text = string.lower(tostring(value or DEFAULT_PROFILE))
	if text == "city" or text == "town" or text == "settlement" then
		return "City"
	end
	return "Main"
end

local function isOptionsTable(value)
	if type(value) ~= "table" then
		return false
	end
	return value.profile ~= nil
		or value.mapProfile ~= nil
		or value.mapScale ~= nil
		or value.seed ~= nil
		or value.biome ~= nil
		or value.baseHeight ~= nil
		or value.waterLevel ~= nil
		or value.plainsBaseRelief ~= nil
		or value.plainsRelief ~= nil
		or value.lakeCount ~= nil
		or value.lakeRadiusMin ~= nil
		or value.lakeRadiusMax ~= nil
		or value.lakeDepth ~= nil
		or value.lakeWaterDepth ~= nil
		or value.lakeShapeNoise ~= nil
		or value.riverCount ~= nil
		or value.riverWidth ~= nil
		or value.riverDepth ~= nil
		or value.riverWaterDepth ~= nil
		or value.riverAmplitude ~= nil
		or value.riverWobble ~= nil
		or value.canyonCount ~= nil
		or value.canyonWidth ~= nil
		or value.canyonDepth ~= nil
		or value.canyonWobble ~= nil
		or value.mesaCount ~= nil
		or value.mesaRadiusMin ~= nil
		or value.mesaRadiusMax ~= nil
		or value.mesaRise ~= nil
		or value.structureCount ~= nil
		or value.structureCounts ~= nil
		or value.rockCount ~= nil
		or value.treeCount ~= nil
		or value.bushCount ~= nil
		or value.miniRockCount ~= nil
		or value.featureMix ~= nil
		or value.northSide ~= nil
		or value.southSide ~= nil
		or value.eastSide ~= nil
		or value.westSide ~= nil
		or value.edgeDecorationWidth ~= nil
		or value.cityMonolithHeight ~= nil
		or value.cityMonolithRadius ~= nil
		or value.decorationEnabled ~= nil
end

local function coerceOptions(value)
	if isOptionsTable(value) then
		return value
	end
	return { roadPlan = value }
end

local function readNumber(options, key, defaultValue, minValue, maxValue)
	local value = nil
	if type(options) == "table" and options[key] ~= nil then
		value = tonumber(options[key])
	end
	if value == nil then
		value = defaultValue
	end
	if value == nil then
		return nil
	end
	if minValue and value < minValue then value = minValue end
	if maxValue and value > maxValue then value = maxValue end
	return value
end

local function setCountIfPresent(config, options, key, minValue, maxValue)
	if type(options) ~= "table" or options[key] == nil then
		return
	end
	local value = readNumber(options, key, config[key] or 0, minValue, maxValue)
	config[key] = math.floor(value + 0.5)
end

local function setBoolIfPresent(config, options, key)
	if type(options) ~= "table" or options[key] == nil then
		return
	end
	config[key] = options[key] == true
end

local function setNumberIfPresent(config, options, key, minValue, maxValue)
	if type(options) ~= "table" or options[key] == nil then
		return
	end
	config[key] = readNumber(options, key, config[key], minValue, maxValue)
end

local function setTextIfPresent(config, options, key)
	if type(options) ~= "table" or options[key] == nil then
		return
	end
	local text = tostring(options[key])
	if text ~= "" then
		config[key] = text
	end
end

local function setBorderSideIfPresent(config, options, optionKey, sideKey)
	if type(options) ~= "table" or options[optionKey] == nil then
		return
	end
	local text = tostring(options[optionKey])
	if text == "" or not config.border or not config.border.sides then
		return
	end
	config.border.sides[sideKey] = text
end

local function getStructureTemplateNames()
	local folder = ReplicatedStorage:FindFirstChild("Structures")
	local names = {}
	if not folder then
		return names
	end
	for _, inst in ipairs(folder:GetChildren()) do
		if inst:IsA("Model") then
			local base = inst:FindFirstChild("Base", true)
			if base and base:IsA("BasePart") then
				names[#names + 1] = inst.Name
			end
		end
	end
	table.sort(names)
	return names
end

local function readStructureCounts(options)
	local counts = {}
	if type(options) ~= "table" or type(options.structureCounts) ~= "table" then
		return counts
	end
	for name, rawValue in pairs(options.structureCounts) do
		local value = tonumber(rawValue) or 0
		value = math.floor(math.max(0, value) + 0.5)
		if value > 50 then
			value = 50
		end
		if value > 0 then
			counts[tostring(name)] = value
		end
	end
	return counts
end

local function buildBase(scale, roadPlan, borderWidthOverride)
	local playableRadius = BASE_PLAYABLE_RADIUS * scale
	local borderWidth = borderWidthOverride or (BASE_BORDER_WIDTH * scale)
	local decoRadius = borderWidthOverride and (playableRadius + borderWidth) or (BASE_DECO_RADIUS * scale)

	return {
		seed = getSeedValue(),
		profile = "Main",
		mapProfile = "Main",
		cityMap = false,
		radius = decoRadius,
		step = 6,

		biome = "grass",
		plainsFreq = 0.0014,
		plainsBaseRelief = 7,
		plainsRelief = 2.5,
		terrainHeightSnap = 0.5,
		plainsWarpStrength = 52,
		waterFillPad = 2,

		mesaBaseCount = 5,
		mesaCountAtLeast = {
			{ k = 7,  p = 0.65 },
			{ k = 9,  p = 0.35 },
			{ k = 11, p = 0.10 },
			{ k = 13, p = 0.03 },
			{ k = 15, p = 0.005 },
			{ k = 18, p = 0.0000001 },
		},

		waterLevel = 22,
		lakeCount = 4,
		lakeRadiusMin = 100,
		lakeRadiusMax = 330,
		lakeDepth = 34,
		lakeWaterDepth = 10,
		lakeEdgePad = 260,
		lakeMinSpacing = 360,
		lakeShoreSandWidth = 28,
		lakeShapeNoise = 0.26,
		lakeShapeLobesMin = 3,
		lakeShapeLobesMax = 7,

		explicitRiverCount = false,
		explicitCanyonCount = false,

		riverBaseCount = 1,
		riverCountAtLeast = {
			{ k = 3, p = 0.75 },
			{ k = 4, p = 0.45 },
			{ k = 5, p = 0.10 },
			{ k = 6, p = 0.01 },
			{ k = 7, p = 0.002 },
			{ k = 8, p = 0.0006 },
			{ k = 9, p = 0.00015 },
			{ k = 10, p = 0.00001 },
		},

		canyonBaseCount = 1,
		canyonCountAtLeast = {
			{ k = 3, p = 0.75 },
			{ k = 4, p = 0.45 },
			{ k = 5, p = 0.10 },
			{ k = 6, p = 0.01 },
			{ k = 7, p = 0.002 },
			{ k = 8, p = 0.0006 },
			{ k = 9, p = 0.00015 },
			{ k = 10, p = 0.00001 },
		},

		featureMix = "both",
		riverPreference = 0.55,

		riverWidth = 110,
		riverAmplitude = 260,
		riverFrequency = 0.0022,
		riverWobble = 70,
		riverSplineControlsMin = 5,
		riverSplineControlsMax = 8,
		riverSplineBend = 340,
		riverSplineFineWobble = 24,
		riverFallbackInset = 0.96,
		riverMinLengthRatio = 0.45,
		riverMesaAvoidPad = 90,
		riverMesaDirectBlockRatio = 0.42,
		riverMesaStopBackoff = 38,
		riverBlockedHillRadius = 54,
		riverBlockedHillRise = 16,
		riverCanyonStopMask = 0.12,
		riverWaterfallStopBackoff = 18,
		riverWaterfallMinDrop = 10,
		riverWaterfallThickness = 10,
		riverWaterfallPoolRadius = 32,
		riverMinBelowWater = 3,

		canyonWobble = 80,
		canyonWobbleFreq = 0.0018,

		decorationEnabled = true,
		decorationFolderName = "Decoration",
		rockCount = 170,
		treeCount = 230,
		bushCount = 360,
		miniRockCount = 1800,
		structureCount = 6,

		resourceSpawnEnabled = false,
		resourceSpawnCount = 0,
		resourceSpawnMinSpacing = 95,
		resourceSpawnWaterClearance = 80,
		resourceSpawnColliderClearance = 12,
		resourceSpawnRoadClearance = 34,
		resourceSpawnMaxSlope = 8,
		resourceSpawnMinNormalY = 0.93,
		resourceSpawnMesaSideMin = 0.10,
		resourceSpawnMesaTopMin = 0.96,

		bottomY = -650,
		topY = 650,
		baseHeight = 220,

		riverMode = "surface",
		riverDepth = 10,
		riverWaterDepth = 7,
		riverFreeboard = 1,

		riverHillStopRise = 13,
		riverHillSampleStep = 12,
		riverEndFade = 18,
		riverStampStep = 8,
		riverCoveLength = 18,
		riverCoveRadiusMul = 1.12,
		riverCoveNeckMul = 0.94,

		riverEndProbeNear = 12,
		riverEndProbeFar = 30,
		riverEndCliffRise = 16,
		riverEndRampRise = 6,
		riverRampStopBackoff = 24,
		riverCliffCoveDepth = 4,

		canyonDepth = 700,
		canyonWidth = 260,

		plainsStep = 2,

		wallRadius = playableRadius,
		wallPad = 12,

		border = {
			playableRadius = playableRadius,
			decoRadius = decoRadius,
			width = borderWidth,
			innerBlend = math.min(120, math.max(60, borderWidth * 0.35)),
			cornerBlend = math.min(200, math.max(80, borderWidth * 0.55)),
			sides = {
				N = "ocean",
				S = "mountains",
				E = "mountains",
				W = "desert_abandoned",
			},
			oceanWaterLevel = 200,
			oceanDepth = 60,
			oceanBeachWidth = 150,
			oceanCoastPower = 1.6,
			cliffDrop = 90,
			cliffOuterBaseHeight = 120,
			cliffShelfLen = 160,
			cliffHardness = 0.85,
			mountainsRise = 190,
			mountainsRiseHeavy = 300,
			mountainsSnow = true,
		},

		hazardCell = 14,
		hazardRiverMask = 0.20,
		hazardCanyonMask = 0.05,
		hazardRampMaskMax = 0.08,
		hazardBorderSlope = 4,
		hazardBorderBand = 260,

		riverCliffStopBackoff = 54,
		riverCliffEndCapRadiusMul = 0.90,
		riverCliffSideHillOffset = 38,
		riverCliffSideHillRadius = 34,
		riverCliffSideHillRise = 12,

		mesaRise = 95,
		mesaRadiusMin = 95,
		mesaRadiusMax = 190,
		mesaPlateauRatioMin = 0.54,
		mesaPlateauRatioMax = 0.70,
		mesaShapePowerMin = 2.0,
		mesaShapePowerMax = 3.2,
		mesaShapeNoise1Max = 0.18,
		mesaShapeNoise2Max = 0.10,
		mesaCliffPower = 0.55,
		mesaRampLength = 20,
		mesaRampWidth = 46,
		mesaRampHalfAngle = 0.32,
		mesaRampTopOffset = 3,

		mesaRampRunout = 150,
		mesaRampTopInset = 6,
		mesaHazardLipT = 0.84,
		mesaHazardRampClear = 12,
		mesaHazardMouthExtra = 10,

		mesaLipStart = 0.76,
		mesaLipEnd = 0.95,
		mesaLipRaise = 12,
		mesaRampBlend = 4,
		mesaHazardClearExtra = 14,

		roadPlan = roadPlan,
		maxBridgeLength = 450,
		bridgeMinSeparation = 280,
		supplementalBridgeTargetCount = 2,
		supplementalBridgeMaxCount = 0,
		supplementalBridgeEndpointSeparation = 220,
	}
end

local function applySharedOverrides(config, options)
	setBoolIfPresent(config, options, "decorationEnabled")

	setNumberIfPresent(config, options, "seed", 1, 2147483647)
	if config.seed then
		config.seed = math.floor(config.seed + 0.5)
	end
	setTextIfPresent(config, options, "biome")
	setTextIfPresent(config, options, "featureMix")
	if config.featureMix ~= "exclusive" then
		config.featureMix = "both"
	end

	setNumberIfPresent(config, options, "baseHeight", -200, 500)
	setNumberIfPresent(config, options, "waterLevel", -200, 500)
	setNumberIfPresent(config, options, "plainsBaseRelief", 0, 80)
	setNumberIfPresent(config, options, "plainsRelief", 0, 40)

	setCountIfPresent(config, options, "lakeCount", 0, 20)
	setNumberIfPresent(config, options, "lakeRadiusMin", 10, 600)
	setNumberIfPresent(config, options, "lakeRadiusMax", 10, 900)
	if config.lakeRadiusMin > config.lakeRadiusMax then
		config.lakeRadiusMin, config.lakeRadiusMax = config.lakeRadiusMax, config.lakeRadiusMin
	end
	setNumberIfPresent(config, options, "lakeDepth", 1, 160)
	setNumberIfPresent(config, options, "lakeWaterDepth", 1, 80)
	setNumberIfPresent(config, options, "lakeShapeNoise", 0, 0.75)

	setCountIfPresent(config, options, "riverCount", 0, 12)
	setNumberIfPresent(config, options, "riverWidth", 20, 360)
	setNumberIfPresent(config, options, "riverDepth", 1, 120)
	setNumberIfPresent(config, options, "riverWaterDepth", 1, 80)
	setNumberIfPresent(config, options, "riverAmplitude", 0, 600)
	setNumberIfPresent(config, options, "riverWobble", 0, 220)

	setCountIfPresent(config, options, "canyonCount", 0, 12)
	setNumberIfPresent(config, options, "canyonWidth", 40, 700)
	setNumberIfPresent(config, options, "canyonDepth", 40, 1200)
	setNumberIfPresent(config, options, "canyonWobble", 0, 260)

	setCountIfPresent(config, options, "mesaCount", 0, 40)
	setNumberIfPresent(config, options, "mesaRadiusMin", 20, 500)
	setNumberIfPresent(config, options, "mesaRadiusMax", 20, 700)
	if config.mesaRadiusMin > config.mesaRadiusMax then
		config.mesaRadiusMin, config.mesaRadiusMax = config.mesaRadiusMax, config.mesaRadiusMin
	end
	setNumberIfPresent(config, options, "mesaRise", 0, 260)

	setCountIfPresent(config, options, "structureCount", 0, 50)
	config.structureCounts = readStructureCounts(options)
	setCountIfPresent(config, options, "rockCount", 0, 1000)
	setCountIfPresent(config, options, "treeCount", 0, 1000)
	setCountIfPresent(config, options, "bushCount", 0, 1600)
	setCountIfPresent(config, options, "miniRockCount", 0, 4000)

	setBorderSideIfPresent(config, options, "northSide", "N")
	setBorderSideIfPresent(config, options, "southSide", "S")
	setBorderSideIfPresent(config, options, "eastSide", "E")
	setBorderSideIfPresent(config, options, "westSide", "W")

	if options.riverCount ~= nil then
		config.explicitRiverCount = true
		config.riverBaseCount = config.riverCount
		config.riverCountAtLeast = {}
	end
	if options.canyonCount ~= nil then
		config.explicitCanyonCount = true
		config.canyonBaseCount = config.canyonCount
		config.canyonCountAtLeast = {}
	end
	if options.mesaCount ~= nil then
		config.mesaBaseCount = config.mesaCount
		config.mesaCountAtLeast = {}
	end

	config.resourceSpawnEnabled = false
	config.resourceSpawnCount = 0
end

local function buildMain(options)
	local scale = readNumber(options, "mapScale", MAIN_MAP_SCALE, 0.25, 4)
	local config = buildBase(scale, options.roadPlan, nil)
	config.profile = "Main"
	config.mapProfile = "Main"
	config.cityMap = false
	applySharedOverrides(config, options)
	return config
end

local function buildCity(options)
	local scale = readNumber(options, "mapScale", CITY_MAP_SCALE, 0.15, MAIN_MAP_SCALE)
	local edgeWidth = readNumber(options, "edgeDecorationWidth", CITY_EDGE_DECORATION_WIDTH, 120, 700)
	local config = buildBase(scale, options.roadPlan, edgeWidth)

	config.profile = "City"
	config.mapProfile = "City"
	config.cityMap = true
	config.plainsBaseRelief = 0
	config.plainsRelief = 0
	config.mesaBaseCount = 0
	config.mesaCount = 0
	config.mesaCountAtLeast = {}
	config.riverBaseCount = 0
	config.riverCount = 0
	config.riverCountAtLeast = {}
	config.canyonBaseCount = 0
	config.canyonCount = 0
	config.canyonCountAtLeast = {}
	config.lakeCount = 0
	config.lakeRadiusMin = 45
	config.lakeRadiusMax = 95
	config.lakeDepth = 20
	config.lakeWaterDepth = 7
	config.lakeEdgePad = 90
	config.lakeMinSpacing = 160
	config.lakeShoreSandWidth = 18
	config.lakeShapeNoise = 0.34
	config.structureCount = 0
	config.rockCount = 55
	config.treeCount = 70
	config.bushCount = 105
	config.miniRockCount = 280
	config.hazardBorderBand = math.min(240, edgeWidth + 40)
	config.cityEdgeDecorationWidth = edgeWidth
	config.cityFlatHalfSize = math.max(96, config.border.playableRadius - edgeWidth)
	config.cityFlatHeight = config.baseHeight
	config.cityMonolithEnabled = true
	config.cityMonolithHeight = 96
	config.cityMonolithRadius = 18
	config.cityMonolithAvoidRadius = 130
	config.resourceSpawnEnabled = false
	config.resourceSpawnCount = 0

	applySharedOverrides(config, options)
	config.cityFlatHeight = config.baseHeight
	config.lakeCount = 0
	config.riverBaseCount = 0
	config.riverCount = 0
	config.riverCountAtLeast = {}
	config.canyonBaseCount = 0
	config.canyonCount = 0
	config.canyonCountAtLeast = {}
	config.mesaBaseCount = 0
	config.mesaCount = 0
	config.mesaCountAtLeast = {}
	config.structureCount = 0
	config.structureCounts = {}
	setNumberIfPresent(config, options, "cityMonolithHeight", 24, 220)
	setNumberIfPresent(config, options, "cityMonolithRadius", 6, 60)
	return config
end

function M.Build(optionsOrRoadPlan)
	local options = coerceOptions(optionsOrRoadPlan)
	local profile = normalizeProfile(options.profile or options.mapProfile)
	if profile == "City" then
		return buildCity(options)
	end
	return buildMain(options)
end

function M.GetDefaultOptions()
	return {
		profile = DEFAULT_PROFILE,
		mapProfile = DEFAULT_PROFILE,
		mapScale = CITY_MAP_SCALE,
		edgeDecorationWidth = CITY_EDGE_DECORATION_WIDTH,
		lakeCount = 0,
		riverCount = 0,
		canyonCount = 0,
		mesaCount = 0,
		decorationEnabled = true,
		resourceSpawnEnabled = false,
		seed = getSeedValue(),
		biome = "grass",
		baseHeight = 220,
		waterLevel = 22,
		plainsBaseRelief = 0,
		plainsRelief = 0,
		lakeRadiusMin = 45,
		lakeRadiusMax = 95,
		lakeDepth = 20,
		lakeWaterDepth = 7,
		lakeShapeNoise = 0.34,
		riverWidth = 110,
		riverDepth = 10,
		riverWaterDepth = 7,
		riverAmplitude = 260,
		riverWobble = 70,
		canyonWidth = 260,
		canyonDepth = 700,
		canyonWobble = 80,
		mesaRadiusMin = 95,
		mesaRadiusMax = 190,
		mesaRise = 95,
		structureCount = 0,
		structureCounts = {},
		structureTemplates = getStructureTemplateNames(),
		rockCount = 55,
		treeCount = 70,
		bushCount = 105,
		miniRockCount = 280,
		featureMix = "both",
		northSide = "ocean",
		southSide = "mountains",
		eastSide = "mountains",
		westSide = "desert_abandoned",
		cityMonolithHeight = 96,
		cityMonolithRadius = 18,
	}
end

return M