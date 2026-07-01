--[[
Name: MountInfo
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.MountInfo
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Clean source lines: 11
]]
local HorseInfo = {
	mountedHorses = {},
	horseSpeeds = {},
	movementTimers = {},
	horseToPlayer   = {},
	mountDebounce = {},
	mountingPlayers = {},
}

return HorseInfo
