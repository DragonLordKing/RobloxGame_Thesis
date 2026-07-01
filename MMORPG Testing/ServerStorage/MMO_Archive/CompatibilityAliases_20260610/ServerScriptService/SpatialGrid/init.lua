--[[
Name: SpatialGrid
Class: ModuleScript
Original path: game.ServerStorage.MMO_Archive.CompatibilityAliases_20260610.ServerScriptService.SpatialGrid
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ServerScriptService
Requires:
  - return require(target)
Clean source lines: 4
]]
local packageRoot = game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage")
local target = packageRoot
target = target:WaitForChild("SpatialGrid")
return require(target)