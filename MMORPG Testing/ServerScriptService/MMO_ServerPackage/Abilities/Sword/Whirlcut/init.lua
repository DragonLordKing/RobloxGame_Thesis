--[[
Name: Whirlcut
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Abilities.Sword.Whirlcut
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage
Requires:
  - local Core = require(script.Parent.Parent.AbilityCore)
  - local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
Functions: Execute
Clean source lines: 31
]]
local Core = require(script.Parent.Parent.AbilityCore)
local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)

local RADIUS = 7
local DAMAGE = 18
local COOLDOWN = 3
local MANA_COST = 6

return {
	Key = "Q",
	Index = 2,
	Name = "Whirlcut",
	Description = "Spin in place and hit enemies around you.",
	TargetType = T.SELF,
	Cooldown = COOLDOWN,
	Damage = DAMAGE,
	Radius = RADIUS,
	Range = RADIUS,
	ManaCost = MANA_COST,
	CastLock = 0.15,
	MoveSlow = 0.2,

	Execute = function(ctx)
		return Core.Cylinder.Static(ctx, {
			Origin = ctx.StartPos,
			Radius = RADIUS,
			Damage = DAMAGE,
			VFX = "SwordWhirlcut",
		})
	end,
}