--[[
Name: PristineGatherersPack
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Equipment.PristineGatherersPack
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: M.ApplyStats
Clean source lines: 8
]]
local M = {}

function M.ApplyStats(stats)
	stats.MaxWeight = (stats.MaxWeight or 100) + 35
	stats.ItemPower = (stats.ItemPower or 0) + 95
end

return M