--[[
Name: BaseOcclusion
Class: ModuleScript
Original path: game.StarterPlayer.StarterPlayerScripts.PlayerModule.CameraModule.BaseOcclusion
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=false, LinkedSource=""
Functions: BaseOcclusion.new, BaseOcclusion:CharacterAdded, BaseOcclusion:CharacterRemoving, BaseOcclusion:OnCameraSubjectChanged, BaseOcclusion:GetOcclusionMode, BaseOcclusion:Enable, BaseOcclusion:Update, __call
Clean source lines: 42
]]
local BaseOcclusion: any = {}
BaseOcclusion.__index = BaseOcclusion
setmetatable(BaseOcclusion, {
	__call = function(_, ...)
		return BaseOcclusion.new(...)
	end
})

function BaseOcclusion.new()
	local self = setmetatable({}, BaseOcclusion)
	return self
end


function BaseOcclusion:CharacterAdded(char: Model, player: Player)
end


function BaseOcclusion:CharacterRemoving(char: Model, player: Player)
end

function BaseOcclusion:OnCameraSubjectChanged(newSubject)
end


function BaseOcclusion:GetOcclusionMode(): Enum.DevCameraOcclusionMode?

	warn("BaseOcclusion GetOcclusionMode must be overridden by derived classes")
	return nil
end

function BaseOcclusion:Enable(enabled: boolean)
	warn("BaseOcclusion Enable must be overridden by derived classes")
end

function BaseOcclusion:Update(dt: number, desiredCameraCFrame: CFrame, desiredCameraFocus: CFrame)
	warn("BaseOcclusion Update must be overridden by derived classes")
	return desiredCameraCFrame, desiredCameraFocus
end

return BaseOcclusion
