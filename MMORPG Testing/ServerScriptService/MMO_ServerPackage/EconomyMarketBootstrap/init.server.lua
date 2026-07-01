--[[
Name: EconomyMarketBootstrap
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.EconomyMarketBootstrap
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Requires:
  - local EconomyMarketService = require(script.Parent:WaitForChild("EconomyMarketService"))
Clean source lines: 4
]]
local EconomyMarketService = require(script.Parent:WaitForChild("EconomyMarketService"))

EconomyMarketService.Start()
