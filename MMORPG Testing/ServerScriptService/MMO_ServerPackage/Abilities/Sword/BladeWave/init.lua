--[[
Name: BladeWave
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Abilities.Sword.BladeWave
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage
Requires:
  - local Core = require(script.Parent.Parent.AbilityCore)
  - local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
Functions: Execute
Clean source lines: 36
]]
local Core = require(script.Parent.Parent.AbilityCore)
local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)

local RANGE = 36
local RADIUS = 3
local DAMAGE = 26
local COOLDOWN = 5
local MANA_COST = 14
local SPEED = 100

return {
	Key = "W",
	Index = 3,
	Name = "Blade Wave",
	Description = "Launch a rolling wave of force along your aim direction.",
	TargetType = T.DIR,
	Cooldown = COOLDOWN,
	Damage = DAMAGE,
	Radius = RADIUS,
	Range = RANGE,
	ManaCost = MANA_COST,
	CastLock = 0.25,
	MoveSlow = 0.45,

	Execute = function(ctx)
		return Core.Cylinder.Projectile(ctx, {
			Origin = ctx.StartPos,
			Dir = ctx.TargetArg,
			Radius = RADIUS,
			Range = RANGE,
			Damage = DAMAGE,
			Speed = SPEED,
			VFX = "SwordBladeWave",
		})
	end,
}