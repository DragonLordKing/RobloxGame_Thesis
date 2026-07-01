--[[
Name: RendingSweep
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Abilities.Sword.RendingSweep
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

local RANGE = 14
local WIDTH = 7
local DAMAGE = 30
local COOLDOWN = 4
local MANA_COST = 8

return {
	Key = "Q",
	Index = 3,
	Name = "Rending Sweep",
	Description = "Sweep a wider arc forward for a heavier melee hit.",
	TargetType = T.DIR,
	Cooldown = COOLDOWN,
	Damage = DAMAGE,
	Range = RANGE,
	ManaCost = MANA_COST,
	CastLock = 0.18,
	MoveSlow = 0.35,

	Execute = function(ctx)
		return Core.Line.Static(ctx, {
			Origin = ctx.StartPos,
			Dir = ctx.TargetArg,
			Width = WIDTH,
			Range = RANGE,
			Damage = DAMAGE,
			VFX = "SwordRendingSweep",
		})
	end,
}