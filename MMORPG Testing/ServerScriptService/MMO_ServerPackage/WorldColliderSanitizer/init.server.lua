--[[
Name: WorldColliderSanitizer
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.WorldColliderSanitizer
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Workspace
Functions: containsHelperPattern, getGeneratedColliders, isGeneratedHelperPart, sanitizePart, sanitizeRoot, sanitizeExisting
Clean source lines: 89
]]
local Workspace = game:GetService("Workspace")

local GENERATED_WORLD_NAME = "GeneratedWorld"
local COLLIDERS_NAME = "Colliders"

local HELPER_NAME_PATTERNS = {
	"collider",
	"reserved",
	"zone",
	"boundary",
	"wall",
}

local function containsHelperPattern(name)
	local lower = string.lower(name or "")
	for _, pattern in ipairs(HELPER_NAME_PATTERNS) do
		if string.find(lower, pattern, 1, true) then
			return true
		end
	end
	return false
end

local function getGeneratedColliders()
	local generatedWorld = Workspace:FindFirstChild(GENERATED_WORLD_NAME)
	return generatedWorld and generatedWorld:FindFirstChild(COLLIDERS_NAME) or nil
end

local function isGeneratedHelperPart(part)
	local colliders = getGeneratedColliders()
	if colliders and part:IsDescendantOf(colliders) then
		return true
	end

	if part.Name == "CityReservedZone" then
		return true
	end

	if part.Transparency >= 0.95 and containsHelperPattern(part.Name) then
		return true
	end

	local parent = part.Parent
	return part.Transparency >= 0.95 and parent and containsHelperPattern(parent.Name)
end

local function sanitizePart(part)
	if not part:IsA("BasePart") or not isGeneratedHelperPart(part) then
		return
	end

	part.CastShadow = false
	if part.Transparency >= 0.95 and not part.CanCollide then
		part.CanQuery = false
		part.CanTouch = false
	end
end

local function sanitizeRoot(root)
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("BasePart") then
			sanitizePart(inst)
		end
	end
end

local function sanitizeExisting()
	local generatedWorld = Workspace:FindFirstChild(GENERATED_WORLD_NAME)
	if generatedWorld then
		sanitizeRoot(generatedWorld)
	end

	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name == "CityReservedZone" then
			sanitizePart(inst)
		end
	end
end

sanitizeExisting()

Workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("BasePart") then
		task.defer(sanitizePart, inst)
	elseif inst.Name == GENERATED_WORLD_NAME or inst.Name == COLLIDERS_NAME then
		task.defer(sanitizeRoot, inst)
	end
end)
