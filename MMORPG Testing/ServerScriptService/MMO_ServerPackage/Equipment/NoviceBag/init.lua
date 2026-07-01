--[[
Name: NoviceBag
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Equipment.NoviceBag
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: Bag.ApplyStats
Clean source lines: 14
]]
local Bag = {}

Bag.ItemId = "NoviceBag"
Bag.DisplayName = "Novice Bag"
Bag.Tier = 1
Bag.CarryCapacity = 25
Bag.Weight = 0.4

function Bag.ApplyStats(stats)
	stats.MaxWeight = (stats.MaxWeight or 100) + Bag.CarryCapacity
end

return Bag
