--[[
Name: BrownRidingHorse
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Equipment.Mounts.Horses.BrownRidingHorse
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: Horse.ApplyStats
Clean source lines: 25
]]
local Horse = {}

Horse.ItemId = "BrownRidingHorse"
Horse.DisplayName = "Brown Riding Horse"
Horse.MountCategory = "Horses"
Horse.TemplatePath = "Mounts/Horses/BrownRidingHorse"
Horse.BaseSpeed = 16
Horse.MaxSpeed = 40
Horse.Health = 300
Horse.MaxHealth = 300
Horse.GallopTime = 4
Horse.Weight = 0
Horse.Tier = 1

function Horse.ApplyStats(stats)
	stats.MountStats = stats.MountStats or {}
	stats.MountStats.Health = Horse.Health
	stats.MountStats.MaxHealth = Horse.MaxHealth
	stats.MountStats.GallopTime = Horse.GallopTime
	stats.MountStats.BaseSpeed = Horse.BaseSpeed
	stats.MountStats.MaxSpeed = Horse.MaxSpeed
end

return Horse
