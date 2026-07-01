--[[
Name: PiercingThrust
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Abilities.Sword.PiercingThrust
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage
Requires:
  - local Core = require(script.Parent.Parent.AbilityCore)
  - local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
Functions: Execute
Clean source lines: 33
]]
local Core = require(script.Parent.Parent.AbilityCore)
local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)

local RANGE = 24
local WIDTH = 3
local DAMAGE = 32
local COOLDOWN = 3.5
local MANA_COST = 10

return {
	Key = "W",
	Index = 2,
	Name = "Piercing Thrust",
	Description = "Thrust a narrow line that reaches farther than a normal slash.",
	TargetType = T.DIR,
	Cooldown = COOLDOWN,
	Damage = DAMAGE,
	Range = RANGE,
	ManaCost = MANA_COST,
	CastLock = 0.15,
	MoveSlow = 0.35,

	Execute = function(ctx)
		return Core.Line.Static(ctx, {
			Origin = ctx.StartPos,
			Dir = ctx.TargetArg,
			Width = WIDTH,
			Range = RANGE,
			Damage = DAMAGE,
			VFX = "SwordPiercingThrust",
		})
	end,
}