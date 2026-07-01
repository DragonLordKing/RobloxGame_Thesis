--[[
Name: GuardianLongsword
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Equipment.GuardianLongsword
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage, ServerScriptService
Requires:
  - local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
  - local Core = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))
Functions: M.ApplyStats, Execute
Clean source lines: 60
]]
local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
local Core = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))

local M = {}

M.WeaponType = "Sword"
M.ItemPower = 330
M.BaseDamage = 10
M.BasicCooldown = 0.96
M.Range = 10

function M.ApplyStats(stats)
	local itemPower = M.ItemPower
	stats.ItemPower = (stats.ItemPower or 0) + itemPower
	stats.PhysicalAttackBonus = (stats.PhysicalAttackBonus or 0) + math.floor(itemPower * 0.43)
	stats.PhysicalAbilityBonus = (stats.PhysicalAbilityBonus or 0) + math.floor(itemPower * 0.15)
	stats.Armor = (stats.Armor or 0) + math.floor(itemPower * 0.10)
	stats.AttackSpeedBonus = (stats.AttackSpeedBonus or 0) + 0.06
end

M.UniqueE = {
	AbilityId = "GuardianLongsword_E",
	Name = "Guardian Rush",
	Description = "Rush toward a point, damaging the path and knocking enemies away at the end.",
	Cooldown = 5,
	TargetType = T.LOC,
	CastLock = 0.35,
	MoveSlow = 0.35,
	Damage = 38,
	Radius = 8,
	Range = 28,
	ManaCost = 14,
	Execute = function(ctx)
		local root = ctx.Character and ctx.Character:FindFirstChild("HumanoidRootPart")
		if not (root and typeof(ctx.TargetArg) == "Vector3") then
			return {}
		end
		local flat = Vector3.new(ctx.TargetArg.X - root.Position.X, 0, ctx.TargetArg.Z - root.Position.Z)
		if flat.Magnitude < 0.1 then
			return {}
		end
		local distance = math.min(flat.Magnitude, 28)
		local hits = Core.Move.Dash(ctx, {
			Dir = flat.Unit,
			Distance = distance,
			Duration = 0.26,
			Width = 6,
			Damage = ctx.Damage or M.UniqueE.Damage,
		}) or {}
		Core.Force.Knockback(ctx, {
			Position = root.Position,
			Radius = 8,
			Power = 58,
			Duration = 0.2,
		})
		return hits
	end,
}

return M