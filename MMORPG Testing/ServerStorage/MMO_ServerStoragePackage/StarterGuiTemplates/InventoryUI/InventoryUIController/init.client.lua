--[[
Name: InventoryUIController
Class: LocalScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.StarterGuiTemplates.InventoryUI.InventoryUIController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ReplicatedStorage
Requires:
  - local Controller = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForC...
Clean source lines: 4
]]
local Controller = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Controllers"):WaitForChild("InventoryController"))

Controller.Start(script.Parent)
