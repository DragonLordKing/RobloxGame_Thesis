--[[
Name: MountController
Class: ModuleScript
Original path: game.ServerStorage.MMO_Archive.CompatibilityAliases_20260610.ReplicatedStorage.Client.Modules.Controllers.MountController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage
Requires:
  - return require(target)
Clean source lines: 7
]]
local packageRoot = game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage")
local target = packageRoot
target = target:WaitForChild("Client")
target = target:WaitForChild("Modules")
target = target:WaitForChild("Controllers")
target = target:WaitForChild("MountController")
return require(target)