--[[
Name: WorldMapService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.WorldRuntime.WorldMapService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, Workspace
Requires:
  - local WorldConfig = require(ReplicatedPackage:WaitForChild("WorldRuntime"):WaitForChild("WorldPlaceConfig"))
  - local GatheringConfig = require(ReplicatedPackage:WaitForChild("GatheringConfig"))
Functions: generatedRoots, readGeneratedConfig, makeBounds, addPartExtents, collectPartBounds, isBoundaryPart, boundsFromGeneratedWorld, boundsFromConfig, materialName, normalizePurityName, normalizePurityEntries, purityEntriesForTier, buildPurityInfo, slopeFromNormal, terrainRayParams, sampleAxes, hasAncestorName, isWaterVolumePart, collectWaterVolumes, waterHeightAt, sampleTerrain, isOccupiedMapCell, trimEmptySampleMargins, normalizeToBounds, exitDirection, isExitPart, scanExits, regionMaterialFor, scanMapRegions, prettyStructureName, structureIconFor, structurePosition, structureFolders, scanStructures, addBand, hasAnyEnabled, buildEdgeBands, currentGeneratedSummary, generatedCacheToken, WorldMapService.GetLocalSnapshot, WorldMapService.GetGlobalSnapshot, WorldMapService.Start, requestRemote.OnServerInvoke
Signal classes referenced: RemoteFunction
Clean source lines: 612
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ReplicatedPackage = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
local WorldConfig = require(ReplicatedPackage:WaitForChild("WorldRuntime"):WaitForChild("WorldPlaceConfig"))
local GatheringConfig = require(ReplicatedPackage:WaitForChild("GatheringConfig"))

local WorldMapService = {}
local started = false
local cachedLocalSnapshots = {}
local DEFAULT_SAMPLE_AXIS = 128
local MIN_SAMPLE_AXIS = 96
local MAX_SAMPLE_AXIS = 224
local TARGET_STUDS_PER_SAMPLE = 16
local EMPTY_MARGIN_PADDING_CELLS = 1
local RAY_HEIGHT = 1200
local RAY_DEPTH = 2400
local MAX_CLIMBABLE_SLOPE = 43
local EDGE_BAND_FRACTION = 0.075

local remoteFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
end

local requestRemote = remoteFolder:FindFirstChild("WorldMapRequest")
if not requestRemote or not requestRemote:IsA("RemoteFunction") then
	if requestRemote then requestRemote:Destroy() end
	requestRemote = Instance.new("RemoteFunction")
	requestRemote.Name = "WorldMapRequest"
	requestRemote.Parent = remoteFolder
end

local GENERATED_ROOT_NAMES = { "GeneratedMap", "GeneratedWorld" }

local function generatedRoots()
	local roots = {}
	for _, name in ipairs(GENERATED_ROOT_NAMES) do
		local root = Workspace:FindFirstChild(name)
		if root then
			table.insert(roots, root)
		end
	end
	return roots
end

local function readGeneratedConfig()
	for _, root in ipairs(generatedRoots()) do
		local configModule = root:FindFirstChild("MapConfig")
		if configModule and configModule:IsA("ModuleScript") then
			local ok, result = pcall(require, configModule)
			if ok and type(result) == "table" then
				return result
			end
		end
	end
	return nil
end

local function makeBounds(minX, maxX, minZ, maxZ)
	minX = tonumber(minX) or -1024
	maxX = tonumber(maxX) or 1024
	minZ = tonumber(minZ) or -1024
	maxZ = tonumber(maxZ) or 1024
	if maxX < minX then minX, maxX = maxX, minX end
	if maxZ < minZ then minZ, maxZ = maxZ, minZ end
	local width = math.max(1, maxX - minX)
	local depth = math.max(1, maxZ - minZ)
	return { MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ, Width = width, Depth = depth }
end

local function addPartExtents(part, state)
	local half = part.Size * 0.5
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local corner = part.CFrame * Vector3.new(half.X * sx, 0, half.Z * sz)
			state.minX = math.min(state.minX, corner.X)
			state.maxX = math.max(state.maxX, corner.X)
			state.minZ = math.min(state.minZ, corner.Z)
			state.maxZ = math.max(state.maxZ, corner.Z)
			state.count += 1
		end
	end
end

local function collectPartBounds(root, predicate)
	if not root then return nil end
	local state = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge, count = 0 }
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("BasePart") and (not predicate or predicate(inst)) then
			addPartExtents(inst, state)
		end
	end
	if state.count <= 0 then return nil end
	return makeBounds(state.minX, state.maxX, state.minZ, state.maxZ)
end

local function isBoundaryPart(part)
	if part:GetAttribute("MapBoundary") == true or part:GetAttribute("WorldBoundary") == true then return true end
	local lower = string.lower(part.Name or "")
	return lower:find("wall", 1, true) ~= nil or lower:find("boundary", 1, true) ~= nil or lower:find("edge", 1, true) ~= nil
end

local function boundsFromGeneratedWorld()
	for _, root in ipairs(generatedRoots()) do
		local colliders = root:FindFirstChild("Colliders")
		local boundaryBounds = collectPartBounds(colliders, isBoundaryPart)
		if boundaryBounds then
			return boundaryBounds
		end
	end
	return nil
end

local function boundsFromConfig()
	local mapConfig = readGeneratedConfig()
	local grid = mapConfig and mapConfig.Grid
	if type(grid) == "table" then
		local cell = tonumber(grid.CellStuds) or 256
		local w = math.max(1, math.floor(tonumber(grid.W) or 16)) * cell
		local h = math.max(1, math.floor(tonumber(grid.H) or 16)) * cell
		local origin = grid.Origin or {}
		local ox = tonumber(origin.x or origin.X) or 0
		local oz = tonumber(origin.z or origin.Z) or 0
		local originMode = tostring(grid.OriginMode or grid.OriginKind or "Center"):lower()
		local originIsMin = grid.OriginIsMin == true or originMode == "min" or originMode == "corner" or originMode == "minimum"
		local minX = originIsMin and ox or (ox - w * 0.5)
		local minZ = originIsMin and oz or (oz - h * 0.5)
		return makeBounds(minX, minX + w, minZ, minZ + h)
	end
	return boundsFromGeneratedWorld() or makeBounds(-1024, 1024, -1024, 1024)
end

local function materialName(material)
	if typeof(material) == "EnumItem" then
		return material.Name
	end
	return tostring(material or "Air")
end

local function normalizePurityName(name)
	local text = tostring(name or "None")
	if text == "AshenForged" then return "Ashen Forged" end
	if text == "Low" or text == "Glowing" then return "Faint" end
	if text == "Medium" or text == "Pure" then return "Kindled" end
	if text == "High" or text == "Radiant" then return "Ignited" end
	if text == "Transcendent" then return "Ashen Forged" end
	if text == "Faint" or text == "Kindled" or text == "Ignited" or text == "Ashen Forged" then return text end
	return "None"
end

local function normalizePurityEntries(raw)
	local entries = {}
	if type(raw) ~= "table" then return entries end
	if #raw > 0 then
		for _, entry in ipairs(raw) do
			if type(entry) == "table" then
				local weight = tonumber(entry.Weight or entry.Chance or entry[2]) or 0
				if weight > 0 then
					table.insert(entries, { Name = normalizePurityName(entry.Name or entry.Purity or entry[1]), Weight = weight })
				end
			end
		end
	else
		for name, weight in pairs(raw) do
			weight = tonumber(weight) or 0
			if weight > 0 then
				table.insert(entries, { Name = normalizePurityName(name), Weight = weight })
			end
		end
	end
	return entries
end

local function purityEntriesForTier(tier)
	local raw = type(GatheringConfig.PurityRespawnWeightsByTier) == "table" and GatheringConfig.PurityRespawnWeightsByTier[tier] or nil
	local entries = normalizePurityEntries(raw or GatheringConfig.DefaultPurityRespawnWeights)
	local total = 0
	for _, entry in ipairs(entries) do total += math.max(0, tonumber(entry.Weight) or 0) end
	local out = {}
	for _, entry in ipairs(entries) do
		local weight = math.max(0, tonumber(entry.Weight) or 0)
		local pct = total > 0 and (weight / total * 100) or 0
		table.insert(out, { Name = entry.Name, Weight = weight, Percent = math.floor(pct * 10 + 0.5) / 10 })
	end
	return out
end

local function buildPurityInfo(currentMap)
	local minTier = math.clamp(math.floor(tonumber(currentMap.ResourceTierMin or currentMap.MinResourceTier or currentMap.TierMin or currentMap.Tier or 1) or 1), 1, 20)
	local maxTier = math.clamp(math.floor(tonumber(currentMap.ResourceTierMax or currentMap.MaxResourceTier or currentMap.TierMax or currentMap.Tier or minTier) or minTier), minTier, 20)
	local tiers = {}
	for tier = math.max(4, minTier), math.min(5, maxTier) do
		table.insert(tiers, { Tier = tier, Entries = purityEntriesForTier(tier) })
	end
	local summary = #tiers > 0 and string.format("Purity: T%d-T%d", tiers[1].Tier, tiers[#tiers].Tier) or "Purity: none below T4"
	return { MinTier = minTier, MaxTier = maxTier, Summary = summary, Tiers = tiers }
end

local function slopeFromNormal(normal)
	if typeof(normal) ~= "Vector3" then return 0 end
	local dot = math.clamp(normal:Dot(Vector3.yAxis), -1, 1)
	return math.deg(math.acos(dot))
end

local function terrainRayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = false
	return params
end

local function sampleAxes(bounds)
	local cols = math.ceil(math.max(1, bounds.Width) / TARGET_STUDS_PER_SAMPLE)
	local rows = math.ceil(math.max(1, bounds.Depth) / TARGET_STUDS_PER_SAMPLE)
	cols = math.clamp(cols, MIN_SAMPLE_AXIS, MAX_SAMPLE_AXIS)
	rows = math.clamp(rows, MIN_SAMPLE_AXIS, MAX_SAMPLE_AXIS)
	return cols, rows
end

local function hasAncestorName(inst, keyword)
	local current = inst.Parent
	while current and current ~= Workspace do
		if string.find(string.lower(current.Name or ""), keyword, 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isWaterVolumePart(inst)
	if not inst:IsA("BasePart") then return false end
	local mapMaterial = inst:GetAttribute("MapMaterial") or inst:GetAttribute("Material") or inst:GetAttribute("Biome")
	if mapMaterial and tostring(mapMaterial):lower() == "water" then return true end
	if inst.Material == Enum.Material.Water then return true end
	local lower = string.lower(inst.Name or "")
	if lower:find("water", 1, true) or lower:find("lake", 1, true) or lower:find("river", 1, true) or lower:find("ocean", 1, true) or lower:find("sea", 1, true) then return true end
	return hasAncestorName(inst, "lake") or hasAncestorName(inst, "water") or hasAncestorName(inst, "river") or hasAncestorName(inst, "ocean")
end

local function collectWaterVolumes()
	local volumes = {}
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if isWaterVolumePart(inst) then
			table.insert(volumes, inst)
		end
	end
	return volumes
end

local function waterHeightAt(volumes, worldX, worldZ)
	for _, part in ipairs(volumes) do
		if part.Parent then
			local localPos = part.CFrame:PointToObjectSpace(Vector3.new(worldX, part.Position.Y, worldZ))
			local half = part.Size * 0.5
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z then
				return part.Position.Y + half.Y
			end
		end
	end
	return nil
end

local function sampleTerrain(bounds, fallbackMaterial)
	local samples = {}
	local params = terrainRayParams()
	local sampleCols, sampleRows = sampleAxes(bounds)
	for y = 1, sampleRows do
		local row = {}
		local zAlpha = (y - 0.5) / sampleRows
		local z = bounds.MinZ + bounds.Depth * zAlpha
		for x = 1, sampleCols do
			local xAlpha = (x - 0.5) / sampleCols
			local worldX = bounds.MinX + bounds.Width * xAlpha
			local origin = Vector3.new(worldX, RAY_HEIGHT, z)
			local result = Workspace:Raycast(origin, Vector3.new(0, -RAY_DEPTH, 0), params)
			if result then
				local slope = slopeFromNormal(result.Normal)
				row[x] = {
					Material = materialName(result.Material),
					Height = math.floor(result.Position.Y + 0.5),
					Slope = math.floor(slope + 0.5),
					Blocked = slope > MAX_CLIMBABLE_SLOPE,
					Water = result.Material == Enum.Material.Water,
				}
			else
				row[x] = { Material = "Void", Height = 0, Slope = 0, Blocked = false, Water = false, Void = true }
			end
		end
		table.insert(samples, row)
	end
	return samples, sampleCols, sampleRows
end

local function isOccupiedMapCell(cell)
	return type(cell) == "table" and cell.Void ~= true and cell.Material ~= "Void"
end

local function trimEmptySampleMargins(samples, bounds)
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local sourceRows = math.max(1, #samples)
	local sourceCols = math.max(1, samples[1] and #samples[1] or DEFAULT_SAMPLE_AXIS)
	for rowIndex, row in ipairs(samples) do
		for colIndex, cell in ipairs(row) do
			if isOccupiedMapCell(cell) then
				minX = math.min(minX, colIndex)
				maxX = math.max(maxX, colIndex)
				minY = math.min(minY, rowIndex)
				maxY = math.max(maxY, rowIndex)
			end
		end
	end
	if minX == math.huge then
		return samples, bounds, sourceCols, sourceRows
	end

	minX = math.max(1, minX - EMPTY_MARGIN_PADDING_CELLS)
	maxX = math.min(sourceCols, maxX + EMPTY_MARGIN_PADDING_CELLS)
	minY = math.max(1, minY - EMPTY_MARGIN_PADDING_CELLS)
	maxY = math.min(sourceRows, maxY + EMPTY_MARGIN_PADDING_CELLS)

	if minX == 1 and maxX == sourceCols and minY == 1 and maxY == sourceRows then
		return samples, bounds, sourceCols, sourceRows
	end

	local trimmed = {}
	for rowIndex = minY, maxY do
		local sourceRow = samples[rowIndex]
		local row = {}
		for colIndex = minX, maxX do
			table.insert(row, sourceRow[colIndex])
		end
		table.insert(trimmed, row)
	end

	local sampleWidth = bounds.Width / sourceCols
	local sampleDepth = bounds.Depth / sourceRows
	local trimmedBounds = makeBounds(
		bounds.MinX + (minX - 1) * sampleWidth,
		bounds.MinX + maxX * sampleWidth,
		bounds.MinZ + (minY - 1) * sampleDepth,
		bounds.MinZ + maxY * sampleDepth
	)
	return trimmed, trimmedBounds, maxX - minX + 1, maxY - minY + 1
end

local function normalizeToBounds(pos, bounds)
	return {
		X = math.clamp((pos.X - bounds.MinX) / math.max(1, bounds.Width), 0, 1),
		Y = math.clamp((pos.Z - bounds.MinZ) / math.max(1, bounds.Depth), 0, 1),
	}
end

local function exitDirection(name)
	local lower = tostring(name or ""):lower()
	if lower:find("east", 1, true) then return "East" end
	if lower:find("west", 1, true) then return "West" end
	if lower:find("north", 1, true) then return "North" end
	if lower:find("south", 1, true) then return "South" end
	return "Exit"
end

local function isExitPart(inst)
	if not (inst and inst:IsA("BasePart")) then return false end
	if inst:GetAttribute("WorldExit") == true or inst:GetAttribute("MapExit") == true then return true end
	return tostring(inst.Name):match("^Exit") ~= nil
end

local function scanExits(bounds)
	local exits = {}
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if isExitPart(inst) then
			local target = WorldConfig.GetTargetForExit(inst)
			table.insert(exits, {
				Name = inst.Name,
				Direction = exitDirection(inst.Name),
				Position = normalizeToBounds(inst.Position, bounds),
				WorldPosition = { X = inst.Position.X, Y = inst.Position.Y, Z = inst.Position.Z },
				TargetMapKey = target and target.TargetMapKey or nil,
				TargetPlaceId = target and target.TargetPlaceId or nil,
				TargetSpawnId = target and target.TargetSpawnId or nil,
				PortalId = target and target.SourcePortalId or inst.Name,
			})
		end
	end
	table.sort(exits, function(a, b) return tostring(a.Name) < tostring(b.Name) end)
	return exits
end

local function regionMaterialFor(inst)
	local attr = inst:GetAttribute("MapMaterial") or inst:GetAttribute("Material") or inst:GetAttribute("Biome")
	if attr and tostring(attr) ~= "" then return tostring(attr) end
	local name = string.lower(inst.Name)
	if name:find("desert", 1, true) or name:find("sand", 1, true) then return "Sand" end
	if name:find("ocean", 1, true) or name:find("water", 1, true) then return "Water" end
	if name:find("mountain", 1, true) or name:find("rock", 1, true) then return "Rock" end
	if name:find("grass", 1, true) then return "Grass" end
	return nil
end

local function scanMapRegions(bounds)
	local regions = {}
	local folder = Workspace:FindFirstChild("WorldMapMarkers")
	if not folder then return regions end
	for _, inst in ipairs(folder:GetDescendants()) do
		if inst:IsA("BasePart") then
			local material = regionMaterialFor(inst)
			if material then
				local min = normalizeToBounds(inst.Position - (inst.Size * 0.5), bounds)
				local max = normalizeToBounds(inst.Position + (inst.Size * 0.5), bounds)
				table.insert(regions, {
					Name = inst.Name,
					Material = material,
					Rect = {
						X = math.min(min.X, max.X),
						Y = math.min(min.Y, max.Y),
						W = math.abs(max.X - min.X),
						H = math.abs(max.Y - min.Y),
					},
				})
			end
		end
	end
	return regions
end

local function prettyStructureName(name)
	local text = tostring(name or "Structure")
	text = text:gsub("_", " ")
	text = text:gsub("(%l)(%u)", "%1 %2")
	return text
end

local function structureIconFor(name, inst)
	local explicit = inst and inst:GetAttribute("MapIcon")
	if explicit and tostring(explicit) ~= "" then return tostring(explicit) end
	local lower = string.lower(tostring(name or ""))
	if lower:find("city", 1, true) or lower:find("claim", 1, true) then return "Sword" end
	if lower:find("camp", 1, true) or lower:find("fort", 1, true) or lower:find("dungeon", 1, true) or lower:find("boss", 1, true) then return "Sword" end
	return "Sword"
end

local function structurePosition(inst)
	if inst:IsA("Model") then
		local ok, cf = pcall(function()
			return inst:GetBoundingBox()
		end)
		if ok and typeof(cf) == "CFrame" then
			return cf.Position
		end
		return inst:GetPivot().Position
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	return nil
end

local function structureFolders()
	local folders = {}
	for _, root in ipairs(generatedRoots()) do
		local structures = root:FindFirstChild("Structures")
		if structures then table.insert(folders, structures) end
	end
	for _, name in ipairs({ "Structures", "WorldStructures", "MapStructures" }) do
		local folder = Workspace:FindFirstChild(name)
		if folder then table.insert(folders, folder) end
	end
	return folders
end

local function scanStructures(bounds)
	local structures = {}
	local seen = {}
	for _, folder in ipairs(structureFolders()) do
		for _, inst in ipairs(folder:GetChildren()) do
			if not seen[inst] and inst:GetAttribute("MapHidden") ~= true then
				seen[inst] = true
				local pos = structurePosition(inst)
				if pos then
					local displayName = inst:GetAttribute("DisplayName") or inst:GetAttribute("MapName") or prettyStructureName(inst.Name)
					table.insert(structures, {
						Name = tostring(displayName),
						RawName = inst.Name,
						Icon = structureIconFor(displayName, inst),
						Position = normalizeToBounds(pos, bounds),
						WorldPosition = { X = pos.X, Y = pos.Y, Z = pos.Z },
					})
				end
			end
		end
	end
	table.sort(structures, function(a, b) return tostring(a.Name) < tostring(b.Name) end)
	return structures
end

local function addBand(out, side, kind, thickness)
	table.insert(out, { Side = side, Kind = kind, Thickness = thickness or EDGE_BAND_FRACTION })
end

local function hasAnyEnabled(sideTable)
	for _, enabled in pairs(type(sideTable) == "table" and sideTable or {}) do
		if enabled then return true end
	end
	return false
end

local function buildEdgeBands(currentMap, summary)
	local bands = {}
	local ocean = type(currentMap.Ocean) == "table" and currentMap.Ocean or {}
	local mountains = type(currentMap.Mountains) == "table" and currentMap.Mountains or {}
	local desert = type(currentMap.Desert) == "table" and currentMap.Desert or {}
	local explicitEdges = hasAnyEnabled(ocean) or hasAnyEnabled(mountains) or hasAnyEnabled(desert)
	if not explicitEdges and tostring(summary.BorderType or ""):lower() == "ocean" then
		for _, side in ipairs({ "North", "South", "East", "West" }) do addBand(bands, side, "Ocean") end
	end
	for side, enabled in pairs(ocean) do if enabled then addBand(bands, side, "Ocean") end end
	for side, enabled in pairs(desert) do if enabled then addBand(bands, side, "Desert") end end
	for side, enabled in pairs(mountains) do if enabled then addBand(bands, side, "Mountain", EDGE_BAND_FRACTION * 1.1) end end
	return bands
end

local function currentGeneratedSummary()
	local mapConfig = readGeneratedConfig()
	if type(mapConfig) ~= "table" then return {} end
	local border = mapConfig.Border or {}
	local roads = mapConfig.Roads or {}
	return {
		Biome = mapConfig.Biome,
		DominantMaterial = mapConfig.Biome,
		BorderType = border.Type,
		OceanSeaLevel = border.OceanSeaLevel,
		RoadStyle = roads.Style,
		RoadWidthStuds = roads.WidthStuds,
		Seed = mapConfig.Seed,
	}
end

local function generatedCacheToken(bounds)
	local runId = ""
	for _, root in ipairs(generatedRoots()) do
		runId = tostring(root:GetAttribute("GenerationPluginRunId") or root:GetAttribute("GenerationRunId") or runId)
		if runId ~= "" then break end
	end
	return string.format("%s:%.1f:%.1f:%.1f:%.1f", runId, bounds.MinX, bounds.MaxX, bounds.MinZ, bounds.MaxZ)
end

function WorldMapService.GetLocalSnapshot(force)
	local rawBounds = boundsFromConfig()
	local currentMap = WorldConfig.GetCurrentMap() or {}
	local mapKey = WorldConfig.GetCurrentMapKey()
	local cacheKey = tostring(mapKey) .. ":" .. generatedCacheToken(rawBounds)
	if not force and cachedLocalSnapshots[cacheKey] then
		return cachedLocalSnapshots[cacheKey]
	end
	local summary = currentGeneratedSummary()
	local samples, sampleCols, sampleRows = sampleTerrain(rawBounds, currentMap.DominantMaterial or summary.DominantMaterial or currentMap.Biome or summary.Biome)
	local bounds = rawBounds
	samples, bounds, sampleCols, sampleRows = trimEmptySampleMargins(samples, rawBounds)
	local snapshot = {
		Mode = "Local",
		MapKey = mapKey,
		DisplayName = currentMap.DisplayName or summary.DisplayName or "Current Map",
		RegionKey = currentMap.RegionKey or WorldConfig.DefaultLogicalRegion,
		Bounds = bounds,
		RawBounds = rawBounds,
		SampleSize = math.max(sampleCols, sampleRows),
		SampleCols = sampleCols,
		SampleRows = sampleRows,
		StudsPerSample = math.max(bounds.Width / math.max(1, sampleCols), bounds.Depth / math.max(1, sampleRows)),
		Samples = samples,
		Regions = scanMapRegions(bounds),
		Structures = scanStructures(bounds),
		PurityInfo = buildPurityInfo(currentMap),
		EdgeBands = buildEdgeBands(currentMap, summary),
		Exits = scanExits(bounds),
		Summary = summary,
		CacheKey = cacheKey,
		ServerTime = os.time(),
	}
	cachedLocalSnapshots[cacheKey] = snapshot
	return snapshot
end

function WorldMapService.GetGlobalSnapshot()
	return {
		Mode = "Global",
		CurrentMapKey = WorldConfig.GetCurrentMapKey(),
		Maps = WorldConfig.GetMapsForClient(),
		RegionTimers = WorldConfig.RegionTimers,
		ServerTime = os.time(),
	}
end

function WorldMapService.Start()
	if started then return end
	started = true
	requestRemote.OnServerInvoke = function(player, mode)
		if mode == "Global" then
			return WorldMapService.GetGlobalSnapshot()
		end
		return WorldMapService.GetLocalSnapshot(false)
	end
end

return WorldMapService
