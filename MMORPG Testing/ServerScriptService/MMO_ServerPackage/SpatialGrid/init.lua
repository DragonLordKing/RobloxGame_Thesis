--[[
Name: SpatialGrid
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.SpatialGrid
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: keyFromXZ, bucket, M.Add, M.Remove, M.Update, M.Query
Clean source lines: 82
]]
local CELL      = 35
local INV_CELL  = 1 / CELL

local Grid      = {}
local LastCell  = {}


local function keyFromXZ(x, z)
	return math.floor(x * INV_CELL) .. ":" .. math.floor(z * INV_CELL)
end

local function bucket(key)
	local b = Grid[key]
	if not b then
		b = {}
		Grid[key] = b
	end
	return b
end


local M = {}

function M.Add(model)
	local root = model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildWhichIsA("BasePart")
	if not root then return end

	local key = keyFromXZ(root.Position.X, root.Position.Z)
	bucket(key)[model] = true
	LastCell[model]    = key
end

function M.Remove(model)
	local key = LastCell[model]
	if key and Grid[key] then
		Grid[key][model] = nil
	end
	LastCell[model] = nil
end

function M.Update(model)
	local root = model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildWhichIsA("BasePart")
	if not root then return end

	local newKey = keyFromXZ(root.Position.X, root.Position.Z)
	local oldKey = LastCell[model]

	if newKey ~= oldKey then

		if oldKey and Grid[oldKey] then
			Grid[oldKey][model] = nil
		end

		bucket(newKey)[model] = true
		LastCell[model] = newKey
	end
end


function M.Query(centerXZ, radius)
	local radCells = math.ceil(radius * INV_CELL)
	local ix0 = math.floor((centerXZ.X - radius) * INV_CELL)
	local iz0 = math.floor((centerXZ.Z - radius) * INV_CELL)
	local hits = {}

	for ix = ix0, ix0 + radCells * 2 do
		for iz = iz0, iz0 + radCells * 2 do
			local b = Grid[ix .. ":" .. iz]
			if b then
				for mdl in pairs(b) do
					hits[#hits+1] = mdl
				end
			end
		end
	end
	return hits
end

return M
