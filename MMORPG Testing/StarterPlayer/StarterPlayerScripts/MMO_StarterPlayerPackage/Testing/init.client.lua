--[[
Name: Testing
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.Testing
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, RunService, UserInputService
Functions: setScriptableCamera, getCamera, startFollowLoop
Clean source lines: 81
]]
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player  = Players.LocalPlayer
local camera  = workspace.CurrentCamera

local function setScriptableCamera(activeCamera)
	if activeCamera then
		activeCamera.CameraType = Enum.CameraType.Scriptable
	end
end

local function getCamera()
	camera = workspace.CurrentCamera
	setScriptableCamera(camera)
	return camera
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	getCamera()
end)


local MIN_ZOOM, MAX_ZOOM = 10, 40
local currentDistance    = 30
local CAMERA_ORIENTATION = CFrame.Angles(math.rad(-68), 0, 0)

local CAMERA_OVERRIDE_ATTR = "BuildCameraOverride"

if player:GetAttribute(CAMERA_OVERRIDE_ATTR) == nil then
	player:SetAttribute(CAMERA_OVERRIDE_ATTR, false)
end

setScriptableCamera(camera)


UserInputService.InputChanged:Connect(function(input, gp)
	if gp then return end
	if player:GetAttribute(CAMERA_OVERRIDE_ATTR) then return end

	if input.UserInputType == Enum.UserInputType.MouseWheel then
		currentDistance -= input.Position.Z
		currentDistance  = math.clamp(currentDistance, MIN_ZOOM, MAX_ZOOM)
	end
end)


local followConn

local function startFollowLoop(char)
	if followConn then
		followConn:Disconnect()
	end

	local root = char:WaitForChild("HumanoidRootPart")

	followConn = RunService.RenderStepped:Connect(function()
		if player:GetAttribute(CAMERA_OVERRIDE_ATTR) then
			return
		end

		local activeCamera = getCamera()
		if not activeCamera then
			return
		end

		local targetPos     = root.Position
		local forwardVector = CAMERA_ORIENTATION.LookVector
		local cameraPos     = targetPos - forwardVector * currentDistance
		activeCamera.CFrame = CFrame.new(cameraPos) * CAMERA_ORIENTATION
		activeCamera.Focus  = CFrame.new(targetPos)
	end)
end


if player.Character then
	startFollowLoop(player.Character)
end

player.CharacterAdded:Connect(startFollowLoop)