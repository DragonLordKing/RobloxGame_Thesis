--[[
Name: RoadService
Class: ModuleScript
Original path: game.ServerScriptService.RoadSystem.RoadService
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage
Requires:
  - local WorldState = require(script.Parent:WaitForChild("WorldState"))
  - local RoadPlanner = require(script.Parent:WaitForChild("RoadPlanner"))
  - local RoadBuilder = require(script.Parent:WaitForChild("RoadBuilder"))
  - local RoadDefaults = require(Shared:WaitForChild("RoadDefaults"))
Functions: resolveSharedFolder, formatTerminalLabel, formatCounts, logRoadDebug, sanitizePlan, M.GetEditorMask, M.Generate
Clean source lines: 224
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldState = require(script.Parent:WaitForChild("WorldState"))
local RoadPlanner = require(script.Parent:WaitForChild("RoadPlanner"))
local RoadBuilder = require(script.Parent:WaitForChild("RoadBuilder"))

local function resolveSharedFolder()
	local localShared = script.Parent:FindFirstChild("Shared")
	if localShared then
		return localShared
	end
	return ReplicatedStorage:WaitForChild("RoadSystem"):WaitForChild("Shared")
end

local Shared = resolveSharedFolder()
local RoadDefaults = require(Shared:WaitForChild("RoadDefaults"))

local M = {}

local function formatTerminalLabel(t)
	if not t then
		return "?"
	end
	if t.kind == "anchor" then
		return string.format("anchor(%d,%d)", t.gx or -1, t.gz or -1)
	end
	return string.format("%s(%s:%s)", t.kind or "node", tostring(t.side or "?"), tostring(t.slot or "?"))
end

local function formatCounts(counts)
	local parts = {}
	for key, value in pairs(counts or {}) do
		parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
	end
	table.sort(parts)
	return #parts > 0 and table.concat(parts, ",") or "none"
end

local function logRoadDebug(planned)
	print(string.format(
		"[RoadDebug] summary= %s roadTerminals= %d tunnelTerminals= %d connections= %d runs= %d supplementalBridges= %d bridgeMax= %s",
		(#planned.connections > 0 and "ok" or "no_connections_built"),
		#planned.roadTerminals,
		#planned.tunnelTerminals,
		#planned.connections,
		#planned.runs,
		#(planned.supplementalBridges or {}),
		tostring(planned.plan and planned.plan.settings and planned.plan.settings.maxBridgeLength)
	))

	local terminalDebug = planned.debug and planned.debug.terminalDebug
	if terminalDebug then
		for key, info in pairs(terminalDebug.edges or {}) do
			if info and info.status ~= "ok" then
				print(string.format(
					"[RoadDebug] exit %s blocked status=%s attempts=%s reasons={%s}",
					key,
					tostring(info.status),
					tostring(info.attempts),
					formatCounts(info.reasonCounts)
				))
			end
		end
		for key, info in pairs(terminalDebug.anchors or {}) do
			if info and info.status ~= "ok" then
				print(string.format(
					"[RoadDebug] anchor %s blocked status=%s attempts=%s reasons={%s}",
					key,
					tostring(info.status),
					tostring(info.attempts),
					formatCounts(info.reasonCounts)
				))
			end
		end
	end

	for _, edge in ipairs((planned.debug and planned.debug.connectionAttempts) or {}) do
		local astar = edge.astar or {}
		local fallback = edge.fallbackRetry or edge.fallback
		local final = edge.final
		local fallbackStatus = "unused"
		if fallback then
			local info = fallback.info or {}
			if fallback.ok then
				fallbackStatus = "ok"
				if info.kind then
					fallbackStatus = fallbackStatus .. "(" .. tostring(info.kind) .. ")"
				end
				if fallback.tried and fallback.total then
					fallbackStatus = fallbackStatus .. string.format("[%s/%s]", tostring(fallback.tried), tostring(fallback.total))
				end
			else
				fallbackStatus = tostring(info.reason or "blocked")
				if info.bridgeLength then
					fallbackStatus = fallbackStatus .. string.format("(len=%.1f limit=%s)", info.bridgeLength, tostring(info.limit))
				end
				if fallback.tried and fallback.total then
					fallbackStatus = fallbackStatus .. string.format("[%s/%s]", tostring(fallback.tried), tostring(fallback.total))
				end
			end
		end
		local finalStatus = final and (final.ok and "ok" or tostring((final.info and final.info.reason) or "blocked")) or "n/a"
		print(string.format(
			"[RoadDebug] edge %d %s -> %s chosen=%s astar=%s phase=%s coarseCell=%s fineCell=%s expansions=%s/%s closed=%s openPeak=%s/%s blocked={%s} bridgeRejects={%s} longestRejectedBridge=%s fallback=%s final=%s",
			edge.index or -1,
			formatTerminalLabel(edge.from),
			formatTerminalLabel(edge.to),
			tostring(edge.chosen),
			tostring(astar.status),
			tostring(astar.phase),
			tostring(astar.coarseCellSize),
			tostring(astar.fineCellSize),
			tostring(astar.expansions),
			tostring(astar.maxExpansions),
			tostring(astar.closedCount),
			tostring(astar.openPeak),
			tostring(astar.maxOpenNodes),
			formatCounts(astar.blocked),
			formatCounts(astar.bridgeRejects),
			tostring(astar.longestRejectedBridge),
			fallbackStatus,
			finalStatus
		))
	end
end


local function sanitizePlan(rawPlan)
	local plan = RoadDefaults.MergePlan(rawPlan)
	plan.exits = plan.exits or {}
	plan.anchors = plan.anchors or {}
	local uniqueExits = {}
	local exits = {}
	for _, exitDef in ipairs(plan.exits) do
		if type(exitDef) == "table" then
			local side = exitDef.side
			local slot = tonumber(exitDef.slot)
			local mode = exitDef.mode
			if (side == "N" or side == "S" or side == "E" or side == "W") and slot and slot >= 1 and slot <= plan.edgeSlotsPerSide and (mode == "road" or mode == "tunnel") then
				local key = side .. ":" .. tostring(slot)
				if not uniqueExits[key] then
					uniqueExits[key] = true
					exits[#exits + 1] = {
						side = side,
						slot = slot,
						mode = mode,
					}
				end
			end
		end
	end
	plan.exits = exits
	local uniqueAnchors = {}
	local anchors = {}
	for _, anchor in ipairs(plan.anchors) do
		if type(anchor) == "table" then
			local gx = tonumber(anchor.gx)
			local gz = tonumber(anchor.gz)
			if gx and gz and gx >= 1 and gx <= plan.mapGridSize and gz >= 1 and gz <= plan.mapGridSize then
				local key = tostring(gx) .. ":" .. tostring(gz)
				if not uniqueAnchors[key] then
					uniqueAnchors[key] = true
					anchors[#anchors + 1] = { gx = gx, gz = gz }
				end
			end
		end
	end
	plan.anchors = anchors

	local defaults = RoadDefaults.DefaultPlan.settings
	local bridgeCap = defaults.maxBridgeLength or 450
	plan.settings.maxBridgeLength = bridgeCap
	plan.settings.bridgeMinSeparation = math.max(tonumber(plan.settings.bridgeMinSeparation) or 0, defaults.bridgeMinSeparation or 280)
	plan.settings.supplementalBridgeTargetCount = defaults.supplementalBridgeTargetCount or 2
	plan.settings.supplementalBridgeMaxCount = defaults.supplementalBridgeMaxCount or 0
	plan.settings.supplementalBridgeEndpointSeparation = math.max(tonumber(plan.settings.supplementalBridgeEndpointSeparation) or 0, defaults.supplementalBridgeEndpointSeparation or 220)
	return plan
end

function M.GetEditorMask(rawPlan)
	local world = WorldState.Get()
	if not world then
		return false, "World state is not available yet. Generate the terrain first."
	end
	local plan = sanitizePlan(rawPlan)
	return true, RoadPlanner.GetEditorMask(world, plan)
end

function M.Generate(rawPlan)
	local world = WorldState.Get()
	if not world then
		return false, "World state is not available yet. Generate the terrain first."
	end
	if type(world) ~= "table" or not world.root or not world.heights then
		return false, "HybridWorldGen must return the world context table for roads to work."
	end
	local plan = sanitizePlan(rawPlan)
	local roadTerminalCount = #plan.anchors
	local tunnelCount = 0
	for _, exitDef in ipairs(plan.exits) do
		if exitDef.mode == "road" then
			roadTerminalCount += 1
		else
			tunnelCount += 1
		end
	end
	if roadTerminalCount < 2 and tunnelCount == 0 then
		return false, "Select at least two road points, or at least one tunnel exit."
	end
	local planned = RoadPlanner.BuildPlan(world, plan)
	logRoadDebug(planned)
	if #planned.roadTerminals < 2 and #planned.tunnelTerminals == 0 then
		return false, "Nothing valid was selected. Obstructed grid slots are now blocked in the editor."
	end
	local blueprint = RoadBuilder.CompileBlueprint(world, planned)
	planned.blueprint = blueprint
	world.lastRoadRawPlan = plan
	world.lastRoadPlanResult = planned
	RoadBuilder.Build(world, planned, blueprint)
	return true, planned
end

return M
