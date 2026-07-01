--[[
Name: TranscendentPurityBlade
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Equipment.TranscendentPurityBlade
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Requires:
  - local Base = require(script.Parent:WaitForChild("TestSword"))
Functions: M.ApplyStats
Clean source lines: 23
]]
local Base = require(script.Parent:WaitForChild("TestSword"))

local M = {}
for key, value in pairs(Base) do
	M[key] = value
end

M.WeaponType = "Sword"
M.BaseDamage = 13
M.BasicCooldown = 0.88
M.Range = 10

M.ItemPower = 520

function M.ApplyStats(stats)
	local itemPower = M.ItemPower
	stats.ItemPower = (stats.ItemPower or 0) + itemPower
	stats.PhysicalAttackBonus = (stats.PhysicalAttackBonus or 0) + math.floor(itemPower * 0.38)
	stats.PhysicalAbilityBonus = (stats.PhysicalAbilityBonus or 0) + math.floor(itemPower * 0.18)
	stats.AttackSpeedBonus = (stats.AttackSpeedBonus or 0) + 0.12
end

return M