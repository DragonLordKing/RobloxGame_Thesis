--[[
Name: RoadDefaults
Class: ModuleScript
Original path: game.ReplicatedStorage.RoadSystem.Shared.RoadDefaults
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: M.DeepCopy, M.MergePlan
Clean source lines: 136
]]
local M = {}

M.DefaultPlan = {
	mapGridSize = 9,
	edgeSlotsPerSide = 4,
	exits = {},
	anchors = {},
	settings = {
		pathCellSize = 18,
		coarsePathCellSize = 36,
		finePathCellSize = 10,
		refineCorridorRadius = 132,
		roadWidth = 22,
		roadThickness = 1.4,
		roadLift = 0.25,
		roadStampThickness = 2.8,
		roadPaintThickness = 6,
		roadPaintOffset = 6,
		roadCarveDepth = 2.4,
		roadFillThickness = 3.0,
		roadFillTopOffset = 0.45,
		roadStampEmbed = 0.7,
		roadStampStep = 3,
		roadBuildPad = 1.5,
		roadBuildYieldSlice = 0.035,
		roadSurfaceCacheCell = 4,
		roadEmbedDepth = 1.95,
		roadTopExpose = -0.05,
		roadCutClearance = 3.4,
		roadShoulder = 7,
		roadSmoothPasses = 2,
		roadCurveStep = 3,
		roadBlueprintSpacing = 3,
		roadHeightSmoothPasses = 2,
		roadVoxelResolution = 4,
		roadVoxelPad = 4,
		roadFinishStep = 2.4,
		roadFinishEmbed = 1.7,
		roadFinishCenterRadiusScale = 0.46,
		roadFinishShoulderRadiusScale = 0.24,
		roadSlopeEmbedScale = 8.5,
		roadSlopeEmbedMax = 2.4,
		exitStraightLength = 140,
		outOfMapDistance = 260,
		wiggleAmplitude = 24,
		wiggleScale = 0.0045,
		wiggleFadeStart = 0.18,
		wiggleFadeEnd = 0.82,
		mesaPenalty = 1000000,
		structurePenalty = 1000000,
		riverPenalty = 55,
		canyonPenalty = 80,
		slopePenalty = 2.2,
		maxSlope = 24,
		reuseBonus = 0.7,
		bridgeDeckLift = 5,
		bridgeExtraWidth = 8,
		bridgePostGap = 16,
		portLength = 76,
		portWidth = 34,
		portDeckLift = 2.4,
		bridgeRiverThreshold = 0.08,
		bridgeCanyonThreshold = 0.03,
		bridgeApproachPenalty = 0,
		bridgeSlopePenaltyScale = 0.08,
		bridgeCostScale = 0.14,
		heuristicScale = 0.05,
		mainlandBiasRadius = 110,
		mainlandBiasStep = 18,
		mainlandBiasPenalty = 24,
		boundsBiasPenalty = 18,
		bridgeStraightSampleStep = 8,

		bridgeDeckEmbed = 1.35,
		bridgeHazardClearWidth = 24,
		bridgeSideWallThickness = 2.6,
		bridgeSideWallHeight = 6,
		bridgeSideWallOffset = 0.8,
		bridgeMinSeparation = 280,
		supplementalBridgeCellSize = 24,
		supplementalBridgeSampleStep = 8,
		supplementalBridgeHazardRatio = 0.4,
		supplementalBridgeTargetCount = 2,
		supplementalBridgeMaxCount = 0,
		supplementalBridgeEndpointSeparation = 220,
		supplementalBridgeBoundaryInset = 150,
		roadForceTopRaise = 1.0,
		maxBridgeLength = 450,
		mesaBlockThreshold = 0.08,
		tunnelRadius = 16,
		tunnelDepth = 80,
		tunnelLip = 14,
		exitDecorDistance = 170,
		terminalMaxSlope = 14,
		terminalRiverBlock = 0.18,
		terminalCanyonBlock = 0.03,
		terminalProbeDistance = 220,
		terminalProbeStep = 10,
		terminalClearDistance = 46,
		anchorSearchRadius = 96,
		anchorSearchStep = 18,
		maxPathExpansions = 0,
		pathYieldEvery = 100,
		pathYieldSeconds = 0.05,
		maxOpenNodes = 0,
	},
}

function M.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = M.DeepCopy(v)
	end
	return out
end

function M.MergePlan(plan)
	local out = M.DeepCopy(M.DefaultPlan)
	plan = plan or {}
	for k, v in pairs(plan) do
		if k ~= "settings" then
			out[k] = M.DeepCopy(v)
		end
	end
	out.settings = out.settings or {}
	for k, v in pairs((plan and plan.settings) or {}) do
		out.settings[k] = v
	end
	return out
end

return M
