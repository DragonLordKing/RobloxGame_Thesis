--[[
Name: MapSettings
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.MapSettings
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage
Requires:
  - return require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("WorldRuntime"):WaitForChild("WorldPlaceConfig"))
Clean source lines: 12
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, WorldConfig = pcall(function()
	return require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("WorldRuntime"):WaitForChild("WorldPlaceConfig"))
end)

local map = ok and WorldConfig.GetCurrentMap and WorldConfig.GetCurrentMap() or nil

return {
	Name = tostring(game:GetAttribute("MapName") or (map and map.DisplayName) or "Testing Grounds"),
	ZoneType = tostring(game:GetAttribute("ZoneType") or (map and map.ZoneType) or "Warn"),
}