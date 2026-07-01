--[[
Name: WorldPlaceConfig
Class: ModuleScript
Original path: game.ServerStorage.MMO_Archive.CompatibilityAliases_20260610.ReplicatedStorage.WorldRuntime.WorldPlaceConfig
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage
Requires:
  - return require(target)
Clean source lines: 5
]]
local packageRoot = game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage")
local target = packageRoot
target = target:WaitForChild("WorldRuntime")
target = target:WaitForChild("WorldPlaceConfig")
return require(target)