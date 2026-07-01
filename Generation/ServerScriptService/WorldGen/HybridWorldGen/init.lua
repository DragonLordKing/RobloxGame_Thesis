--[[
Name: HybridWorldGen
Class: ModuleScript
Original path: game.ServerScriptService.WorldGen.HybridWorldGen
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage, RunService
Requires:
  - local RoadPlanner = require(roadRoot:WaitForChild("RoadPlanner"))
  - local RoadBuilder = require(roadRoot:WaitForChild("RoadBuilder"))
Functions: getOrCreateRoot, clearRegion, clamp, lerp, smoothstep, snapHeight, deterministicUnit, cityFloorVariantOffset, makeYielder, raycastSurface, basePlainsHeight, minDistToSquareEdge, forEachDescendantBasePart, getCityReservedHalfSize, isInsideCityFlatCore, allowCityOuterFeature, normalizeType, sampleAtLeast, idxFromCoord, coordFromIdx, inBounds, heightAtCoord, forEachCellChunked, nearestSideTypeFromDists, makeRiverControls, canyonCenterV, catmullRom, riverCenterV, riverCoordFromUV, distPointToSegment, normalize2, sampleHeightNearest, classifyRiverEndMode, backoffPointToward, registerCliffStop, carveFixedWaterDisk, finalizeRiverEndpoints, carveFixedWaterSegment, writeRockColumn, isCellWater, isCellCanyon, writeTopLayer, riverSurfaceHeightAtU, computeRiverBounds, walk, angleDelta, mesaBoundaryNoise, mesaToLocal, mesaToWorld, mesaEval, mesaPointAtQ, segmentDistanceAndT, forEachMesaCell, distPointToLineSegment, pointInRampCorridor, buildMesaRampGeometry, applyMesas, carveMesaRamp, rebuildMesaHazards, mountainHeight
Clean source lines: 4174
]]
local M = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Terrain = workspace.Terrain

type RiverPoint = {
	x: number,
	z: number,
	u: number,
}

local function getOrCreateRoot()
	local root = workspace:FindFirstChild("GeneratedWorld")
	if root then root:Destroy() end
	root = Instance.new("Folder")
	root.Name = "GeneratedWorld"
	root.Parent = workspace
	return root
end

local function clearRegion(radius, bottomY, topY)
	local pad = 64
	local minX = -radius - pad * 0.5
	local maxX =  radius + pad * 0.5
	local minZ = -radius - pad * 0.5
	local maxZ =  radius + pad * 0.5

	local CHUNK_XZ = 1024
	local CHUNK_Y  = 1024

	local y = bottomY
	while y < topY do
		local y1 = math.min(topY, y + CHUNK_Y)
		local sy = (y1 - y)
		local cy = y + sy * 0.5

		local x = minX
		while x < maxX do
			local x1 = math.min(maxX, x + CHUNK_XZ)
			local sx = (x1 - x)
			local cx = x + sx * 0.5

			local z = minZ
			while z < maxZ do
				local z1 = math.min(maxZ, z + CHUNK_XZ)
				local sz = (z1 - z)
				local cz = z + sz * 0.5

				Terrain:FillBlock(CFrame.new(cx, cy, cz), Vector3.new(sx, sy, sz), Enum.Material.Air)
				z = z1
			end

			x = x1
		end

		RunService.Heartbeat:Wait()
		y = y1
	end
end

local function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smoothstep(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function snapHeight(h, snap)
	snap = snap or 0
	if snap <= 0 then
		return h
	end
	return math.floor(h / snap + 0.5) * snap
end

local function deterministicUnit(seed, a, b, salt)
	local n = math.noise((a + seed * 0.017 + salt * 13.1) * 0.173, (b - seed * 0.019 - salt * 7.7) * 0.173, salt * 0.037)
	return clamp(n * 0.5 + 0.5, 0, 1)
end

local function cityFloorVariantOffset(x, z, seed, cfg)
	if cfg.cityFloorVariationEnabled == false then
		return 0
	end
	local variantCount = math.max(1, math.floor(cfg.cityFloorVariantCount or 50))
	local cellSize = math.max(6, cfg.cityFloorVariantCellSize or 24)
	local amplitude = cfg.cityFloorVariantAmplitude or 1.15
	local gx = math.floor(x / cellSize)
	local gz = math.floor(z / cellSize)
	local pick = math.floor(deterministicUnit(seed, gx, gz, 31) * variantCount) + 1
	if pick > variantCount then
		pick = variantCount
	end
	local value = deterministicUnit(seed, pick, pick * 7, 53) * 2 - 1
	local neighbor = deterministicUnit(seed, gx - gz, gx + gz, 71) * 2 - 1
	return snapHeight((value * 0.72 + neighbor * 0.28) * amplitude, cfg.cityFloorVariantSnap or 0.25)
end

local function makeYielder(sliceSeconds)
	local last = os.clock()
	return function(force)
		if force or (os.clock() - last) >= sliceSeconds then
			RunService.Heartbeat:Wait()
			last = os.clock()
		end
	end
end

local function raycastSurface(x, z, rayStartY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { workspace:FindFirstChild("GeneratedWorld") }

	local origin = Vector3.new(x, rayStartY, z)
	local dir = Vector3.new(0, -(rayStartY + 8000), 0)
	return workspace:Raycast(origin, dir, params)
end

local function basePlainsHeight(x, z, seed, cfg)
	if cfg.cityMap and cfg.cityFlatHalfSize and math.abs(x) <= cfg.cityFlatHalfSize and math.abs(z) <= cfg.cityFlatHalfSize then
		local h = (cfg.cityFlatHeight or cfg.baseHeight) + cityFloorVariantOffset(x, z, seed, cfg)
		return clamp(h, cfg.minHeight, cfg.maxHeight)
	end

	local warpFreq = cfg.plainsWarpFreq or (cfg.plainsFreq * 0.42)
	local warpStrength = cfg.plainsWarpStrength or 52
	local warpX = math.noise((x + seed * 211) * warpFreq, (z - seed * 223) * warpFreq) * warpStrength
	local warpZ = math.noise((x - seed * 227) * warpFreq, (z + seed * 229) * warpFreq) * warpStrength
	local sx = x + warpX
	local sz = z + warpZ

	local nA = math.noise((sx + seed * 91) * cfg.plainsFreq, (sz - seed * 77) * cfg.plainsFreq)
	local nB = math.noise((sx + seed * 17) * (cfg.plainsFreq * 2.1), (sz - seed * 33) * (cfg.plainsFreq * 2.1))
	local nC = math.noise((sx - seed * 43) * (cfg.plainsFreq * 5.7), (sz + seed * 47) * (cfg.plainsFreq * 5.7))
	local nD = math.noise((x + seed * 59) * (cfg.plainsFreq * 13.0), (z - seed * 61) * (cfg.plainsFreq * 13.0))

	local fineRelief = cfg.plainsFineRelief or math.min(2.25, math.max(0, cfg.plainsRelief) * 0.85)
	local microRelief = cfg.plainsMicroRelief or math.min(1.15, math.max(0, cfg.plainsRelief) * 0.45)
	local h = cfg.baseHeight + nA * cfg.plainsBaseRelief + nB * cfg.plainsRelief + nC * fineRelief + nD * microRelief
	h = snapHeight(h, cfg.terrainHeightSnap)
	return clamp(h, cfg.minHeight, cfg.maxHeight)
end

local function minDistToSquareEdge(x, z, half)
	local dE = half - x
	local dW = x + half
	local dS = half - z
	local dN = z + half
	local d = dE
	if dW < d then d = dW end
	if dS < d then d = dS end
	if dN < d then d = dN end
	return d, dN, dS, dE, dW
end

local function forEachDescendantBasePart(root: Instance, fn: (BasePart) -> ())
	local descendants: {Instance} = root:GetDescendants()
	for i = 1, #descendants do
		local d = descendants[i]
		if d:IsA("BasePart") then
			fn(d)
		end
	end
end

function M.Generate(config)
	local cfg = {
		seed = config.seed or 12345,
		radius = config.radius or 512,
		step = config.step or 4,

		bottomY = config.bottomY or -80,
		topY = config.topY or 320,

		minHeight = (type(config.minHeight) == "number" and config.minHeight) or nil,
		maxHeight = (type(config.maxHeight) == "number" and config.maxHeight) or nil,

		baseHeight = config.baseHeight or 46,
		plainsFreq = config.plainsFreq or 0.0014,
		plainsBaseRelief = config.plainsBaseRelief or 7,
		plainsRelief = config.plainsRelief or 2.5,
		plainsStep = config.plainsStep or 1,
		terrainHeightSnap = (type(config.terrainHeightSnap) == "number" and config.terrainHeightSnap) or 0.5,
		plainsWarpFreq = config.plainsWarpFreq,
		plainsWarpStrength = config.plainsWarpStrength,
		plainsFineRelief = config.plainsFineRelief,
		plainsMicroRelief = config.plainsMicroRelief,
		waterFillPad = (type(config.waterFillPad) == "number" and config.waterFillPad) or 2,

		mapProfile = config.mapProfile or config.profile or "Main",
		cityMap = (config.cityMap == true) or string.lower(tostring(config.mapProfile or config.profile or "")) == "city",
		cityFlatHalfSize = config.cityFlatHalfSize,
		cityFlatHeight = config.cityFlatHeight,
		cityEdgeDecorationWidth = config.cityEdgeDecorationWidth,
		cityFloorVariationEnabled = (config.cityFloorVariationEnabled ~= false),
		cityFloorVariantCount = config.cityFloorVariantCount or 50,
		cityFloorVariantCellSize = config.cityFloorVariantCellSize or 24,
		cityFloorVariantAmplitude = config.cityFloorVariantAmplitude or 1.15,
		cityFloorVariantSnap = config.cityFloorVariantSnap or 0.25,
		cityMonolithEnabled = (config.cityMonolithEnabled == true),
		cityMonolithHeight = config.cityMonolithHeight or 96,
		cityMonolithRadius = config.cityMonolithRadius or 18,
		cityMonolithAvoidRadius = config.cityMonolithAvoidRadius or 110,

		grassDepth = config.grassDepth or 8,

		biome = (config.biome or "grass"),

		mesaCount = (type(config.mesaCount) == "number" and config.mesaCount) or nil,
		mesaRadiusMin = config.mesaRadiusMin or 40,
		mesaRadiusMax = config.mesaRadiusMax or 90,
		mesaRise = config.mesaRise or 60,
		mesaFalloff = config.mesaFalloff or 14,
		mesaTopClamp = config.mesaTopClamp or 2,
		mesaTopRelief = config.mesaTopRelief or 0.5,
		mesaCoreT = config.mesaCoreT or 0.94,

		minRamps = config.minRamps or 1,
		maxRamps = config.maxRamps or 3,
		rampWidth = config.rampWidth or 92,
		rampStep = config.rampStep or 2,
		rampSnapFrac = config.rampSnapFrac or 0.92,
		rampFan = config.rampFan or 0.35,
		rampAttachSteps = config.rampAttachSteps or 28,
		rampTopInset = config.rampTopInset or 18,
		rampLandingLen = config.rampLandingLen or 30,
		rampLength = config.rampLength or 110,
		rampLeaveT = config.rampLeaveT or 0.04,

		waterLevel = config.waterLevel or 22,
		waterDepth = config.waterDepth or 5,

		lakeCount = (type(config.lakeCount) == "number" and config.lakeCount) or 0,
		lakeRadiusMin = config.lakeRadiusMin or 120,
		lakeRadiusMax = config.lakeRadiusMax or 260,
		lakeDepth = config.lakeDepth or 26,
		lakeWaterDepth = config.lakeWaterDepth or 8,
		lakeEdgePad = config.lakeEdgePad or 220,
		lakeMinSpacing = config.lakeMinSpacing or 360,
		lakeShoreSandWidth = config.lakeShoreSandWidth or 18,
		lakeShapeNoise = config.lakeShapeNoise or 0.24,
		lakeShapeLobesMin = config.lakeShapeLobesMin or 3,
		lakeShapeLobesMax = config.lakeShapeLobesMax or 7,
		lakeMaxMesaMask = config.lakeMaxMesaMask or 0.08,
		lakeMaxSlope = config.lakeMaxSlope or 12,

		riverCount = (type(config.riverCount) == "number" and config.riverCount) or nil,
		riverWidth = config.riverWidth or 90,
		riverDepth = config.riverDepth or 22,
		riverAmplitude = config.riverAmplitude or 220,
		riverFrequency = config.riverFrequency or 0.0032,
		riverWobble = config.riverWobble or 40,
		riverSplineControlsMin = config.riverSplineControlsMin or 5,
		riverSplineControlsMax = config.riverSplineControlsMax or 8,
		riverSplineBend = config.riverSplineBend or math.max(config.riverAmplitude or 220, config.riverWobble or 40, 180),
		riverSplineFineWobble = config.riverSplineFineWobble or 18,
		riverFallbackInset = config.riverFallbackInset or 0.96,
		riverMinLength = config.riverMinLength,
		riverMinLengthRatio = config.riverMinLengthRatio or 0.45,
		riverMesaAvoidPad = config.riverMesaAvoidPad or 90,
		riverMesaDirectBlockRatio = config.riverMesaDirectBlockRatio or 0.42,
		riverMesaStopBackoff = config.riverMesaStopBackoff or 38,
		riverBlockedHillRadius = config.riverBlockedHillRadius or 54,
		riverBlockedHillRise = config.riverBlockedHillRise or 16,
		riverCanyonStopMask = config.riverCanyonStopMask or 0.12,
		riverWaterfallStopBackoff = config.riverWaterfallStopBackoff or 18,
		riverWaterfallMinDrop = config.riverWaterfallMinDrop or 10,
		riverWaterfallThickness = config.riverWaterfallThickness or 10,
		riverWaterfallPoolRadius = config.riverWaterfallPoolRadius or 32,
		riverMinBelowWater = config.riverMinBelowWater or 3,
		explicitRiverCount = (config.explicitRiverCount == true),
		explicitCanyonCount = (config.explicitCanyonCount == true),

		canyonCount = (type(config.canyonCount) == "number" and config.canyonCount) or nil,
		canyonWidth = config.canyonWidth or 220,
		canyonDepth = config.canyonDepth or 360,
		canyonWobble = config.canyonWobble or 70,
		canyonWobbleFreq = config.canyonWobbleFreq or 0.0022,

		smoothRadius = config.smoothRadius or 3.5,
		smoothSkipPad = config.smoothSkipPad or 22,

		structureClearSize = config.structureClearSize or Vector3.new(44, 30, 44),
		structurePadSize = config.structurePadSize or Vector3.new(52, 8, 52),
		structureAvoidPad = config.structureAvoidPad or 26,
		structureRayStartY = config.structureRayStartY or 5000,
		structureMaxSlope = config.structureMaxSlope or 2,
		structureMesaMinT = config.structureMesaMinT or 0.985,
		structureMinSpacing = config.structureMinSpacing or 400,
		structureLift = config.structureLift or 6,
		structureCount = (type(config.structureCount) == "number" and config.structureCount) or 6,
		structureCounts = config.structureCounts,

		decorationEnabled = (config.decorationEnabled ~= false),
		decorationFolderName = config.decorationFolderName or "Decoration",
		decorationRayStartY = config.decorationRayStartY or 5000,

		rockCount = config.rockCount,
		treeCount = config.treeCount,
		bushCount = config.bushCount,
		miniRockCount = config.miniRockCount,

		treeFlatNormalY = config.treeFlatNormalY or 0.985,
		treeMinSpacing = config.treeMinSpacing or 20,
		treeMaxSpacing = config.treeMaxSpacing or 30,

		treeClusterChance = config.treeClusterChance or 0.12,
		treeClusterSizeMin = config.treeClusterSizeMin or 6,
		treeClusterSizeMax = config.treeClusterSizeMax or 12,
		treeClusterRadiusMin = config.treeClusterRadiusMin or 16,
		treeClusterRadiusMax = config.treeClusterRadiusMax or 28,

		treeSoilEmbedMin = config.treeSoilEmbedMin or 0.50,
		treeSoilEmbedMax = config.treeSoilEmbedMax or 0.62,

		miniRockScatterChance = config.miniRockScatterChance or 0.55,
		miniRockScatterRadius = config.miniRockScatterRadius or 26,
		miniRockScatterMin = config.miniRockScatterMin or 4,
		miniRockScatterMax = config.miniRockScatterMax or 11,

		resourceSpawnEnabled = (config.resourceSpawnEnabled == true),
		resourceSpawnFolderName = config.resourceSpawnFolderName or "ResourceSpawns",
		resourceSpawnCount = config.resourceSpawnCount or 80,
		resourceSpawnMinSpacing = config.resourceSpawnMinSpacing or 70,
		resourceSpawnWaterClearance = config.resourceSpawnWaterClearance or 60,
		resourceSpawnColliderClearance = config.resourceSpawnColliderClearance or 10,
		resourceSpawnRoadClearance = config.resourceSpawnRoadClearance or 28,
		resourceSpawnMaxSlope = config.resourceSpawnMaxSlope or 8,
		resourceSpawnMinNormalY = config.resourceSpawnMinNormalY or 0.93,
		resourceSpawnMesaSideMin = config.resourceSpawnMesaSideMin or 0.10,
		resourceSpawnMesaTopMin = config.resourceSpawnMesaTopMin or 0.96,
		resourceSpawnRayStartY = config.resourceSpawnRayStartY or 5000,

		chunkCells = config.chunkCells or 32,
		yieldSlice = config.yieldSlice or 0.02,

		mesaBaseCount = config.mesaBaseCount,
		mesaCountAtLeast = config.mesaCountAtLeast,

		riverBaseCount = config.riverBaseCount,
		riverCountAtLeast = config.riverCountAtLeast,

		canyonBaseCount = config.canyonBaseCount,
		canyonCountAtLeast = config.canyonCountAtLeast,

		featureMix = config.featureMix or "both",
		riverPreference = config.riverPreference,

		riverMode = config.riverMode or "surface",
		riverWaterDepth = config.riverWaterDepth or 6,
		riverFreeboard = config.riverFreeboard or 1,

		riverHillStopRise = config.riverHillStopRise or 18,
		riverHillSampleStep = config.riverHillSampleStep or 12,
		riverEndFade = config.riverEndFade or 24,
		riverStampStep = config.riverStampStep or 9,
		riverCoveLength = config.riverCoveLength or 32,
		riverCoveRadiusMul = config.riverCoveRadiusMul or 1.18,
		riverCoveNeckMul = config.riverCoveNeckMul or 0.92,

		riverEndProbeNear = config.riverEndProbeNear or 12,
		riverEndProbeFar = config.riverEndProbeFar or 30,
		riverEndCliffRise = config.riverEndCliffRise or 16,
		riverEndRampRise = config.riverEndRampRise or 6,
		riverRampStopBackoff = config.riverRampStopBackoff or 24,
		riverCliffCoveDepth = config.riverCliffCoveDepth or 4,

		canyonEndLipRise = config.canyonEndLipRise or 14,

		border = config.border,
		wallRadius = config.wallRadius,
		wallPad = config.wallPad or 12,

		hazardWallEnabled = (config.hazardWallEnabled ~= false),
		hazardCell = config.hazardCell or 12,
		hazardRiverMask = config.hazardRiverMask or 0.06,
		hazardCanyonMask = config.hazardCanyonMask or 0.05,
		hazardRampMaskMax = config.hazardRampMaskMax or 0.08,
		hazardBorderSlope = config.hazardBorderSlope or 4,
		hazardBorderBand = config.hazardBorderBand or 180,

		riverCliffStopBackoff = config.riverCliffStopBackoff or 48,
		riverCliffEndCapRadiusMul = config.riverCliffEndCapRadiusMul or 0.82,
		riverCliffSideHillOffset = config.riverCliffSideHillOffset or 34,
		riverCliffSideHillRadius = config.riverCliffSideHillRadius or 30,
		riverCliffSideHillRise = config.riverCliffSideHillRise or 10,

		hazardMesaEnabled = (config.hazardMesaEnabled ~= false),
		hazardMesaProbeDist = config.hazardMesaProbeDist or 30,
		hazardMesaDrop = config.hazardMesaDrop or 8,
		hazardMesaTopMaskMin = config.hazardMesaTopMaskMin or 0.72,

		mesaPlateauRatioMin = config.mesaPlateauRatioMin or 0.52,
		mesaPlateauRatioMax = config.mesaPlateauRatioMax or 0.72,
		mesaShapePowerMin = config.mesaShapePowerMin or 2.0,
		mesaShapePowerMax = config.mesaShapePowerMax or 3.4,
		mesaShapeNoise1Max = config.mesaShapeNoise1Max or 0.18,
		mesaShapeNoise2Max = config.mesaShapeNoise2Max or 0.10,
		mesaCliffPower = config.mesaCliffPower or 0.55,
		mesaRampLength = config.mesaRampLength or 20,
		mesaRampWidth = config.mesaRampWidth or 28,
		mesaRampHalfAngle = config.mesaRampHalfAngle or 0.34,
		mesaRampTopOffset = config.mesaRampTopOffset or 3,
		mesaRampPlateauInsetQ = config.mesaRampPlateauInsetQ or 0.10,

		mesaRampRunout = config.mesaRampRunout or 56,
		mesaRampTopInset = config.mesaRampTopInset or 6,
		mesaHazardLipT = config.mesaHazardLipT or 0.82,
		mesaHazardRampClear = config.mesaHazardRampClear or 10,
		mesaHazardMouthExtra = config.mesaHazardMouthExtra or 8,

		mesaLipStart = config.mesaLipStart or 0.74,
		mesaLipEnd = config.mesaLipEnd or 0.96,
		mesaLipRaise = config.mesaLipRaise or 10,
		mesaRampBlend = config.mesaRampBlend or 4,
		mesaHazardClearExtra = config.mesaHazardClearExtra or 6,
	}

	if cfg.cityMap then
		cfg.lakeCount = 0
		cfg.riverCount = 0
		cfg.canyonCount = 0
		cfg.mesaCount = 0
		cfg.structureCount = 0
		cfg.structureCounts = {}
	end

	local borderCfg = cfg.border
	if type(borderCfg) ~= "table" then
		borderCfg = {}
	end

	local playableRadius = borderCfg.playableRadius or cfg.radius
	local decoRadius = borderCfg.decoRadius or borderCfg.outerRadius or cfg.radius
	if decoRadius < playableRadius then
		decoRadius = playableRadius
	end

	local borderWidth = borderCfg.width or math.max(0, decoRadius - playableRadius)

	local function getCityReservedHalfSize()
		if not cfg.cityMap or not cfg.cityFlatHalfSize then
			return nil
		end
		return math.max(0, cfg.cityFlatHalfSize)
	end

	local function isInsideCityFlatCore(x, z, pad)
		local halfSize = getCityReservedHalfSize()
		if not halfSize then
			return false
		end
		pad = pad or 0
		return math.abs(x) <= (halfSize + pad) and math.abs(z) <= (halfSize + pad)
	end

	local function allowCityOuterFeature(x, z, pad)
		return not isInsideCityFlatCore(x, z, pad)
	end

	local borderInnerBlend = borderCfg.innerBlend or math.min(120, math.max(40, math.floor(borderWidth * 0.25)))
	local borderCornerBlend = borderCfg.cornerBlend or math.min(borderWidth, math.max(64, math.floor(borderWidth * 0.35)))

	local sideMap = borderCfg.sides
	if type(sideMap) ~= "table" then
		sideMap = {}
	end

	local function normalizeType(v)
		if type(v) ~= "string" then return "none" end
		v = string.lower(v)
		if v == "mountains" or v == "mountain" then return "mountains" end
		if v == "mountains_heavy" or v == "heavy_mountains" or v == "alot_of_mountains" or v == "lots_of_mountains" then return "mountains_heavy" end
		if v == "ocean" or v == "sea" then return "ocean" end
		if v == "cliff_grasslands" or v == "cliff" or v == "drop_grasslands" then return "cliff_grasslands" end
		if v == "desert" or v == "abandoned_desert" or v == "desert_abandoned" then return "desert_abandoned" end
		if v == "none" then return "none" end
		return "none"
	end

	local sideN = normalizeType(sideMap.N or sideMap.n or sideMap.North or sideMap.north)
	local sideS = normalizeType(sideMap.S or sideMap.s or sideMap.South or sideMap.south)
	local sideE = normalizeType(sideMap.E or sideMap.e or sideMap.East or sideMap.east)
	local sideW = normalizeType(sideMap.W or sideMap.w or sideMap.West or sideMap.west)

	local areaScale = (playableRadius * playableRadius) / (512 * 512)
	cfg.rockCount = cfg.rockCount or math.floor(140 * areaScale + 0.5)
	cfg.treeCount = cfg.treeCount or math.floor(190 * areaScale + 0.5)
	cfg.bushCount = cfg.bushCount or math.floor(260 * areaScale + 0.5)
	cfg.miniRockCount = cfg.miniRockCount or math.floor(950 * areaScale + 0.5)
	cfg.minHeight = cfg.minHeight or (cfg.bottomY + 2)
	cfg.maxHeight = cfg.maxHeight or (cfg.topY - 2)

	local topMatDefault
	if cfg.biome == "desert" then
		topMatDefault = Enum.Material.Sand
	elseif cfg.biome == "snow" then
		topMatDefault = Enum.Material.Snow
	else
		topMatDefault = Enum.Material.Grass
	end

	local seed, step = cfg.seed, cfg.step
	local genRadius = decoRadius
	local rng = Random.new(seed)

	local function sampleAtLeast(baseCount, atLeast)
		local u = rng:NextNumber()
		local n = baseCount
		for _, e in ipairs(atLeast) do
			if u < e.p then
				n = e.k
			else
				break
			end
		end
		return n
	end

	local DEFAULT_RIVER_AT_LEAST = {
		{ k = 2, p = 0.75 },
		{ k = 3, p = 0.45 },
		{ k = 4, p = 0.10 },
		{ k = 5, p = 0.01 },
		{ k = 6, p = 0.002 },
		{ k = 7, p = 0.0006 },
		{ k = 8, p = 0.00015 },
		{ k = 9, p = 0.00001 },
	}

	local DEFAULT_CANYON_AT_LEAST = {
		{ k = 2, p = 0.75 },
		{ k = 3, p = 0.45 },
		{ k = 4, p = 0.10 },
		{ k = 5, p = 0.01 },
		{ k = 6, p = 0.002 },
		{ k = 7, p = 0.0006 },
		{ k = 8, p = 0.00015 },
		{ k = 9, p = 0.00001 },
	}

	local DEFAULT_MESA_AT_LEAST = {
		{ k = 5,  p = 0.65 },
		{ k = 7,  p = 0.35 },
		{ k = 9,  p = 0.10 },
		{ k = 11, p = 0.03 },
		{ k = 13, p = 0.005 },
		{ k = 15, p = 0.0000001 },
	}

	if cfg.mesaCount == nil then
		cfg.mesaCount = sampleAtLeast(cfg.mesaBaseCount or 3, cfg.mesaCountAtLeast or DEFAULT_MESA_AT_LEAST)
	end

	if cfg.riverCount == nil then
		cfg.riverCount = sampleAtLeast(cfg.riverBaseCount or 1, cfg.riverCountAtLeast or DEFAULT_RIVER_AT_LEAST)
	end

	if cfg.canyonCount == nil then
		cfg.canyonCount = sampleAtLeast(cfg.canyonBaseCount or 1, cfg.canyonCountAtLeast or DEFAULT_CANYON_AT_LEAST)
	end

	local useRivers = (cfg.riverCount and cfg.riverCount > 0 and cfg.riverWidth > 0)
	local useCanyons = (cfg.canyonCount and cfg.canyonCount > 0 and cfg.canyonWidth > 0)

	if useRivers and useCanyons and cfg.featureMix == "exclusive" and not (cfg.explicitRiverCount and cfg.explicitCanyonCount) then
		local pref = cfg.riverPreference or 0.5
		if rng:NextNumber() < pref then
			useCanyons = false
		else
			useRivers = false
		end
	end

	local root = getOrCreateRoot()

	local meta = Instance.new("Folder")
	meta.Name = "Meta"
	meta.Parent = root
	local seedValue = Instance.new("IntValue")
	seedValue.Name = "Seed"
	seedValue.Value = seed
	seedValue.Parent = meta

	clearRegion(genRadius, cfg.bottomY, cfg.topY)

	local sizeCount = math.floor((genRadius * 2) / step) + 1

	local heights = table.create(sizeCount)
	local mesaMask = table.create(sizeCount)
	local mesaIdAt = table.create(sizeCount)
	local riverMask = table.create(sizeCount)
	local canyonMask = table.create(sizeCount)
	local rampMask = table.create(sizeCount)
	local baseHeights = table.create(sizeCount)
	local topMatAt = table.create(sizeCount)
	local waterTopAt = table.create(sizeCount)
	local waterMask = table.create(sizeCount)
	local mesaHazardMask = table.create(sizeCount)

	for i = 1, sizeCount do
		heights[i] = table.create(sizeCount)
		mesaMask[i] = table.create(sizeCount)
		mesaIdAt[i] = table.create(sizeCount)
		riverMask[i] = table.create(sizeCount)
		canyonMask[i] = table.create(sizeCount)
		rampMask[i] = table.create(sizeCount)
		baseHeights[i] = table.create(sizeCount)
		topMatAt[i] = table.create(sizeCount)
		waterTopAt[i] = table.create(sizeCount)
		waterMask[i] = table.create(sizeCount)
	end

	for i = 1, sizeCount do
		mesaHazardMask[i] = table.create(sizeCount)
	end

	local distToPlayable = table.create(sizeCount)
	local nearSideType = table.create(sizeCount)
	local riverAllow = table.create(sizeCount)
	local canyonAllow = table.create(sizeCount)

	for i = 1, sizeCount do
		distToPlayable[i] = table.create(sizeCount)
		nearSideType[i] = table.create(sizeCount)
		riverAllow[i] = table.create(sizeCount)
		canyonAllow[i] = table.create(sizeCount)
	end

	local function idxFromCoord(v)
		return math.floor((v + genRadius) / step) + 1
	end

	local function coordFromIdx(i)
		return (i - 1) * step - genRadius
	end

	local function inBounds(ix, iz)
		return ix >= 1 and ix <= sizeCount and iz >= 1 and iz <= sizeCount
	end

	local function heightAtCoord(x, z)
		local ix = idxFromCoord(x)
		local iz = idxFromCoord(z)
		if heights[ix] and heights[ix][iz] then
			return heights[ix][iz]
		end
		return nil
	end

	local Y = makeYielder(cfg.yieldSlice)
	local CH = cfg.chunkCells

	local function forEachCellChunked(fn)
		for ix0 = 1, sizeCount, CH do
			local ix1 = math.min(sizeCount, ix0 + CH - 1)
			for iz0 = 1, sizeCount, CH do
				local iz1 = math.min(sizeCount, iz0 + CH - 1)
				for ix = ix0, ix1 do
					for iz = iz0, iz1 do
						fn(ix, iz)
					end
				end
				Y()
			end
			Y()
		end
	end

	local function nearestSideTypeFromDists(dN, dS, dE, dW)
		local best = dN
		local tpe = sideN

		if dS < best then best = dS; tpe = sideS end
		if dE < best then best = dE; tpe = sideE end
		if dW < best then best = dW; tpe = sideW end

		return tpe
	end

	forEachCellChunked(function(ix, iz)
		local x = coordFromIdx(ix)
		local z = coordFromIdx(iz)

		local d, dN, dS, dE, dW = minDistToSquareEdge(x, z, playableRadius)
		distToPlayable[ix][iz] = d

		local tpe = nearestSideTypeFromDists(dN, dS, dE, dW)
		nearSideType[ix][iz] = tpe

		riverAllow[ix][iz] = (d >= 0) and 1 or 0
		canyonAllow[ix][iz] = (d >= 0)
	end)

	local canyons = {}
	if useCanyons then
		for i = 1, cfg.canyonCount do
			local theta = rng:NextNumber(0, math.pi * 2)
			local c = math.cos(theta)
			local sn = math.sin(theta)
			local off = rng:NextNumber(-playableRadius * 0.80, playableRadius * 0.80)
			local tilt = rng:NextNumber(-0.22, 0.22)
			canyons[i] = { off = off, tilt = tilt, s = i * 97.3, c = c, sn = sn }
		end
	end

	local function makeRiverControls(riverIndex: number, baseOffset: number)
		local minControls = math.max(4, math.floor(cfg.riverSplineControlsMin or 5))
		local maxControls = math.max(minControls, math.floor(cfg.riverSplineControlsMax or minControls))
		local count = rng:NextInteger(minControls, maxControls)
		local controls = table.create(count)
		local bend = cfg.riverSplineBend or cfg.riverAmplitude or 220

		for i = 1, count do
			local t = (i - 1) / math.max(1, count - 1)
			local middleWeight = math.sin(t * math.pi)
			local drift = math.noise(seed * 0.013 + riverIndex * 7.1, t * 3.4) * bend * 0.45
			local wander = rng:NextNumber(-bend, bend) * middleWeight
			local endNudge = rng:NextNumber(-bend * 0.30, bend * 0.30)
			local v = baseOffset + drift + wander

			if i == 1 or i == count then
				v = baseOffset + endNudge
			end

			controls[i] = { t = t, v = clamp(v, -playableRadius * 0.88, playableRadius * 0.88) }
		end

		return controls
	end

	local rivers = {}
	if useRivers then
		for i = 1, cfg.riverCount do
			local theta = rng:NextNumber(0, math.pi * 2)
			local c = math.cos(theta)
			local sn = math.sin(theta)
			local off = rng:NextNumber(-playableRadius * 0.38, playableRadius * 0.38)
			rivers[i] = {
				off = off,
				s = i * 133.7,
				c = c,
				sn = sn,
				uStart = -playableRadius * 1.12,
				uEnd = playableRadius * 1.12,
				controls = makeRiverControls(i, off),
			}
		end
	end

	local function canyonCenterV(u, def)
		return (u * def.tilt) + def.off
	end

	local function catmullRom(p0: number, p1: number, p2: number, p3: number, t: number): number
		local t2 = t * t
		local t3 = t2 * t
		return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
	end

	local function riverCenterV(u, def)
		local controls = def.controls
		if controls and #controls >= 2 then
			local uStart = def.uStart or (-playableRadius * 1.12)
			local uEnd = def.uEnd or (playableRadius * 1.12)
			local normalized = clamp((u - uStart) / math.max(1, uEnd - uStart), 0, 1)
			local scaled = normalized * (#controls - 1)
			local index = math.floor(scaled) + 1
			if index >= #controls then
				index = #controls - 1
			end
			local localT = scaled - (index - 1)
			local p0 = controls[math.max(1, index - 1)].v
			local p1 = controls[index].v
			local p2 = controls[index + 1].v
			local p3 = controls[math.min(#controls, index + 2)].v
			local fine = math.noise((u + seed * 13 + def.s) * (cfg.riverFrequency * 0.55), (seed + def.s) * 0.01) * (cfg.riverSplineFineWobble or 0)
			return catmullRom(p0, p1, p2, p3, localT) + fine
		end

		local wobble = math.noise((u + seed * 13 + def.s) * (def.freq * 0.8), (seed + def.s) * 0.01) * cfg.riverWobble
		return def.off + def.amp * math.sin((u + seed * 13 + def.s) * def.freq) + wobble
	end

	local function riverCoordFromUV(u, v, def)
		local x = u * def.c - v * def.sn
		local z = u * def.sn + v * def.c
		return x, z
	end

	local function distPointToSegment(px, pz, ax, az, bx, bz)
		local abx = bx - ax
		local abz = bz - az
		local apx = px - ax
		local apz = pz - az

		local ab2 = abx * abx + abz * abz
		local t = 0
		if ab2 > 1e-6 then
			t = clamp((apx * abx + apz * abz) / ab2, 0, 1)
		end

		local qx = ax + abx * t
		local qz = az + abz * t

		local dx = px - qx
		local dz = pz - qz
		return math.sqrt(dx * dx + dz * dz)
	end

	local function normalize2(x, z)
		local m = math.sqrt(x * x + z * z)
		if m <= 1e-6 then
			return 0, 0
		end
		return x / m, z / m
	end

	local function sampleHeightNearest(x, z)
		return heightAtCoord(x, z)
	end

	local function classifyRiverEndMode(endX, endZ, outX, outZ, cfg)
		local h0 = sampleHeightNearest(endX, endZ)
		if h0 == nil then
			return "cliff"
		end

		local nearD = cfg.riverEndProbeNear or 12
		local farD = cfg.riverEndProbeFar or 30

		local hNear = sampleHeightNearest(endX + outX * nearD, endZ + outZ * nearD)
		local hFar = sampleHeightNearest(endX + outX * farD, endZ + outZ * farD)

		if hNear == nil then
			return "cliff"
		end

		if hFar == nil then
			hFar = hNear
		end

		local riseNear = hNear - h0
		local riseFar = hFar - h0

		if riseNear >= (cfg.riverEndCliffRise or 16) then
			return "cliff"
		end

		if riseFar >= (cfg.riverEndRampRise or 6) then
			return "ramp"
		end

		return "open"
	end

	local cliffStops = {}
	local riverBlockedStops = {}
	local riverWaterfalls = {}
	local riverBaseSurface = nil

	local function backoffPointToward(pt, towardPt, backoff, minKeep)
		local dx = towardPt.x - pt.x
		local dz = towardPt.z - pt.z
		local segLen = math.sqrt(dx * dx + dz * dz)
		if segLen <= 1e-6 then
			return
		end

		minKeep = minKeep or 6
		local maxBackoff = math.max(0, segLen - minKeep)
		local d = math.min(backoff, maxBackoff)
		if d <= 0 then
			return
		end

		pt.x = pt.x + dx / segLen * d
		pt.z = pt.z + dz / segLen * d
	end

	local function registerCliffStop(pt, towardPt, outX, outZ)
		backoffPointToward(pt, towardPt, cfg.riverCliffStopBackoff or 48, 10)
		cliffStops[#cliffStops + 1] = {
			x = pt.x,
			z = pt.z,
			dirX = outX,
			dirZ = outZ,
		}
	end

	local function carveFixedWaterDisk(cx, cz, radius, waterTop, targetBed, riverAllow, riverMask, waterTopAt, waterMask, heights, sizeCount, idxFromCoord, coordFromIdx)
		local minIx = math.max(1, idxFromCoord(cx - radius) - 1)
		local maxIx = math.min(sizeCount, idxFromCoord(cx + radius) + 1)
		local minIz = math.max(1, idxFromCoord(cz - radius) - 1)
		local maxIz = math.min(sizeCount, idxFromCoord(cz + radius) + 1)

		for ix = minIx, maxIx do
			local x = coordFromIdx(ix)
			local dx = x - cx
			local dx2 = dx * dx

			for iz = minIz, maxIz do
				local allow = riverAllow[ix][iz] or 0
				if allow <= 0 then
					continue
				end

				local z = coordFromIdx(iz)
				local dz = z - cz
				local d = math.sqrt(dx2 + dz * dz)

				if d < radius then
					local t = (1 - (d / radius)) * allow
					local newBed = lerp(heights[ix][iz], targetBed, 0.35 + 0.65 * t)
					if newBed < heights[ix][iz] then
						heights[ix][iz] = newBed
					end

					if waterTop > heights[ix][iz] + 0.25 then
						if (waterTopAt[ix][iz] == nil) or (waterTop > waterTopAt[ix][iz]) then
							waterTopAt[ix][iz] = waterTop
						end
						waterMask[ix][iz] = math.max(waterMask[ix][iz] or 0, t)
						riverMask[ix][iz] = math.max(riverMask[ix][iz] or 0, t)
					end
				end
			end
		end
	end

	local function finalizeRiverEndpoints(pts: {RiverPoint})
		if #pts < 2 then
			return
		end

		local firstPt = pts[1]
		local secondPt = pts[2]
		local lastIndex = #pts
		local lastPt = pts[lastIndex]
		local prevPt = pts[lastIndex - 1]

		local startDx = firstPt.x - secondPt.x
		local startDz = firstPt.z - secondPt.z
		local endDx = lastPt.x - prevPt.x
		local endDz = lastPt.z - prevPt.z

		local startOutX, startOutZ = normalize2(startDx, startDz)
		local endOutX, endOutZ = normalize2(endDx, endDz)

		local startMode = classifyRiverEndMode(firstPt.x, firstPt.z, startOutX, startOutZ, cfg)
		local endMode = classifyRiverEndMode(lastPt.x, lastPt.z, endOutX, endOutZ, cfg)

		if startMode == "ramp" then
			backoffPointToward(firstPt, secondPt, cfg.riverRampStopBackoff or 24, 8)
		elseif startMode == "cliff" then
			registerCliffStop(firstPt, secondPt, startOutX, startOutZ)
		end

		if endMode == "ramp" then
			backoffPointToward(lastPt, prevPt, cfg.riverRampStopBackoff or 24, 8)
		elseif endMode == "cliff" then
			registerCliffStop(lastPt, prevPt, endOutX, endOutZ)
		end
	end

	local function carveFixedWaterSegment(ax, az, bx, bz, radius, waterTop, targetBed, riverAllow, riverMask, waterTopAt, waterMask, heights, sizeCount, idxFromCoord, coordFromIdx)
		local minIx = math.max(1, idxFromCoord(math.min(ax, bx) - radius) - 1)
		local maxIx = math.min(sizeCount, idxFromCoord(math.max(ax, bx) + radius) + 1)
		local minIz = math.max(1, idxFromCoord(math.min(az, bz) - radius) - 1)
		local maxIz = math.min(sizeCount, idxFromCoord(math.max(az, bz) + radius) + 1)

		for ix = minIx, maxIx do
			local x = coordFromIdx(ix)

			for iz = minIz, maxIz do
				local allow = riverAllow[ix][iz] or 0
				if allow <= 0 then
					continue
				end

				local z = coordFromIdx(iz)
				local d = distPointToSegment(x, z, ax, az, bx, bz)

				if d < radius then
					local t = (1 - (d / radius)) * allow
					local newBed = lerp(heights[ix][iz], targetBed, 0.35 + 0.65 * t)
					if newBed < heights[ix][iz] then
						heights[ix][iz] = newBed
					end

					if waterTop > heights[ix][iz] + 0.25 then
						if (waterTopAt[ix][iz] == nil) or (waterTop > waterTopAt[ix][iz]) then
							waterTopAt[ix][iz] = waterTop
						end
						waterMask[ix][iz] = math.max(waterMask[ix][iz] or 0, t)
						riverMask[ix][iz] = math.max(riverMask[ix][iz] or 0, t)
					end
				end
			end
		end
	end

	local function writeRockColumn(x: number, z: number, h: number)
		local floorY = cfg.bottomY
		local fillH = h - floorY
		if fillH <= 0 then
			return
		end

		Terrain:FillBlock(
			CFrame.new(x, floorY + fillH * 0.5, z),
			Vector3.new(step, fillH, step),
			Enum.Material.Rock
		)
	end

	local function isCellWater(ix: number, iz: number): boolean
		return (waterTopAt[ix][iz] ~= nil) or ((riverMask[ix][iz] or 0) > 0.12)
	end

	local function isCellCanyon(ix: number, iz: number): boolean
		return (canyonMask[ix][iz] or 0) > 0.05
	end

	local function writeTopLayer(ix: number, iz: number, x: number, z: number, h: number)
		local fillH = h - cfg.bottomY
		if fillH <= 0 then
			return
		end

		local isCanyon = isCellCanyon(ix, iz)
		local isWater = isCellWater(ix, iz)

		if not isCanyon and not isWater then
			local gd = math.min(cfg.grassDepth, fillH)
			if gd <= 0 then
				return
			end

			local mat = topMatAt[ix][iz] or topMatDefault
			Terrain:FillBlock(
				CFrame.new(x, h - gd * 0.5, z),
				Vector3.new(step, gd, step),
				mat
			)
			return
		end

		local mat = topMatAt[ix][iz]
		if mat and not isCanyon then
			local gd = math.min(cfg.grassDepth, fillH)
			if gd <= 0 then
				return
			end

			Terrain:FillBlock(
				CFrame.new(x, h - gd * 0.5, z),
				Vector3.new(step, gd, step),
				mat
			)
		end
	end

	local function riverSurfaceHeightAtU(u, def)
		local v = riverCenterV(u, def)
		local x, z = riverCoordFromUV(u, v, def)

		local ix = idxFromCoord(x)
		local iz = idxFromCoord(z)
		if not inBounds(ix, iz) then
			return nil
		end

		if (riverAllow[ix][iz] or 0) <= 0 then
			return nil
		end

		return heights[ix][iz], x, z, ix, iz
	end

	local function computeRiverBounds(def)
		local sampleStep = math.max(step, cfg.riverHillSampleStep or 12)
		local stopRise = cfg.riverHillStopRise or 18

		local scanMin = def.uStart or (-playableRadius * 1.25)
		local scanMax = def.uEnd or (playableRadius * 1.25)
		local fallbackInset = cfg.riverFallbackInset or 0.96

		local bestU = nil
		local bestH = math.huge

		for u = scanMin, scanMax, sampleStep do
			local h = riverSurfaceHeightAtU(u, def)
			if h and h < bestH then
				bestH = h
				bestU = u
			end
		end

		local fallbackMin = math.max(scanMin, -playableRadius * fallbackInset)
		local fallbackMax = math.min(scanMax, playableRadius * fallbackInset)

		if bestU == nil then
			def.uMin = fallbackMin
			def.uMax = fallbackMax
		else
			local function walk(dir)
				local lastGoodU = bestU
				local prevH = bestH
				local floorH = bestH
				local u = bestU + dir * sampleStep

				while (dir < 0 and u >= scanMin) or (dir > 0 and u <= scanMax) do
					local h = riverSurfaceHeightAtU(u, def)
					if not h then
						break
					end

					if h < floorH then
						floorH = h
					end

					local riseFromPrev = h - prevH
					local riseFromFloor = h - floorH

					if riseFromPrev > stopRise or riseFromFloor > stopRise * 1.75 then
						break
					end

					lastGoodU = u
					prevH = h
					u += dir * sampleStep
				end

				return lastGoodU
			end

			def.uMin = walk(-1)
			def.uMax = walk(1)
		end

		local minLength = cfg.riverMinLength or (playableRadius * (cfg.riverMinLengthRatio or 0.45))
		if not def.uMin or not def.uMax or (def.uMax - def.uMin) < minLength then
			def.uMin = fallbackMin
			def.uMax = fallbackMax
		end

		if def.uMin and def.uMax and def.uMin > def.uMax then
			def.uMin, def.uMax = def.uMax, def.uMin
		end

		if def.uMin then
			local vMin = riverCenterV(def.uMin, def)
			def.endMinX, def.endMinZ = riverCoordFromUV(def.uMin, vMin, def)
		else
			def.endMinX, def.endMinZ = nil, nil
		end

		if def.uMax then
			local vMax = riverCenterV(def.uMax, def)
			def.endMaxX, def.endMaxZ = riverCoordFromUV(def.uMax, vMax, def)
		else
			def.endMaxX, def.endMaxZ = nil, nil
		end
	end

	type MesaDef = {
		cx: number,
		cz: number,
		rx: number,
		rz: number,
		rot: number,
		rotC: number,
		rotS: number,
		topH: number,
		plateauQ: number,
		shapePower: number,
		cliffPower: number,
		n1Amp: number,
		n1Freq: number,
		n1Phase: number,
		n2Amp: number,
		n2Freq: number,
		n2Phase: number,
		rampTheta: number,
		rampHalfAngle: number,
		rampWidth: number,
		rampTopInset: number,
		rampRunout: number,
		rampTopOffset: number,
		lipStartQ: number,
		lipEndQ: number,
		lipRaise: number,
		rampBaseX: number,
		rampBaseZ: number,
		rampEdgeX: number,
		rampEdgeZ: number,
		rampTopX: number,
		rampTopZ: number,
	}

	local function angleDelta(a: number, b: number): number
		local d = (a - b + math.pi) % (math.pi * 2) - math.pi
		return d
	end

	local function mesaBoundaryNoise(m: MesaDef, theta: number): number
		local v =
			1
			+ math.sin(theta * m.n1Freq + m.n1Phase) * m.n1Amp
			+ math.sin(theta * m.n2Freq + m.n2Phase) * m.n2Amp
		return clamp(v, 0.62, 1.38)
	end

	local function mesaToLocal(m: MesaDef, x: number, z: number): (number, number)
		local dx = x - m.cx
		local dz = z - m.cz
		local lx = dx * m.rotC + dz * m.rotS
		local lz = -dx * m.rotS + dz * m.rotC
		return lx, lz
	end

	local function mesaToWorld(m: MesaDef, lx: number, lz: number): (number, number)
		local x = m.cx + lx * m.rotC - lz * m.rotS
		local z = m.cz + lx * m.rotS + lz * m.rotC
		return x, z
	end

	local function mesaEval(m: MesaDef, x: number, z: number): (number, number, boolean)
		local lx, lz = mesaToLocal(m, x, z)
		local nx = lx / m.rx
		local nz = lz / m.rz
		local ax = math.abs(nx)
		local az = math.abs(nz)
		local n = m.shapePower
		local k = (ax ^ n + az ^ n) ^ (1 / n)

		if k <= 1e-6 then
			return 0, 0, true
		end

		local theta = math.atan2(nz, nx)
		local q = k / mesaBoundaryNoise(m, theta)
		return q, theta, q <= 1
	end

	local function mesaPointAtQ(m: MesaDef, theta: number, qTarget: number): (number, number)
		local c = math.cos(theta)
		local s = math.sin(theta)
		local n = m.shapePower
		local k = (math.abs(c) ^ n + math.abs(s) ^ n) ^ (1 / n)
		local edge = mesaBoundaryNoise(m, theta)
		local rNorm = qTarget * edge / math.max(k, 1e-6)
		local lx = c * rNorm * m.rx
		local lz = s * rNorm * m.rz
		return mesaToWorld(m, lx, lz)
	end

	local function segmentDistanceAndT(px: number, pz: number, ax: number, az: number, bx: number, bz: number): (number, number)
		local abx = bx - ax
		local abz = bz - az
		local apx = px - ax
		local apz = pz - az
		local ab2 = abx * abx + abz * abz

		local t = 0
		if ab2 > 1e-6 then
			t = clamp((apx * abx + apz * abz) / ab2, 0, 1)
		end

		local qx = ax + abx * t
		local qz = az + abz * t
		local dx = px - qx
		local dz = pz - qz

		return math.sqrt(dx * dx + dz * dz), t
	end

	local function forEachMesaCell(m: MesaDef, pad: number, fn: (number, number) -> ())
		local reach = math.max(m.rx, m.rz) * 1.7 + pad
		local minIx = math.max(1, idxFromCoord(m.cx - reach) - 1)
		local maxIx = math.min(sizeCount, idxFromCoord(m.cx + reach) + 1)
		local minIz = math.max(1, idxFromCoord(m.cz - reach) - 1)
		local maxIz = math.min(sizeCount, idxFromCoord(m.cz + reach) + 1)

		for ix = minIx, maxIx do
			for iz = minIz, maxIz do
				fn(ix, iz)
			end
		end
	end

	local function distPointToLineSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): (number, number)
		local abx = bx - ax
		local abz = bz - az
		local apx = px - ax
		local apz = pz - az
		local ab2 = abx * abx + abz * abz

		local t = 0
		if ab2 > 1e-6 then
			t = clamp((apx * abx + apz * abz) / ab2, 0, 1)
		end

		local qx = ax + abx * t
		local qz = az + abz * t
		local dx = px - qx
		local dz = pz - qz

		return math.sqrt(dx * dx + dz * dz), t
	end

	local function pointInRampCorridor(m: MesaDef, x: number, z: number, extraWidth: number): (boolean, number, number)
		local d, t = distPointToLineSegment(x, z, m.rampBaseX, m.rampBaseZ, m.rampTopX, m.rampTopZ)
		local halfW = m.rampWidth * 0.5 + extraWidth
		if d > halfW then
			return false, d, t
		end
		return true, d, t
	end

	local function buildMesaRampGeometry(m: MesaDef)
		local edgeX, edgeZ = mesaPointAtQ(m, m.rampTheta, 1.0)
		local insideRefQ = math.max(0.05, m.plateauQ - 0.02)
		local insideRefX, insideRefZ = mesaPointAtQ(m, m.rampTheta, insideRefQ)

		local dirX, dirZ = normalize2(insideRefX - edgeX, insideRefZ - edgeZ)
		if dirX == 0 and dirZ == 0 then
			dirX, dirZ = 1, 0
		end

		local topX = edgeX + dirX * m.rampTopInset
		local topZ = edgeZ + dirZ * m.rampTopInset
		local baseX = edgeX - dirX * m.rampRunout
		local baseZ = edgeZ - dirZ * m.rampRunout

		m.rampBaseX = baseX
		m.rampBaseZ = baseZ
		m.rampEdgeX = edgeX
		m.rampEdgeZ = edgeZ
		m.rampTopX = topX
		m.rampTopZ = topZ
	end

	forEachCellChunked(function(ix, iz)
		local x = coordFromIdx(ix)
		local z = coordFromIdx(iz)
		local h0 = basePlainsHeight(x, z, seed, cfg)
		baseHeights[ix][iz] = h0
		heights[ix][iz] = clamp(h0, cfg.minHeight, cfg.maxHeight)
		mesaMask[ix][iz] = 0
		mesaIdAt[ix][iz] = 0
	end)

	local mesas: {MesaDef} = {}

	for i = 1, cfg.mesaCount do
		local tries = 0
		while tries < 260 do
			tries += 1

			local cx = rng:NextInteger(-playableRadius + 180, playableRadius - 180)
			local cz = rng:NextInteger(-playableRadius + 180, playableRadius - 180)

			local baseR = rng:NextNumber(cfg.mesaRadiusMin, cfg.mesaRadiusMax)
			local rx = baseR * rng:NextNumber(0.85, 1.30)
			local rz = baseR * rng:NextNumber(0.85, 1.30)

			local ok = allowCityOuterFeature(cx, cz, math.max(rx, rz) + 36)
			for j = 1, #mesas do
				local other = mesas[j]
				local dx = cx - other.cx
				local dz = cz - other.cz
				local minD = math.max(rx, rz) + math.max(other.rx, other.rz) + 70
				if (dx * dx + dz * dz) < (minD * minD) then
					ok = false
					break
				end
			end

			if ok then
				local rot = rng:NextNumber(0, math.pi * 2)
				local topH = basePlainsHeight(cx, cz, seed, cfg) + cfg.mesaRise
				topH = math.floor(topH / cfg.plainsStep + 0.5) * cfg.plainsStep

				local mesa: MesaDef = {
					cx = cx,
					cz = cz,
					rx = rx,
					rz = rz,
					rot = rot,
					rotC = math.cos(rot),
					rotS = math.sin(rot),
					topH = clamp(topH, cfg.minHeight, cfg.maxHeight),
					plateauQ = rng:NextNumber(cfg.mesaPlateauRatioMin, cfg.mesaPlateauRatioMax),
					shapePower = rng:NextNumber(cfg.mesaShapePowerMin, cfg.mesaShapePowerMax),
					cliffPower = cfg.mesaCliffPower,
					n1Amp = rng:NextNumber(0.06, cfg.mesaShapeNoise1Max),
					n1Freq = rng:NextInteger(2, 4),
					n1Phase = rng:NextNumber(0, math.pi * 2),
					n2Amp = rng:NextNumber(0.03, cfg.mesaShapeNoise2Max),
					n2Freq = rng:NextInteger(5, 8),
					n2Phase = rng:NextNumber(0, math.pi * 2),
					rampTheta = rng:NextNumber(-math.pi, math.pi),
					rampHalfAngle = cfg.mesaRampHalfAngle,
					rampWidth = cfg.mesaRampWidth,
					rampTopInset = cfg.mesaRampTopInset,
					rampRunout = cfg.mesaRampRunout,
					rampTopOffset = cfg.mesaRampTopOffset,
					lipStartQ = cfg.mesaLipStart,
					lipEndQ = cfg.mesaLipEnd,
					lipRaise = cfg.mesaLipRaise,
					rampBaseX = 0,
					rampBaseZ = 0,
					rampEdgeX = 0,
					rampEdgeZ = 0,
					rampTopX = 0,
					rampTopZ = 0,
				}

				mesas[#mesas + 1] = mesa
				break
			end
		end
	end

	local function applyMesas()
		for i = 1, #mesas do
			local m = mesas[i]

			forEachMesaCell(m, step * 2, function(ix, iz)
				local x = coordFromIdx(ix)
				local z = coordFromIdx(iz)

				local q, _, inside = mesaEval(m, x, z)

				if inside then
					local target = 0
					local mask = 0

					if q <= m.plateauQ then
						target = m.topH
						mask = 1
					else
						local t = 1 - ((q - m.plateauQ) / math.max(1e-6, 1 - m.plateauQ))
						t = clamp(t, 0, 1)
						target = lerp(baseHeights[ix][iz], m.topH, t ^ m.cliffPower)
						mask = t
					end

					if q >= m.lipStartQ and q <= m.lipEndQ then
						local lipT = clamp((q - m.lipStartQ) / math.max(1e-6, m.lipEndQ - m.lipStartQ), 0, 1)
						local lipBell = math.sin(lipT * math.pi)
						target += m.lipRaise * lipBell
					end

					target = clamp(target, cfg.minHeight, cfg.maxHeight)

					if target > heights[ix][iz] then
						heights[ix][iz] = target
						mesaMask[ix][iz] = mask
						mesaIdAt[ix][iz] = i
					end
				end
			end)
		end
	end

	local function carveMesaRamp(mesaId: number)
		local m = mesas[mesaId]
		if not m then
			return
		end

		local edgeX, edgeZ = mesaPointAtQ(m, m.rampTheta, 1.0)

		local insideRefQ = math.max(0.05, m.plateauQ - 0.02)
		local insideRefX, insideRefZ = mesaPointAtQ(m, m.rampTheta, insideRefQ)

		local dirX, dirZ = normalize2(insideRefX - edgeX, insideRefZ - edgeZ)
		if dirX == 0 and dirZ == 0 then
			return
		end

		local topInset = cfg.mesaRampTopInset or 6
		local runout = cfg.mesaRampRunout or 56

		local topX = edgeX + dirX * topInset
		local topZ = edgeZ + dirZ * topInset

		local baseX = edgeX - dirX * runout
		local baseZ = edgeZ - dirZ * runout

		local baseH = heightAtCoord(baseX, baseZ)
		if baseH == nil then
			baseH = basePlainsHeight(baseX, baseZ, seed, cfg)
		end

		m.rampBaseX = baseX
		m.rampBaseZ = baseZ
		m.rampEdgeX = edgeX
		m.rampEdgeZ = edgeZ
		m.rampTopX = topX
		m.rampTopZ = topZ

		local halfW = m.rampWidth * 0.5

		local minX = math.min(baseX, topX) - halfW - step
		local maxX = math.max(baseX, topX) + halfW + step
		local minZ = math.min(baseZ, topZ) - halfW - step
		local maxZ = math.max(baseZ, topZ) + halfW + step

		local minIx = math.max(1, idxFromCoord(minX) - 1)
		local maxIx = math.min(sizeCount, idxFromCoord(maxX) + 1)
		local minIz = math.max(1, idxFromCoord(minZ) - 1)
		local maxIz = math.min(sizeCount, idxFromCoord(maxZ) + 1)

		for ix = minIx, maxIx do
			local x = coordFromIdx(ix)

			for iz = minIz, maxIz do
				if (canyonMask[ix][iz] or 0) > 0.10 then
					continue
				end

				local z = coordFromIdx(iz)
				local d, t = segmentDistanceAndT(x, z, baseX, baseZ, topX, topZ)

				if d < halfW then
					local side = smoothstep(1 - (d / halfW))
					local rampT = smoothstep(t)

					local crestH = m.topH + m.rampTopOffset
					local rampH = lerp(baseH, crestH, rampT)

					local settle = smoothstep(clamp((rampT - 0.78) / 0.22, 0, 1))
					rampH = lerp(rampH, m.topH, settle)

					local newH = lerp(heights[ix][iz], rampH, side)
					heights[ix][iz] = clamp(newH, cfg.minHeight, cfg.maxHeight)

					if side > (rampMask[ix][iz] or 0) then
						rampMask[ix][iz] = side
					end

					mesaHazardMask[ix][iz] = 0
				end
			end
		end
	end

	local function rebuildMesaHazards()
		for i = 1, #mesas do
			local m = mesas[i]
			local hazardClear = cfg.mesaHazardClearExtra or 6

			forEachMesaCell(m, math.max(m.rampRunout, m.rampWidth) + step * 2, function(ix, iz)
				local x = coordFromIdx(ix)
				local z = coordFromIdx(iz)

				mesaHazardMask[ix][iz] = 0

				local q, _, inside = mesaEval(m, x, z)
				if not inside then
					return
				end

				local hazardStart = cfg.mesaHazardLipT or m.lipEndQ
				if q < hazardStart then
					return
				end

				mesaHazardMask[ix][iz] = 1
			end)
		end
	end

	applyMesas()

	if useCanyons then
		for ix = 1, sizeCount do
			local x = coordFromIdx(ix)
			for i = 1, #canyons do
				local def = canyons[i]
				local xc = x * def.c
				local xs = x * def.sn
				for iz = 1, sizeCount do
					if not canyonAllow[ix][iz] then
						continue
					end

					local z = coordFromIdx(iz)
					local u = xc + z * def.sn
					local v = -xs + z * def.c

					local cv = canyonCenterV(u, def)
					local d = math.abs(v - cv)
					local half = cfg.canyonWidth * 0.5
					if d < half then
						local t = 1 - (d / half)
						local depth = cfg.canyonDepth * (t * t)
						local surface = heights[ix][iz]
						local bed = clamp(surface - depth, cfg.minHeight, surface - 2)
						heights[ix][iz] = bed
						canyonMask[ix][iz] = math.max(canyonMask[ix][iz] or 0, t)
					end
				end
			end
		end
	end

	rebuildMesaHazards()


	local function mountainHeight(x, z, p, heavy)
		local rise = heavy and (borderCfg.mountainsRiseHeavy or 260) or (borderCfg.mountainsRise or 160)
		local freq1 = heavy and (borderCfg.mountainsFreqHeavy or 0.006) or (borderCfg.mountainsFreq or 0.0042)
		local freq2 = heavy and (borderCfg.mountainsFreq2Heavy or 0.012) or (borderCfg.mountainsFreq2 or 0.0085)
		local n1 = math.noise((x + seed * 29) * freq1, (z - seed * 31) * freq1)
		local n2 = math.noise((x + seed * 53) * freq2, (z - seed * 57) * freq2)
		local ridgy = math.abs(n2) * 2 - 1
		local t = smoothstep(p)
		local amp = (0.65 * n1 + 0.55 * ridgy)
		local h = cfg.baseHeight + rise * (t * t) + amp * (heavy and 70 or 48) * t
		h = snapHeight(h, cfg.terrainHeightSnap)
		return h
	end

	local function desertHeight(x, z, p)
		local t = smoothstep(p)
		local n1 = math.noise((x + seed * 71) * 0.0028, (z - seed * 73) * 0.0028)
		local n2 = math.noise((x + seed * 79) * 0.0060, (z - seed * 83) * 0.0060)
		local dunes = (n1 * 0.8 + n2 * 0.5) * (18 * (0.35 + 0.65 * t))
		local h = cfg.baseHeight + dunes
		h = snapHeight(h, cfg.terrainHeightSnap)
		return h
	end

	local function oceanBedHeight(x, z, p)
		local wl = borderCfg.oceanWaterLevel or cfg.waterLevel
		local depth = borderCfg.oceanDepth or 26
		local t = smoothstep(p)
		local n = math.noise((x + seed * 101) * 0.0032, (z - seed * 103) * 0.0032)
		local und = n * 3.0
		local bed = (wl - depth) + und - (t * 6)
		bed = snapHeight(bed, cfg.terrainHeightSnap)
		return bed, wl
	end

	local function cliffGrassHeight(x, z, p, currentH)
		local drop = borderCfg.cliffDrop or 90
		local shelfLen = borderCfg.cliffShelfLen or 120
		local t = clamp(p, 0, 1)
		local tt = smoothstep(t)

		local baseOuter = (borderCfg.cliffOuterBaseHeight ~= nil) and borderCfg.cliffOuterBaseHeight or (cfg.baseHeight - drop)
		local noiseOuter = math.noise((x + seed * 131) * 0.0028, (z - seed * 137) * 0.0028) * 6
		local outer = baseOuter + noiseOuter

		local cliffHardness = borderCfg.cliffHardness or 0.85
		local edgeT = clamp((t - cliffHardness) / math.max(1e-6, (1 - cliffHardness)), 0, 1)
		local cliff = lerp(outer, currentH, 1 - smoothstep(edgeT))

		local s = borderWidth > 0 and math.min(borderWidth, shelfLen) or shelfLen
		local shelfT = clamp(t * (borderWidth / math.max(1, s)), 0, 1)
		local shelf = lerp(outer, cliff, smoothstep(shelfT))

		shelf = snapHeight(shelf, cfg.terrainHeightSnap)
		return shelf
	end

	local function pickBorderMat(borderType, sideWeight)
		if borderType == "ocean" then
			return Enum.Material.Sand
		end
		if borderType == "desert_abandoned" then
			return Enum.Material.Sand
		end
		if borderType == "cliff_grasslands" then
			return Enum.Material.Grass
		end
		if borderType == "mountains" or borderType == "mountains_heavy" then
			if cfg.biome == "snow" and (borderCfg.mountainsSnow ~= false) then
				return Enum.Material.Snow
			end
			return Enum.Material.Rock
		end
		return topMatDefault
	end

	local function borderTypeHeight(borderType, x, z, p, currentH)
		if borderType == "mountains" then
			return mountainHeight(x, z, p, false), nil
		end
		if borderType == "mountains_heavy" then
			return mountainHeight(x, z, p, true), nil
		end
		if borderType == "desert_abandoned" then
			return desertHeight(x, z, p), nil
		end
		if borderType == "ocean" then
			local bed, wl = oceanBedHeight(x, z, p)

			local t = smoothstep(p)
			local pow = borderCfg.oceanCoastPower or 1.6
			t = t ^ pow

			local h = lerp(currentH, bed, t)
			h = snapHeight(h, cfg.terrainHeightSnap)

			return h, wl
		end
		if borderType == "cliff_grasslands" then
			return cliffGrassHeight(x, z, p, currentH), nil
		end
		return currentH, nil
	end

	local function applyBorders()
		if borderWidth <= 0 then return end
		forEachCellChunked(function(ix, iz)
			local x = coordFromIdx(ix)
			local z = coordFromIdx(iz)

			local dDeco, dN, dS, dE, dW = minDistToSquareEdge(x, z, genRadius)
			if dDeco > borderWidth then
				return
			end

			local dPlay = minDistToSquareEdge(x, z, playableRadius)
			local alpha
			if dPlay >= 0 then
				alpha = clamp(1 - (dPlay / math.max(1, borderInnerBlend)), 0, 1)
			else
				alpha = 1
			end
			if alpha <= 0 then
				return
			end

			local function wFromDist(d)
				if d >= borderWidth then return 0 end
				local p = 1 - (d / borderWidth)
				return smoothstep(p), p
			end

			local wN, pN = wFromDist(dN)
			local wS, pS = wFromDist(dS)
			local wE, pE = wFromDist(dE)
			local wW, pW = wFromDist(dW)

			if borderCornerBlend > 0 then
				local function cornerT(d)
					local t = clamp(1 - (d / borderCornerBlend), 0, 1)
					return smoothstep(t)
				end
				local cN = cornerT(dN)
				local cS = cornerT(dS)
				local cE = cornerT(dE)
				local cW = cornerT(dW)

				wN = wN * (0.65 + 0.35 * cN)
				wS = wS * (0.65 + 0.35 * cS)
				wE = wE * (0.65 + 0.35 * cE)
				wW = wW * (0.65 + 0.35 * cW)
			end

			local sum = wN + wS + wE + wW
			if sum <= 1e-6 then
				return
			end

			local h0 = heights[ix][iz]
			local hb = 0
			local bestW = -1
			local bestType = "none"
			local bestP = 0
			local chosenWaterTop = nil
			local chosenWaterW = -1

			local function addSide(w, p, tpe)
				if w <= 0 or tpe == "none" then return end
				local ht, wt = borderTypeHeight(tpe, x, z, p, h0)
				hb += ht * w
				if w > bestW then
					bestW = w
					bestType = tpe
					bestP = p
				end
				if wt ~= nil and w > chosenWaterW then
					chosenWaterW = w
					chosenWaterTop = wt
				end
			end

			addSide(wN, pN, sideN)
			addSide(wS, pS, sideS)
			addSide(wE, pE, sideE)
			addSide(wW, pW, sideW)

			local hBorder = hb / sum
			hBorder = clamp(hBorder, cfg.minHeight, cfg.maxHeight)

			local finalH = lerp(h0, hBorder, alpha)
			finalH = clamp(finalH, cfg.minHeight, cfg.maxHeight)
			heights[ix][iz] = finalH

			local mat = pickBorderMat(bestType, bestW / sum)
			topMatAt[ix][iz] = mat

			if chosenWaterTop ~= nil then
				local wl = chosenWaterTop
				if wl > finalH + 0.25 then
					waterTopAt[ix][iz] = wl
					waterMask[ix][iz] = math.max(waterMask[ix][iz] or 0, alpha)
				end
				if bestType == "ocean" then
					local beach = borderCfg.oceanBeachWidth or math.min(borderWidth, 110)
					if beach > 0 then
						local dd = dDeco
						local beachP = clamp((beach - dd) / beach, 0, 1)
						local t = smoothstep(beachP)
						if t > 0.1 then
							topMatAt[ix][iz] = Enum.Material.Sand
						end
					end
				end
			end
		end)
	end

	applyBorders()

	local function localHeightDelta(ix, iz)
		local h = heights[ix] and heights[ix][iz]
		if h == nil then
			return math.huge
		end
		local d = 0
		if ix > 1 and heights[ix - 1] and heights[ix - 1][iz] then
			d = math.max(d, math.abs(h - heights[ix - 1][iz]))
		end
		if ix < sizeCount and heights[ix + 1] and heights[ix + 1][iz] then
			d = math.max(d, math.abs(h - heights[ix + 1][iz]))
		end
		if iz > 1 and heights[ix][iz - 1] then
			d = math.max(d, math.abs(h - heights[ix][iz - 1]))
		end
		if iz < sizeCount and heights[ix][iz + 1] then
			d = math.max(d, math.abs(h - heights[ix][iz + 1]))
		end
		return d
	end

	local function lakeShapeScale(lake, theta)
		local scale = 1
		for _, lobe in ipairs(lake.lobes) do
			scale += math.sin(theta * lobe.freq + lobe.phase) * lobe.amp
		end
		return clamp(scale, 0.58, 1.42)
	end

	local function lakeShapeQ(lake, x, z)
		local dx = x - lake.x
		local dz = z - lake.z
		local lx = dx * lake.rotC + dz * lake.rotS
		local lz = -dx * lake.rotS + dz * lake.rotC
		local nx = lx / lake.rx
		local nz = lz / lake.rz
		local baseQ = math.sqrt(nx * nx + nz * nz)
		local theta = math.atan2(nz, nx)
		return baseQ / lakeShapeScale(lake, theta)
	end

	local function lakeFootprintIsClear(lake)
		if not allowCityOuterFeature(lake.x, lake.z, lake.maxRadius + cfg.lakeShoreSandWidth + 12) then
			return false
		end

		local sampleRadius = lake.maxRadius + cfg.lakeShoreSandWidth
		local sampleStep = math.max(step * 3, 18)
		local x = lake.x - sampleRadius
		while x <= lake.x + sampleRadius do
			local z = lake.z - sampleRadius
			while z <= lake.z + sampleRadius do
				local q = lakeShapeQ(lake, x, z)
				if q <= 1 + (cfg.lakeShoreSandWidth / math.max(1, lake.maxRadius)) then
					local ix = idxFromCoord(x)
					local iz = idxFromCoord(z)
					if not inBounds(ix, iz) then
						return false
					end
					if waterTopAt[ix][iz] ~= nil or (riverMask[ix][iz] or 0) > 0.05 or (canyonMask[ix][iz] or 0) > 0.03 then
						return false
					end
					if (mesaMask[ix][iz] or 0) > cfg.lakeMaxMesaMask then
						return false
					end
					if localHeightDelta(ix, iz) > cfg.lakeMaxSlope then
						return false
					end
				end
				z += sampleStep
			end
			x += sampleStep
		end
		return true
	end

	local function makeLakeDef(x, z, radius)
		local rx = radius * rng:NextNumber(0.78, 1.35)
		local rz = radius * rng:NextNumber(0.72, 1.28)
		local lobes = {}
		local lobeCount = rng:NextInteger(cfg.lakeShapeLobesMin, cfg.lakeShapeLobesMax)
		for i = 1, lobeCount do
			lobes[#lobes + 1] = {
				freq = rng:NextInteger(2, 7),
				phase = rng:NextNumber(0, math.pi * 2),
				amp = rng:NextNumber(0.04, cfg.lakeShapeNoise / math.max(1, lobeCount * 0.55)),
			}
		end
		local maxRadius = math.max(rx, rz) * (1 + cfg.lakeShapeNoise)
		return {
			x = x,
			z = z,
			radius = radius,
			rx = rx,
			rz = rz,
			maxRadius = maxRadius,
			rot = rng:NextNumber(0, math.pi * 2),
			lobes = lobes,
		}
	end

	local function buildLakeDefs()
		local lakes = {}
		local count = math.max(0, cfg.lakeCount or 0)
		local edgePad = math.max(cfg.lakeEdgePad, cfg.lakeRadiusMax + 40)
		if playableRadius <= edgePad * 2 then
			return lakes
		end
		for _ = 1, count do
			for _attempt = 1, 220 do
				local radius = rng:NextNumber(cfg.lakeRadiusMin, cfg.lakeRadiusMax)
				local x = rng:NextNumber(-playableRadius + edgePad, playableRadius - edgePad)
				local z = rng:NextNumber(-playableRadius + edgePad, playableRadius - edgePad)
				local lake = makeLakeDef(x, z, radius)
				lake.rotC = math.cos(lake.rot)
				lake.rotS = math.sin(lake.rot)
				local ok = lakeFootprintIsClear(lake)
				if ok then
					for _, other in ipairs(lakes) do
						local dx = x - other.x
						local dz = z - other.z
						local minD = lake.maxRadius + other.maxRadius + cfg.lakeMinSpacing
						if (dx * dx + dz * dz) < (minD * minD) then
							ok = false
							break
						end
					end
				end
				if ok then
					local ix = idxFromCoord(x)
					local iz = idxFromCoord(z)
					local surface = heights[ix][iz]
					lake.waterTop = surface - math.max(1, cfg.riverFreeboard or 1)
					lakes[#lakes + 1] = lake
					break
				end
			end
		end
		return lakes
	end

	local function applyLake(lake)
		local shore = cfg.lakeShoreSandWidth
		local reach = lake.maxRadius + shore
		local minIx = math.max(1, idxFromCoord(lake.x - reach) - 1)
		local maxIx = math.min(sizeCount, idxFromCoord(lake.x + reach) + 1)
		local minIz = math.max(1, idxFromCoord(lake.z - reach) - 1)
		local maxIz = math.min(sizeCount, idxFromCoord(lake.z + reach) + 1)
		for ix = minIx, maxIx do
			local x = coordFromIdx(ix)
			for iz = minIz, maxIz do
				local z = coordFromIdx(iz)
				local q = lakeShapeQ(lake, x, z)
				local shoreQ = 1 + shore / math.max(1, lake.maxRadius)
				if q <= shoreQ then
					local shoreT = clamp((shoreQ - q) / math.max(0.001, shoreQ - 1), 0, 1)
					if q > 1 and shoreT > 0.05 then
						topMatAt[ix][iz] = Enum.Material.Sand
					end
					if q <= 1 then
						local t = smoothstep(1 - q)
						local targetBed = lake.waterTop - cfg.lakeWaterDepth - cfg.lakeDepth * t
						local bed = lerp(heights[ix][iz], targetBed, 0.45 + 0.55 * t)
						bed = clamp(bed, cfg.minHeight, cfg.maxHeight)
						if bed < heights[ix][iz] then
							heights[ix][iz] = bed
						end
						if lake.waterTop > heights[ix][iz] + 0.25 then
							if (waterTopAt[ix][iz] == nil) or lake.waterTop > waterTopAt[ix][iz] then
								waterTopAt[ix][iz] = lake.waterTop
							end
							waterMask[ix][iz] = math.max(waterMask[ix][iz] or 0, t)
						end
						if q > 1 - (shore / math.max(1, lake.maxRadius)) then
							topMatAt[ix][iz] = Enum.Material.Sand
						end
					end
				end
			end
		end
	end

	local lakes = buildLakeDefs()
	for _, lake in ipairs(lakes) do
		applyLake(lake)
	end

	if useRivers then
		for i = 1, #rivers do
			computeRiverBounds(rivers[i])
		end

		riverBaseSurface = table.create(sizeCount)
		for ix = 1, sizeCount do
			riverBaseSurface[ix] = table.create(sizeCount)
			for iz = 1, sizeCount do
				riverBaseSurface[ix][iz] = heights[ix][iz]
				riverMask[ix][iz] = 0
			end
		end

		local riverCellBlockedByMesa
		local riverCellBlockedByCanyon

		local function stampRiverDisk(cx, cz, radius)
			local minIx = math.max(1, idxFromCoord(cx - radius) - 1)
			local maxIx = math.min(sizeCount, idxFromCoord(cx + radius) + 1)
			local minIz = math.max(1, idxFromCoord(cz - radius) - 1)
			local maxIz = math.min(sizeCount, idxFromCoord(cz + radius) + 1)

			for ix = minIx, maxIx do
				local x = coordFromIdx(ix)
				local dx = x - cx
				local dx2 = dx * dx

				for iz = minIz, maxIz do
					local allow = riverAllow[ix][iz] or 0
					if allow <= 0 then
						continue
					end
					if riverCellBlockedByMesa and riverCellBlockedByMesa(ix, iz) then
						continue
					end
					if riverCellBlockedByCanyon and riverCellBlockedByCanyon(ix, iz) then
						continue
					end

					local z = coordFromIdx(iz)
					local dz = z - cz
					local d = math.sqrt(dx2 + dz * dz)

					if d < radius then
						local t = (1 - (d / radius)) * allow
						if t > (riverMask[ix][iz] or 0) then
							riverMask[ix][iz] = t
						end
					end
				end
			end
		end

		riverCellBlockedByMesa = function(ix, iz)
			if not inBounds(ix, iz) then
				return true
			end
			if (mesaMask[ix][iz] or 0) > 0.02 or (rampMask[ix][iz] or 0) > 0.04 or (mesaIdAt[ix][iz] or 0) ~= 0 then
				return true
			end
			return false
		end

		riverCellBlockedByCanyon = function(ix, iz)
			return (canyonMask[ix][iz] or 0) >= (cfg.riverCanyonStopMask or 0.12)
		end

		local function pointMesaBlock(x, z, pad)
			pad = pad or cfg.riverMesaAvoidPad or 0
			for _, m in ipairs(mesas) do
				local q, _, inside = mesaEval(m, x, z)
				local qPad = pad / math.max(1, math.max(m.rx, m.rz))
				if inside or q <= 1 + qPad then
					return m, q
				end
			end
			return nil, nil
		end

		local function lineMesaHit(a, b, pad)
			local dx = b.x - a.x
			local dz = b.z - a.z
			local len = math.sqrt(dx * dx + dz * dz)
			if len <= 1e-6 then
				local m, q = pointMesaBlock(a.x, a.z, pad)
				if m then
					return { mesa = m, q = q, x = a.x, z = a.z, t = 0 }
				end
				return nil
			end

			local samples = math.max(2, math.ceil(len / math.max(step * 2, 12)))
			for s = 1, samples do
				local t = s / samples
				local x = a.x + dx * t
				local z = a.z + dz * t
				local m, q = pointMesaBlock(x, z, pad)
				if m then
					return { mesa = m, q = q, x = x, z = z, t = t }
				end
			end
			return nil
		end

		local function lineClearOfMesas(a, b, pad)
			return lineMesaHit(a, b, pad) == nil
		end

		local function pointInRiverPlayArea(x, z)
			local inset = math.max(cfg.riverWidth or 0, 24)
			return math.abs(x) <= playableRadius - inset and math.abs(z) <= playableRadius - inset
		end

		local function directMesaBlock(a, b, m)
			local d = distPointToLineSegment(m.cx, m.cz, a.x, a.z, b.x, b.z)
			return d <= math.min(m.rx, m.rz) * (cfg.riverMesaDirectBlockRatio or 0.42)
		end

		local function tryMesaDetour(a, b, m)
			local dx, dz = normalize2(b.x - a.x, b.z - a.z)
			if dx == 0 and dz == 0 then
				return nil
			end

			local clear = math.max(m.rx, m.rz) + (cfg.riverMesaAvoidPad or 90) + (cfg.riverWidth or 0) * 0.5
			local lead = math.max(clear * 0.42, cfg.riverWidth or 60)
			local best = nil
			local bestLen = math.huge

			for _, side in ipairs({ 1, -1 }) do
				local sx = -dz * side
				local sz = dx * side
				local p1 = {
					x = m.cx - dx * lead + sx * clear,
					z = m.cz - dz * lead + sz * clear,
					u = lerp(a.u or 0, b.u or 0, 0.35),
				}
				local p2 = {
					x = m.cx + dx * lead + sx * clear,
					z = m.cz + dz * lead + sz * clear,
					u = lerp(a.u or 0, b.u or 0, 0.65),
				}

				if pointInRiverPlayArea(p1.x, p1.z) and pointInRiverPlayArea(p2.x, p2.z)
					and lineClearOfMesas(a, p1, cfg.riverWidth * 0.35)
					and lineClearOfMesas(p1, p2, cfg.riverWidth * 0.35)
					and lineClearOfMesas(p2, b, cfg.riverWidth * 0.35) then
					local l1 = math.sqrt((p1.x - a.x) ^ 2 + (p1.z - a.z) ^ 2)
					local l2 = math.sqrt((p2.x - p1.x) ^ 2 + (p2.z - p1.z) ^ 2)
					local l3 = math.sqrt((b.x - p2.x) ^ 2 + (b.z - p2.z) ^ 2)
					local total = l1 + l2 + l3
					if total < bestLen then
						bestLen = total
						best = { p1, p2 }
					end
				end
			end

			return best
		end

		local function appendRiverPoint(list, pt)
			if not pt then
				return
			end
			local last = list[#list]
			if last then
				local dx = pt.x - last.x
				local dz = pt.z - last.z
				if (dx * dx + dz * dz) < 1 then
					return
				end
			end
			list[#list + 1] = pt
		end

		local function stopPointBeforeMesa(a, b, hit)
			local dx = b.x - a.x
			local dz = b.z - a.z
			local len = math.sqrt(dx * dx + dz * dz)
			local backoff = cfg.riverMesaStopBackoff or 38
			local t = hit and hit.t or 1
			if len > 1e-6 then
				t = clamp(t - (backoff / len), 0, 1)
			else
				t = 0
			end
			return {
				x = a.x + dx * t,
				z = a.z + dz * t,
				u = lerp(a.u or 0, b.u or 0, t),
			}
		end

		local function addBlockedRiverStop(stopPt, nextPt)
			local dirX, dirZ = normalize2(nextPt.x - stopPt.x, nextPt.z - stopPt.z)
			riverBlockedStops[#riverBlockedStops + 1] = {
				x = stopPt.x,
				z = stopPt.z,
				dirX = dirX,
				dirZ = dirZ,
			}
		end

		local function routeRiverAroundMesas(pts)
			if #mesas == 0 or #pts < 2 then
				return pts
			end

			local routed = {}
			local i = 1
			local guard = #pts * 4 + 20
			while i <= #pts and guard > 0 do
				guard -= 1
				appendRiverPoint(routed, pts[i])
				if i >= #pts then
					break
				end

				local a = routed[#routed]
				local b = pts[i + 1]
				local hit = lineMesaHit(a, b, cfg.riverMesaAvoidPad)
				if hit then
					local exitIndex = i + 1
					while exitIndex < #pts do
						local m = pointMesaBlock(pts[exitIndex].x, pts[exitIndex].z, cfg.riverMesaAvoidPad)
						if m ~= hit.mesa then
							break
						end
						exitIndex += 1
					end

					b = pts[exitIndex]
					local detour = nil
					if b and not directMesaBlock(a, b, hit.mesa) then
						detour = tryMesaDetour(a, b, hit.mesa)
					end

					if detour then
						appendRiverPoint(routed, detour[1])
						appendRiverPoint(routed, detour[2])
						i = exitIndex
					else
						local stopPt = stopPointBeforeMesa(a, b or pts[i + 1], hit)
						appendRiverPoint(routed, stopPt)
						addBlockedRiverStop(stopPt, b or pts[i + 1])
						break
					end
				else
					i += 1
				end
			end

			return routed
		end

		local function findCanyonHit(a, b)
			local dx = b.x - a.x
			local dz = b.z - a.z
			local len = math.sqrt(dx * dx + dz * dz)
			if len <= 1e-6 then
				return nil
			end
			local samples = math.max(2, math.ceil(len / math.max(step * 2, 12)))
			for s = 1, samples do
				local t = s / samples
				local x = a.x + dx * t
				local z = a.z + dz * t
				local ix = idxFromCoord(x)
				local iz = idxFromCoord(z)
				if inBounds(ix, iz) and riverCellBlockedByCanyon(ix, iz) then
					return { x = x, z = z, t = t }
				end
			end
			return nil
		end

		local function truncateRiverAtCanyon(pts)
			if #pts < 2 then
				return pts
			end

			local out = {}
			appendRiverPoint(out, pts[1])
			for i = 1, #pts - 1 do
				local a = pts[i]
				local b = pts[i + 1]
				local hit = findCanyonHit(a, b)
				if hit then
					local dx = b.x - a.x
					local dz = b.z - a.z
					local len = math.sqrt(dx * dx + dz * dz)
					local stopT = hit.t
					if len > 1e-6 then
						stopT = clamp(hit.t - ((cfg.riverWaterfallStopBackoff or 18) / len), 0, 1)
					end
					local stopPt = {
						x = a.x + dx * stopT,
						z = a.z + dz * stopT,
						u = lerp(a.u or 0, b.u or 0, stopT),
					}
					appendRiverPoint(out, stopPt)

					local dirX, dirZ = normalize2(dx, dz)
					local topY = (heightAtCoord(stopPt.x, stopPt.z) or cfg.baseHeight) - (cfg.riverFreeboard or 1)
					local bottomY = heightAtCoord(hit.x, hit.z) or (topY - (cfg.riverWaterfallMinDrop or 10))
					if topY - bottomY < (cfg.riverWaterfallMinDrop or 10) then
						bottomY = topY - (cfg.riverWaterfallMinDrop or 10)
					end
					riverWaterfalls[#riverWaterfalls + 1] = {
						x = hit.x,
						z = hit.z,
						dirX = dirX,
						dirZ = dirZ,
						topY = topY,
						bottomY = bottomY,
					}
					return out
				end

				appendRiverPoint(out, b)
			end
			return out
		end

		local function stampRiverSegment(ax: number, az: number, bx: number, bz: number, radius: number)
			local minIx = math.max(1, idxFromCoord(math.min(ax, bx) - radius) - 1)
			local maxIx = math.min(sizeCount, idxFromCoord(math.max(ax, bx) + radius) + 1)
			local minIz = math.max(1, idxFromCoord(math.min(az, bz) - radius) - 1)
			local maxIz = math.min(sizeCount, idxFromCoord(math.max(az, bz) + radius) + 1)

			for ix = minIx, maxIx do
				local x = coordFromIdx(ix)
				for iz = minIz, maxIz do
					local allow = riverAllow[ix][iz] or 0
					if allow <= 0 then
						continue
					end
					if riverCellBlockedByMesa(ix, iz) then
						continue
					end
					if riverCellBlockedByCanyon(ix, iz) then
						continue
					end

					local z = coordFromIdx(iz)
					local d = distPointToSegment(x, z, ax, az, bx, bz)

					if d < radius then
						local t = (1 - (d / radius)) * allow
						if t > (riverMask[ix][iz] or 0) then
							riverMask[ix][iz] = t
						end
					end
				end
			end
		end

		local function stampRiverPolyline(pts: {RiverPoint}, radius: number)
			for p = 1, #pts - 1 do
				local a: RiverPoint = pts[p]
				local b: RiverPoint = pts[p + 1]

				local ax = a.x
				local az = a.z
				local bx = b.x
				local bz = b.z

				stampRiverSegment(ax, az, bx, bz, radius)
			end
		end

		local function buildRiverPolyline(def, sampleStep: number): {RiverPoint}
			local pts: {RiverPoint} = {}
			if not def.uMin or not def.uMax then
				return pts
			end

			local u = def.uMin
			while u < def.uMax do
				local v = riverCenterV(u, def)
				local x, z = riverCoordFromUV(u, v, def)
				pts[#pts + 1] = { x = x, z = z, u = u }
				u += sampleStep
			end

			do
				local v = riverCenterV(def.uMax, def)
				local x, z = riverCoordFromUV(def.uMax, v, def)
				pts[#pts + 1] = { x = x, z = z, u = def.uMax }
			end

			return pts
		end

		local stampStep = math.max(step, cfg.riverStampStep or 9)
		local half = cfg.riverWidth * 0.5

		for i = 1, #rivers do
			local def = rivers[i]
			local pts = buildRiverPolyline(def, stampStep)
			pts = routeRiverAroundMesas(pts)
			pts = truncateRiverAtCanyon(pts)

			if #pts >= 2 then
				finalizeRiverEndpoints(pts)
				stampRiverPolyline(pts, half)
			elseif #pts == 1 then
				stampRiverDisk(pts[1].x, pts[1].z, half)
			end
		end

		forEachCellChunked(function(ix, iz)
			local t = riverMask[ix][iz] or 0
			if t <= 0 then
				return
			end

			local surface = riverBaseSurface[ix][iz]
			local depth = cfg.riverDepth * (t * t)

			local bed
			local top

			if cfg.riverMode == "sea" then
				bed = surface - depth
				local forceBelow = cfg.waterLevel - cfg.riverMinBelowWater
				if bed > forceBelow then
					bed = forceBelow
				end
				bed = clamp(bed, cfg.minHeight, cfg.maxHeight)
				heights[ix][iz] = bed

				top = cfg.waterLevel
				if top > bed + 0.25 then
					if (waterTopAt[ix][iz] == nil) or (top > waterTopAt[ix][iz]) then
						waterTopAt[ix][iz] = top
					end
					waterMask[ix][iz] = math.max(waterMask[ix][iz] or 0, t)
				end
			else
				bed = surface - depth
				bed = clamp(bed, cfg.minHeight, surface - 0.25)
				heights[ix][iz] = bed

				top = math.min(surface - (cfg.riverFreeboard or 1), bed + (cfg.riverWaterDepth or 6))
				if top > bed + 0.25 then
					if (waterTopAt[ix][iz] == nil) or (top > waterTopAt[ix][iz]) then
						waterTopAt[ix][iz] = top
					end
					waterMask[ix][iz] = math.max(waterMask[ix][iz] or 0, t)
				end
			end
		end)
	end

	local function applyRiverCliffStops()
		if #cliffStops == 0 then
			return
		end

		local half = cfg.riverWidth * 0.5
		local sideOffset = cfg.riverCliffSideHillOffset or 34
		local sideRadius = cfg.riverCliffSideHillRadius or 30
		local sideRise = cfg.riverCliffSideHillRise or 10

		for i = 1, #cliffStops do
			local stop = cliffStops[i]
			local sideX = -stop.dirZ
			local sideZ = stop.dirX

			local hill1X = stop.x + sideX * sideOffset
			local hill1Z = stop.z + sideZ * sideOffset
			local hill2X = stop.x - sideX * sideOffset
			local hill2Z = stop.z - sideZ * sideOffset

			local minX = math.min(hill1X - sideRadius, hill2X - sideRadius)
			local maxX = math.max(hill1X + sideRadius, hill2X + sideRadius)
			local minZ = math.min(hill1Z - sideRadius, hill2Z - sideRadius)
			local maxZ = math.max(hill1Z + sideRadius, hill2Z + sideRadius)

			local minIx = math.max(1, idxFromCoord(minX) - 1)
			local maxIx = math.min(sizeCount, idxFromCoord(maxX) + 1)
			local minIz = math.max(1, idxFromCoord(minZ) - 1)
			local maxIz = math.min(sizeCount, idxFromCoord(maxZ) + 1)

			for ix = minIx, maxIx do
				local x = coordFromIdx(ix)

				for iz = minIz, maxIz do
					local z = coordFromIdx(iz)

					if (riverMask[ix][iz] or 0) < 0.18 then
						local function applyHill(cx, cz)
							local dx = x - cx
							local dz = z - cz
							local d = math.sqrt(dx * dx + dz * dz)

							if d < sideRadius then
								local t = smoothstep(1 - (d / sideRadius))
								local base = riverBaseSurface[ix][iz]
								local target = clamp(base + sideRise * t, cfg.minHeight, cfg.maxHeight)
								if heights[ix][iz] < target then
									heights[ix][iz] = target
								end
							end
						end

						applyHill(hill1X, hill1Z)
						applyHill(hill2X, hill2Z)
					end
				end
			end
		end
	end

	local function applyRiverBlockedStops()
		if #riverBlockedStops == 0 or not riverBaseSurface then
			return
		end

		local radius = cfg.riverBlockedHillRadius or 54
		local rise = cfg.riverBlockedHillRise or 16
		for _, stop in ipairs(riverBlockedStops) do
			local dirX = stop.dirX or 0
			local dirZ = stop.dirZ or 0
			local centerX = stop.x + dirX * radius * 0.45
			local centerZ = stop.z + dirZ * radius * 0.45
			local minIx = math.max(1, idxFromCoord(centerX - radius) - 1)
			local maxIx = math.min(sizeCount, idxFromCoord(centerX + radius) + 1)
			local minIz = math.max(1, idxFromCoord(centerZ - radius) - 1)
			local maxIz = math.min(sizeCount, idxFromCoord(centerZ + radius) + 1)

			for ix = minIx, maxIx do
				local x = coordFromIdx(ix)
				for iz = minIz, maxIz do
					local z = coordFromIdx(iz)
					local dx = x - centerX
					local dz = z - centerZ
					local d = math.sqrt(dx * dx + dz * dz)
					if d < radius then
						local ahead = (x - stop.x) * dirX + (z - stop.z) * dirZ
						if ahead > -radius * 0.35 then
							local t = smoothstep(1 - d / radius)
							local base = riverBaseSurface[ix][iz] or heights[ix][iz]
							local target = clamp(base + rise * t, cfg.minHeight, cfg.maxHeight)
							if heights[ix][iz] < target then
								heights[ix][iz] = target
							end
							if ahead > -radius * 0.05 then
								riverMask[ix][iz] = 0
								waterMask[ix][iz] = 0
								waterTopAt[ix][iz] = nil
							end
						end
					end
				end
			end
		end
	end

	local function edgeCloseFactor(distance: number, band: number): number
		if band <= 0 then
			return 0
		end

		local p = 1 - (distance / band)
		return smoothstep(p)
	end

	local function applyRiverEdgeCapCell(ix: number, iz: number, distance: number, bandR: number, hillRise: number)
		local rm = riverMask[ix][iz] or 0
		if rm <= 0.06 or distance > bandR then
			return
		end

		local close = edgeCloseFactor(distance, bandR)
		local fill = (cfg.riverDepth * 0.9) * (rm * rm) * close
		local bump = hillRise * (rm ^ 1.25) * (close ^ 1.35)

		local newH = clamp(heights[ix][iz] + fill + bump, cfg.minHeight, cfg.maxHeight)
		heights[ix][iz] = newH

		local wt = waterTopAt[ix][iz]
		if wt and wt <= newH + 0.25 then
			waterTopAt[ix][iz] = nil
			waterMask[ix][iz] = 0
		end

		riverMask[ix][iz] = rm * (1 - close)
	end

	local function applyCanyonEdgeCapCell(ix: number, iz: number, distance: number, bandC: number, canyonLipRise: number)
		local cm = canyonMask[ix][iz] or 0
		if cm <= 0.06 or distance > bandC then
			return
		end

		local close = edgeCloseFactor(distance, bandC)
		local fill = (cfg.canyonDepth * 0.90) * (cm * cm) * close
		local lip = canyonLipRise * (cm ^ 1.15) * (close ^ 1.30)

		heights[ix][iz] = clamp(heights[ix][iz] + fill + lip, cfg.minHeight, cfg.maxHeight)
		canyonMask[ix][iz] = cm * (1 - close)
	end

	local function capRiversAndCanyonsAtEdges()
		local bandR = cfg.riverEndBand or 70
		local bandC = cfg.canyonEndBand or 110
		local hillRise = cfg.riverEndHillRise or 10
		local canyonLipRise = cfg.canyonEndLipRise or 14

		if bandR <= 0 and bandC <= 0 then
			return
		end

		forEachCellChunked(function(ix, iz)
			local d: number = distToPlayable[ix][iz] :: number
			if d < 0 then
				return
			end

			local tpe = nearSideType[ix][iz] or "none"
			if tpe == "none" then
				return
			end

			if bandR > 0 then
				applyRiverEdgeCapCell(ix, iz, d, bandR, hillRise)
			end

			if bandC > 0 then
				applyCanyonEdgeCapCell(ix, iz, d, bandC, canyonLipRise)
			end
		end)
	end

	if useRivers then
		applyRiverCliffStops()
		applyRiverBlockedStops()
	end

	capRiversAndCanyonsAtEdges()

	forEachCellChunked(function(ix, iz)
		local x = coordFromIdx(ix)
		local z = coordFromIdx(iz)
		local h = clamp(heights[ix][iz], cfg.minHeight, cfg.maxHeight)

		writeRockColumn(x, z, h)
		writeTopLayer(ix, iz, x, z, h)
	end)

	for ix = 1, sizeCount do
		local x = coordFromIdx(ix)
		for iz = 1, sizeCount do
			local top = waterTopAt[ix][iz]
			if top then
				local z = coordFromIdx(iz)
				local bottom = heights[ix][iz]
				if top > bottom + 0.25 then
					local waterPad = cfg.waterFillPad or 0
					Terrain:FillBlock(
						CFrame.new(x, (top + bottom) * 0.5, z),
						Vector3.new(step + waterPad, top - bottom, step + waterPad),
						Enum.Material.Water
					)
				end
			end
		end
	end

	forEachCellChunked(function(ix, iz)
		local x = coordFromIdx(ix)
		local z = coordFromIdx(iz)
		local h = heights[ix][iz]

		local skip = false
		if (waterTopAt[ix][iz] ~= nil) then skip = true end
		if (riverMask[ix][iz] or 0) > 0.12 then skip = true end
		if (canyonMask[ix][iz] or 0) > 0.05 then skip = true end
		if (mesaMask[ix][iz] or 0) > 0.18 then skip = true end
		if (rampMask[ix][iz] or 0) > 0.10 then skip = true end

		if not skip then
			local mat = topMatAt[ix][iz] or topMatDefault
			Terrain:FillBall(Vector3.new(x, h, z), cfg.smoothRadius, mat)
		end
	end)

	if #riverWaterfalls > 0 then
		for _, fall in ipairs(riverWaterfalls) do
			local topY = fall.topY
			local bottomY = fall.bottomY
			if topY and bottomY and topY > bottomY + 1 then
				local dir = Vector3.new(fall.dirX or 0, 0, fall.dirZ or 1)
				if dir.Magnitude < 0.01 then
					dir = Vector3.new(0, 0, 1)
				end
				local center = Vector3.new(fall.x, (topY + bottomY) * 0.5, fall.z)
				local cf = CFrame.lookAt(center, center + dir)
				local width = math.max(step * 2, (cfg.riverWidth or 60) * 0.62)
				local thickness = cfg.riverWaterfallThickness or 10
				Terrain:FillBlock(cf, Vector3.new(width, topY - bottomY, thickness), Enum.Material.Water)
				Terrain:FillBall(Vector3.new(fall.x, bottomY + 1.5, fall.z), cfg.riverWaterfallPoolRadius or 32, Enum.Material.Water)
			end
		end
	end

	local structures = Instance.new("Folder")
	structures.Name = "Structures"
	structures.Parent = root

	local placedStructures = {}
	local placedStructureBounds = {}

	local structureSrc = ReplicatedStorage:FindFirstChild("Structures")

	local function findStructureBase(inst: Instance)
		local base = inst:FindFirstChild("Base", true)
		if base and base:IsA("BasePart") then
			return base
		end
		return nil
	end

	local function structureRadiusForTemplate(template: Instance)
		local base = findStructureBase(template)
		if not base then
			return nil, nil
		end
		return 0.5 * math.max(base.Size.X, base.Size.Z), base.Size
	end

	local function addStructureBounds(model: Model)
		local bbC, bbS = model:GetBoundingBox()
		placedStructureBounds[#placedStructureBounds + 1] = {
			minX = bbC.Position.X - bbS.X * 0.5,
			maxX = bbC.Position.X + bbS.X * 0.5,
			minZ = bbC.Position.Z - bbS.Z * 0.5,
			maxZ = bbC.Position.Z + bbS.Z * 0.5,
		}
	end

	local function isInsideStructureBounds(x, z, pad)
		pad = pad or 0
		for i = 1, #placedStructureBounds do
			local b = placedStructureBounds[i]
			if x >= (b.minX - pad) and x <= (b.maxX + pad) and z >= (b.minZ - pad) and z <= (b.maxZ + pad) then
				return true
			end
		end
		return false
	end

	local cityReservedHalfSize = getCityReservedHalfSize()
	if cityReservedHalfSize then
		placedStructureBounds[#placedStructureBounds + 1] = {
			minX = -cityReservedHalfSize,
			maxX = cityReservedHalfSize,
			minZ = -cityReservedHalfSize,
			maxZ = cityReservedHalfSize,
			kind = "CityReservedZone",
		}
	end

	local function canPlaceStructure(x, z, r)
		local minExtra = cfg.structureMinSpacing or 1000
		for i = 1, #placedStructures do
			local s = placedStructures[i]
			local dx = x - s.x
			local dz = z - s.z
			local minD = r + s.r + minExtra
			if (dx * dx + dz * dz) < (minD * minD) then
				return false
			end
		end
		return true
	end

	local function maxNeighborDelta(ix, iz)
		local h = heights[ix] and heights[ix][iz]
		if h == nil then
			return 0
		end

		local d = 0

		if ix > 1 and heights[ix - 1] and heights[ix - 1][iz] then
			d = math.max(d, math.abs(h - heights[ix - 1][iz]))
		end
		if ix < sizeCount and heights[ix + 1] and heights[ix + 1][iz] then
			d = math.max(d, math.abs(h - heights[ix + 1][iz]))
		end
		if iz > 1 and heights[ix] and heights[ix][iz - 1] then
			d = math.max(d, math.abs(h - heights[ix][iz - 1]))
		end
		if iz < sizeCount and heights[ix] and heights[ix][iz + 1] then
			d = math.max(d, math.abs(h - heights[ix][iz + 1]))
		end

		return d
	end

	local function isForbiddenXZ(x, z)
		local ix = idxFromCoord(x)
		local iz = idxFromCoord(z)
		if not inBounds(ix, iz) then return true end

		if (waterTopAt[ix][iz] ~= nil) then return true end
		if (riverMask[ix][iz] or 0) > 0.12 then return true end
		if (canyonMask[ix][iz] or 0) > 0.05 then return true end

		local mt = mesaMask[ix][iz] or 0
		if mt > 0.12 and mt < cfg.structureMesaMinT then
			return true
		end

		if maxNeighborDelta(ix, iz) > cfg.structureMaxSlope then
			return true
		end

		if (heightAtCoord(x, z) or 0) < (cfg.minHeight + 2) then
			return true
		end

		return false
	end

	local function isForbiddenStructureCell(ix, iz)
		if not inBounds(ix, iz) then
			return true
		end

		if waterTopAt[ix][iz] ~= nil then
			return true
		end

		if (riverMask[ix][iz] or 0) > 0.12 then
			return true
		end

		if (canyonMask[ix][iz] or 0) > 0.05 then
			return true
		end

		local mt = mesaMask[ix][iz] or 0
		if mt > 0.12 and mt < cfg.structureMesaMinT then
			return true
		end

		return false
	end

	local function validateStructureFootprint(x, z, baseSize)
		local checkX = baseSize.X + cfg.structureAvoidPad * 2
		local checkZ = baseSize.Z + cfg.structureAvoidPad * 2

		local halfX = checkX * 0.5
		local halfZ = checkZ * 0.5
		local sampleStep = math.max(step, 6)

		local minH = math.huge
		local maxH = -math.huge

		local sx = -halfX
		while sx <= halfX do
			local sz = -halfZ
			while sz <= halfZ do
				local px = x + sx
				local pz = z + sz
				local ix = idxFromCoord(px)
				local iz = idxFromCoord(pz)

				if isForbiddenStructureCell(ix, iz) then
					return false, nil
				end

				local h = heights[ix][iz]
				if h < minH then
					minH = h
				end
				if h > maxH then
					maxH = h
				end

				sz += sampleStep
			end
			sx += sampleStep
		end

		if maxH - minH > cfg.structureMaxSlope then
			return false, nil
		end

		return true, maxH
	end

	local function findStructureSpot(template: Instance)
		local r, baseSize = structureRadiusForTemplate(template)
		if not r or not baseSize then
			return nil
		end

		for attempt = 1, 3000 do
			local x = rng:NextInteger(-playableRadius + 180, playableRadius - 180)
			local z = rng:NextInteger(-playableRadius + 180, playableRadius - 180)

			if allowCityOuterFeature(x, z, r + cfg.structureAvoidPad) and canPlaceStructure(x, z, r) and not isInsideStructureBounds(x, z, 4) then
				local ok, y = validateStructureFootprint(x, z, baseSize)
				if ok and y then
					return x, z, y, r
				end
			end
		end

		return nil
	end

	local function placeStructureFromTemplate(template: Instance, x: number, z: number, y: number)
		local model = template:Clone()
		local base = findStructureBase(model)
		if not base then
			model:Destroy()
			return nil, nil
		end

		model.Parent = structures

		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end

		local yaw = rng:NextNumber(0, math.pi * 2)
		local targetBaseCf = CFrame.new(x, y + base.Size.Y * 0.5 + cfg.structureLift, z) * CFrame.Angles(0, yaw, 0)
		local offset = base.CFrame:ToObjectSpace(model:GetPivot())
		model:PivotTo(targetBaseCf * offset)

		addStructureBounds(model)

		return model, 0.5 * math.max(base.Size.X, base.Size.Z)
	end

	local structureTemplates = {}
	local structureTemplateByName = {}

	if not structureSrc then
		warn("[WorldGen] ReplicatedStorage.Structures not found")
	else
		for _, inst in ipairs(structureSrc:GetChildren()) do
			if inst:IsA("Model") then
				if findStructureBase(inst) then
					structureTemplates[#structureTemplates + 1] = inst
					structureTemplateByName[inst.Name] = inst
				else
					warn(("[WorldGen] Structure model missing Base: %s"):format(inst:GetFullName()))
				end
			end
		end
		table.sort(structureTemplates, function(a, b)
			return a.Name < b.Name
		end)
	end

	local placed = 0
	local requestedStructures = 0

	local function placeStructureCopies(template: Instance, count: number)
		local localPlaced = 0
		for _ = 1, count do
			local px, pz, y, pr = findStructureSpot(template)
			if px then
				local model, actualR = placeStructureFromTemplate(template, px, pz, y)
				if model then
					placed += 1
					localPlaced += 1
					placedStructures[#placedStructures + 1] = { x = px, z = pz, r = actualR or pr }
				end
			end
			Y()
		end
		return localPlaced
	end

	if type(cfg.structureCounts) == "table" then
		for name, rawCount in pairs(cfg.structureCounts) do
			local count = tonumber(rawCount) or 0
			count = math.max(0, math.floor(count + 0.5))
			if count > 0 then
				requestedStructures += count
				local template = structureTemplateByName[tostring(name)]
				if template then
					local made = placeStructureCopies(template, count)
					if made < count then
						warn(("[WorldGen] Placed %d/%d requested %s structures."):format(made, count, tostring(name)))
					end
				else
					warn(("[WorldGen] Requested unknown structure: %s"):format(tostring(name)))
				end
			end
		end
	end

	local structureTarget = math.max(0, math.floor(cfg.structureCount or 0))
	for _ = 1, structureTarget do
		if #structureTemplates == 0 then
			break
		end

		local template = structureTemplates[rng:NextInteger(1, #structureTemplates)]
		placeStructureCopies(template, 1)
	end

	if (structureTarget + requestedStructures) > 0 and placed == 0 then
		warn("[WorldGen] No structures placed. Check ReplicatedStorage.Structures and structure terrain constraints.")
	end

	local function findCityMonolithTemplate()
		if not structureSrc then
			return nil
		end
		local monolithFolder = structureSrc:FindFirstChild("Monolith")
		if not (monolithFolder and monolithFolder:IsA("Folder")) then
			return nil
		end
		local candidates = {}
		for _, inst in ipairs(monolithFolder:GetChildren()) do
			if inst:IsA("Model") or inst:IsA("BasePart") then
				candidates[#candidates + 1] = inst
			end
		end
		if #candidates == 0 then
			return nil
		end
		table.sort(candidates, function(a, b)
			return a.Name < b.Name
		end)
		return candidates[rng:NextInteger(1, #candidates)]
	end

	local function applyCityMonolithAttributes(model)
		model.Name = "CityClaimMonolith"
		model:SetAttribute("CityClaimMonolith", true)
		model:SetAttribute("ClaimSystemPending", true)
		if cityReservedHalfSize then
			model:SetAttribute("CityReservedHalfSize", cityReservedHalfSize)
			model:SetAttribute("CityReservedFullSize", cityReservedHalfSize * 2)
		end
	end

	local function placeCustomCityMonolith(template, groundY)
		local clone = template:Clone()
		local model
		if clone:IsA("Model") then
			model = clone
		elseif clone:IsA("BasePart") then
			model = Instance.new("Model")
			clone.Parent = model
		else
			clone:Destroy()
			return false
		end
		applyCityMonolithAttributes(model)
		model.Parent = structures
		local firstPart = nil
		forEachDescendantBasePart(model, function(part: BasePart)
			part.Anchored = true
			if firstPart == nil then
				firstPart = part
			end
		end)
		if not firstPart then
			model:Destroy()
			return false
		end
		local base = findStructureBase(model)
		model.PrimaryPart = base or model.PrimaryPart or firstPart
		local bbCf, bbSize = model:GetBoundingBox()
		local desiredBb = CFrame.new(0, groundY + bbSize.Y * 0.5, 0)
		local bbToPivot = bbCf:ToObjectSpace(model:GetPivot())
		model:PivotTo(desiredBb * bbToPivot)
		addStructureBounds(model)
		placedStructures[#placedStructures + 1] = {
			x = 0,
			z = 0,
			r = math.max(cfg.cityMonolithAvoidRadius or 110, bbSize.X * 0.5, bbSize.Z * 0.5),
		}
		return true
	end

	local function createCityMonolith()
		if not cfg.cityMonolithEnabled then
			return
		end

		local groundY = heightAtCoord(0, 0) or cfg.baseHeight
		local customTemplate = findCityMonolithTemplate()
		if customTemplate and placeCustomCityMonolith(customTemplate, groundY) then
			return
		end

		local height = cfg.cityMonolithHeight or 96
		local radius = cfg.cityMonolithRadius or 18
		local model = Instance.new("Model")
		applyCityMonolithAttributes(model)
		model.Parent = structures

		local base = Instance.new("Part")
		base.Name = "ClaimBase"
		base.Anchored = true
		base.CanCollide = true
		base.CanTouch = false
		base.CanQuery = true
		base.Material = Enum.Material.Slate
		base.Color = Color3.fromRGB(45, 48, 52)
		base.Size = Vector3.new(radius * 2.4, 4, radius * 2.4)
		base.Position = Vector3.new(0, groundY + 2, 0)
		base.Parent = model

		local shaft = Instance.new("Part")
		shaft.Name = "ClaimMonolith"
		shaft.Anchored = true
		shaft.CanCollide = true
		shaft.CanTouch = false
		shaft.CanQuery = true
		shaft.Material = Enum.Material.Slate
		shaft.Color = Color3.fromRGB(27, 30, 36)
		shaft.Size = Vector3.new(radius * 1.25, height, radius * 1.25)
		shaft.CFrame = CFrame.new(0, groundY + 4 + height * 0.5, 0)
		shaft.Parent = model

		local core = Instance.new("Part")
		core.Name = "ClaimCore"
		core.Anchored = true
		core.CanCollide = false
		core.CanTouch = false
		core.CanQuery = false
		core.Material = Enum.Material.Neon
		core.Color = Color3.fromRGB(86, 190, 255)
		core.Transparency = 0.18
		core.Size = Vector3.new(4, height * 0.68, 4)
		core.CFrame = CFrame.new(0, groundY + 4 + height * 0.5, 0)
		core.Parent = model

		model.PrimaryPart = shaft
		addStructureBounds(model)
		placedStructures[#placedStructures + 1] = { x = 0, z = 0, r = cfg.cityMonolithAvoidRadius or 110 }
	end

	createCityMonolith()

	local colliders = Instance.new("Folder")
	colliders.Name = "Colliders"
	colliders.Parent = root

	if cityReservedHalfSize then
		local cityZone = Instance.new("Part")
		cityZone.Name = "CityReservedZone"
		cityZone.Anchored = true
		cityZone.CanCollide = false
		cityZone.CanTouch = false
		cityZone.CanQuery = true
		cityZone.Transparency = 1
		cityZone.Size = Vector3.new(cityReservedHalfSize * 2, 12, cityReservedHalfSize * 2)
		cityZone.Position = Vector3.new(0, (cfg.cityFlatHeight or cfg.baseHeight) + 6, 0)
		cityZone:SetAttribute("CityReservedZone", true)
		cityZone:SetAttribute("HalfSize", cityReservedHalfSize)
		cityZone:SetAttribute("FullSize", cityReservedHalfSize * 2)
		cityZone.Parent = colliders
	end

	local decorations = Instance.new("Folder")
	decorations.Name = "Decorations"
	decorations.Parent = root

	local decoColliders = Instance.new("Folder")
	decoColliders.Name = "DecorationColliders"
	decoColliders.Parent = colliders

	local decoSrc = ReplicatedStorage:FindFirstChild(cfg.decorationFolderName)
	local decoRoot = decoSrc
	local decoRootPath = cfg.decorationFolderName
	local biomeFolderByName = {
		grass = "Grass",
		desert = "Desert",
		snow = "Snow",
	}
	local biomeFolderName = biomeFolderByName[string.lower(tostring(cfg.biome or "grass"))]
	if decoSrc and biomeFolderName then
		local biomeFolder = decoSrc:FindFirstChild(biomeFolderName)
		if biomeFolder and biomeFolder:IsA("Folder") then
			decoRoot = biomeFolder
			decoRootPath = cfg.decorationFolderName .. "." .. biomeFolderName
		end
	end

	if cfg.decorationEnabled then
		if not decoSrc then
			warn(("[WorldGen] ReplicatedStorage.%s not found; skipping decorations."):format(cfg.decorationFolderName))
		else
			local required = { "Rocks", "Trees", "Bushes", "MiniRocks" }
			for _, name in ipairs(required) do
				local f = decoRoot and decoRoot:FindFirstChild(name)
				if not f then
					warn(("[WorldGen] Missing folder: ReplicatedStorage.%s.%s"):format(decoRootPath, name))
				else
					local n = #f:GetChildren()
					if n == 0 then
						warn(("[WorldGen] Folder empty: ReplicatedStorage.%s.%s"):format(decoRootPath, name))
					end
				end
			end
		end
	end

	local function getFolder(name)
		if not decoRoot then return nil end
		local f = decoRoot:FindFirstChild(name)
		if not f then return nil end
		return f
	end

	local function pickTemplate(folderName)
		local f = getFolder(folderName)
		if not f then return nil end

		local candidates = {}
		for _, inst in ipairs(f:GetDescendants()) do
			if inst:IsA("Model") and not inst:FindFirstAncestorWhichIsA("Model") then
				candidates[#candidates+1] = inst
			elseif inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Model") then
				candidates[#candidates+1] = inst
			end
		end

		if #candidates == 0 then
			local kids = f:GetChildren()
			if #kids == 0 then return nil end
			return kids[rng:NextInteger(1, #kids)]
		end

		return candidates[rng:NextInteger(1, #candidates)]
	end

	local function wrapAsModel(inst)
		if inst:IsA("Model") then
			return inst
		end
		if inst:IsA("BasePart") then
			local m = Instance.new("Model")
			m.Name = inst.Name
			inst.Parent = m
			return m
		end
		if inst:IsA("Folder") then
			local child = inst:FindFirstChildWhichIsA("Model") or inst:FindFirstChildWhichIsA("BasePart")
			if child then
				child.Parent = nil
				inst:Destroy()
				return wrapAsModel(child)
			end
		end
		return nil
	end

	local function setNoCollision(model: Instance)
		forEachDescendantBasePart(model, function(part: BasePart)
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end)
	end

	local function setChildrenNoCollision(inst: Instance)
		forEachDescendantBasePart(inst, function(part: BasePart)
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end)
	end

	local function makeCollider(name, cf, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = true
		p.Transparency = 1
		p.Size = size
		p.CFrame = cf
		p.Parent = decoColliders
		return p
	end

	local lakeColliders = Instance.new("Folder")
	lakeColliders.Name = "LakeColliders"
	lakeColliders.Parent = colliders

	for i, lake in ipairs(lakes) do
		local p = Instance.new("Part")
		p.Name = "LakeCollider_" .. i
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = true
		p.Transparency = 1
		p.Size = Vector3.new(lake.rx * 2.2, 8, lake.rz * 2.2)
		p.CFrame = CFrame.new(lake.x, (lake.waterTop or cfg.waterLevel) + 4, lake.z) * CFrame.Angles(0, lake.rot or 0, 0)
		p.Parent = lakeColliders
	end

	local function basisFromNormal(normal, angle)
		local up = normal.Unit
		local t1 = up:Cross(Vector3.new(0, 1, 0))
		if t1.Magnitude < 1e-4 then
			t1 = up:Cross(Vector3.new(1, 0, 0))
		end
		t1 = t1.Unit
		local t2 = up:Cross(t1).Unit
		local c = math.cos(angle)
		local s = math.sin(angle)
		local forward = (t1 * c + t2 * s).Unit
		return CFrame.lookAt(Vector3.zero, forward, up)
	end

	local terrainParams = RaycastParams.new()
	terrainParams.FilterType = Enum.RaycastFilterType.Exclude
	terrainParams.IgnoreWater = false
	terrainParams.FilterDescendantsInstances = { root }

	local function raycastAt(x, z, startY)
		Y()
		local origin = Vector3.new(x, startY, z)
		local dir = Vector3.new(0, -(startY + 8000), 0)
		return workspace:Raycast(origin, dir, terrainParams)
	end

	local function raycastBedIfWater(x, z, startY)
		local r = raycastAt(x, z, startY)
		if not r then return nil end
		if r.Material ~= Enum.Material.Water then
			return r
		end

		local y = r.Position.Y - 2
		for _ = 1, 10 do
			local rr = raycastAt(x, z, y)
			if rr and rr.Material ~= Enum.Material.Water then
				return rr
			end
			y -= 4
		end
		return nil
	end

	local function waitForTerrainRaycastReady()
		local startY = cfg.decorationRayStartY
		for i = 1, 120 do
			local hit = raycastAt(0, 0, startY)
			if hit then
				return true
			end
			task.wait()
		end
		return false
	end

	waitForTerrainRaycastReady()

	local function placeFromTemplate(template, x, z, surfaceY, rotCf)
		local inst = template:Clone()
		local model = wrapAsModel(inst)
		if not model then
			inst:Destroy()
			return nil
		end

		model.Parent = decorations

		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end

		local pivot0 = model:GetPivot()
		model:PivotTo(CFrame.new(pivot0.Position) * rotCf)

		local bbC, bbS = model:GetBoundingBox()
		local bottomY = bbC.Position.Y - (bbS.Y * 0.5)
		local pivotY = model:GetPivot().Position.Y
		local bottomOffset = pivotY - bottomY

		local finalCf = CFrame.new(x, surfaceY + bottomOffset, z) * rotCf
		model:PivotTo(finalCf)

		return model
	end

	local treePoints = {}

	local function canPlaceTreeAt(x, z, spacing)
		for i = 1, #treePoints do
			local p = treePoints[i]
			local dx = x - p.x
			local dz = z - p.z
			if (dx * dx + dz * dz) < (spacing * spacing) then
				return false
			end
		end
		return true
	end

	local function findSoilPart(model)
		local soil = model:FindFirstChild("Soil", true)
		if soil and soil:IsA("BasePart") then
			return soil
		end
		return nil
	end

	local function placeTreeFromTemplate(template, x, z, surfaceY, rotCf)
		local inst = template:Clone()
		local model = wrapAsModel(inst)
		if not model then
			inst:Destroy()
			return nil
		end

		model.Parent = decorations

		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end

		local pivot0 = model:GetPivot()
		model:PivotTo(CFrame.new(pivot0.Position) * rotCf)

		local soil = findSoilPart(model)
		if not soil then
			model:Destroy()
			return nil
		end

		local embedMin = cfg.treeSoilEmbedMin or 0.50
		local embedMax = cfg.treeSoilEmbedMax or 0.62
		if embedMin < 0.50 then embedMin = 0.50 end
		if embedMax < embedMin then embedMax = embedMin end

		local embed = rng:NextNumber(embedMin, embedMax)
		local soilH = soil.Size.Y
		local targetSoilY = surfaceY - (embed - 0.5) * soilH

		local soilTarget = CFrame.new(x, targetSoilY, z) * rotCf
		local offset = soil.CFrame:ToObjectSpace(model:GetPivot())
		model:PivotTo(soilTarget * offset)

		return model
	end

	local function findTrunkPart(model)
		local trunk = model:FindFirstChild("Trunk", true)
		if trunk and trunk:IsA("BasePart") then
			return trunk
		end

		local best = nil
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				local partName: string = d.Name
				local n = string.lower(partName)
				if string.find(n, "trunk") then
					best = d
					break
				end
			end
		end
		if best then return best end

		local bbC, bbS = model:GetBoundingBox()
		local fake = Instance.new("Part")
		fake.Size = Vector3.new(math.max(2, bbS.X * 0.18), math.max(6, bbS.Y * 0.7), math.max(2, bbS.Z * 0.18))
		fake.CFrame = bbC
		return fake
	end

	local placedBushOrRockPoints = {}

	local function noteScatterAnchor(x, z)
		placedBushOrRockPoints[#placedBushOrRockPoints + 1] = { x = x, z = z }
	end

	local function spawnMiniRockAt(x, z, forceUnderWaterOk)
		local startY = cfg.decorationRayStartY

		if not allowCityOuterFeature(x, z, 4) then
			return false
		end

		if isInsideStructureBounds(x, z, 2) then
			return false
		end

		if forceUnderWaterOk then
			local topHit = raycastAt(x, z, startY)
			if not topHit or topHit.Material ~= Enum.Material.Water then
				return false
			end

			local bed = raycastBedIfWater(x, z, startY)
			if not bed then return false end

			local template = pickTemplate("MiniRocks")
			if not template then return false end

			local rot = basisFromNormal(bed.Normal, rng:NextNumber(0, math.pi * 2))
			local model = placeFromTemplate(template, x, z, bed.Position.Y, rot)
			if not model then return false end

			setChildrenNoCollision(model)
			return true
		end

		local r = raycastAt(x, z, startY)
		if not r then return false end
		if r.Material == Enum.Material.Water then
			return false
		end

		local template = pickTemplate("MiniRocks")
		if not template then return false end

		local rot = basisFromNormal(r.Normal, rng:NextNumber(0, math.pi * 2))
		local model = placeFromTemplate(template, x, z, r.Position.Y, rot)
		if not model then return false end

		setChildrenNoCollision(model)
		return true
	end

	local function scatterMiniRocksAround(x, z)
		if rng:NextNumber() > (cfg.miniRockScatterChance or 0) then
			return
		end

		local count = rng:NextInteger(cfg.miniRockScatterMin, cfg.miniRockScatterMax)
		local rad = cfg.miniRockScatterRadius

		for _ = 1, count do
			Y()
			local a = rng:NextNumber(0, math.pi * 2)
			local rr = rng:NextNumber(0, rad)
			local px = x + math.cos(a) * rr
			local pz = z + math.sin(a) * rr
			spawnMiniRockAt(px, pz, true)
		end
	end

	local function placeRocks()
		local placed2 = 0
		local target = cfg.rockCount or 0
		local attempts = target * 12

		for _ = 1, attempts do
			Y()
			if placed2 >= target then break end
			local x = rng:NextNumber(-playableRadius + 40, playableRadius - 40)
			local z = rng:NextNumber(-playableRadius + 40, playableRadius - 40)

			if not allowCityOuterFeature(x, z, 14) then
				continue
			end

			if isInsideStructureBounds(x, z, 4) then
				continue
			end

			local r = raycastAt(x, z, cfg.decorationRayStartY)
			if not r then
				continue
			end
			if r.Material == Enum.Material.Water then
				continue
			end

			local template = pickTemplate("Rocks")
			if not template then
				continue
			end

			local rot = CFrame.Angles(
				rng:NextNumber(0, math.pi * 2),
				rng:NextNumber(0, math.pi * 2),
				rng:NextNumber(0, math.pi * 2)
			)

			local model = placeFromTemplate(template, x, z, r.Position.Y, rot)
			if model then
				local buryFrac = rng:NextNumber(0.30, 0.50)
				local bbC0, bbS0 = model:GetBoundingBox()
				model:PivotTo(model:GetPivot() + Vector3.new(0, -bbS0.Y * buryFrac, 0))

				setNoCollision(model)

				local bbC, bbS = model:GetBoundingBox()
				makeCollider("RockCollider", bbC, bbS)

				placed2 += 1
				noteScatterAnchor(x, z)
				scatterMiniRocksAround(x, z)
			end
		end
	end

	local function placeBushes()
		local placed2 = 0
		local target = cfg.bushCount or 0
		local attempts = target * 10

		for _ = 1, attempts do
			Y()
			if placed2 >= target then break end
			local x = rng:NextNumber(-playableRadius + 40, playableRadius - 40)
			local z = rng:NextNumber(-playableRadius + 40, playableRadius - 40)

			if not allowCityOuterFeature(x, z, 14) then
				continue
			end

			if isInsideStructureBounds(x, z, 4) then
				continue
			end

			local r = raycastAt(x, z, cfg.decorationRayStartY)
			if r and r.Material ~= Enum.Material.Water then
				local template = pickTemplate("bushes") or pickTemplate("Bushes")
				if template then
					local rot = basisFromNormal(r.Normal, rng:NextNumber(0, math.pi * 2))
					local model = placeFromTemplate(template, x, z, r.Position.Y, rot)
					if model then
						setChildrenNoCollision(model)
						placed2 += 1
						noteScatterAnchor(x, z)
						scatterMiniRocksAround(x, z)
					end
				end
			end
		end
	end

	local function placeTrees()
		local placed2 = 0
		local target = cfg.treeCount or 0
		local attempts = target * 14

		for _ = 1, attempts do
			Y()
			if placed2 >= target then break end

			local x = rng:NextNumber(-playableRadius + 60, playableRadius - 60)
			local z = rng:NextNumber(-playableRadius + 60, playableRadius - 60)

			if not allowCityOuterFeature(x, z, 14) then
				continue
			end

			if isInsideStructureBounds(x, z, 6) then
				continue
			end

			local r = raycastAt(x, z, cfg.decorationRayStartY)
			if not r then
				continue
			end

			if r.Material == Enum.Material.Water then
				continue
			end

			if r.Material == Enum.Material.Rock then
				continue
			end

			if r.Normal.Y < (cfg.treeFlatNormalY or 0.985) then
				continue
			end

			local spacing = rng:NextNumber(cfg.treeMinSpacing, cfg.treeMaxSpacing)
			if not canPlaceTreeAt(x, z, spacing) then
				continue
			end

			local template = pickTemplate("Trees")
			if not template then
				continue
			end

			local yaw = rng:NextNumber(0, math.pi * 2)
			local rot = CFrame.Angles(0, yaw, 0)

			local model = placeTreeFromTemplate(template, x, z, r.Position.Y, rot)
			if model then
				setNoCollision(model)

				local trunk2 = findTrunkPart(model)
				if trunk2 and trunk2:IsA("BasePart") then
					makeCollider("TreeCollider", trunk2.CFrame, trunk2.Size)
				else
					local soil = findSoilPart(model)
					if soil then
						makeCollider("TreeCollider", soil.CFrame, soil.Size)
					end
				end

				treePoints[#treePoints + 1] = { x = x, z = z }
				placed2 += 1
			end
		end
	end

	local function placeMiniRocks()
		local placed2 = 0
		local target = cfg.miniRockCount or 0
		local attempts = target * 7

		for _ = 1, attempts do
			Y()
			if placed2 >= target then break end

			local x, z
			if #placedBushOrRockPoints > 0 and rng:NextNumber() < 0.65 then
				local a = placedBushOrRockPoints[rng:NextInteger(1, #placedBushOrRockPoints)]
				local ang = rng:NextNumber(0, math.pi * 2)
				local rr = rng:NextNumber(0, cfg.miniRockScatterRadius)
				x = a.x + math.cos(ang) * rr
				z = a.z + math.sin(ang) * rr
			else
				x = rng:NextNumber(-playableRadius + 40, playableRadius - 40)
				z = rng:NextNumber(-playableRadius + 40, playableRadius - 40)
			end

			if spawnMiniRockAt(x, z, true) then
				placed2 += 1
			end
		end
	end

	if cfg.decorationEnabled then
		placeRocks()
		placeTrees()
		placeBushes()
		placeMiniRocks()
	end

	local MAX_PART = 2048
	local wallT = 8
	local wallRadius = cfg.wallRadius or playableRadius
	local ext = wallRadius + (cfg.wallPad or 12)
	local wallH = math.min(cfg.topY - cfg.bottomY, MAX_PART)
	local wallCenterY = (cfg.topY + cfg.bottomY) * 0.5

	local function makeWall(name: string, pos: Vector3, size: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = true
		p.Transparency = 1
		p.Size = size
		p.Position = pos
		p.Parent = colliders
	end

	local function makeWallLine(prefix: string, axis: string, fixed: number, startPos: number, endPos: number)
		local total = endPos - startPos
		local segCount = math.max(1, math.ceil(total / MAX_PART))

		for s = 1, segCount do
			local a = startPos + (s - 1) * MAX_PART
			local b = math.min(endPos, a + MAX_PART)
			local len = b - a
			local center = (a + b) * 0.5

			if axis == "X" then
				makeWall(prefix .. "_" .. s, Vector3.new(center, wallCenterY, fixed), Vector3.new(len, wallH, wallT))
			else
				makeWall(prefix .. "_" .. s, Vector3.new(fixed, wallCenterY, center), Vector3.new(wallT, wallH, len))
			end
		end
	end

	local function buildOuterWalls()
		makeWallLine("Wall_N", "X", -ext, -ext, ext)
		makeWallLine("Wall_S", "X",  ext, -ext, ext)
		makeWallLine("Wall_W", "Z", -ext, -ext, ext)
		makeWallLine("Wall_E", "Z",  ext, -ext, ext)
	end

	buildOuterWalls()

	local function safeNeighborDelta(ix, iz)
		local h = heights[ix] and heights[ix][iz]
		if h == nil then
			return 0
		end

		local d = 0

		if ix > 1 and heights[ix - 1] and heights[ix - 1][iz] then
			d = math.max(d, math.abs(h - heights[ix - 1][iz]))
		end
		if ix < sizeCount and heights[ix + 1] and heights[ix + 1][iz] then
			d = math.max(d, math.abs(h - heights[ix + 1][iz]))
		end
		if iz > 1 and heights[ix][iz - 1] then
			d = math.max(d, math.abs(h - heights[ix][iz - 1]))
		end
		if iz < sizeCount and heights[ix][iz + 1] then
			d = math.max(d, math.abs(h - heights[ix][iz + 1]))
		end

		return d
	end

	local function buildHazardWalls()
		if not cfg.hazardWallEnabled then
			return
		end

		local folder = Instance.new("Folder")
		folder.Name = "HazardWalls"
		folder.Parent = colliders

		local cell = cfg.hazardCell
		local minCoord = -genRadius
		local span = genRadius * 2
		local gxCount = math.max(1, math.ceil(span / cell))
		local gzCount = math.max(1, math.ceil(span / cell))

		local mask = table.create(gxCount)

		for gx = 1, gxCount do
			mask[gx] = table.create(gzCount)

			local x0 = minCoord + (gx - 1) * cell
			local x1 = math.min(genRadius, x0 + cell)
			local cx = (x0 + x1) * 0.5

			for gz = 1, gzCount do
				local z0 = minCoord + (gz - 1) * cell
				local z1 = math.min(genRadius, z0 + cell)
				local cz = (z0 + z1) * 0.5

				local ix = idxFromCoord(cx)
				local iz = idxFromCoord(cz)

				local blocked = false

				if inBounds(ix, iz) then
					local river = riverMask[ix][iz] or 0
					local canyon = canyonMask[ix][iz] or 0

					local riverSurface = nil
					if riverBaseSurface and riverBaseSurface[ix] then
						riverSurface = riverBaseSurface[ix][iz]
					end

					local riverDrop = 0
					if riverSurface ~= nil then
						riverDrop = riverSurface - heights[ix][iz]
					end

					if river >= cfg.hazardRiverMask and riverDrop >= 3 then
						blocked = true
					end

					if canyon >= (cfg.hazardCanyonMask or 0.05) then
						blocked = true
					end

					if waterTopAt[ix][iz] ~= nil then
						blocked = true
					end

					if (mesaHazardMask[ix] and (mesaHazardMask[ix][iz] or 0) > 0.5) then
						blocked = true
					end
				end

				mask[gx][gz] = blocked
			end
		end

		local counter = 0

		for gz = 1, gzCount do
			local gx = 1
			while gx <= gxCount do
				if not mask[gx][gz] then
					gx += 1
				else
					local g2 = gx
					while g2 + 1 <= gxCount and mask[g2 + 1][gz] do
						g2 += 1
					end

					local x0 = minCoord + (gx - 1) * cell
					local x1 = math.min(genRadius, minCoord + g2 * cell)
					local z0 = minCoord + (gz - 1) * cell
					local z1 = math.min(genRadius, z0 + cell)

					counter += 1

					local p = Instance.new("Part")
					p.Name = "HazardWall_" .. counter
					p.Anchored = true
					p.CanCollide = true
					p.CanTouch = false
					p.CanQuery = false
					p.Transparency = 1
					p.Size = Vector3.new(x1 - x0, wallH, z1 - z0)
					p.Position = Vector3.new((x0 + x1) * 0.5, wallCenterY, (z0 + z1) * 0.5)
					p.Parent = folder

					gx = g2 + 1
				end
			end
		end
	end

	buildHazardWalls()
	local world = {
		root = root,
		seed = seed,
		mapProfile = cfg.mapProfile,
		cityMap = cfg.cityMap,
		cityReservedHalfSize = cityReservedHalfSize,
		cityReservedFullSize = cityReservedHalfSize and cityReservedHalfSize * 2 or nil,
		biome = cfg.biome,
		baseHeight = cfg.baseHeight,
		playableRadius = playableRadius,
		decoRadius = decoRadius,
		step = step,
		sizeCount = sizeCount,
		heights = heights,
		mesaMask = mesaMask,
		riverMask = riverMask,
		canyonMask = canyonMask,
		lakeCount = #lakes,
		waterTopAt = waterTopAt,
		topMatAt = topMatAt,
		placedStructureBounds = placedStructureBounds,
		borderSideTypes = {
			N = sideN,
			S = sideS,
			E = sideE,
			W = sideW,
		},
	}
	if cfg.roadPlan ~= nil then
		local roadRoot = script.Parent.Parent:WaitForChild("RoadSystem")
		local RoadPlanner = require(roadRoot:WaitForChild("RoadPlanner"))
		local RoadBuilder = require(roadRoot:WaitForChild("RoadBuilder"))
		local planned = RoadPlanner.BuildPlan(world, cfg.roadPlan)
		local blueprint = RoadBuilder.CompileBlueprint(world, planned)
		planned.blueprint = blueprint
		world.lastRoadRawPlan = cfg.roadPlan
		world.lastRoadPlanResult = planned
		RoadBuilder.Build(world, planned, blueprint)
	end

	local function collectBlockingParts()
		local list = {}
		local roots = { colliders, root:FindFirstChild("RoadSystemGenerated") }
		for _, scope in ipairs(roots) do
			if scope then
				for _, inst in ipairs(scope:GetDescendants()) do
					if inst:IsA("BasePart") and inst.CanCollide then
						list[#list + 1] = inst
					end
				end
			end
		end
		return list
	end

	local function pointInsideBlockingPart(part: BasePart, pos: Vector3, clearance: number): boolean
		local broad = math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5 + clearance
		if (part.Position - pos).Magnitude > broad then
			return false
		end
		local lp = part.CFrame:PointToObjectSpace(pos)
		return math.abs(lp.X) <= part.Size.X * 0.5 + clearance
			and math.abs(lp.Y) <= part.Size.Y * 0.5 + clearance
			and math.abs(lp.Z) <= part.Size.Z * 0.5 + clearance
	end

	local function isNearWaterForResource(ix, iz)
		local cellRadius = math.max(1, math.ceil((cfg.resourceSpawnWaterClearance or 60) / step))
		for dx = -cellRadius, cellRadius do
			for dz = -cellRadius, cellRadius do
				local nix = ix + dx
				local niz = iz + dz
				if inBounds(nix, niz) then
					local wx = coordFromIdx(nix)
					local wz = coordFromIdx(niz)
					local dist = math.sqrt((wx - coordFromIdx(ix)) ^ 2 + (wz - coordFromIdx(iz)) ^ 2)
					if dist <= (cfg.resourceSpawnWaterClearance or 60) then
						if waterTopAt[nix][niz] ~= nil or (riverMask[nix][niz] or 0) > 0.06 then
							return true
						end
					end
				end
			end
		end
		return false
	end

	local function isNearRoadForResource(x, z)
		local planned = world.lastRoadPlanResult
		if not planned then
			return false
		end
		local clearance = cfg.resourceSpawnRoadClearance or 28
		for _, run in ipairs(planned.runs or {}) do
			local points = run.points or {}
			for i = 1, #points - 1 do
				local a = points[i]
				local b = points[i + 1]
				local d = distPointToLineSegment(x, z, a.x, a.z, b.x, b.z)
				if d <= clearance then
					return true
				end
			end
		end
		return false
	end

	local function canPlaceResourceAt(x, z, blockingParts, placedPoints)
		local ix = idxFromCoord(x)
		local iz = idxFromCoord(z)
		if not inBounds(ix, iz) then
			return nil
		end
		if isInsideStructureBounds(x, z, cfg.resourceSpawnColliderClearance or 10) then
			return nil
		end
		if waterTopAt[ix][iz] ~= nil or (riverMask[ix][iz] or 0) > 0.06 or isNearWaterForResource(ix, iz) then
			return nil
		end
		if (canyonMask[ix][iz] or 0) > 0.04 then
			return nil
		end
		local mesa = mesaMask[ix][iz] or 0
		if mesa >= (cfg.resourceSpawnMesaSideMin or 0.10) and mesa < (cfg.resourceSpawnMesaTopMin or 0.96) then
			return nil
		end
		if maxNeighborDelta(ix, iz) > (cfg.resourceSpawnMaxSlope or 8) then
			return nil
		end
		if isNearRoadForResource(x, z) then
			return nil
		end
		local minSpacing = cfg.resourceSpawnMinSpacing or 70
		for _, p in ipairs(placedPoints) do
			local dx = x - p.x
			local dz = z - p.z
			if (dx * dx + dz * dz) < (minSpacing * minSpacing) then
				return nil
			end
		end

		local hit = raycastAt(x, z, cfg.resourceSpawnRayStartY or cfg.decorationRayStartY)
		if not hit or hit.Material == Enum.Material.Water then
			return nil
		end
		if hit.Normal.Y < (cfg.resourceSpawnMinNormalY or 0.93) then
			return nil
		end

		local pos = hit.Position + Vector3.new(0, 1.0, 0)
		for _, part in ipairs(blockingParts) do
			if pointInsideBlockingPart(part, pos, cfg.resourceSpawnColliderClearance or 10) then
				return nil
			end
		end
		return pos
	end

	local function placeResourceSpawns()
		if not cfg.resourceSpawnEnabled then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = cfg.resourceSpawnFolderName or "ResourceSpawns"
		folder.Parent = root
		local blockingParts = collectBlockingParts()
		local placedPoints = {}
		local target = math.max(0, cfg.resourceSpawnCount or 0)
		local attempts = math.max(target * 50, 200)
		local pad = math.max(80, cfg.resourceSpawnWaterClearance or 60)
		local resourceTypes = { "Wood", "Stone", "Ore", "Fiber", "Hide" }

		for _ = 1, attempts do
			if #placedPoints >= target then
				break
			end
			local x = rng:NextNumber(-playableRadius + pad, playableRadius - pad)
			local z = rng:NextNumber(-playableRadius + pad, playableRadius - pad)
			local pos = canPlaceResourceAt(x, z, blockingParts, placedPoints)
			if pos then
				local marker = Instance.new("Part")
				marker.Name = "ResourceSpawn_" .. tostring(#placedPoints + 1)
				marker.Anchored = true
				marker.CanCollide = false
				marker.CanTouch = false
				marker.CanQuery = false
				marker.Size = Vector3.new(8, 0.6, 8)
				marker.Position = pos
				marker.Material = Enum.Material.Neon
				marker.Color = Color3.fromRGB(255, 214, 82)
				marker.Transparency = 0.35
				marker:SetAttribute("ResourceSpawn", true)
				marker:SetAttribute("ResourceType", resourceTypes[rng:NextInteger(1, #resourceTypes)])
				marker.Parent = folder
				placedPoints[#placedPoints + 1] = { x = x, z = z }
			end
			Y()
		end
		world.resourceSpawnCount = #placedPoints
	end

	placeResourceSpawns()
	return world
end

return M