--[[
Name: NPCRegistry
Class: ModuleScript
Original path: game.ServerStorage.MMO_Archive.CompatibilityAliases_20260610.ServerScriptService.NPC.NPCRegistry
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ServerScriptService
Requires:
  - return require(target)
Clean source lines: 5
]]
local packageRoot = game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage")
local target = packageRoot
target = target:WaitForChild("NPC")
target = target:WaitForChild("NPCRegistry")
return require(target)