--[[
Name: EarthsplitterGreatsword
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Equipment.EarthsplitterGreatsword
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage, ServerScriptService
Requires:
  - local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
  - local Core = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))
Functions: M.ApplyStats, Execute
Clean source lines: 43
]]
local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
local Core = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))

local M = {}

M.WeaponType = "Sword"
M.ItemPower = 360
M.BaseDamage = 12
M.BasicCooldown = 1.04
M.Range = 11

function M.ApplyStats(stats)
	local itemPower = M.ItemPower
	stats.ItemPower = (stats.ItemPower or 0) + itemPower
	stats.PhysicalAttackBonus = (stats.PhysicalAttackBonus or 0) + math.floor(itemPower * 0.46)
	stats.PhysicalAbilityBonus = (stats.PhysicalAbilityBonus or 0) + math.floor(itemPower * 0.18)
	stats.AttackSpeedBonus = (stats.AttackSpeedBonus or 0) + 0.04
end

M.UniqueE = {
	AbilityId = "EarthsplitterGreatsword_E",
	Name = "Earthsplitter Rupture",
	Description = "Mark a ground circle, then rupture it after a short warning.",
	Cooldown = 6,
	TargetType = T.LOC,
	CastLock = 0.65,
	MoveSlow = 0.65,
	Damage = 64,
	Radius = 13,
	Range = 32,
	ManaCost = 18,
	Execute = function(ctx)
		return Core.Cylinder.Delayed(ctx, {
			Position = ctx.TargetArg,
			Range = 32,
			Radius = 13,
			Duration = 0.65,
			Damage = ctx.Damage or M.UniqueE.Damage,
		})
	end,
}

return M