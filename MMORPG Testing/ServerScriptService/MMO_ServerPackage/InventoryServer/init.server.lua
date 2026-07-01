--[[
Name: InventoryServer
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.InventoryServer
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Requires:
  - local InventoryService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("InventoryStorageService"))
  - local EconomyMarketService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("EconomyMarketService"))
Clean source lines: 6
]]
local InventoryService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("InventoryStorageService"))
local EconomyMarketService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("EconomyMarketService"))

InventoryService.Start()
EconomyMarketService.Start()
