--[[
Name: MouseUtil
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Util.MouseUtil
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, UserInputService, GuiService, Workspace
Functions: currentCamera, getMouseRay, hasNonGroundMarker, getHumanoidModel, isHumanoidPart, hasGatheringMarker, hasDetectorMarker, hasEconomyMarker, isInteractionHit, isTransparentPart, shouldSkipGroundHit, shouldSkipInteractionHit, buildExcludes, raycastFromMouseWithSkip, characterFeetY, intersectPlaneY, guiVisibleInTree, guiObjectConsumesClick, MouseUtil.raycastFromMouse, MouseUtil.raycastInteractionFromMouse, MouseUtil.getMouseInteractionTarget, MouseUtil.getMouseTargetPosition, MouseUtil.getMouseClickEffectPosition, MouseUtil.getMouseGroundClickEffectPosition, MouseUtil.isMouseOverAnyGui
Clean source lines: 356
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local MouseUtil = {}

local MAX_RAY_DISTANCE = 5000
local MAX_RAY_STEPS = 32
local CLICK_Y_OFFSET = 0.05
local GROUND_Y_TOLERANCE = 1
local GROUND_TRANSPARENT_SKIP_ALPHA = 0.35
local INTERACTION_TRANSPARENT_SKIP_ALPHA = 0.35

local NON_GROUND_NAMES = {
	["Non-Collidable"] = true,
	NonCollidable = true,
	Ignore = true,
	BuildPlacementGhost = true,
	InventoryDragGhost = true,
	ACircleIndicator = true,
}

local NON_GROUND_GROUPS = {
	["Non-Collidable"] = true,
	NonCollidable = true,
	Character = true,
	Horse = true,
	Mobs = true,
	Walkthrough = true,
}

local function currentCamera()
	return Workspace.CurrentCamera
end

local function getMouseRay()
	local camera = currentCamera()
	if not camera then
		return nil
	end
	local mouseLocation = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
end

local function hasNonGroundMarker(inst)
	local current = inst
	while current and current ~= Workspace do
		if NON_GROUND_NAMES[current.Name] then
			return true
		end
		if current:GetAttribute("NonCollidable") == true or current:GetAttribute("Non-Collidable") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function getHumanoidModel(inst)
	local model = inst and inst:FindFirstAncestorWhichIsA("Model")
	if model and model:FindFirstChildOfClass("Humanoid") then
		return model
	end
	return nil
end

local function isHumanoidPart(inst)
	return getHumanoidModel(inst) ~= nil
end

local function hasGatheringMarker(inst)
	local current = inst
	while current and current ~= Workspace do
		if current:GetAttribute("GatheringNode") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function hasDetectorMarker(inst)
	local current = inst
	while current and current ~= Workspace do
		if current.Name == "Detector" or current:FindFirstChild("Detector") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function hasEconomyMarker(inst)
	local current = inst
	while current and current ~= Workspace do
		local name = string.lower(current.Name)
		if current:GetAttribute("LootChest") == true
			or current:GetAttribute("DeathSack") == true
			or current:GetAttribute("MarketType") ~= nil
			or current:GetAttribute("ChestType") ~= nil
			or name:find("deathsack", 1, true)
			or name:find("death_sack", 1, true)
			or name:find("treasurechesttype", 1, true)
			or name:find("auction", 1, true)
			or name:find("blackmarket", 1, true)
			or name:find("black_market", 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isInteractionHit(inst)
	return isHumanoidPart(inst) or hasGatheringMarker(inst) or hasDetectorMarker(inst) or hasEconomyMarker(inst)
end

local function isTransparentPart(inst, threshold)
	return inst and inst:IsA("BasePart") and inst.Transparency >= threshold
end

local function shouldSkipGroundHit(result, referenceY)
	local inst = result and result.Instance
	if not inst then
		return true
	end
	if referenceY and math.abs(result.Position.Y - referenceY) > GROUND_Y_TOLERANCE then
		return true
	end
	if inst == Workspace.Terrain then
		return false
	end
	if hasNonGroundMarker(inst) or isHumanoidPart(inst) then
		return true
	end
	if inst:IsA("BasePart") then
		if inst.CanCollide == false then
			return true
		end
		if isTransparentPart(inst, GROUND_TRANSPARENT_SKIP_ALPHA) then
			return true
		end
		if NON_GROUND_GROUPS[inst.CollisionGroup] then
			return true
		end
	end
	return false
end

local function shouldSkipInteractionHit(result)
	local inst = result and result.Instance
	if not inst then
		return true
	end
	if inst == Workspace.Terrain then
		return true
	end
	if isInteractionHit(inst) then
		return false
	end
	if hasNonGroundMarker(inst) then
		return true
	end
	if inst:IsA("BasePart") then
		if inst.CanCollide == false then
			return true
		end
		if NON_GROUND_GROUPS[inst.CollisionGroup] then
			return true
		end
	end
	if isTransparentPart(inst, INTERACTION_TRANSPARENT_SKIP_ALPHA) then
		return true
	end
	return false
end

local function buildExcludes(extra)
	local excludes = {}
	if player.Character then
		table.insert(excludes, player.Character)
	end
	if type(extra) == "table" then
		for _, inst in ipairs(extra) do
			if typeof(inst) == "Instance" then
				table.insert(excludes, inst)
			end
		end
	end
	return excludes
end

local function raycastFromMouseWithSkip(extraExclude, shouldSkip)
	local ray = getMouseRay()
	if not ray then
		return nil
	end

	local excludes = buildExcludes(extraExclude)
	local origin = ray.Origin
	local remaining = MAX_RAY_DISTANCE
	local dir = ray.Direction.Unit

	for _ = 1, MAX_RAY_STEPS do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excludes
		params.IgnoreWater = true

		local result = Workspace:Raycast(origin, dir * remaining, params)
		if not result then
			return nil
		end
		if not shouldSkip(result) then
			return result
		end

		table.insert(excludes, result.Instance)
		local travelled = result.Distance + 0.05
		origin += dir * travelled
		remaining -= travelled
		if remaining <= 0 then
			return nil
		end
	end

	return nil
end

local function characterFeetY()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local halfRoot = hrp.Size.Y * 0.5
	if humanoid then
		return hrp.Position.Y - humanoid.HipHeight - halfRoot
	end
	return hrp.Position.Y - halfRoot
end

local function intersectPlaneY(ray, y)
	if not ray or math.abs(ray.Direction.Y) < 0.001 then
		return nil
	end
	local t = (y - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

function MouseUtil.raycastFromMouse(extraExclude)
	local referenceY = characterFeetY()
	return raycastFromMouseWithSkip(extraExclude, function(result)
		return shouldSkipGroundHit(result, referenceY)
	end)
end

function MouseUtil.raycastInteractionFromMouse(extraExclude)
	return raycastFromMouseWithSkip(extraExclude, shouldSkipInteractionHit)
end

function MouseUtil.getMouseInteractionTarget(extraExclude)
	local result = MouseUtil.raycastInteractionFromMouse(extraExclude)
	return result and result.Instance or nil
end

function MouseUtil.getMouseTargetPosition()
	local result = MouseUtil.raycastFromMouse()
	if result then
		return result.Position
	end

	local y = characterFeetY()
	if y then
		local planePoint = intersectPlaneY(getMouseRay(), y)
		if planePoint then
			return Vector3.new(planePoint.X, y, planePoint.Z)
		end
	end
	return nil
end

function MouseUtil.getMouseClickEffectPosition()
	local y = characterFeetY()
	local target = MouseUtil.getMouseTargetPosition()
	if target then
		if y then
			return Vector3.new(target.X, y + CLICK_Y_OFFSET, target.Z)
		end
		return target + Vector3.new(0, CLICK_Y_OFFSET, 0)
	end
	return nil
end

function MouseUtil.getMouseGroundClickEffectPosition()
	local result = MouseUtil.raycastFromMouse()
	if result then
		return result.Position + Vector3.new(0, CLICK_Y_OFFSET, 0)
	end
	return MouseUtil.getMouseClickEffectPosition()
end

local function guiVisibleInTree(gui)
	local current = gui
	while current and current ~= player.PlayerGui do
		if current:IsA("GuiObject") and current.Visible == false then
			return false
		end
		current = current.Parent
	end
	return true
end

local function guiObjectConsumesClick(gui)
	if not (gui and gui:IsA("GuiObject") and guiVisibleInTree(gui)) then
		return false
	end
	if gui:IsA("GuiButton") or gui:IsA("TextBox") or gui:IsA("ScrollingFrame") then
		return true
	end
	if gui.Active == true then
		return true
	end
	if gui:IsA("TextLabel") and gui.Text ~= "" and gui.TextTransparency < 1 then
		return true
	end
	if gui:IsA("ImageLabel") and gui.Image ~= "" and gui.ImageTransparency < 1 then
		return true
	end
	if gui.BackgroundTransparency < 1 then
		return true
	end
	return false
end

function MouseUtil.isMouseOverAnyGui()
	local mouseLoc = UserInputService:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	local x = mouseLoc.X
	local y = mouseLoc.Y - inset.Y
	for _, gui in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(x, y)) do
		if guiObjectConsumesClick(gui) then
			return true
		end
	end
	return false
end

return MouseUtil