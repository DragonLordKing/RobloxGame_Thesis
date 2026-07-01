--[[
Name: TestSword
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Equipment.TestSword
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage, ServerScriptService
Requires:
  - local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
  - local Core = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))
Functions: TestSword.ApplyStats, Execute
Clean source lines: 42
]]
local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
local Core = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))

local TestSword = {}

TestSword.WeaponType = "Sword"
TestSword.ItemPower      = 120
TestSword.BaseDamage     = 3
TestSword.BasicCooldown  = 1
TestSword.Range          = 10

function TestSword.ApplyStats(stats)
	local itemPower = TestSword.ItemPower
	stats.ItemPower = (stats.ItemPower or 0) + itemPower
	stats.PhysicalAttackBonus = (stats.PhysicalAttackBonus or 0) + math.floor(itemPower * 0.79)
	stats.PhysicalAbilityBonus = (stats.PhysicalAbilityBonus or 0) + math.floor(itemPower * 0.12)
	stats.AttackSpeedBonus = (stats.AttackSpeedBonus or 0) + 0.05
end


TestSword.UniqueE = {
	AbilityId = "TestSword_E",
	Cooldown = 1,
	TargetType = T.LOC,
	CastLock  = 1.2,
	MoveSlow  = 1,
	Damage = 50,
	Radius = 8,
	Duration = 1.2,
	Execute = function(ctx)
		return Core.JumpImpact(ctx, {
			Origin   = ctx.StartPos,
			TargetPos = ctx.TargetArg,
			Duration  = 1.2,
			Radius    = 21,
			Damage    = ctx.Damage or TestSword.UniqueE.Damage,
			Range     = 30,
		})
	end,
}

return TestSword