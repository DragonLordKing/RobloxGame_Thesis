--[[
Name: StormstepSaber
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Equipment.StormstepSaber
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage, ServerScriptService
Requires:
  - local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
  - local Core = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))
Functions: M.ApplyStats, Execute
Clean source lines: 44
]]
local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
local Core = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))

local M = {}

M.WeaponType = "Sword"
M.ItemPower = 300
M.BaseDamage = 9
M.BasicCooldown = 0.92
M.Range = 10

function M.ApplyStats(stats)
	local itemPower = M.ItemPower
	stats.ItemPower = (stats.ItemPower or 0) + itemPower
	stats.PhysicalAttackBonus = (stats.PhysicalAttackBonus or 0) + math.floor(itemPower * 0.45)
	stats.PhysicalAbilityBonus = (stats.PhysicalAbilityBonus or 0) + math.floor(itemPower * 0.16)
	stats.AttackSpeedBonus = (stats.AttackSpeedBonus or 0) + 0.10
end

M.UniqueE = {
	AbilityId = "StormstepSaber_E",
	Name = "Stormstep Burst",
	Description = "Blink to a target point and burst on arrival.",
	Cooldown = 4,
	TargetType = T.LOC,
	CastLock = 0.25,
	MoveSlow = 0.25,
	Damage = 42,
	Radius = 10,
	Range = 34,
	ManaCost = 12,
	Execute = function(ctx)
		return Core.Move.BlinkDelayed(ctx, {
			TargetPos = ctx.TargetArg,
			Range = 34,
			Duration = 0.18,
			PathWidth = 4,
			ArrivalRadius = 10,
			Damage = ctx.Damage or M.UniqueE.Damage,
		})
	end,
}

return M