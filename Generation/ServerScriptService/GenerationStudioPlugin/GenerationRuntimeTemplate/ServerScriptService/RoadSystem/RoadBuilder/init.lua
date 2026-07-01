--[[
Name: RoadBuilder
Class: ModuleScript
Original path: game.ServerScriptService.GenerationStudioPlugin.GenerationRuntimeTemplate.ServerScriptService.RoadSystem.RoadBuilder
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Workspace, RunService
Functions: makeBuildYielder, Y, surfaceCacheKey, clamp, lerp, smoothstep01, distance2, normalize2, pointToSegmentDistance, copyPoint, densifyPoints, chaikinSmooth, idxFromCoord, inBounds, sampleHeight, sampleMasks, pointInsidePlayableArea, ensureFolder, cloneVoxelGrid, captureDecorationSnapshot, restorePreviousRoadBuild, getSideType, bridgeStyle, sampleRoadBase, makeTerrainRaycastParams, sampleCurrentTerrainSurface, sampleRoadSurface, roadMaterial, isWaterMaterial, pointIsOverWater, findLastDryPoint, trimPointsBeforeWater, makePart, makeCollider, segmentCFrame, cloneHazardPiece, carveHazardWindow, carveHazardCorridor, segmentTouchesPartXZ, destroyDecorationsAlongPoints, enrichPointsWithSurface, compileRoadPoints, makeAlignedRegion, regionBounds, segmentRoadMaterial, paintRoadStrip, buildRoadRun, buildBridge, buildTunnel, buildPort, buildExitDecoration, M.CompileBlueprint, M.Build, activeYield
Clean source lines: 1097
]]
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Terrain = Workspace.Terrain

local M = {}

local activeYield = function() end
local activeSurfaceCache = nil
local activeSurfaceCacheCell = 4
local activeRaycastParams = nil
local activeTerrainSnapshots = nil

local function makeBuildYielder(sliceSeconds)
	local slice = math.max(0.01, sliceSeconds or 0.035)
	local last = os.clock()
	return function(force)
		if force or os.clock() - last >= slice then
			RunService.Heartbeat:Wait()
			last = os.clock()
		end
	end
end

local function Y(force)
	activeYield(force)
end

local function surfaceCacheKey(x, z, cellSize)
	local cell = math.max(1, cellSize or 4)
	return tostring(math.floor(x / cell + 0.5)) .. ":" .. tostring(math.floor(z / cell + 0.5))
end

local function clamp(x, a, b)
	if x < a then
		return a
	end
	if x > b then
		return b
	end
	return x
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smoothstep01(t)
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function distance2(ax, az, bx, bz)
	local dx = bx - ax
	local dz = bz - az
	return math.sqrt(dx * dx + dz * dz)
end

local function normalize2(x, z)
	local m = math.sqrt(x * x + z * z)
	if m <= 1e-6 then
		return 0, 0
	end
	return x / m, z / m
end

local function pointToSegmentDistance(px, pz, ax, az, bx, bz)
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
	return distance2(px, pz, qx, qz), t, qx, qz
end

local function copyPoint(p)
	return {
		x = p.x,
		y = p.y,
		z = p.z,
		material = p.material,
	}
end

local function densifyPoints(points, spacing)
	if #points <= 1 then
		return points
	end
	local out = { copyPoint(points[1]) }
	for i = 1, #points - 1 do
		Y()
		local a = points[i]
		local b = points[i + 1]
		local length = distance2(a.x, a.z, b.x, b.z)
		if length > 1e-3 then
			local steps = math.max(1, math.ceil(length / math.max(1.5, spacing)))
			for step = 1, steps do
				Y()
				local t = step / steps
				table.insert(out, {
					x = a.x + (b.x - a.x) * t,
					y = (a.y or 0) + ((b.y or 0) - (a.y or 0)) * t,
					z = a.z + (b.z - a.z) * t,
				})
			end
		end
	end
	return out
end

local function chaikinSmooth(points, passes)
	local current = points
	for _ = 1, passes do
		if #current <= 2 then
			break
		end
		local nextPoints = { copyPoint(current[1]) }
		for i = 1, #current - 1 do
			Y()
			local a = current[i]
			local b = current[i + 1]
			table.insert(nextPoints, {
				x = a.x * 0.75 + b.x * 0.25,
				y = (a.y or 0) * 0.75 + (b.y or 0) * 0.25,
				z = a.z * 0.75 + b.z * 0.25,
			})
			table.insert(nextPoints, {
				x = a.x * 0.25 + b.x * 0.75,
				y = (a.y or 0) * 0.25 + (b.y or 0) * 0.75,
				z = a.z * 0.25 + b.z * 0.75,
			})
		end
		table.insert(nextPoints, copyPoint(current[#current]))
		current = nextPoints
	end
	return current
end

local function idxFromCoord(world, value)
	return math.floor((value + world.decoRadius) / world.step) + 1
end

local function inBounds(world, ix, iz)
	return ix >= 1 and ix <= world.sizeCount and iz >= 1 and iz <= world.sizeCount
end

local function sampleHeight(world, x, z)
	local ix = idxFromCoord(world, x)
	local iz = idxFromCoord(world, z)
	if not inBounds(world, ix, iz) then
		return nil, ix, iz
	end
	return world.heights[ix][iz], ix, iz
end

local function sampleMasks(world, x, z)
	local h, ix, iz = sampleHeight(world, x, z)
	if not h then
		return nil
	end
	return {
		height = h,
		ix = ix,
		iz = iz,
		river = (world.riverMask and world.riverMask[ix] and world.riverMask[ix][iz]) or 0,
		canyon = (world.canyonMask and world.canyonMask[ix] and world.canyonMask[ix][iz]) or 0,
		water = world.waterTopAt and world.waterTopAt[ix] and world.waterTopAt[ix][iz] ~= nil,
	}
end

local function pointInsidePlayableArea(world, x, z, pad)
	pad = pad or 0
	local r = (world.playableRadius or 0) - pad
	return x >= -r and x <= r and z >= -r and z <= r
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function cloneVoxelGrid(source, xCount, yCount, zCount)
	local out = table.create(xCount)
	for ix = 1, xCount do
		local srcX = source[ix]
		local outX = table.create(yCount)
		out[ix] = outX
		for iy = 1, yCount do
			local srcY = srcX[iy]
			local outY = table.create(zCount)
			outX[iy] = outY
			for iz = 1, zCount do
				outY[iz] = srcY[iz]
			end
		end
	end
	return out
end

local function captureDecorationSnapshot(world)
	local restore = {
		terrainSnapshots = {},
		decorations = nil,
		decoColliders = nil,
	}
	local root = world.root
	if not root then
		return restore
	end
	local decorations = root:FindFirstChild("Decorations")
	if decorations then
		restore.decorations = decorations:Clone()
	end
	local colliders = root:FindFirstChild("Colliders")
	local decoColliders = colliders and colliders:FindFirstChild("DecorationColliders")
	if decoColliders then
		restore.decoColliders = decoColliders:Clone()
	end
	return restore
end

local function restorePreviousRoadBuild(world)
	local restore = world.lastRoadRestore
	if not restore or not world.root then
		return
	end
	local snapshots = restore.terrainSnapshots or {}
	for i = #snapshots, 1, -1 do
		Y()
		local snapshot = snapshots[i]
		Terrain:WriteVoxels(snapshot.region, snapshot.resolution, snapshot.materials, snapshot.occupancies)
	end
	local roadsRoot = world.root:FindFirstChild("RoadSystemGenerated")
	if roadsRoot then
		roadsRoot:Destroy()
	end
	if restore.decorations then
		local currentDecorations = world.root:FindFirstChild("Decorations")
		if currentDecorations then
			currentDecorations:Destroy()
		end
		local restoredDecorations = restore.decorations:Clone()
		restoredDecorations.Name = "Decorations"
		restoredDecorations.Parent = world.root
	end
	if restore.decoColliders then
		local colliders = world.root:FindFirstChild("Colliders")
		if not colliders then
			colliders = Instance.new("Folder")
			colliders.Name = "Colliders"
			colliders.Parent = world.root
		end
		local currentDecoColliders = colliders:FindFirstChild("DecorationColliders")
		if currentDecoColliders then
			currentDecoColliders:Destroy()
		end
		local restoredDecoColliders = restore.decoColliders:Clone()
		restoredDecoColliders.Name = "DecorationColliders"
		restoredDecoColliders.Parent = colliders
	end
	world.lastRoadRestore = nil
end

local function getSideType(world, side)
	local sideTypes = world.borderSideTypes or {}
	return sideTypes[side] or "none"
end

local function bridgeStyle(world, side)
	if world.biome == "desert" then
		return {
			deck = Enum.Material.Sandstone,
			rail = Enum.Material.Sandstone,
			post = Enum.Material.Sandstone,
		}
	end
	if world.biome == "snow" then
		return {
			deck = Enum.Material.Slate,
			rail = Enum.Material.Slate,
			post = Enum.Material.Rock,
		}
	end
	local sideType = getSideType(world, side)
	if sideType == "desert_abandoned" then
		return {
			deck = Enum.Material.Sandstone,
			rail = Enum.Material.Sandstone,
			post = Enum.Material.Sandstone,
		}
	end
	return {
		deck = Enum.Material.WoodPlanks,
		rail = Enum.Material.Wood,
		post = Enum.Material.Wood,
	}
end

local function sampleRoadBase(world, x, z)
	local h, ix, iz = sampleHeight(world, x, z)
	if not h then
		return nil, nil
	end
	local topMat = nil
	if world.topMatAt and world.topMatAt[ix] then
		topMat = world.topMatAt[ix][iz]
	end
	return h, topMat
end

local function makeTerrainRaycastParams(world)
	local ignore = {}
	if world.root then
		local roadsRoot = world.root:FindFirstChild("RoadSystemGenerated")
		if roadsRoot then
			table.insert(ignore, roadsRoot)
		end
		local decorations = world.root:FindFirstChild("Decorations")
		if decorations then
			table.insert(ignore, decorations)
		end
		local decoColliders = world.root:FindFirstChild("DecorationColliders")
		if decoColliders then
			table.insert(ignore, decoColliders)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false
	return params
end

local function sampleCurrentTerrainSurface(world, x, z)
	Y()
	local cache = activeSurfaceCache
	local cacheKey = nil
	if cache then
		cacheKey = surfaceCacheKey(x, z, activeSurfaceCacheCell)
		local cached = cache[cacheKey]
		if cached ~= nil then
			if cached == false then
				return nil, nil
			end
			return cached.y, cached.material
		end
	end
	local params = activeRaycastParams or makeTerrainRaycastParams(world)
	local originY = math.max((world.baseHeight or 0) + 1200, 1600)
	local result = Workspace:Raycast(Vector3.new(x, originY, z), Vector3.new(0, -4000, 0), params)
	if result and result.Instance == Terrain then
		if cache then
			cache[cacheKey] = { y = result.Position.Y, material = result.Material }
		end
		return result.Position.Y, result.Material
	end
	if cache then
		cache[cacheKey] = false
	end
	return nil, nil
end

local function sampleRoadSurface(world, x, z)
	local liveHeight, liveMaterial = sampleCurrentTerrainSurface(world, x, z)
	if liveHeight ~= nil then
		return liveHeight, liveMaterial
	end
	return sampleRoadBase(world, x, z)
end

local function roadMaterial(world, surfaceMaterial)
	if world.biome == "desert" then
		return Enum.Material.Sandstone
	end
	if world.biome == "snow" then
		return Enum.Material.Ground
	end
	if surfaceMaterial == Enum.Material.Sand or surfaceMaterial == Enum.Material.Sandstone then
		return Enum.Material.Sandstone
	end
	if surfaceMaterial == Enum.Material.Snow or surfaceMaterial == Enum.Material.Glacier or surfaceMaterial == Enum.Material.Ice then
		return Enum.Material.Ground
	end
	return Enum.Material.Mud
end

local function isWaterMaterial(material)
	return material == Enum.Material.Water
end

local function pointIsOverWater(world, x, z)
	local masks = sampleMasks(world, x, z)
	if masks and masks.water then
		return true
	end
	local _, liveMaterial = sampleCurrentTerrainSurface(world, x, z)
	return isWaterMaterial(liveMaterial)
end

local function findLastDryPoint(world, a, b)
	local ax, az = a.x, a.z
	local bx, bz = b.x, b.z
	local dryX, dryZ = ax, az
	for _ = 1, 8 do
		Y()
		local midX = (dryX + bx) * 0.5
		local midZ = (dryZ + bz) * 0.5
		if pointIsOverWater(world, midX, midZ) then
			bx, bz = midX, midZ
		else
			dryX, dryZ = midX, midZ
		end
	end
	return { x = dryX, z = dryZ }
end

local function trimPointsBeforeWater(world, points)
	if #points == 0 then
		return points
	end
	local out = {}
	local lastDry = nil
	for i = 1, #points do
		Y()
		local p = points[i]
		if pointIsOverWater(world, p.x, p.z) then
			if lastDry then
				local shoreline = findLastDryPoint(world, lastDry, p)
				if distance2(lastDry.x, lastDry.z, shoreline.x, shoreline.z) > 0.35 then
					table.insert(out, shoreline)
				end
			end
			break
		end
		table.insert(out, p)
		lastDry = p
	end
	return out
end

local function makePart(parent, name, material, size, cframe, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = false
	p.CanQuery = false
	p.Material = material
	p.Size = size
	p.CFrame = cframe
	if color then
		p.Color = color
	end
	p.Parent = parent
	return p
end

local function makeCollider(parent, name, size, cframe)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.CFrame = cframe
	p.Parent = parent
	return p
end

local function segmentCFrame(a, b, yLift)
	local a3 = Vector3.new(a.x, a.y + yLift, a.z)
	local b3 = Vector3.new(b.x, b.y + yLift, b.z)
	local mid = (a3 + b3) * 0.5
	return CFrame.lookAt(mid, b3, Vector3.yAxis)
end

local function cloneHazardPiece(parent, template, minX, maxX, minZ, maxZ)
	local sx = maxX - minX
	local sz = maxZ - minZ
	if sx <= 0.2 or sz <= 0.2 then
		return
	end
	local p = Instance.new("Part")
	p.Name = template.Name
	p.Anchored = true
	p.CanCollide = template.CanCollide
	p.CanTouch = template.CanTouch
	p.CanQuery = template.CanQuery
	p.Transparency = template.Transparency
	p.Material = template.Material
	p.Color = template.Color
	p.Size = Vector3.new(sx, template.Size.Y, sz)
	p.Position = Vector3.new((minX + maxX) * 0.5, template.Position.Y, (minZ + maxZ) * 0.5)
	p.Parent = parent
end

local function carveHazardWindow(root, minCutX, maxCutX, minCutZ, maxCutZ)
	local colliders = root:FindFirstChild("Colliders")
	if not colliders then
		return
	end
	local hazards = colliders:FindFirstChild("HazardWalls")
	if not hazards then
		return
	end
	for _, part in ipairs(hazards:GetChildren()) do
		Y()
		if part:IsA("BasePart") then
			local minX = part.Position.X - part.Size.X * 0.5
			local maxX = part.Position.X + part.Size.X * 0.5
			local minZ = part.Position.Z - part.Size.Z * 0.5
			local maxZ = part.Position.Z + part.Size.Z * 0.5
			local ix0 = math.max(minX, minCutX)
			local ix1 = math.min(maxX, maxCutX)
			local iz0 = math.max(minZ, minCutZ)
			local iz1 = math.min(maxZ, maxCutZ)
			if ix0 < ix1 and iz0 < iz1 then
				cloneHazardPiece(hazards, part, minX, ix0, minZ, maxZ)
				cloneHazardPiece(hazards, part, ix1, maxX, minZ, maxZ)
				cloneHazardPiece(hazards, part, ix0, ix1, minZ, iz0)
				cloneHazardPiece(hazards, part, ix0, ix1, iz1, maxZ)
				part:Destroy()
			end
		end
	end
end

local function carveHazardCorridor(root, ax, az, bx, bz, width)
	local length = distance2(ax, az, bx, bz)
	if length <= 1 then
		local pad = width * 0.5 + 1.25
		carveHazardWindow(root, ax - pad, ax + pad, az - pad, az + pad)
		return
	end
	local step = math.max(4, math.min(10, width * 0.35))
	local samples = math.max(1, math.ceil(length / step))
	local pad = width * 0.5 + 1.25
	for i = 0, samples do
		Y()
		local t = i / samples
		local x = ax + (bx - ax) * t
		local z = az + (bz - az) * t
		carveHazardWindow(root, x - pad, x + pad, z - pad, z + pad)
	end
	carveHazardWindow(root, ax - pad - step, ax + pad + step, az - pad - step, az + pad + step)
	carveHazardWindow(root, bx - pad - step, bx + pad + step, bz - pad - step, bz + pad + step)
end

local function segmentTouchesPartXZ(part, ax, az, bx, bz, radius)
	local ext = math.sqrt((part.Size.X * 0.5) ^ 2 + (part.Size.Z * 0.5) ^ 2)
	local dist = pointToSegmentDistance(part.Position.X, part.Position.Z, ax, az, bx, bz)
	return dist <= (radius + ext)
end

local function destroyDecorationsAlongPoints(world, settings, points)
	local decorations = world.root and world.root:FindFirstChild("Decorations")
	if not decorations then
		return
	end
	local collidersRoot = world.root and world.root:FindFirstChild("Colliders")
	local decoColliders = collidersRoot and collidersRoot:FindFirstChild("DecorationColliders") or nil
	local roadWidth = settings.roadWidth or 22
	local corridorRadius = math.max(roadWidth * 0.58, 7)
	local destroyRadius = corridorRadius + 1.5
	local models = {}
	for _, child in ipairs(decorations:GetChildren()) do
		Y()
		if child:IsA("Model") then
			models[#models + 1] = child
		elseif child:IsA("BasePart") then
			models[#models + 1] = child
		end
	end
	local toDestroy = {}
	for i = 1, #points - 1 do
		Y()
		local a = points[i]
		local b = points[i + 1]
		for _, inst in ipairs(models) do
			Y()
			if not toDestroy[inst] then
				if inst:IsA("Model") then
					for _, part in ipairs(inst:GetDescendants()) do
						if part:IsA("BasePart") and segmentTouchesPartXZ(part, a.x, a.z, b.x, b.z, destroyRadius) then
							toDestroy[inst] = true
							break
						end
					end
				elseif inst:IsA("BasePart") then
					if segmentTouchesPartXZ(inst, a.x, a.z, b.x, b.z, destroyRadius) then
						toDestroy[inst] = true
					end
				end
			end
		end
	end
	if not next(toDestroy) then
		return
	end
	for inst in pairs(toDestroy) do
		Y()
		if decoColliders then
			local bbCf, bbSize
			if inst:IsA("Model") then
				bbCf, bbSize = inst:GetBoundingBox()
			else
				bbCf, bbSize = inst.CFrame, inst.Size
			end
			local halfX = bbSize.X * 0.5 + corridorRadius + 2
			local halfZ = bbSize.Z * 0.5 + corridorRadius + 2
			for _, collider in ipairs(decoColliders:GetChildren()) do
				Y()
				if collider:IsA("BasePart") then
					local dx = math.abs(collider.Position.X - bbCf.Position.X)
					local dz = math.abs(collider.Position.Z - bbCf.Position.Z)
					if dx <= halfX and dz <= halfZ then
						collider:Destroy()
					end
				end
			end
		end
		inst:Destroy()
	end
end

local function enrichPointsWithSurface(world, points, smoothPasses)
	local out = table.create(#points)
	local lastY = world.baseHeight or 0
	local lastMaterial = nil
	for i = 1, #points do
		Y()
		local p = points[i]
		local y, material = sampleRoadSurface(world, p.x, p.z)
		if y == nil then
			y = lastY
			material = material or lastMaterial
		end
		out[i] = {
			x = p.x,
			y = y,
			z = p.z,
			material = material,
		}
		lastY = y
		lastMaterial = material
	end
	for _ = 1, smoothPasses or 0 do
		if #out <= 2 then
			break
		end
		local nextPoints = table.create(#out)
		nextPoints[1] = copyPoint(out[1])
		for i = 2, #out - 1 do
			Y()
			local prev = out[i - 1]
			local cur = out[i]
			local nxt = out[i + 1]
			nextPoints[i] = {
				x = cur.x,
				y = (prev.y + cur.y * 2 + nxt.y) * 0.25,
				z = cur.z,
				material = cur.material,
			}
		end
		nextPoints[#out] = copyPoint(out[#out])
		out = nextPoints
	end
	return out
end

local function compileRoadPoints(world, settings, points)
	local runPoints = points
	local roadWidth = settings.roadWidth or 22
	local curveStep = settings.roadBlueprintSpacing or settings.roadCurveStep or math.max(2.5, roadWidth * 0.16)
	if #points >= 3 then
		runPoints = chaikinSmooth(points, settings.roadSmoothPasses or 2)
		runPoints = densifyPoints(runPoints, curveStep)
	else
		runPoints = densifyPoints(points, curveStep)
	end
	return enrichPointsWithSurface(world, runPoints, settings.roadHeightSmoothPasses or 2)
end

local function makeAlignedRegion(minX, minY, minZ, maxX, maxY, maxZ, resolution)
	if maxX < minX then
		minX, maxX = maxX, minX
	end
	if maxY < minY then
		minY, maxY = maxY, minY
	end
	if maxZ < minZ then
		minZ, maxZ = maxZ, minZ
	end
	local region = Region3.new(Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ))
	return region:ExpandToGrid(resolution)
end

local function regionBounds(region)
	local size = region.Size
	local center = region.CFrame.Position
	local half = size * 0.5
	return center - half, center + half, size
end

local function segmentRoadMaterial(world, a, b, t)
	local mat = (t <= 0.5 and a.material) or b.material or a.material
	return roadMaterial(world, mat)
end

local function paintRoadStrip(world, settings, a, b)
	local length = distance2(a.x, a.z, b.x, b.z)
	if length <= 0.5 then
		return
	end
	if a.y == nil then
		a.y = sampleRoadSurface(world, a.x, a.z) or world.baseHeight or 0
	end
	if b.y == nil then
		b.y = sampleRoadSurface(world, b.x, b.z) or a.y or world.baseHeight or 0
	end
	local resolution = settings.roadVoxelResolution or 4
	local roadWidth = math.max(4, settings.roadWidth or 22)
	local paintRadius = roadWidth * 0.5
	local paintDepth = math.max(resolution, settings.roadPaintDepth or 8)
	local voxelPad = settings.roadVoxelPad or 4
	local roadLift = settings.roadLift or 0
	local region = makeAlignedRegion(
		math.min(a.x, b.x) - paintRadius - voxelPad,
		math.min(a.y, b.y) - paintDepth - voxelPad,
		math.min(a.z, b.z) - paintRadius - voxelPad,
		math.max(a.x, b.x) + paintRadius + voxelPad,
		math.max(a.y, b.y) + resolution + voxelPad,
		math.max(a.z, b.z) + paintRadius + voxelPad,
		resolution
	)
	local materials, occupancies = Terrain:ReadVoxels(region, resolution)
	local minBound, _, size = regionBounds(region)
	local xCount = math.max(0, math.floor(size.X / resolution + 0.5))
	local yCount = math.max(0, math.floor(size.Y / resolution + 0.5))
	local zCount = math.max(0, math.floor(size.Z / resolution + 0.5))
	local snapshot = nil
	if activeTerrainSnapshots and xCount > 0 and yCount > 0 and zCount > 0 then
		snapshot = {
			region = region,
			resolution = resolution,
			materials = cloneVoxelGrid(materials, xCount, yCount, zCount),
			occupancies = cloneVoxelGrid(occupancies, xCount, yCount, zCount),
		}
	end
	local changed = false
	for ix = 1, xCount do
		Y()
		local wx = minBound.X + (ix - 0.5) * resolution
		local mx = materials[ix]
		local ox = occupancies[ix]
		for iz = 1, zCount do
			local wz = minBound.Z + (iz - 0.5) * resolution
			local lateral, t = pointToSegmentDistance(wx, wz, a.x, a.z, b.x, b.z)
			if lateral <= paintRadius and not pointIsOverWater(world, wx, wz) then
				local surfaceY = lerp(a.y, b.y, t) + roadLift
				local liveY, liveMaterial = sampleRoadSurface(world, wx, wz)
				if liveY ~= nil and not isWaterMaterial(liveMaterial) then
					surfaceY = liveY + roadLift
				end
				local roadMat = segmentRoadMaterial(world, a, b, t)
				for iy = yCount, 1, -1 do
					local occupancy = ox[iy][iz]
					if occupancy > 0.05 then
						local wy = minBound.Y + (iy - 0.5) * resolution
						if wy <= (surfaceY + resolution) then
							for jy = iy, 1, -1 do
								local jyOccupancy = ox[jy][iz]
								local jyY = minBound.Y + (jy - 0.5) * resolution
								if jyOccupancy <= 0.05 or (surfaceY - jyY) > paintDepth then
									break
								end
								if not isWaterMaterial(mx[jy][iz]) and mx[jy][iz] ~= roadMat then
									mx[jy][iz] = roadMat
									changed = true
								end
							end
							break
						end
					end
				end
			end
		end
	end
	if changed then
		if snapshot then
			activeTerrainSnapshots[#activeTerrainSnapshots + 1] = snapshot
		end
		Terrain:WriteVoxels(region, resolution, materials, occupancies)
	end
end

local function buildRoadRun(folder, world, settings, compiled)
	local points = compiled.points or compiled
	if #points < 2 then
		return
	end
	destroyDecorationsAlongPoints(world, settings, points)
	for i = 1, #points - 1 do
		Y()
		paintRoadStrip(world, settings, points[i], points[i + 1])
	end
end

local function buildBridge(folder, world, settings, points, side)
	local style = bridgeStyle(world, side)
	local runDeckY = nil
	for i = 1, #points do
		Y()
		local p = points[i]
		local sample = sampleMasks(world, p.x, p.z)
		if sample then
			local candidate = sample.height + settings.bridgeDeckLift
			if runDeckY == nil or candidate > runDeckY then
				runDeckY = candidate
			end
		end
	end
	if runDeckY == nil then
		return
	end
	for i = 1, #points - 1 do
		local a = points[i]
		local b = points[i + 1]
		local sa = sampleMasks(world, a.x, a.z)
		local sb = sampleMasks(world, b.x, b.z)
		if sa and sb then
			local deckY = runDeckY - (settings.bridgeDeckEmbed or 1.35)
			local length = distance2(a.x, a.z, b.x, b.z)
			if length > 1 then
				local deckA = { x = a.x, y = deckY, z = a.z }
				local deckB = { x = b.x, y = deckY, z = b.z }
				local deckCf = segmentCFrame(deckA, deckB, 0)
				local roadWidth = settings.roadWidth or 22
				local deckWidth = roadWidth + (settings.bridgeExtraWidth or 8)
				makePart(folder, "BridgeDeck", style.deck, Vector3.new(deckWidth, 1.4, length), deckCf)
				makeCollider(folder, "BridgeSafetyFloor", Vector3.new(deckWidth + 1.5, 5, length + 2), deckCf * CFrame.new(0, -2.1, 0))
				local railOffset = deckWidth * 0.5 - 1.2
				local railHeight = 2.6
				local sideWallThickness = settings.bridgeSideWallThickness or 2.6
				local sideWallHeight = settings.bridgeSideWallHeight or 6
				local sideWallOffset = settings.bridgeSideWallOffset or 0.8
				local dx, dz = normalize2(b.x - a.x, b.z - a.z)
				local px, pz = -dz, dx
				local midX = (a.x + b.x) * 0.5
				local midZ = (a.z + b.z) * 0.5
				local railLen = length
				local leftCf = CFrame.lookAt(Vector3.new(midX + px * railOffset, deckY + railHeight, midZ + pz * railOffset), Vector3.new(midX + px * railOffset + dx, deckY + railHeight, midZ + pz * railOffset + dz), Vector3.yAxis)
				local rightCf = CFrame.lookAt(Vector3.new(midX - px * railOffset, deckY + railHeight, midZ - pz * railOffset), Vector3.new(midX - px * railOffset + dx, deckY + railHeight, midZ - pz * railOffset + dz), Vector3.yAxis)
				makePart(folder, "BridgeRail", style.rail, Vector3.new(0.6, 1.2, railLen), leftCf)
				makePart(folder, "BridgeRail", style.rail, Vector3.new(0.6, 1.2, railLen), rightCf)
				makeCollider(folder, "BridgeSideBlocker", Vector3.new(sideWallThickness, sideWallHeight, railLen + 2), leftCf * CFrame.new(sideWallOffset, -0.5, 0))
				makeCollider(folder, "BridgeSideBlocker", Vector3.new(sideWallThickness, sideWallHeight, railLen + 2), rightCf * CFrame.new(-sideWallOffset, -0.5, 0))
				local posts = math.max(1, math.floor(length / settings.bridgePostGap))
				for p = 0, posts do
					Y()
					local t = p / posts
					local x = a.x + (b.x - a.x) * t
					local z = a.z + (b.z - a.z) * t
					local ground = sampleRoadSurface(world, x, z)
					if ground then
						local postY = (deckY + ground) * 0.5
						local postH = math.max(4, deckY - ground)
						makePart(folder, "BridgePost", style.post, Vector3.new(1.2, postH, 1.2), CFrame.new(x, postY, z))
					end
				end
				local clearWidth = math.min(deckWidth - 4.5, settings.bridgeHazardClearWidth or math.max(roadWidth + 2, deckWidth - 6))
				carveHazardCorridor(world.root, a.x, a.z, b.x, b.z, clearWidth)
				makeCollider(folder, "BridgeEntrySeal", Vector3.new(deckWidth + 2.5, 7, 12), CFrame.lookAt(Vector3.new(a.x - dx * 2.5, deckY - 1.6, a.z - dz * 2.5), Vector3.new(a.x + dx, deckY - 1.6, a.z + dz), Vector3.yAxis))
				makeCollider(folder, "BridgeExitSeal", Vector3.new(deckWidth + 2.5, 7, 12), CFrame.lookAt(Vector3.new(b.x + dx * 2.5, deckY - 1.6, b.z + dz * 2.5), Vector3.new(b.x + dx * 3.5, deckY - 1.6, b.z + dz * 3.5), Vector3.yAxis))
			end
		end
	end
end

local function buildTunnel(folder, world, settings, tunnel)
	local dirX, dirZ = tunnel.dir.x, tunnel.dir.z
	local mouthX = tunnel.x - dirX * 8
	local mouthZ = tunnel.z - dirZ * 8
	local h = sampleRoadSurface(world, mouthX, mouthZ)
	if not h then
		return
	end
	local radius = settings.tunnelRadius
	local depth = settings.tunnelDepth
	for i = 0, math.floor(depth / 8) do
		Y()
		local px = mouthX + dirX * (i * 8)
		local pz = mouthZ + dirZ * (i * 8)
		Terrain:FillBall(Vector3.new(px, h + radius * 0.25, pz), radius, Enum.Material.Air)
		Terrain:FillBall(Vector3.new(px, h - radius * 0.55, pz), radius * 0.9, Enum.Material.Air)
	end
	local lipCf = CFrame.lookAt(Vector3.new(mouthX, h + radius * 0.35, mouthZ), Vector3.new(mouthX + dirX, h + radius * 0.35, mouthZ + dirZ), Vector3.yAxis)
	makePart(folder, "TunnelLipTop", Enum.Material.Rock, Vector3.new(radius * 2.4, 3, 2), lipCf * CFrame.new(0, radius * 0.6, 0))
	makePart(folder, "TunnelLipBottom", Enum.Material.Rock, Vector3.new(radius * 2.0, 2, 2), lipCf * CFrame.new(0, -radius * 0.65, 0))
	makePart(folder, "TunnelLipLeft", Enum.Material.Rock, Vector3.new(2, radius * 1.8, 2), lipCf * CFrame.new(-radius * 0.95, 0, 0))
	makePart(folder, "TunnelLipRight", Enum.Material.Rock, Vector3.new(2, radius * 1.8, 2), lipCf * CFrame.new(radius * 0.95, 0, 0))
end

local function buildPort(folder, world, settings, shorePoint, dirX, dirZ)
	if not shorePoint then
		return
	end
	dirX, dirZ = normalize2(dirX, dirZ)
	if dirX == 0 and dirZ == 0 then
		return
	end
	local groundY = sampleRoadSurface(world, shorePoint.x, shorePoint.z) or shorePoint.y or world.baseHeight or 0
	local deckY = groundY + (settings.portDeckLift or 2.4)
	local length = settings.portLength or 76
	local roadWidth = settings.roadWidth or 22
	local width = math.max(roadWidth + 10, settings.portWidth or 34)
	local startOffset = math.max(8, roadWidth * 0.35)
	local centerX = shorePoint.x + dirX * (startOffset + length * 0.5)
	local centerZ = shorePoint.z + dirZ * (startOffset + length * 0.5)
	local cf = CFrame.lookAt(Vector3.new(centerX, deckY, centerZ), Vector3.new(centerX + dirX, deckY, centerZ + dirZ), Vector3.yAxis)
	makePart(folder, "PortDock", Enum.Material.WoodPlanks, Vector3.new(width, 1.35, length), cf)

	local px, pz = -dirZ, dirX
	local railOffset = width * 0.5 - 1.2
	local railY = deckY + 2.2
	local leftCf = CFrame.lookAt(Vector3.new(centerX + px * railOffset, railY, centerZ + pz * railOffset), Vector3.new(centerX + px * railOffset + dirX, railY, centerZ + pz * railOffset + dirZ), Vector3.yAxis)
	local rightCf = CFrame.lookAt(Vector3.new(centerX - px * railOffset, railY, centerZ - pz * railOffset), Vector3.new(centerX - px * railOffset + dirX, railY, centerZ - pz * railOffset + dirZ), Vector3.yAxis)
	makePart(folder, "PortRail", Enum.Material.Wood, Vector3.new(0.7, 1.2, length), leftCf)
	makePart(folder, "PortRail", Enum.Material.Wood, Vector3.new(0.7, 1.2, length), rightCf)

	local postCount = 4
	for i = 0, postCount do
		Y()
		local t = i / postCount
		local x = shorePoint.x + dirX * (startOffset + length * t)
		local z = shorePoint.z + dirZ * (startOffset + length * t)
		for _, side in ipairs({ -1, 1 }) do
			makePart(folder, "PortPost", Enum.Material.Wood, Vector3.new(1.4, 8, 1.4), CFrame.new(x + px * railOffset * side, deckY - 3.6, z + pz * railOffset * side))
		end
	end
end

local function buildExitDecoration(folder, world, settings, ext)
	local points = ext.points
	local sideType = getSideType(world, ext.side)
	local shorelinePoint = nil
	if ext.compiledPoints and #ext.compiledPoints >= 2 then
		local runPoints = ext.compiledPoints
		if sideType == "ocean" then
			runPoints = trimPointsBeforeWater(world, runPoints)
		end
		if #runPoints >= 2 then
			buildRoadRun(folder, world, settings, runPoints)
			shorelinePoint = runPoints[#runPoints]
		end
	end
	local last = points[#points]
	local prev = points[#points - 1]
	if not last or not prev then
		return
	end
	local dx, dz = normalize2(last.x - prev.x, last.z - prev.z)
	if sideType == "ocean" then
		buildPort(folder, world, settings, shorelinePoint or prev, dx, dz)
		return
	elseif sideType == "mountains" or sideType == "mountains_heavy" then
		local h = sampleRoadSurface(world, prev.x, prev.z)
		if h then
			for i = 0, 5 do
				Y()
				local x = prev.x + dx * (i * 10)
				local z = prev.z + dz * (i * 10)
				Terrain:FillBall(Vector3.new(x, h + 10, z), (settings.roadWidth or 22) * 0.6, Enum.Material.Air)
			end
		end
	end
end

function M.CompileBlueprint(world, planResult)
	local settings = planResult.plan.settings
	local previousYield = activeYield
	local previousSurfaceCache = activeSurfaceCache
	local previousSurfaceCacheCell = activeSurfaceCacheCell
	local previousRaycastParams = activeRaycastParams
	activeYield = makeBuildYielder(settings.roadBuildYieldSlice or 0.035)
	restorePreviousRoadBuild(world)
	activeSurfaceCache = {}
	activeSurfaceCacheCell = settings.roadSurfaceCacheCell or 4
	activeRaycastParams = makeTerrainRaycastParams(world)
	local blueprint = {
		settings = settings,
		landRuns = {},
		bridgeRuns = {},
		tunnels = {},
		exterior = {},
	}
	for _, tunnel in ipairs(planResult.tunnelTerminals or {}) do
		Y()
		blueprint.tunnels[#blueprint.tunnels + 1] = tunnel
	end
	for _, run in ipairs(planResult.runs or {}) do
		Y()
		if #run.points >= 2 then
			if run.kind == "road" then
				blueprint.landRuns[#blueprint.landRuns + 1] = {
					kind = run.kind,
					points = compileRoadPoints(world, settings, run.points),
				}
			elseif run.kind == "bridge_river" or run.kind == "bridge_canyon" then
				blueprint.bridgeRuns[#blueprint.bridgeRuns + 1] = run
			end
		end
	end
	for _, ext in ipairs(planResult.exterior or {}) do
		Y()
		local compiled = nil
		if ext.points and #ext.points >= 2 then
			compiled = compileRoadPoints(world, settings, ext.points)
		end
		blueprint.exterior[#blueprint.exterior + 1] = {
			kind = ext.kind,
			side = ext.side,
			points = ext.points,
			compiledPoints = compiled,
		}
	end
	activeYield = previousYield
	activeSurfaceCache = previousSurfaceCache
	activeSurfaceCacheCell = previousSurfaceCacheCell
	activeRaycastParams = previousRaycastParams
	return blueprint
end

function M.Build(world, planResult, blueprint)
	local settings = (blueprint and blueprint.settings) or (planResult.plan and planResult.plan.settings) or {}
	local previousYield = activeYield
	local previousSurfaceCache = activeSurfaceCache
	local previousSurfaceCacheCell = activeSurfaceCacheCell
	local previousRaycastParams = activeRaycastParams
	local previousTerrainSnapshots = activeTerrainSnapshots
	activeYield = makeBuildYielder(settings.roadBuildYieldSlice or 0.035)
	restorePreviousRoadBuild(world)
	activeSurfaceCache = {}
	activeSurfaceCacheCell = settings.roadSurfaceCacheCell or 4
	activeRaycastParams = makeTerrainRaycastParams(world)
	blueprint = blueprint or M.CompileBlueprint(world, planResult)
	local root = world.root
	local restore = captureDecorationSnapshot(world)
	activeTerrainSnapshots = restore.terrainSnapshots
	local roadsRoot = ensureFolder(root, "RoadSystemGenerated")
	roadsRoot:ClearAllChildren()
	Y(true)
	local roadFolder = ensureFolder(roadsRoot, "Roads")
	local bridgeFolder = ensureFolder(roadsRoot, "Bridges")
	local tunnelFolder = ensureFolder(roadsRoot, "Tunnels")
	local exitFolder = ensureFolder(roadsRoot, "Exits")
	for _, tunnel in ipairs(blueprint.tunnels or {}) do
		Y()
		buildTunnel(tunnelFolder, world, blueprint.settings, tunnel)
	end
	for _, run in ipairs(blueprint.landRuns or {}) do
		Y()
		buildRoadRun(roadFolder, world, blueprint.settings, run)
	end
	for _, run in ipairs(blueprint.bridgeRuns or {}) do
		Y()
		buildBridge(bridgeFolder, world, blueprint.settings, run.points, nil)
	end
	for _, ext in ipairs(blueprint.exterior or {}) do
		Y()
		buildExitDecoration(exitFolder, world, blueprint.settings, ext)
	end
	world.lastRoadRestore = restore
	activeYield = previousYield
	activeSurfaceCache = previousSurfaceCache
	activeSurfaceCacheCell = previousSurfaceCacheCell
	activeRaycastParams = previousRaycastParams
	activeTerrainSnapshots = previousTerrainSnapshots
	return roadsRoot
end

return M