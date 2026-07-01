--[[
Name: FlagUtil
Class: ModuleScript
Original path: game.StarterPlayer.StarterPlayerScripts.PlayerModule.CommonUtils.FlagUtil
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=false, LinkedSource=""
Functions: FlagUtil.getUserFlag
Clean source lines: 16
]]
export type FlagUtilType = {


	getUserFlag: (string) -> boolean,
}

local FlagUtil: FlagUtilType = {} :: FlagUtilType;

function FlagUtil.getUserFlag(flagName)
	local success, result = pcall(function()
		return UserSettings():IsUserFeatureEnabled(flagName)
	end)
	return success and result
end

return FlagUtil