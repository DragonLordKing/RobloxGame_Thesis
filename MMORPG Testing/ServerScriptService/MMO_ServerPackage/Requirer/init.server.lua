--[[
Name: Requirer
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.Requirer
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ServerScriptService
Requires:
  - local humanoidStats = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCoreLean"):WaitForChild("Bootstrap"))
  - local ValorService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("Progression"):WaitForChild("ValorService"))
  - local PlayerCombatStateService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
  - local PartyService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PartyService"))
  - require(WorldRuntime:WaitForChild("SmartChestService")).Start()
  - require(WorldRuntime:WaitForChild("WorldMapService")).Start()
  - require(WorldRuntime:WaitForChild("WorldLogoutProxyService")).Start()
  - require(WorldRuntime:WaitForChild("WorldTeleportService")).Start()
Clean source lines: 17
]]
local humanoidStats = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCoreLean"):WaitForChild("Bootstrap"))

local ValorService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("Progression"):WaitForChild("ValorService"))
ValorService.Start()

local PlayerCombatStateService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
PlayerCombatStateService.Start()

local PartyService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PartyService"))
PartyService.Start()

local WorldRuntime = game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("WorldRuntime")
require(WorldRuntime:WaitForChild("SmartChestService")).Start()
require(WorldRuntime:WaitForChild("WorldMapService")).Start()
require(WorldRuntime:WaitForChild("WorldLogoutProxyService")).Start()
require(WorldRuntime:WaitForChild("WorldTeleportService")).Start()
