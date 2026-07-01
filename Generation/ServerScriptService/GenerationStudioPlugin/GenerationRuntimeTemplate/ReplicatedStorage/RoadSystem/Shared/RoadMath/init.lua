--[[
Name: RoadMath
Class: ModuleScript
Original path: game.ServerScriptService.GenerationStudioPlugin.GenerationRuntimeTemplate.ReplicatedStorage.RoadSystem.Shared.RoadMath
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: M.Clamp, M.Lerp, M.Smoothstep, M.Distance2, M.Normalize2, M.Perp2, M.RoundToInt, M.HashKey, M.PointToSegmentDistance, M.PathLength, M.ResamplePolyline, M.Chaikin
Clean source lines: 132
]]
local M = {}

function M.Clamp(x, a, b)
	if x < a then
		return a
	end
	if x > b then
		return b
	end
	return x
end

function M.Lerp(a, b, t)
	return a + (b - a) * t
end

function M.Smoothstep(t)
	t = M.Clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function M.Distance2(ax, az, bx, bz)
	local dx = bx - ax
	local dz = bz - az
	return math.sqrt(dx * dx + dz * dz)
end

function M.Normalize2(x, z)
	local m = math.sqrt(x * x + z * z)
	if m <= 1e-6 then
		return 0, 0
	end
	return x / m, z / m
end

function M.Perp2(x, z)
	return -z, x
end

function M.RoundToInt(x)
	if x >= 0 then
		return math.floor(x + 0.5)
	end
	return math.ceil(x - 0.5)
end

function M.HashKey(ix, iz)
	return tostring(ix) .. ":" .. tostring(iz)
end

function M.PointToSegmentDistance(px, pz, ax, az, bx, bz)
	local abx = bx - ax
	local abz = bz - az
	local apx = px - ax
	local apz = pz - az
	local ab2 = abx * abx + abz * abz
	local t = 0
	if ab2 > 1e-6 then
		t = M.Clamp((apx * abx + apz * abz) / ab2, 0, 1)
	end
	local qx = ax + abx * t
	local qz = az + abz * t
	return M.Distance2(px, pz, qx, qz), t, qx, qz
end

function M.PathLength(points)
	local total = 0
	for i = 1, #points - 1 do
		local a = points[i]
		local b = points[i + 1]
		total += M.Distance2(a.x, a.z, b.x, b.z)
	end
	return total
end

function M.ResamplePolyline(points, spacing)
	if #points <= 1 then
		return points
	end
	local out = { { x = points[1].x, z = points[1].z } }
	local carry = 0
	for i = 1, #points - 1 do
		local a = points[i]
		local b = points[i + 1]
		local segLen = M.Distance2(a.x, a.z, b.x, b.z)
		if segLen > 1e-6 then
			local dirX = (b.x - a.x) / segLen
			local dirZ = (b.z - a.z) / segLen
			local d = spacing - carry
			while d < segLen do
				out[#out + 1] = {
					x = a.x + dirX * d,
					z = a.z + dirZ * d,
				}
				d += spacing
			end
			carry = math.max(0, segLen - (d - spacing))
		else
			carry = 0
		end
	end
	local last = points[#points]
	out[#out + 1] = { x = last.x, z = last.z }
	return out
end

function M.Chaikin(points, iterations)
	local current = points
	for _ = 1, iterations do
		if #current <= 2 then
			break
		end
		local nextPoints = { { x = current[1].x, z = current[1].z } }
		for i = 1, #current - 1 do
			local a = current[i]
			local b = current[i + 1]
			nextPoints[#nextPoints + 1] = {
				x = M.Lerp(a.x, b.x, 0.25),
				z = M.Lerp(a.z, b.z, 0.25),
			}
			nextPoints[#nextPoints + 1] = {
				x = M.Lerp(a.x, b.x, 0.75),
				z = M.Lerp(a.z, b.z, 0.75),
			}
		end
		nextPoints[#nextPoints + 1] = { x = current[#current].x, z = current[#current].z }
		current = nextPoints
	end
	return current
end

return M