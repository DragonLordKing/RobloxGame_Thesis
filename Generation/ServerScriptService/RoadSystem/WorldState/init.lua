--[[
Name: WorldState
Class: ModuleScript
Original path: game.ServerScriptService.RoadSystem.WorldState
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: M.Set, M.Get
Clean source lines: 14
]]
local M = {}

local currentWorld = nil

function M.Set(world)
	currentWorld = world
end

function M.Get()
	return currentWorld
end

return M
