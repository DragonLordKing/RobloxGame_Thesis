--[[
Name: PlayerModule
Class: ModuleScript
Original path: game.StarterPlayer.StarterPlayerScripts.PlayerModule
Exported from: Generation
Original comments: removed
Children: 3
Properties: Archivable=false, LinkedSource=""
Requires:
  - self.cameras = require(script:WaitForChild("CameraModule"))
  - self.controls = require(script:WaitForChild("ControlModule"))
Functions: PlayerModule.new, PlayerModule:GetCameras, PlayerModule:GetControls, PlayerModule:GetClickToMoveController
Clean source lines: 24
]]
local PlayerModule = {}
PlayerModule.__index = PlayerModule

function PlayerModule.new()
	local self = setmetatable({},PlayerModule)
	self.cameras = require(script:WaitForChild("CameraModule"))
	self.controls = require(script:WaitForChild("ControlModule"))
	return self
end

function PlayerModule:GetCameras()
	return self.cameras
end

function PlayerModule:GetControls()
	return self.controls
end

function PlayerModule:GetClickToMoveController()
	return self.controls:GetClickToMoveController()
end

return PlayerModule.new()
