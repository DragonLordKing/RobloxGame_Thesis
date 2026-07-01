--[[
Name: ChestRequirementExamples
Class: ModuleScript
Original path: game.ServerStorage.MMO_Archive.CompatibilityAliases_20260610.ServerStorage.WorldTemplate.ChestRequirementExamples
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ServerStorage
Requires:
  - return require(target)
Clean source lines: 5
]]
local packageRoot = game:GetService("ServerStorage"):WaitForChild("MMO_ServerStoragePackage")
local target = packageRoot
target = target:WaitForChild("WorldTemplate")
target = target:WaitForChild("ChestRequirementExamples")
return require(target)