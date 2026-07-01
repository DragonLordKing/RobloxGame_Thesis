--[[
Name: BaseCharacterController
Class: ModuleScript
Original path: game.StarterPlayer.StarterPlayerScripts.PlayerModule.ControlModule.BaseCharacterController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=false, LinkedSource=""
Requires:
  - local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))
Functions: BaseCharacterController.new, BaseCharacterController:GetMoveVector, BaseCharacterController:IsMoveVectorCameraRelative, BaseCharacterController:GetIsJumping, BaseCharacterController:Enable
Clean source lines: 56
]]
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))


export type BaseCharacterControllerType = {
	new: () -> BaseCharacterControllerType,
	GetMoveVector: (BaseCharacterControllerType) -> Vector3,
	IsMoveVectorCameraRelative: (BaseCharacterControllerType) -> boolean,
	GetIsJumping: (BaseCharacterControllerType) -> boolean,
	Enable: (BaseCharacterControllerType, enable: boolean) -> boolean,


	enabled: boolean,
	moveVector: Vector3,
	moveVectorIsCameraRelative: boolean,
	isJumping: boolean,
	_connectionUtil: any
}

local ZERO_VECTOR3: Vector3 = Vector3.new()

local BaseCharacterController = {} :: BaseCharacterControllerType
(BaseCharacterController :: any).__index = BaseCharacterController

function BaseCharacterController.new()
	local self = setmetatable({}, BaseCharacterController)

	self.enabled = false
	self.moveVector = ZERO_VECTOR3
	self.moveVectorIsCameraRelative = true
	self.isJumping = false
	self._connectionUtil = ConnectionUtil.new()

	return self :: any
end

function BaseCharacterController:GetMoveVector(): Vector3
	return self.moveVector
end

function BaseCharacterController:IsMoveVectorCameraRelative(): boolean
	return self.moveVectorIsCameraRelative
end

function BaseCharacterController:GetIsJumping(): boolean
	return self.isJumping
end


function BaseCharacterController:Enable(enable: boolean): boolean
	error("BaseCharacterController:Enable must be overridden in derived classes and should not be called.")
	return false
end

return BaseCharacterController
