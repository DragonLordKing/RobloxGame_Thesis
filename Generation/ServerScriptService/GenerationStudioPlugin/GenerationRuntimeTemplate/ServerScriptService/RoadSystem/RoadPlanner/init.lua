--[[
Name: RoadPlanner
Class: ModuleScript
Original path: game.ServerScriptService.GenerationStudioPlugin.GenerationRuntimeTemplate.ServerScriptService.RoadSystem.RoadPlanner
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage, RunService
Requires:
  - local RoadMath = require(Shared:WaitForChild("RoadMath"))
  - local RoadDefaults = require(Shared:WaitForChild("RoadDefaults"))
Functions: resolveSharedFolder, getMaxBridgeLength, makeWorldIndex, inWorldBounds, sampleWorld, computeSlope, pointInsideBounds, pointInsidePlayableArea, getCityReservedHalf, pointInsideCityReserve, cityPerimeterMargin, pushCount, shallowCopyCounts, heapLess, heapPush, heapPop, appendUniquePoint, makeLinePoints, isMesaBlocked, isBridgeLikeSample, isBlockedWaterSample, isBridgeApproach, edgeSlotFractions, edgeExitToWorld, anchorToWorld, terminalSettings, terminalPointReason, corridorReason, resolveEdgeTerminal, resolveAnchorTerminal, addCandidate, buildTerminalList, buildPrimEdges, nearestNodeIndex, buildAnchorSpineEdges, addEdge, getCoarseCellSize, getFineCellSize, makeRoadGrid, roadGridToWorld, worldToRoadGrid, inRoadGrid, isRoadGridCellAllowed, buildPathCorridorField, buildReuseField, makeNodeAnalyzer, analyze, nodeCost, makeBridgeSpanChecker, measureFrom, reconstructPath, astarOnGrid, bridgeBucket, makeStateKey, rememberState, mergeCountsInto, combineAstarDebug, astar, tagFallbackPath, makeFallbackPath
Clean source lines: 2284
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function resolveSharedFolder()
	local localShared = script.Parent:FindFirstChild("Shared")
	if localShared then
		return localShared
	end
	return ReplicatedStorage:WaitForChild("RoadSystem"):WaitForChild("Shared")
end

local Shared = resolveSharedFolder()
local RoadMath = require(Shared:WaitForChild("RoadMath"))
local RoadDefaults = require(Shared:WaitForChild("RoadDefaults"))

local M = {}

local MAX_BRIDGE_LENGTH_CAP = 450

local function getMaxBridgeLength(settings)
	local requested = tonumber(settings and settings.maxBridgeLength) or MAX_BRIDGE_LENGTH_CAP
	return math.max(1, math.min(requested, MAX_BRIDGE_LENGTH_CAP))
end

local function makeWorldIndex(world, x, z)
	local step = world.step
	local genRadius = world.decoRadius
	local ix = math.floor((x + genRadius) / step) + 1
	local iz = math.floor((z + genRadius) / step) + 1
	return ix, iz
end

local function inWorldBounds(world, ix, iz)
	return ix >= 1 and ix <= world.sizeCount and iz >= 1 and iz <= world.sizeCount
end

local function sampleWorld(world, x, z)
	local ix, iz = makeWorldIndex(world, x, z)
	if not inWorldBounds(world, ix, iz) then
		return nil
	end
	return {
		ix = ix,
		iz = iz,
		height = world.heights[ix][iz],
		mesa = (world.mesaMask and world.mesaMask[ix] and world.mesaMask[ix][iz]) or 0,
		river = (world.riverMask and world.riverMask[ix] and world.riverMask[ix][iz]) or 0,
		canyon = (world.canyonMask and world.canyonMask[ix] and world.canyonMask[ix][iz]) or 0,
		water = world.waterTopAt and world.waterTopAt[ix] and world.waterTopAt[ix][iz] ~= nil,
		topMat = (world.topMatAt and world.topMatAt[ix] and world.topMatAt[ix][iz]) or nil,
	}
end

local function computeSlope(world, x, z, cellSize)
	local c = sampleWorld(world, x, z)
	if not c then
		return math.huge
	end
	local r = sampleWorld(world, x + cellSize, z)
	local l = sampleWorld(world, x - cellSize, z)
	local u = sampleWorld(world, x, z + cellSize)
	local d = sampleWorld(world, x, z - cellSize)
	local maxDelta = 0
	local h = c.height
	if r then maxDelta = math.max(maxDelta, math.abs(h - r.height)) end
	if l then maxDelta = math.max(maxDelta, math.abs(h - l.height)) end
	if u then maxDelta = math.max(maxDelta, math.abs(h - u.height)) end
	if d then maxDelta = math.max(maxDelta, math.abs(h - d.height)) end
	return maxDelta
end

local function pointInsideBounds(x, z, bounds, pad)
	pad = pad or 0
	for i = 1, #bounds do
		local b = bounds[i]
		if x >= (b.minX - pad) and x <= (b.maxX + pad) and z >= (b.minZ - pad) and z <= (b.maxZ + pad) then
			return true
		end
	end
	return false
end

local function pointInsidePlayableArea(world, x, z, pad)
	pad = pad or 0
	local r = world.playableRadius - pad
	return x >= -r and x <= r and z >= -r and z <= r
end

local function getCityReservedHalf(world)
	local half = tonumber(world.cityReservedHalfSize)
	if half and half > 0 then
		return half
	end
	for _, b in ipairs(world.placedStructureBounds or {}) do
		if b.kind == "CityReservedZone" then
			local maxAbs = math.max(
				math.abs(b.minX or 0),
				math.abs(b.maxX or 0),
				math.abs(b.minZ or 0),
				math.abs(b.maxZ or 0)
			)
			if maxAbs > 0 then
				return maxAbs
			end
		end
	end
	return nil
end

local function pointInsideCityReserve(world, x, z, pad)
	local half = getCityReservedHalf(world)
	if not half then
		return false
	end
	pad = pad or 0
	return x >= -half - pad and x <= half + pad and z >= -half - pad and z <= half + pad
end

local function cityPerimeterMargin(plan)
	return math.max(plan.settings.roadWidth or 22, 22) * 0.85 + 38
end

local function pushCount(bucket, key)
	bucket[key] = (bucket[key] or 0) + 1
end

local function shallowCopyCounts(source)
	local out = {}
	for k, v in pairs(source or {}) do
		out[k] = v
	end
	return out
end

local function heapLess(a, b)
	if a.f == b.f then
		return (a.h or 0) < (b.h or 0)
	end
	return a.f < b.f
end

local function heapPush(heap, item)
	heap[#heap + 1] = item
	local i = #heap
	while i > 1 do
		local parent = math.floor(i * 0.5)
		if not heapLess(heap[i], heap[parent]) then
			break
		end
		heap[i], heap[parent] = heap[parent], heap[i]
		i = parent
	end
end

local function heapPop(heap)
	local root = heap[1]
	local last = table.remove(heap)
	if #heap > 0 then
		heap[1] = last
		local i = 1
		while true do
			local left = i * 2
			local right = left + 1
			local best = i
			if left <= #heap and heapLess(heap[left], heap[best]) then
				best = left
			end
			if right <= #heap and heapLess(heap[right], heap[best]) then
				best = right
			end
			if best == i then
				break
			end
			heap[i], heap[best] = heap[best], heap[i]
			i = best
		end
	end
	return root
end

local function appendUniquePoint(points, p)
	local last = points[#points]
	if last and RoadMath.Distance2(last.x, last.z, p.x, p.z) <= 0.05 then
		return
	end
	points[#points + 1] = { x = p.x, z = p.z }
end

local function makeLinePoints(a, b, spacing)
	local dist = RoadMath.Distance2(a.x, a.z, b.x, b.z)
	local count = math.max(1, math.ceil(dist / math.max(1, spacing)))
	local out = {}
	for i = 0, count do
		local t = i / count
		out[#out + 1] = {
			x = RoadMath.Lerp(a.x, b.x, t),
			z = RoadMath.Lerp(a.z, b.z, t),
		}
	end
	return out
end

local function isMesaBlocked(sample, settings)
	if not sample then
		return false
	end
	return sample.mesa >= (settings.mesaBlockThreshold or 0.08)
end

local function isBridgeLikeSample(sample, settings)
	if not sample or isMesaBlocked(sample, settings) then
		return false
	end
	return sample.river >= (settings.bridgeRiverThreshold or 0.08) or sample.canyon >= (settings.bridgeCanyonThreshold or 0.03)
end

local function isBlockedWaterSample(sample, settings)
	if not sample then
		return false
	end
	return sample.water and sample.river < (settings.bridgeRiverThreshold or 0.08)
end

local function isBridgeApproach(world, x, z, probe, settings)
	local center = sampleWorld(world, x, z)
	if isBridgeLikeSample(center, settings) then
		return true
	end
	for _, dx in ipairs({ -probe, 0, probe }) do
		for _, dz in ipairs({ -probe, 0, probe }) do
			if dx ~= 0 or dz ~= 0 then
				if isBridgeLikeSample(sampleWorld(world, x + dx, z + dz), settings) then
					return true
				end
			end
		end
	end
	return false
end

local function edgeSlotFractions(slot, slotCount)
	return (slot - 0.5) / math.max(1, slotCount)
end

local function edgeExitToWorld(world, plan, exitDef)
	local p = edgeSlotFractions(exitDef.slot, plan.edgeSlotsPerSide)
	local r = world.playableRadius
	local d = world.decoRadius + plan.settings.outOfMapDistance
	if exitDef.side == "N" then
		local x = RoadMath.Lerp(-r, r, p)
		return {
			inner = { x = x, z = -r },
			outer = { x = x, z = -d },
			dir = { x = 0, z = -1 },
		}
	elseif exitDef.side == "S" then
		local x = RoadMath.Lerp(-r, r, p)
		return {
			inner = { x = x, z = r },
			outer = { x = x, z = d },
			dir = { x = 0, z = 1 },
		}
	elseif exitDef.side == "E" then
		local z = RoadMath.Lerp(-r, r, p)
		return {
			inner = { x = r, z = z },
			outer = { x = d, z = z },
			dir = { x = 1, z = 0 },
		}
	end
	local z = RoadMath.Lerp(-r, r, p)
	return {
		inner = { x = -r, z = z },
		outer = { x = -d, z = z },
		dir = { x = -1, z = 0 },
	}
end

local function anchorToWorld(world, plan, anchor)
	local n = plan.mapGridSize
	local tX = (anchor.gx - 1) / math.max(1, n - 1)
	local tZ = (anchor.gz - 1) / math.max(1, n - 1)
	return {
		x = RoadMath.Lerp(-world.playableRadius, world.playableRadius, tX),
		z = RoadMath.Lerp(-world.playableRadius, world.playableRadius, tZ),
	}
end

local function terminalSettings(plan)
	local settings = plan.settings
	return {
		maxSlope = math.min(settings.maxSlope or 24, settings.terminalMaxSlope or 14),
		riverBlock = settings.terminalRiverBlock or 0.18,
		canyonBlock = settings.terminalCanyonBlock or 0.03,
		probeDistance = settings.terminalProbeDistance or 220,
		probeStep = math.max(4, settings.terminalProbeStep or 10),
		clearDistance = settings.terminalClearDistance or 46,
		anchorSearchRadius = settings.anchorSearchRadius or 96,
		anchorSearchStep = math.max(6, settings.anchorSearchStep or 18),
	}
end

local function terminalPointReason(world, plan, x, z)
	local settings = plan.settings
	local sample = sampleWorld(world, x, z)
	if not sample then
		return false, "out"
	end
	if pointInsideBounds(x, z, world.placedStructureBounds or {}, settings.roadWidth * 0.65) then
		return false, "structure"
	end
	if isMesaBlocked(sample, settings) then
		return false, "mesa"
	end
	local ts = terminalSettings(plan)
	if sample.water then
		return false, "water"
	end
	if sample.river >= ts.riverBlock then
		return false, "river"
	end
	if sample.canyon >= ts.canyonBlock then
		return false, "canyon"
	end
	local fineCellSize = math.max(8, math.min(14, math.floor(((plan.settings.finePathCellSize or (plan.settings.roadWidth * 0.45)) + 0.5))))
	local slope = computeSlope(world, x, z, math.max(4, fineCellSize * 0.75))
	if slope > ts.maxSlope then
		return false, "slope"
	end
	return true, nil
end

local function corridorReason(world, plan, x, z, dirX, dirZ)
	local ts = terminalSettings(plan)
	local px, pz = RoadMath.Perp2(dirX, dirZ)
	local half = math.max(plan.settings.roadWidth * 0.34, 6)
	local offsets = { 0, half, -half }
	for dist = 0, ts.clearDistance, ts.probeStep do
		local cx = x + dirX * dist
		local cz = z + dirZ * dist
		for _, lateral in ipairs(offsets) do
			local ok, reason = terminalPointReason(world, plan, cx + px * lateral, cz + pz * lateral)
			if not ok then
				return false, reason
			end
		end
	end
	return true, nil
end

local function resolveEdgeTerminal(world, plan, worldExit)
	local ts = terminalSettings(plan)
	local inwardX = -worldExit.dir.x
	local inwardZ = -worldExit.dir.z
	local debugInfo = {
		attempts = 0,
		reasonCounts = {},
		status = "failed",
	}
	for dist = 0, ts.probeDistance, ts.probeStep do
		debugInfo.attempts += 1
		local x = worldExit.inner.x + inwardX * dist
		local z = worldExit.inner.z + inwardZ * dist
		local okPoint, pointReason = terminalPointReason(world, plan, x, z)
		if okPoint then
			local okCorridor, corridorFailReason = corridorReason(world, plan, x, z, inwardX, inwardZ)
			if okCorridor then
				debugInfo.status = "ok"
				debugInfo.resolvedOffset = dist
				return {
					usable = true,
					x = x,
					z = z,
					outer = worldExit.outer,
					dir = worldExit.dir,
					entry = { x = worldExit.inner.x, z = worldExit.inner.z },
					resolvedOffset = dist,
				}, debugInfo
			end
			pushCount(debugInfo.reasonCounts, "corridor_" .. tostring(corridorFailReason or "blocked"))
		else
			pushCount(debugInfo.reasonCounts, pointReason or "blocked")
		end
	end
	return nil, debugInfo
end

local function resolveAnchorTerminal(world, plan, anchor, anchorPos)
	local ts = terminalSettings(plan)
	local debugInfo = {
		attempts = 0,
		reasonCounts = {},
		status = "failed",
	}
	local cityHalf = getCityReservedHalf(world)
	local searchRadius = ts.anchorSearchRadius
	if cityHalf and pointInsideCityReserve(world, anchorPos.x, anchorPos.z, 0) then
		local edge = cityHalf + cityPerimeterMargin(plan)
		searchRadius = math.max(searchRadius, edge + ts.anchorSearchStep)
		debugInfo.cityEdge = true
		local clampedX = RoadMath.Clamp(anchorPos.x, -edge, edge)
		local clampedZ = RoadMath.Clamp(anchorPos.z, -edge, edge)
		local candidates = {}
		local function addCandidate(x, z)
			candidates[#candidates + 1] = { x = x, z = z }
		end
		if math.abs(anchorPos.x) >= math.abs(anchorPos.z) then
			addCandidate(anchorPos.x >= 0 and edge or -edge, clampedZ)
		else
			addCandidate(clampedX, anchorPos.z >= 0 and edge or -edge)
		end
		addCandidate(clampedX, -edge)
		addCandidate(edge, clampedZ)
		addCandidate(clampedX, edge)
		addCandidate(-edge, clampedZ)
		for _, p in ipairs(candidates) do
			debugInfo.attempts += 1
			local okPoint, pointReason = terminalPointReason(world, plan, p.x, p.z)
			if okPoint then
				debugInfo.status = "ok"
				debugInfo.resolvedToCityEdge = true
				return {
					usable = true,
					kind = "anchor",
					gx = anchor.gx,
					gz = anchor.gz,
					x = p.x,
					z = p.z,
					requested = anchorPos,
					cityEdge = true,
				}, debugInfo
			end
			pushCount(debugInfo.reasonCounts, pointReason or "blocked")
		end
	end
	for radius = 0, searchRadius, ts.anchorSearchStep do
		local ring = math.max(1, math.floor((radius / ts.anchorSearchStep) * 8))
		for i = 1, ring do
			debugInfo.attempts += 1
			local angle = (i - 1) / ring * math.pi * 2
			local x = anchorPos.x + math.cos(angle) * radius
			local z = anchorPos.z + math.sin(angle) * radius
			local okPoint, pointReason = terminalPointReason(world, plan, x, z)
			if okPoint then
				debugInfo.status = "ok"
				return {
					usable = true,
					kind = "anchor",
					gx = anchor.gx,
					gz = anchor.gz,
					x = x,
					z = z,
					requested = anchorPos,
				}, debugInfo
			end
			pushCount(debugInfo.reasonCounts, pointReason or "blocked")
		end
	end
	return nil, debugInfo
end

local function buildTerminalList(world, plan)
	local roadTerminals = {}
	local tunnelTerminals = {}
	local blockedSelections = {
		edges = {},
		anchors = {},
	}
	local terminalDebug = {
		edges = {},
		anchors = {},
	}
	for _, exitDef in ipairs(plan.exits) do
		local worldExit = edgeExitToWorld(world, plan, exitDef)
		local resolved, debugInfo = resolveEdgeTerminal(world, plan, worldExit)
		local key = exitDef.side .. ":" .. tostring(exitDef.slot)
		terminalDebug.edges[key] = debugInfo
		if resolved and resolved.usable then
			if exitDef.mode == "road" then
				roadTerminals[#roadTerminals + 1] = {
					kind = "exit",
					side = exitDef.side,
					slot = exitDef.slot,
					x = resolved.x,
					z = resolved.z,
					outer = resolved.outer,
					dir = resolved.dir,
					entry = resolved.entry,
					resolvedOffset = resolved.resolvedOffset,
				}
			elseif exitDef.mode == "tunnel" then
				tunnelTerminals[#tunnelTerminals + 1] = {
					kind = "tunnel",
					side = exitDef.side,
					slot = exitDef.slot,
					x = resolved.x,
					z = resolved.z,
					outer = resolved.outer,
					dir = resolved.dir,
					entry = resolved.entry,
					resolvedOffset = resolved.resolvedOffset,
				}
			end
		else
			blockedSelections.edges[key] = true
		end
	end
	for _, anchor in ipairs(plan.anchors) do
		local p = anchorToWorld(world, plan, anchor)
		local resolved, debugInfo = resolveAnchorTerminal(world, plan, anchor, p)
		local key = tostring(anchor.gx) .. ":" .. tostring(anchor.gz)
		terminalDebug.anchors[key] = debugInfo
		if resolved and resolved.usable then
			roadTerminals[#roadTerminals + 1] = resolved
		else
			blockedSelections.anchors[key] = true
		end
	end
	return roadTerminals, tunnelTerminals, blockedSelections, terminalDebug
end

local function buildPrimEdges(nodes)
	if #nodes <= 1 then
		return {}
	end
	local used = { [1] = true }
	local edges = {}
	while #edges < #nodes - 1 do
		local bestA = nil
		local bestB = nil
		local bestD = math.huge
		for a = 1, #nodes do
			if used[a] then
				for b = 1, #nodes do
					if not used[b] then
						local da = nodes[a]
						local db = nodes[b]
						local d = RoadMath.Distance2(da.x, da.z, db.x, db.z)
						if d < bestD then
							bestD = d
							bestA = a
							bestB = b
						end
					end
				end
			end
		end
		if not bestA or not bestB then
			break
		end
		used[bestB] = true
		edges[#edges + 1] = { a = bestA, b = bestB }
	end
	return edges
end

local function nearestNodeIndex(nodes, point)
	local bestIndex = nil
	local bestDist = math.huge
	for i, node in ipairs(nodes) do
		local d = RoadMath.Distance2(node.x, node.z, point.x, point.z)
		if d < bestDist then
			bestDist = d
			bestIndex = i
		end
	end
	return bestIndex
end

local function buildAnchorSpineEdges(roadTerminals)
	local anchors = {}
	local exits = {}
	for _, terminal in ipairs(roadTerminals) do
		if terminal.kind == "anchor" then
			anchors[#anchors + 1] = terminal
		else
			exits[#exits + 1] = terminal
		end
	end

	if #anchors == 0 then
		local edges = {}
		for _, edge in ipairs(buildPrimEdges(roadTerminals)) do
			edges[#edges + 1] = {
				from = roadTerminals[edge.a],
				to = roadTerminals[edge.b],
				kind = "mst",
			}
		end
		return edges
	end

	local edges = {}
	local usedKeys = {}
	local function addEdge(a, b, kind)
		if not a or not b then
			return
		end
		if RoadMath.Distance2(a.x, a.z, b.x, b.z) < 1 then
			return
		end
		local keyA = tostring(a.kind) .. ":" .. tostring(a.side or a.gx) .. ":" .. tostring(a.slot or a.gz)
		local keyB = tostring(b.kind) .. ":" .. tostring(b.side or b.gx) .. ":" .. tostring(b.slot or b.gz)
		local key = keyA < keyB and (keyA .. "|" .. keyB) or (keyB .. "|" .. keyA)
		if usedKeys[key] then
			return
		end
		usedKeys[key] = true
		edges[#edges + 1] = { from = a, to = b, kind = kind }
	end

	for _, edge in ipairs(buildPrimEdges(anchors)) do
		addEdge(anchors[edge.a], anchors[edge.b], "anchor_spine")
	end

	for _, exit in ipairs(exits) do
		local anchorIndex = nearestNodeIndex(anchors, exit)
		addEdge(exit, anchors[anchorIndex], "exit_to_anchor")
	end

	return edges
end

local function getCoarseCellSize(settings)
	local explicit = settings.coarsePathCellSize or settings.pathCellSize
	local derived = math.max(settings.roadWidth * 1.35, explicit or 18)
	return math.max(12, math.floor(derived + 0.5))
end

local function getFineCellSize(settings)
	local explicit = settings.finePathCellSize
	local derived = settings.roadWidth * 0.45
	local cell = explicit or derived
	return math.max(8, math.min(14, math.floor(cell + 0.5)))
end

local function makeRoadGrid(world, cellSize)
	local r = world.playableRadius
	local size = math.floor((r * 2) / cellSize) + 1
	return {
		radius = r,
		cellSize = cellSize,
		size = size,
		allowedCells = nil,
	}
end

local function roadGridToWorld(grid, ix, iz)
	local x = (ix - 1) * grid.cellSize - grid.radius
	local z = (iz - 1) * grid.cellSize - grid.radius
	return x, z
end

local function worldToRoadGrid(grid, x, z)
	local ix = math.floor((x + grid.radius) / grid.cellSize) + 1
	local iz = math.floor((z + grid.radius) / grid.cellSize) + 1
	return ix, iz
end

local function inRoadGrid(grid, ix, iz)
	return ix >= 1 and ix <= grid.size and iz >= 1 and iz <= grid.size
end

local function isRoadGridCellAllowed(grid, ix, iz)
	if not inRoadGrid(grid, ix, iz) then
		return false
	end
	if not grid.allowedCells then
		return true
	end
	return grid.allowedCells[RoadMath.HashKey(ix, iz)] == true
end

local function buildPathCorridorField(points, grid, radius)
	if not points or #points == 0 then
		return nil
	end
	local allowed = {}
	local spacing = math.max(6, grid.cellSize * 0.6)
	local sampled = RoadMath.ResamplePolyline(points, spacing)
	local cellRadius = math.max(1, math.ceil(radius / grid.cellSize))
	for _, p in ipairs(sampled) do
		local ix, iz = worldToRoadGrid(grid, p.x, p.z)
		for dx = -cellRadius, cellRadius do
			for dz = -cellRadius, cellRadius do
				local nix = ix + dx
				local niz = iz + dz
				if inRoadGrid(grid, nix, niz) then
					local wx, wz = roadGridToWorld(grid, nix, niz)
					if RoadMath.Distance2(wx, wz, p.x, p.z) <= (radius + grid.cellSize * 0.8) then
						allowed[RoadMath.HashKey(nix, niz)] = true
					end
				end
			end
		end
	end
	return allowed
end

local function buildReuseField(points, grid, field)
	for _, p in ipairs(points) do
		local ix, iz = worldToRoadGrid(grid, p.x, p.z)
		if inRoadGrid(grid, ix, iz) then
			field[RoadMath.HashKey(ix, iz)] = true
		end
	end
end

local function makeNodeAnalyzer(world, plan, grid)
	local settings = plan.settings
	local cache = {}
	local bounds = world.placedStructureBounds or {}
	local structurePad = settings.roadWidth * 0.6
	local probe = math.max(6, grid.cellSize)

	local function analyze(ix, iz)
		local key = RoadMath.HashKey(ix, iz)
		local cached = cache[key]
		if cached then
			return cached
		end

		local x, z = roadGridToWorld(grid, ix, iz)
		local sample = sampleWorld(world, x, z)
		if not sample then
			cached = {
				x = x,
				z = z,
				sample = nil,
				slope = math.huge,
				bridgeApproach = false,
				blocked = true,
				blockedReason = "out",
				baseCost = math.huge,
			}
			cache[key] = cached
			return cached
		end

		if not pointInsidePlayableArea(world, x, z, math.max(0, grid.cellSize * 0.35)) then
			cached = {
				x = x,
				z = z,
				sample = sample,
				slope = math.huge,
				bridgeApproach = false,
				blocked = true,
				blockedReason = "playable_bounds",
				baseCost = math.huge,
			}
			cache[key] = cached
			return cached
		end

		local h = sample.height
		local maxDelta = 0
		for _, off in ipairs({ { grid.cellSize, 0 }, { -grid.cellSize, 0 }, { 0, grid.cellSize }, { 0, -grid.cellSize } }) do
			local n = sampleWorld(world, x + off[1], z + off[2])
			if n then
				maxDelta = math.max(maxDelta, math.abs(h - n.height))
			end
		end

		local bridgeApproach = isBridgeLikeSample(sample, settings)

		local blocked = false
		local blockedReason = nil
		local cost = 1
		local mainlandPenalty = 0
		if pointInsideBounds(x, z, bounds, structurePad) then
			blocked = true
			blockedReason = "structure"
			cost = math.huge
			elseif isMesaBlocked(sample, settings) then
			blocked = true
			blockedReason = "mesa"
			cost = math.huge
		elseif isBlockedWaterSample(sample, settings) then
			blocked = true
			blockedReason = "water"
			cost = math.huge
		elseif maxDelta > settings.maxSlope and not bridgeApproach then
			blocked = true
			blockedReason = "slope"
			cost = math.huge
		else
			cost = 1 + maxDelta * settings.slopePenalty + sample.river * settings.riverPenalty + sample.canyon * settings.canyonPenalty
			if bridgeApproach then
				local bridgeSlope = maxDelta * (settings.bridgeSlopePenaltyScale or 0.08)
				local bridgeSurface = 0.65 + sample.river * 0.45 + sample.canyon * 0.55
				cost = math.max(0.08, (bridgeSurface + bridgeSlope + (settings.bridgeApproachPenalty or 0)) * (settings.bridgeCostScale or 0.14))
			elseif sample.water and sample.river < 0.1 then
				cost += settings.riverPenalty * 2
			else
				local biasRadius = math.max(grid.cellSize * 2, settings.mainlandBiasRadius or (settings.roadWidth * 5))
				local biasStep = math.max(grid.cellSize, settings.mainlandBiasStep or 18)
				local closestHazard = biasRadius + biasStep
				for dx = -biasRadius, biasRadius, biasStep do
					for dz = -biasRadius, biasRadius, biasStep do
						local dist = math.sqrt(dx * dx + dz * dz)
						if dist > 1 and dist <= biasRadius then
							local nearby = sampleWorld(world, x + dx, z + dz)
							local hazard = false
							if not nearby then
								hazard = true
							elseif isMesaBlocked(nearby, settings) then
								hazard = true
							elseif nearby.canyon >= ((settings.bridgeCanyonThreshold or 0.03) * 0.7) then
								hazard = true
							elseif nearby.river >= ((settings.bridgeRiverThreshold or 0.08) * 0.7) or nearby.water then
								hazard = true
							elseif math.abs(h - nearby.height) > math.max(settings.maxSlope * 0.7, 10) then
								hazard = true
							end
							if hazard and dist < closestHazard then
								closestHazard = dist
							end
						end
					end
				end
				local boundsClear = math.min(world.playableRadius - math.abs(x), world.playableRadius - math.abs(z))
				if boundsClear < biasRadius then
					local t = 1 - math.max(0, boundsClear) / biasRadius
					mainlandPenalty += t * t * (settings.boundsBiasPenalty or 18)
				end
				if closestHazard < (biasRadius + biasStep) then
					local t = 1 - (closestHazard / biasRadius)
					mainlandPenalty += t * t * (settings.mainlandBiasPenalty or 24)
				end
				cost += mainlandPenalty
			end
		end

		cached = {
			x = x,
			z = z,
			sample = sample,
			slope = maxDelta,
			bridgeApproach = bridgeApproach,
			blocked = blocked,
			blockedReason = blockedReason,
			mainlandPenalty = mainlandPenalty,
			baseCost = cost,
		}
		cache[key] = cached
		return cached
	end

	return analyze
end

local function nodeCost(world, plan, settings, grid, ix, iz, reuseField, analyzeNode)
	local node = analyzeNode(ix, iz)
	if node.blocked then
		return math.huge
	end
	local cost = node.baseCost
	if reuseField[RoadMath.HashKey(ix, iz)] then
		cost = math.max(0.2, cost - settings.reuseBonus)
	end
	return cost
end

local function makeBridgeSpanChecker(world, settings, grid)
	local cache = {}
	local probeStep = math.max(4, grid.cellSize * 0.5)
	local maxBridgeLength = getMaxBridgeLength(settings)

	local function measureFrom(x, z, dirX, dirZ, sign)
		local dist = 0
		while dist <= maxBridgeLength do
			dist += probeStep
			local sample = sampleWorld(world, x + dirX * dist * sign, z + dirZ * dist * sign)
			if not sample then
				return maxBridgeLength + probeStep
			end
			if not isBridgeLikeSample(sample, settings) then
				return dist
			end
		end
		return maxBridgeLength + probeStep
	end

	return function(aNode, bNode)
		if not aNode.sample or not bNode.sample then
			return false, { reason = "missing_sample" }
		end
		if isMesaBlocked(aNode.sample, settings) or isMesaBlocked(bNode.sample, settings) then
			return false, { reason = "mesa_endpoint" }
		end

		local aBridge = isBridgeLikeSample(aNode.sample, settings)
		local bBridge = isBridgeLikeSample(bNode.sample, settings)
		if not aBridge and not bBridge then
			return true, { reason = "not_bridge" }
		end

		local dirX, dirZ = RoadMath.Normalize2(bNode.x - aNode.x, bNode.z - aNode.z)
		if dirX == 0 and dirZ == 0 then
			return false, { reason = "zero_dir" }
		end

		local centerX, centerZ
		if aBridge and bBridge then
			centerX = (aNode.x + bNode.x) * 0.5
			centerZ = (aNode.z + bNode.z) * 0.5
		elseif aBridge then
			centerX = aNode.x
			centerZ = aNode.z
		else
			centerX = bNode.x
			centerZ = bNode.z
		end

		local key = table.concat({
			math.floor(centerX * 10 + 0.5),
			math.floor(centerZ * 10 + 0.5),
			math.floor(dirX * 100 + 0.5),
			math.floor(dirZ * 100 + 0.5),
		}, ":")
		local cached = cache[key]
		if cached ~= nil then
			return cached.ok, cached
		end

		local span = measureFrom(centerX, centerZ, dirX, dirZ, 1) + measureFrom(centerX, centerZ, dirX, dirZ, -1)
		local ok = span <= (maxBridgeLength + probeStep)
		local info = {
			ok = ok,
			reason = ok and "ok" or "bridge_too_long",
			span = span,
			limit = maxBridgeLength,
			probeStep = probeStep,
		}
		cache[key] = info
		return ok, info
	end
end

local function reconstructPath(cameFrom, endKey)
	local rev = {}
	local key = endKey
	while key do
		local node = cameFrom[key]
		if not node then
			break
		end
		rev[#rev + 1] = { ix = node.ix, iz = node.iz }
		key = node.prev
		if key == "" then
			break
		end
	end
	local out = {}
	for i = #rev, 1, -1 do
		out[#out + 1] = rev[i]
	end
	return out
end

local function astarOnGrid(world, plan, grid, startPos, endPos, reuseField)
	local settings = plan.settings
	local sx, sz = worldToRoadGrid(grid, startPos.x, startPos.z)
	local ex, ez = worldToRoadGrid(grid, endPos.x, endPos.z)
	local gridCellBudget = math.max(1, grid.size * grid.size)
	local requestedMaxExpansions = settings.maxPathExpansions or 0
	local requestedMaxOpenNodes = settings.maxOpenNodes or 0
	local debug = {
		status = "init",
		expansions = 0,
		maxExpansions = requestedMaxExpansions > 0 and requestedMaxExpansions or math.huge,
		maxOpenNodes = requestedMaxOpenNodes > 0 and requestedMaxOpenNodes or math.huge,
		openPeak = 0,
		closedCount = 0,
		blocked = {},
		bridgeRejects = {},
		start = { ix = sx, iz = sz },
		goal = { ix = ex, iz = ez },
	}
	if not isRoadGridCellAllowed(grid, sx, sz) or not isRoadGridCellAllowed(grid, ex, ez) then
		debug.status = "terminals_out_of_grid"
		return nil, debug
	end

	local analyzeNode = makeNodeAnalyzer(world, plan, grid)
	local canTraverseBridge = makeBridgeSpanChecker(world, settings, grid)
	local maxBridgeLength = getMaxBridgeLength(settings)
	local bridgeStateBucket = math.max(2, grid.cellSize * 0.5)
	local function bridgeBucket(bridgeLength)
		return math.floor((bridgeLength or 0) / bridgeStateBucket)
	end
	local function makeStateKey(ix, iz, bridgeLength)
		return RoadMath.HashKey(ix, iz) .. ":" .. tostring(bridgeBucket(bridgeLength))
	end
	local bestBucketsByCell = {}
	local function rememberState(baseKey, bucket, cost)
		local buckets = bestBucketsByCell[baseKey]
		if not buckets then
			buckets = {}
			bestBucketsByCell[baseKey] = buckets
		else
			for existingBucket, bestCost in pairs(buckets) do
				if existingBucket <= bucket and bestCost <= cost then
					return false
				end
			end
		end
		for existingBucket, bestCost in pairs(buckets) do
			if existingBucket >= bucket and bestCost >= cost then
				buckets[existingBucket] = nil
			end
		end
		buckets[bucket] = cost
		return true
	end
	debug.bridgeStateBucket = bridgeStateBucket
	local maxExpansions = debug.maxExpansions
	local yieldEvery = math.max(1, settings.pathYieldEvery or 180)
	local yieldSeconds = math.max(0.02, settings.pathYieldSeconds or 0.05)
	local lastYieldAt = os.clock()
	local maxOpenNodes = debug.maxOpenNodes
	local heuristicScale = math.max(0, settings.heuristicScale or 0.05)

	local open = {}
	local closed = {}
	local gScore = {}
	local cameFrom = {}
	local startKey = makeStateKey(sx, sz, 0)
	local startBaseKey = RoadMath.HashKey(sx, sz)
	heapPush(open, { ix = sx, iz = sz, f = 0, h = 0, g = 0, stateKey = startKey, bridgeLength = 0 })
	gScore[startKey] = 0
	rememberState(startBaseKey, 0, 0)
	cameFrom[startKey] = { ix = sx, iz = sz, prev = "" }
	local offsets = {
		{ 1, 0 },
		{ -1, 0 },
		{ 0, 1 },
		{ 0, -1 },
		{ 1, 1 },
		{ 1, -1 },
		{ -1, 1 },
		{ -1, -1 },
	}
	local expansions = 0
	while #open > 0 do
		debug.openPeak = math.max(debug.openPeak, #open)
		if #open > maxOpenNodes then
			debug.status = "max_open_nodes"
			return nil, debug
		end
		if expansions > 0 and (expansions % yieldEvery == 0 or os.clock() - lastYieldAt >= yieldSeconds) then
			RunService.Heartbeat:Wait()
			lastYieldAt = os.clock()
		end

		local current = heapPop(open)
		if not current then
			break
		end
		local currentKey = current.stateKey or makeStateKey(current.ix, current.iz, current.bridgeLength or 0)
		if closed[currentKey] or current.g ~= gScore[currentKey] then
			continue
		end
		closed[currentKey] = true
		expansions += 1
		debug.expansions = expansions
		debug.closedCount = debug.closedCount + 1
		if expansions > maxExpansions then
			debug.status = "max_expansions"
			return nil, debug
		end
		if current.ix == ex and current.iz == ez then
			local pathNodes = reconstructPath(cameFrom, currentKey)
			local points = {}
			for _, node in ipairs(pathNodes) do
				local analyzed = analyzeNode(node.ix, node.iz)
				points[#points + 1] = { x = analyzed.x, z = analyzed.z }
			end
			debug.status = "ok"
			debug.pathNodes = #points
			return points, debug
		end
		local currentNode = analyzeNode(current.ix, current.iz)
		for _, off in ipairs(offsets) do
			local nix = current.ix + off[1]
			local niz = current.iz + off[2]
			if inRoadGrid(grid, nix, niz) then
				local nextNode = analyzeNode(nix, niz)
				local stepCost = nodeCost(world, plan, settings, grid, nix, niz, reuseField, analyzeNode)
				if stepCost >= math.huge then
					pushCount(debug.blocked, nextNode.blockedReason or "blocked")
				else
					local bridgeOk, bridgeInfo = canTraverseBridge(currentNode, nextNode)
					if bridgeOk then
						local diag = (off[1] ~= 0 and off[2] ~= 0) and 1.4142 or 1
						local segLen = RoadMath.Distance2(currentNode.x, currentNode.z, nextNode.x, nextNode.z)
						local bridgeSegment = isBridgeLikeSample(currentNode.sample, settings) or isBridgeLikeSample(nextNode.sample, settings)
						local nextBridgeLength = bridgeSegment and ((current.bridgeLength or 0) + segLen) or 0
						if nextBridgeLength > maxBridgeLength then
							pushCount(debug.bridgeRejects, "bridge_too_long")
							if not debug.longestRejectedBridge or nextBridgeLength > debug.longestRejectedBridge then
								debug.longestRejectedBridge = nextBridgeLength
							end
						else
							local nKey = makeStateKey(nix, niz, nextBridgeLength)
							if not closed[nKey] then
								local tentative = gScore[currentKey] + stepCost * diag
								local nBaseKey = RoadMath.HashKey(nix, niz)
								local nBucket = bridgeBucket(nextBridgeLength)
								if tentative < (gScore[nKey] or math.huge) and rememberState(nBaseKey, nBucket, tentative) then
									gScore[nKey] = tentative
									cameFrom[nKey] = { ix = nix, iz = niz, prev = currentKey }
									local h = RoadMath.Distance2(nextNode.x, nextNode.z, endPos.x, endPos.z) * heuristicScale
									heapPush(open, { ix = nix, iz = niz, f = tentative + h, h = h, g = tentative, stateKey = nKey, bridgeLength = nextBridgeLength })
								end
							end
						end
					else
						pushCount(debug.bridgeRejects, (bridgeInfo and bridgeInfo.reason) or "bridge_reject")
						if bridgeInfo and bridgeInfo.span and (not debug.longestRejectedBridge or bridgeInfo.span > debug.longestRejectedBridge) then
							debug.longestRejectedBridge = bridgeInfo.span
						end
					end
				end
			end
		end
	end
	debug.status = "no_path"
	return nil, debug
end

local function mergeCountsInto(target, source)
	for key, value in pairs(source or {}) do
		target[key] = (target[key] or 0) + value
	end
end

local function combineAstarDebug(phase, coarseDebug, fineDebug, coarseGrid, fineGrid)
	local blocked = {}
	local bridgeRejects = {}
	mergeCountsInto(blocked, coarseDebug and coarseDebug.blocked)
	mergeCountsInto(blocked, fineDebug and fineDebug.blocked)
	mergeCountsInto(bridgeRejects, coarseDebug and coarseDebug.bridgeRejects)
	mergeCountsInto(bridgeRejects, fineDebug and fineDebug.bridgeRejects)
	local status = (fineDebug and fineDebug.status) or (coarseDebug and coarseDebug.status) or "no_path"
	if phase == "fine_failed_keep_coarse" then
		status = coarseDebug and coarseDebug.status or status
	end
	return {
		status = status,
		phase = phase,
		coarse = coarseDebug,
		fine = fineDebug,
		coarseCellSize = coarseGrid and coarseGrid.cellSize or nil,
		fineCellSize = fineGrid and fineGrid.cellSize or nil,
		expansions = (coarseDebug and coarseDebug.expansions or 0) + (fineDebug and fineDebug.expansions or 0),
		maxExpansions = (coarseDebug and coarseDebug.maxExpansions or 0) + (fineDebug and fineDebug.maxExpansions or 0),
		openPeak = math.max(coarseDebug and coarseDebug.openPeak or 0, fineDebug and fineDebug.openPeak or 0),
		maxOpenNodes = math.max(coarseDebug and coarseDebug.maxOpenNodes or 0, fineDebug and fineDebug.maxOpenNodes or 0),
		closedCount = (coarseDebug and coarseDebug.closedCount or 0) + (fineDebug and fineDebug.closedCount or 0),
		blocked = blocked,
		bridgeRejects = bridgeRejects,
		longestRejectedBridge = math.max(coarseDebug and coarseDebug.longestRejectedBridge or 0, fineDebug and fineDebug.longestRejectedBridge or 0),
	}
end

local function astar(world, plan, startPos, endPos, reuseField)
	local coarseCellSize = getCoarseCellSize(plan.settings)
	local fineCellSize = getFineCellSize(plan.settings)
	local coarseGrid = makeRoadGrid(world, coarseCellSize)
	local coarsePath, coarseDebug = astarOnGrid(world, plan, coarseGrid, startPos, endPos, reuseField)
	if not coarsePath or #coarsePath < 2 then
		return coarsePath, combineAstarDebug("coarse_failed", coarseDebug, nil, coarseGrid, nil)
	end
	if fineCellSize >= coarseCellSize then
		return coarsePath, combineAstarDebug("coarse_only", coarseDebug, nil, coarseGrid, nil)
	end

	local fineGrid = makeRoadGrid(world, fineCellSize)
	local corridorRadiusBase = math.max(plan.settings.roadWidth * 6, coarseCellSize * 3, 96)
	local corridorRadius = math.max(plan.settings.refineCorridorRadius or corridorRadiusBase, corridorRadiusBase)
	local finePath = nil
	local fineDebug = nil
	local multipliers = { 1.0, 1.6, 2.2 }
	for _, mult in ipairs(multipliers) do
		fineGrid.allowedCells = buildPathCorridorField(coarsePath, fineGrid, corridorRadius * mult)
		local sx, sz = worldToRoadGrid(fineGrid, startPos.x, startPos.z)
		local ex, ez = worldToRoadGrid(fineGrid, endPos.x, endPos.z)
		if fineGrid.allowedCells then
			fineGrid.allowedCells[RoadMath.HashKey(sx, sz)] = true
			fineGrid.allowedCells[RoadMath.HashKey(ex, ez)] = true
		end
		finePath, fineDebug = astarOnGrid(world, plan, fineGrid, startPos, endPos, reuseField)
		if finePath and #finePath >= 2 then
			fineDebug.corridorRadius = corridorRadius * mult
			break
		end
	end
	if finePath and #finePath >= 2 then
		return finePath, combineAstarDebug("refined", coarseDebug, fineDebug, coarseGrid, fineGrid)
	end
	return coarsePath, combineAstarDebug("fine_failed_keep_coarse", coarseDebug, fineDebug, coarseGrid, fineGrid)
end

local classifyRunPoint

local function tagFallbackPath(points, kind)
	points.fallbackKind = kind
	return points
end

local function makeFallbackPath(plan, a, b)
	local settings = plan.settings
	local dist = RoadMath.Distance2(a.x, a.z, b.x, b.z)
	local step = math.max(8, getFineCellSize(settings) * 1.1)
	local count = math.max(2, math.ceil(dist / step))
	local out = {}
	for i = 0, count do
		local t = i / count
		out[#out + 1] = {
			x = RoadMath.Lerp(a.x, b.x, t),
			z = RoadMath.Lerp(a.z, b.z, t),
		}
	end
	return tagFallbackPath(out, "direct")
end

local function makeWaypointFallback(kind, waypoints)
	local out = {}
	for _, p in ipairs(waypoints) do
		appendUniquePoint(out, p)
	end
	return tagFallbackPath(out, kind)
end

local function clampPlayableFallbackPoint(world, plan, p)
	local inset = math.max(plan.settings.roadWidth or 22, 22) * 1.5
	local r = math.max(0, (world.playableRadius or 0) - inset)
	return {
		x = RoadMath.Clamp(p.x, -r, r),
		z = RoadMath.Clamp(p.z, -r, r),
	}
end

local function projectToCityPerimeter(world, plan, p)
	local half = getCityReservedHalf(world)
	if not half then
		return nil, nil
	end
	local h = half + cityPerimeterMargin(plan)
	local maxEdge = (world.playableRadius or h) - math.max(plan.settings.roadWidth or 22, 22) * 1.25
	if maxEdge > half then
		h = math.min(h, maxEdge)
	end
	local x = RoadMath.Clamp(p.x, -h, h)
	local z = RoadMath.Clamp(p.z, -h, h)
	if math.abs(p.x) >= math.abs(p.z) then
		x = p.x >= 0 and h or -h
	else
		z = p.z >= 0 and h or -h
	end
	return { x = x, z = z }, h
end

local function cityPerimeterParam(p, h)
	if math.abs(p.z + h) <= 0.01 then
		return p.x + h
	end
	if math.abs(p.x - h) <= 0.01 then
		return 2 * h + (p.z + h)
	end
	if math.abs(p.z - h) <= 0.01 then
		return 4 * h + (h - p.x)
	end
	return 6 * h + (h - p.z)
end

local function cityPerimeterPoint(t, h)
	local total = 8 * h
	t = t % total
	if t <= 2 * h then
		return { x = -h + t, z = -h }
	elseif t <= 4 * h then
		return { x = h, z = -h + (t - 2 * h) }
	elseif t <= 6 * h then
		return { x = h - (t - 4 * h), z = h }
	end
	return { x = -h, z = h - (t - 6 * h) }
end

local function makeCityPerimeterFallback(world, plan, a, b, direction)
	local startP, h = projectToCityPerimeter(world, plan, a)
	local endP = nil
	endP, h = projectToCityPerimeter(world, plan, b)
	if not startP or not endP or not h or h <= 0 then
		return nil
	end
	local total = 8 * h
	local startT = cityPerimeterParam(startP, h)
	local endT = cityPerimeterParam(endP, h)
	if direction > 0 and endT < startT then
		endT += total
	elseif direction < 0 and endT > startT then
		endT -= total
	end
	local dist = math.abs(endT - startT)
	local step = math.max(36, math.max(plan.settings.roadWidth or 22, 22) * 2.0)
	local count = math.max(1, math.ceil(dist / step))
	local out = {}
	appendUniquePoint(out, a)
	appendUniquePoint(out, startP)
	for i = 1, count do
		local t = startT + (endT - startT) * (i / count)
		appendUniquePoint(out, cityPerimeterPoint(t, h))
	end
	appendUniquePoint(out, b)
	return tagFallbackPath(out, direction > 0 and "city_clockwise" or "city_counterclockwise")
end

local function addDoglegFallbacks(candidates, world, plan, a, b)
	local midA = clampPlayableFallbackPoint(world, plan, { x = a.x, z = b.z })
	local midB = clampPlayableFallbackPoint(world, plan, { x = b.x, z = a.z })
	candidates[#candidates + 1] = makeWaypointFallback("dogleg_xz", { a, midA, b })
	candidates[#candidates + 1] = makeWaypointFallback("dogleg_zx", { a, midB, b })
	local dx, dz = RoadMath.Normalize2(b.x - a.x, b.z - a.z)
	local px, pz = RoadMath.Perp2(dx, dz)
	local baseOffset = math.max(96, math.max(plan.settings.roadWidth or 22, 22) * 5)
	local maxOffset = math.max(baseOffset, (world.playableRadius or baseOffset) * 0.72)
	for _, mult in ipairs({ 1.0, 1.8, 2.7, 3.8, 5.2 }) do
		local offset = math.min(maxOffset, baseOffset * mult)
		for _, sign in ipairs({ -1, 1 }) do
			local p1 = clampPlayableFallbackPoint(world, plan, {
				x = RoadMath.Lerp(a.x, b.x, 0.33) + px * offset * sign,
				z = RoadMath.Lerp(a.z, b.z, 0.33) + pz * offset * sign,
			})
			local p2 = clampPlayableFallbackPoint(world, plan, {
				x = RoadMath.Lerp(a.x, b.x, 0.67) + px * offset * sign,
				z = RoadMath.Lerp(a.z, b.z, 0.67) + pz * offset * sign,
			})
			candidates[#candidates + 1] = makeWaypointFallback("detour_" .. tostring(mult) .. "_" .. tostring(sign), { a, p1, p2, b })
		end
	end
end

local function buildFallbackCandidates(world, plan, a, b)
	local candidates = { makeFallbackPath(plan, a, b) }
	local cityClockwise = makeCityPerimeterFallback(world, plan, a, b, 1)
	if cityClockwise then
		candidates[#candidates + 1] = cityClockwise
	end
	local cityCounter = makeCityPerimeterFallback(world, plan, a, b, -1)
	if cityCounter then
		candidates[#candidates + 1] = cityCounter
	end
	addDoglegFallbacks(candidates, world, plan, a, b)
	return candidates
end

local function wigglePath(world, plan, rawPoints, seedOffset)
	local settings = plan.settings
	local points = RoadMath.ResamplePolyline(rawPoints, math.max(8, getFineCellSize(settings) * 1.1))
	points = RoadMath.Chaikin(points, 2)
	local total = #points
	local out = {}
	for i = 1, total do
		local p = points[i]
		local prev = points[math.max(1, i - 1)]
		local nextP = points[math.min(total, i + 1)]
		if classifyRunPoint(world, p) ~= "road" or classifyRunPoint(world, prev) ~= "road" or classifyRunPoint(world, nextP) ~= "road" then
			out[#out + 1] = { x = p.x, z = p.z }
			continue
		end
		local t = (i - 1) / math.max(1, total - 1)
		local fadeIn = RoadMath.Smoothstep((t - settings.wiggleFadeStart) / math.max(0.001, 0.20))
		local fadeOut = 1 - RoadMath.Smoothstep((t - settings.wiggleFadeEnd) / math.max(0.001, 0.18))
		local fade = math.min(fadeIn, fadeOut)
		local tx, tz = RoadMath.Normalize2(nextP.x - prev.x, nextP.z - prev.z)
		local px, pz = RoadMath.Perp2(tx, tz)
		local noise = math.noise((p.x + seedOffset) * settings.wiggleScale, (p.z - seedOffset) * settings.wiggleScale, seedOffset * 0.01)
		local offset = noise * settings.wiggleAmplitude * fade
		local nx = p.x + px * offset
		local nz = p.z + pz * offset
		local sample = sampleWorld(world, nx, nz)
		if sample and not isMesaBlocked(sample, settings) and not isBlockedWaterSample(sample, settings) and not pointInsideBounds(nx, nz, world.placedStructureBounds or {}, settings.roadWidth * 0.7) then
			out[#out + 1] = { x = nx, z = nz }
		else
			out[#out + 1] = { x = p.x, z = p.z }
		end
	end
	return out
end

function classifyRunPoint(world, p)
	local sample = sampleWorld(world, p.x, p.z)
	if not sample then
		return "road"
	end
	if sample.canyon >= 0.035 then
		return "bridge_canyon"
	end
	if sample.river >= 0.08 then
		return "bridge_river"
	end
	return "road"
end

local function splitRuns(world, points)
	local runs = {}
	if #points == 0 then
		return runs
	end
	local kinds = {}
	for i = 1, #points do
		kinds[i] = classifyRunPoint(world, points[i])
	end
	for i = 2, #points - 1 do
		if kinds[i] == "road" and kinds[i - 1] == kinds[i + 1] and kinds[i - 1] ~= "road" then
			kinds[i] = kinds[i - 1]
		end
	end
	local current = nil
	for i = 1, #points do
		local kind = kinds[i]
		if not current or current.kind ~= kind then
			current = { kind = kind, points = {} }
			runs[#runs + 1] = current
		end
		current.points[#current.points + 1] = points[i]
	end
	return runs
end

local function isPathAllowed(world, plan, points)
	if not points or #points < 2 then
		return false, { reason = "too_short" }
	end

	local settings = plan.settings
	local maxBridgeLength = getMaxBridgeLength(settings)
	local sampleSpacing = math.max(6, getFineCellSize(settings) * 0.9)
	local sampled = RoadMath.ResamplePolyline(points, sampleSpacing)
	local currentBridgeLength = 0

	for i = 1, #sampled do
		local p = sampled[i]
		local sample = sampleWorld(world, p.x, p.z)
		if not sample then
			return false, { reason = "out", index = i }
		end
		if not pointInsidePlayableArea(world, p.x, p.z, 0) then
			return false, { reason = "playable_bounds", index = i }
		end
		if isMesaBlocked(sample, settings) then
			return false, { reason = "mesa", index = i }
		end
		if isBlockedWaterSample(sample, settings) then
			return false, { reason = "water", index = i }
		end
		if pointInsideBounds(p.x, p.z, world.placedStructureBounds or {}, settings.roadWidth * 0.6) then
			return false, { reason = "structure", index = i }
		end

		if i > 1 then
			local prev = sampled[i - 1]
			local segLen = RoadMath.Distance2(prev.x, prev.z, p.x, p.z)
			local bridgeKind = classifyRunPoint(world, prev)
			if bridgeKind == "bridge_river" or bridgeKind == "bridge_canyon" then
				currentBridgeLength += segLen
				if currentBridgeLength > maxBridgeLength then
					return false, { reason = "bridge_too_long", index = i, bridgeLength = currentBridgeLength, limit = maxBridgeLength }
				end
			else
				currentBridgeLength = 0
			end
		end
	end

	return true, { reason = "ok" }
end

local function chooseFallbackPath(world, plan, a, b)
	local candidates = buildFallbackCandidates(world, plan, a, b)
	local blocked = {}
	local lastInfo = nil
	for index, candidate in ipairs(candidates) do
		local ok, info = isPathAllowed(world, plan, candidate)
		if ok then
			return candidate, {
				ok = true,
				info = {
					reason = "ok",
					kind = candidate.fallbackKind or "unknown",
					index = index,
				},
				tried = index,
				total = #candidates,
			}
		end
		lastInfo = info
		pushCount(blocked, info and info.reason or "blocked")
	end
	return nil, {
		ok = false,
		info = lastInfo or { reason = "blocked" },
		tried = #candidates,
		total = #candidates,
		blocked = blocked,
	}
end

local function straightenBridgeRuns(world, plan, points)
	local runs = splitRuns(world, points)
	local out = {}
	local changed = 0
	local rejected = 0
	local spacing = math.max(6, plan.settings.bridgeStraightSampleStep or getFineCellSize(plan.settings))
	for _, run in ipairs(runs) do
		local usePoints = run.points
		if (run.kind == "bridge_river" or run.kind == "bridge_canyon") and #run.points >= 3 then
			local straight = makeLinePoints(run.points[1], run.points[#run.points], spacing)
			local straightBridge = true
			for i = 2, #straight - 1 do
				if classifyRunPoint(world, straight[i]) == "road" then
					straightBridge = false
					break
				end
			end
			if straightBridge then
				local allowed = isPathAllowed(world, plan, straight)
				if allowed then
					usePoints = straight
					changed += 1
				else
					rejected += 1
				end
			else
				rejected += 1
			end
		end
		for _, p in ipairs(usePoints) do
			appendUniquePoint(out, p)
		end
	end
	return out, {
		changed = changed,
		rejected = rejected,
	}
end

local function makeSupplementGrid(world, settings)
	local cellSize = math.max(16, settings.supplementalBridgeCellSize or math.max(18, getFineCellSize(settings) * 2))
	local radius = math.max(cellSize * 2, world.playableRadius - cellSize * 0.5)
	local size = math.max(3, math.floor((radius * 2) / cellSize) + 1)
	return {
		cellSize = cellSize,
		radius = radius,
		size = size,
	}
end

local function supplementGridToWorld(grid, ix, iz)
	local half = (grid.size - 1) * 0.5
	return (ix - 1 - half) * grid.cellSize, (iz - 1 - half) * grid.cellSize
end

local function inSupplementGrid(grid, ix, iz)
	return ix >= 1 and ix <= grid.size and iz >= 1 and iz <= grid.size
end

local function isSupplementLand(world, plan, grid, x, z)
	local settings = plan.settings
	local sample = sampleWorld(world, x, z)
	if not sample then
		return false
	end
	if not pointInsidePlayableArea(world, x, z, math.max(0, grid.cellSize * 0.25)) then
		return false
	end
	if pointInsideBounds(x, z, world.placedStructureBounds or {}, settings.roadWidth * 0.55) then
		return false
	end
	if isMesaBlocked(sample, settings) then
		return false
	end
	if isBlockedWaterSample(sample, settings) then
		return false
	end
	if isBridgeLikeSample(sample, settings) then
		return false
	end
	local slope = computeSlope(world, x, z, math.max(6, grid.cellSize * 0.5))
	if slope > math.max((settings.maxSlope or 24) * 1.2, 18) then
		return false
	end
	return true
end

local function computeSupplementComponents(world, plan)
	local grid = makeSupplementGrid(world, plan.settings)
	local allowed = {}
	local compOf = {}
	local components = {}
	for ix = 1, grid.size do
		for iz = 1, grid.size do
			local x, z = supplementGridToWorld(grid, ix, iz)
			if isSupplementLand(world, plan, grid, x, z) then
				allowed[RoadMath.HashKey(ix, iz)] = { ix = ix, iz = iz, x = x, z = z }
			end
		end
	end
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local nextId = 0
	for key, cell in pairs(allowed) do
		if not compOf[key] then
			nextId += 1
			local comp = { id = nextId, cells = {}, boundary = {}, size = 0 }
			components[#components + 1] = comp
			local queue = { cell }
			compOf[key] = nextId
			local qi = 1
			while qi <= #queue do
				local current = queue[qi]
				qi += 1
				comp.size += 1
				comp.cells[#comp.cells + 1] = current
				local boundary = false
				for _, off in ipairs(offsets) do
					local nix = current.ix + off[1]
					local niz = current.iz + off[2]
					if not inSupplementGrid(grid, nix, niz) then
						boundary = true
					else
						local nKey = RoadMath.HashKey(nix, niz)
						local nextCell = allowed[nKey]
						if nextCell then
							if not compOf[nKey] then
								compOf[nKey] = nextId
								queue[#queue + 1] = nextCell
							end
						else
							boundary = true
						end
					end
				end
				if boundary then
					comp.boundary[#comp.boundary + 1] = current
				end
			end
		end
	end
	return grid, components, compOf
end

local function nearestComponentForPoint(components, point)
	local bestComp = nil
	local bestDist = math.huge
	for _, comp in ipairs(components) do
		local source = (#comp.boundary > 0) and comp.boundary or comp.cells
		for _, cell in ipairs(source) do
			local dist = RoadMath.Distance2(point.x, point.z, cell.x, cell.z)
			if dist < bestDist then
				bestDist = dist
				bestComp = comp
			end
		end
	end
	return bestComp, bestDist
end

local function ufFind(parent, id)
	local p = parent[id]
	while p ~= parent[p] do
		parent[p] = parent[parent[p]]
		p = parent[p]
	end
	parent[id] = p
	return p
end

local function ufUnion(parent, a, b)
	local ra = ufFind(parent, a)
	local rb = ufFind(parent, b)
	if ra ~= rb then
		parent[rb] = ra
	end
end

local function endpointFar(endpoints, point, minSeparation)
	for _, other in ipairs(endpoints or {}) do
		if RoadMath.Distance2(other.x, other.z, point.x, point.z) < minSeparation then
			return false
		end
	end
	return true
end

local function evaluateSupplementBridge(world, plan, a, b)
	local settings = plan.settings
	local maxBridgeLength = getMaxBridgeLength(settings)
	local dist = RoadMath.Distance2(a.x, a.z, b.x, b.z)
	if dist < math.max(settings.roadWidth * 1.25, 24) or dist > maxBridgeLength then
		return nil
	end
	local step = math.max(6, settings.supplementalBridgeSampleStep or getFineCellSize(settings))
	local points = makeLinePoints(a, b, step)
	local hazardCount = 0
	local interiorCount = 0
	local canyonScore = 0
	local riverScore = 0
	local boundaryInset = math.max(0, settings.supplementalBridgeBoundaryInset or 150)
	for i, p in ipairs(points) do
		if not pointInsidePlayableArea(world, p.x, p.z, boundaryInset) then
			return nil
		end
		local sample = sampleWorld(world, p.x, p.z)
		if not sample or isMesaBlocked(sample, settings) then
			return nil
		end
		if pointInsideBounds(p.x, p.z, world.placedStructureBounds or {}, settings.roadWidth * 0.55) then
			return nil
		end
		if i == 1 or i == #points then
			if isBridgeLikeSample(sample, settings) then
				return nil
			end
		else
			interiorCount += 1
			if isBridgeLikeSample(sample, settings) then
				hazardCount += 1
				canyonScore = math.max(canyonScore, sample.canyon or 0)
				riverScore = math.max(riverScore, sample.river or 0)
			end
		end
	end
	if interiorCount < 2 then
		return nil
	end
	if hazardCount / interiorCount < (settings.supplementalBridgeHazardRatio or 0.4) then
		return nil
	end
	return {
		kind = canyonScore >= (settings.bridgeCanyonThreshold or 0.03) and "bridge_canyon" or "bridge_river",
		points = points,
		length = dist,
		a = a,
		b = b,
	}
end

local function pickNearestBoundaryTargets(sourceCell, boundaries, maxDist, limit)
	local chosen = {}
	for _, cell in ipairs(boundaries) do
		local dist = RoadMath.Distance2(sourceCell.x, sourceCell.z, cell.x, cell.z)
		if dist <= maxDist then
			local item = { cell = cell, dist = dist }
			local inserted = false
			for i = 1, #chosen do
				if dist < chosen[i].dist then
					table.insert(chosen, i, item)
					inserted = true
					break
				end
			end
			if not inserted then
				chosen[#chosen + 1] = item
			end
			if #chosen > limit then
				table.remove(chosen)
			end
		end
	end
	return chosen
end

local function endpointsDistinct(selected, candidate, minSeparation)
	for _, item in ipairs(selected) do
		if RoadMath.Distance2(item.a.x, item.a.z, candidate.a.x, candidate.a.z) < minSeparation then
			return false
		end
		if RoadMath.Distance2(item.b.x, item.b.z, candidate.b.x, candidate.b.z) < minSeparation then
			return false
		end
	end
	return true
end

local function componentPairKey(a, b)
	if a > b then
		a, b = b, a
	end
	return tostring(a) .. ":" .. tostring(b)
end

local function orient2(ax, az, bx, bz, cx, cz)
	return (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
end

local function onSegment2(ax, az, bx, bz, cx, cz)
	return math.min(ax, bx) - 1e-4 <= cx and cx <= math.max(ax, bx) + 1e-4 and math.min(az, bz) - 1e-4 <= cz and cz <= math.max(az, bz) + 1e-4
end

local function segmentsIntersectXZ(a1, a2, b1, b2)
	local o1 = orient2(a1.x, a1.z, a2.x, a2.z, b1.x, b1.z)
	local o2 = orient2(a1.x, a1.z, a2.x, a2.z, b2.x, b2.z)
	local o3 = orient2(b1.x, b1.z, b2.x, b2.z, a1.x, a1.z)
	local o4 = orient2(b1.x, b1.z, b2.x, b2.z, a2.x, a2.z)
	if ((o1 > 0 and o2 < 0) or (o1 < 0 and o2 > 0)) and ((o3 > 0 and o4 < 0) or (o3 < 0 and o4 > 0)) then
		return true
	end
	if math.abs(o1) <= 1e-4 and onSegment2(a1.x, a1.z, a2.x, a2.z, b1.x, b1.z) then
		return true
	end
	if math.abs(o2) <= 1e-4 and onSegment2(a1.x, a1.z, a2.x, a2.z, b2.x, b2.z) then
		return true
	end
	if math.abs(o3) <= 1e-4 and onSegment2(b1.x, b1.z, b2.x, b2.z, a1.x, a1.z) then
		return true
	end
	if math.abs(o4) <= 1e-4 and onSegment2(b1.x, b1.z, b2.x, b2.z, a2.x, a2.z) then
		return true
	end
	return false
end

local function runSegmentDistance(pointsA, pointsB)
	local best = math.huge
	for i = 1, #pointsA - 1 do
		local a1 = pointsA[i]
		local a2 = pointsA[i + 1]
		for j = 1, #pointsB - 1 do
			local b1 = pointsB[j]
			local b2 = pointsB[j + 1]
			if segmentsIntersectXZ(a1, a2, b1, b2) then
				return 0
			end
			local d1 = RoadMath.PointToSegmentDistance(a1.x, a1.z, b1.x, b1.z, b2.x, b2.z)
			local d2 = RoadMath.PointToSegmentDistance(a2.x, a2.z, b1.x, b1.z, b2.x, b2.z)
			local d3 = RoadMath.PointToSegmentDistance(b1.x, b1.z, a1.x, a1.z, a2.x, a2.z)
			local d4 = RoadMath.PointToSegmentDistance(b2.x, b2.z, a1.x, a1.z, a2.x, a2.z)
			best = math.min(best, d1, d2, d3, d4)
		end
	end
	return best
end

local function bridgeClearOfOtherBridges(candidate, existingRuns, minSpacing)
	for _, run in ipairs(existingRuns or {}) do
		if run.points and #run.points >= 2 and (run.kind == "bridge_river" or run.kind == "bridge_canyon") then
			local dist = runSegmentDistance(candidate.points, run.points)
			if dist < minSpacing then
				return false
			end
		end
	end
	return true
end

local function buildSupplementalBridges(world, plan, existingBridgeRuns)
	local settings = plan.settings
	local _, components = computeSupplementComponents(world, plan)
	if #components <= 1 then
		return {}
	end
	local targetCount = math.max(2, settings.supplementalBridgeTargetCount or 2)
	local requestedMaxSupplemental = tonumber(settings.supplementalBridgeMaxCount) or 0
	local maxSupplemental = requestedMaxSupplemental > 0 and requestedMaxSupplemental or math.max(#components, #components * targetCount)
	local minSeparation = math.max(settings.roadWidth * 3.0, settings.supplementalBridgeEndpointSeparation or 220)
	local minBridgeSpacing = math.max(180, settings.bridgeMinSeparation or 280)
	local results = {}
	local allBridgeRuns = {}
	local degrees = {}
	local endpointsByComp = {}
	local pairCounts = {}
	local neighborsByComp = {}
	local candidateNeighborsByComp = {}
	local parent = {}
	for _, comp in ipairs(components) do
		degrees[comp.id] = 0
		endpointsByComp[comp.id] = {}
		neighborsByComp[comp.id] = {}
		candidateNeighborsByComp[comp.id] = {}
		parent[comp.id] = comp.id
	end
	for _, run in ipairs(existingBridgeRuns or {}) do
		if run.kind == "bridge_river" or run.kind == "bridge_canyon" then
			allBridgeRuns[#allBridgeRuns + 1] = run
			if run.points and #run.points >= 2 then
				local compA = nearestComponentForPoint(components, run.points[1])
				local compB = nearestComponentForPoint(components, run.points[#run.points])
				if compA and compB and compA.id ~= compB.id then
					degrees[compA.id] += 1
					degrees[compB.id] += 1
					ufUnion(parent, compA.id, compB.id)
					local pairKey = componentPairKey(compA.id, compB.id)
					pairCounts[pairKey] = (pairCounts[pairKey] or 0) + 1
					neighborsByComp[compA.id][compB.id] = true
					neighborsByComp[compB.id][compA.id] = true
					endpointsByComp[compA.id][#endpointsByComp[compA.id] + 1] = run.points[1]
					endpointsByComp[compB.id][#endpointsByComp[compB.id] + 1] = run.points[#run.points]
				end
			end
		end
	end

	local candidates = {}
	for i = 1, #components - 1 do
		for j = i + 1, #components do
			local compA = components[i]
			local compB = components[j]
			local sourceBoundary = compA.boundary
			local targetBoundary = compB.boundary
			if #sourceBoundary > #targetBoundary then
				sourceBoundary, targetBoundary = targetBoundary, sourceBoundary
				compA, compB = compB, compA
			end
			for _, sourceCell in ipairs(sourceBoundary) do
				local nearest = pickNearestBoundaryTargets(sourceCell, targetBoundary, getMaxBridgeLength(settings), 8)
				for _, item in ipairs(nearest) do
					local candidate = evaluateSupplementBridge(world, plan, sourceCell, item.cell)
					if candidate then
						candidate.compA = compA.id
						candidate.compB = compB.id
						candidate.pairKey = componentPairKey(compA.id, compB.id)
						candidateNeighborsByComp[compA.id][compB.id] = true
						candidateNeighborsByComp[compB.id][compA.id] = true
						candidates[#candidates + 1] = candidate
					end
				end
			end
		end
	end

	local function countSet(set)
		local n = 0
		for _ in pairs(set or {}) do
			n += 1
		end
		return n
	end

	local function distinctTargetFor(compId)
		local candidateCount = countSet(candidateNeighborsByComp[compId])
		local existingCount = countSet(neighborsByComp[compId])
		return math.min(targetCount, math.max(candidateCount, existingCount))
	end

	local function candidateHelpsDistinct(candidate)
		local aNeeds = countSet(neighborsByComp[candidate.compA]) < distinctTargetFor(candidate.compA)
		local bNeeds = countSet(neighborsByComp[candidate.compB]) < distinctTargetFor(candidate.compB)
		local aGetsNew = not neighborsByComp[candidate.compA][candidate.compB]
		local bGetsNew = not neighborsByComp[candidate.compB][candidate.compA]
		return (aNeeds and aGetsNew) or (bNeeds and bGetsNew)
	end

	local duplicateBridgeSpacing = math.max(minBridgeSpacing, minSeparation * 1.35)

	table.sort(candidates, function(lhs, rhs)
		local lhsNeed = ((degrees[lhs.compA] or 0) < targetCount and 1 or 0) + ((degrees[lhs.compB] or 0) < targetCount and 1 or 0)
		local rhsNeed = ((degrees[rhs.compA] or 0) < targetCount and 1 or 0) + ((degrees[rhs.compB] or 0) < targetCount and 1 or 0)
		local lhsPenalty = math.min(degrees[lhs.compA] or 0, degrees[lhs.compB] or 0) * 80 + (pairCounts[lhs.pairKey] or 0) * 1600 - lhsNeed * 120
		local rhsPenalty = math.min(degrees[rhs.compA] or 0, degrees[rhs.compB] or 0) * 80 + (pairCounts[rhs.pairKey] or 0) * 1600 - rhsNeed * 120
		local lhsScore = lhs.length + lhsPenalty
		local rhsScore = rhs.length + rhsPenalty
		if lhsScore == rhsScore then
			if lhs.compA == rhs.compA then
				return lhs.compB < rhs.compB
			end
			return lhs.compA < rhs.compA
		end
		return lhsScore < rhsScore
	end)

	local function canUseCandidate(candidate, allowDuplicatePair)
		if not allowDuplicatePair and (pairCounts[candidate.pairKey] or 0) > 0 then
			return false
		end
		if not endpointFar(endpointsByComp[candidate.compA], candidate.a, minSeparation) then
			return false
		end
		if not endpointFar(endpointsByComp[candidate.compB], candidate.b, minSeparation) then
			return false
		end
		local spacing = allowDuplicatePair and duplicateBridgeSpacing or minBridgeSpacing
		if not bridgeClearOfOtherBridges(candidate, allBridgeRuns, spacing) then
			return false
		end
		return true
	end

	local function acceptCandidate(candidate)
		results[#results + 1] = {
			kind = candidate.kind,
			points = candidate.points,
			supplemental = true,
		}
		allBridgeRuns[#allBridgeRuns + 1] = candidate
		degrees[candidate.compA] += 1
		degrees[candidate.compB] += 1
		pairCounts[candidate.pairKey] = (pairCounts[candidate.pairKey] or 0) + 1
		neighborsByComp[candidate.compA][candidate.compB] = true
		neighborsByComp[candidate.compB][candidate.compA] = true
		endpointsByComp[candidate.compA][#endpointsByComp[candidate.compA] + 1] = candidate.a
		endpointsByComp[candidate.compB][#endpointsByComp[candidate.compB] + 1] = candidate.b
		ufUnion(parent, candidate.compA, candidate.compB)
	end

	for _, candidate in ipairs(candidates) do
		if #results >= maxSupplemental then
			break
		end
		if ufFind(parent, candidate.compA) ~= ufFind(parent, candidate.compB) and canUseCandidate(candidate, false) then
			acceptCandidate(candidate)
		end
	end

	local function needsMoreDistinct()
		for _, comp in ipairs(components) do
			if countSet(neighborsByComp[comp.id]) < distinctTargetFor(comp.id) then
				return true
			end
		end
		return false
	end

	local function needsMoreBridges()
		for _, comp in ipairs(components) do
			if degrees[comp.id] < targetCount then
				return true
			end
		end
		return false
	end

	while needsMoreDistinct() and #results < maxSupplemental do
		local added = false
		for _, candidate in ipairs(candidates) do
			if #results >= maxSupplemental then
				break
			end
			if candidateHelpsDistinct(candidate) and canUseCandidate(candidate, false) then
				acceptCandidate(candidate)
				added = true
				if not needsMoreDistinct() then
					break
				end
			end
		end
		if not added then
			break
		end
	end

	while needsMoreBridges() and #results < maxSupplemental do
		local added = false
		for _, candidate in ipairs(candidates) do
			if #results >= maxSupplemental then
				break
			end
			if (degrees[candidate.compA] < targetCount or degrees[candidate.compB] < targetCount) and canUseCandidate(candidate, false) then
				acceptCandidate(candidate)
				added = true
				if not needsMoreBridges() then
					break
				end
			end
		end
		if not added then
			break
		end
	end

	while needsMoreBridges() and #results < maxSupplemental do
		local added = false
		for _, candidate in ipairs(candidates) do
			if #results >= maxSupplemental then
				break
			end
			if (degrees[candidate.compA] < targetCount or degrees[candidate.compB] < targetCount) and canUseCandidate(candidate, true) then
				acceptCandidate(candidate)
				added = true
				if not needsMoreBridges() then
					break
				end
			end
		end
		if not added then
			break
		end
	end

	return results
end

function M.GetEditorMask(world, rawPlan)
	local plan = RoadDefaults.MergePlan(rawPlan)
	local mask = {
		blocked = {},
		reasons = {},
		resolved = {},
	}
	for sideIndex, side in ipairs({ "N", "E", "S", "W" }) do
		for slot = 1, plan.edgeSlotsPerSide do
			local exitDef = { side = side, slot = slot, mode = "road" }
			local worldExit = edgeExitToWorld(world, plan, exitDef)
			local resolved = resolveEdgeTerminal(world, plan, worldExit)
			local key = side .. ":" .. tostring(slot)
			if not (resolved and resolved.usable) then
				mask.blocked[key] = true
				mask.reasons[key] = "obstructed"
			elseif resolved and resolved.resolvedOffset and resolved.resolvedOffset > 0 then
				mask.resolved[key] = resolved.resolvedOffset
			end
		end
	end
	for gz = 1, plan.mapGridSize do
		for gx = 1, plan.mapGridSize do
			local isEdge = false
			if gz == 1 or gz == plan.mapGridSize or gx == 1 or gx == plan.mapGridSize then
				isEdge = true
			end
			if not isEdge then
				local anchor = { gx = gx, gz = gz }
				local p = anchorToWorld(world, plan, anchor)
				local resolved = resolveAnchorTerminal(world, plan, anchor, p)
				local key = tostring(gx) .. ":" .. tostring(gz)
				if not (resolved and resolved.usable) then
					mask.blocked[key] = true
					mask.reasons[key] = "obstructed"
				elseif resolved and RoadMath.Distance2(resolved.x, resolved.z, p.x, p.z) > 1 then
					mask.resolved[key] = true
				end
			end
		end
	end
	return mask
end

function M.BuildPlan(world, rawPlan)
	local plan = RoadDefaults.MergePlan(rawPlan)
	local roadTerminals, tunnelTerminals, blockedSelections, terminalDebug = buildTerminalList(world, plan)
	local output = {
		plan = plan,
		roadTerminals = roadTerminals,
		tunnelTerminals = tunnelTerminals,
		connections = {},
		runs = {},
		exterior = {},
		blockedSelections = blockedSelections,
		debug = {
			terminalDebug = terminalDebug,
			connectionAttempts = {},
		},
	}
	if #roadTerminals < 2 then
		output.supplementalBridges = buildSupplementalBridges(world, plan, output.runs)
		for _, run in ipairs(output.supplementalBridges) do
			output.runs[#output.runs + 1] = run
		end
		return output
	end
	local roadEdges = buildAnchorSpineEdges(roadTerminals)
	local reuseField = {}
	for i, edge in ipairs(roadEdges) do
		local a = edge.from
		local b = edge.to
		local rawPath, astarDebug = astar(world, plan, a, b, reuseField)
		local attemptDebug = {
			index = i,
			from = a,
			to = b,
			astar = astarDebug,
			chosen = "failed",
		}
		if (not rawPath or #rawPath < 2) and plan.settings.allowDirectFallback ~= false then
			local fallbackPath, fallbackDebug = chooseFallbackPath(world, plan, a, b)
			attemptDebug.fallback = fallbackDebug
			if fallbackPath then
				rawPath = fallbackPath
				attemptDebug.chosen = "fallback"
			else
				attemptDebug.chosen = "failed"
			end
		end
		if rawPath and #rawPath >= 2 then
			rawPath[1] = { x = a.x, z = a.z }
			rawPath[#rawPath] = { x = b.x, z = b.z }
			rawPath, attemptDebug.bridgeStraightenRaw = straightenBridgeRuns(world, plan, rawPath)
			local path = wigglePath(world, plan, rawPath, i * 37.1)
			path, attemptDebug.bridgeStraightenFinal = straightenBridgeRuns(world, plan, path)
			local wiggleOk, wiggleInfo = isPathAllowed(world, plan, path)
			attemptDebug.wiggle = {
				ok = wiggleOk,
				info = wiggleInfo,
			}
			if not wiggleOk then
				path = rawPath
			end
			local finalOk, finalInfo = isPathAllowed(world, plan, path)
			attemptDebug.final = {
				ok = finalOk,
				info = finalInfo,
			}
			if not finalOk and attemptDebug.chosen ~= "fallback" and plan.settings.allowDirectFallback ~= false then
				local retryPath, retryDebug = chooseFallbackPath(world, plan, a, b)
				attemptDebug.fallbackRetry = retryDebug
				if retryPath then
					retryPath[1] = { x = a.x, z = a.z }
					retryPath[#retryPath] = { x = b.x, z = b.z }
					retryPath, attemptDebug.fallbackRetryBridgeStraightenRaw = straightenBridgeRuns(world, plan, retryPath)
					local retryFinal = wigglePath(world, plan, retryPath, i * 71.7)
					retryFinal, attemptDebug.fallbackRetryBridgeStraightenFinal = straightenBridgeRuns(world, plan, retryFinal)
					local retryWiggleOk, retryWiggleInfo = isPathAllowed(world, plan, retryFinal)
					attemptDebug.fallbackRetryWiggle = {
						ok = retryWiggleOk,
						info = retryWiggleInfo,
					}
					if not retryWiggleOk then
						retryFinal = retryPath
					end
					local retryFinalOk, retryFinalInfo = isPathAllowed(world, plan, retryFinal)
					attemptDebug.fallbackRetryFinal = {
						ok = retryFinalOk,
						info = retryFinalInfo,
					}
					if retryFinalOk then
						path = retryFinal
						finalOk = true
						finalInfo = retryFinalInfo
						attemptDebug.chosen = "fallback"
						attemptDebug.final = {
							ok = finalOk,
							info = finalInfo,
						}
					end
				end
			end
			if finalOk then
				if attemptDebug.chosen ~= "fallback" then
					attemptDebug.chosen = "astar"
				end
				buildReuseField(path, makeRoadGrid(world, getFineCellSize(plan.settings)), reuseField)
				output.connections[#output.connections + 1] = {
					from = a,
					to = b,
					points = path,
				}
				local runs = splitRuns(world, path)
				for _, run in ipairs(runs) do
					output.runs[#output.runs + 1] = run
				end
			else
				attemptDebug.chosen = "failed"
			end
		end
		output.debug.connectionAttempts[#output.debug.connectionAttempts + 1] = attemptDebug
	end
	for _, terminal in ipairs(roadTerminals) do
		if terminal.kind == "exit" and terminal.outer then
			local exitStart = terminal.entry or { x = terminal.x, z = terminal.z }
			local exitMid = {
				x = exitStart.x + terminal.dir.x * plan.settings.exitStraightLength,
				z = exitStart.z + terminal.dir.z * plan.settings.exitStraightLength,
			}
			output.exterior[#output.exterior + 1] = {
				kind = "exit_extension",
				side = terminal.side,
				points = {
					{ x = terminal.x, z = terminal.z },
					exitStart,
					exitMid,
					{ x = terminal.outer.x, z = terminal.outer.z },
				},
			}
		end
	end
	output.supplementalBridges = buildSupplementalBridges(world, plan, output.runs)
	for _, run in ipairs(output.supplementalBridges) do
		output.runs[#output.runs + 1] = run
	end
	return output
end

return M
