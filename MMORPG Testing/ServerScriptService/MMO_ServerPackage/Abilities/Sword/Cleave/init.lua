--[[
Name: Cleave
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Abilities.Sword.Cleave
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
local workspace = game.Workspace

local Core = require(script.Parent.Parent.AbilityCore)
local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)

local RADIUS = 5
local RANGE = 12
local DAMAGE = 25
local MANA_COST = 0

return {
	Key      = "Q",
	Index    = 1,
	Name     = "Cleave",
	Description = "Slash a short line in front of you.",
	TargetType = T.SELF,
	Cooldown = 0.1,
	Damage   = DAMAGE,
	Radius    = RADIUS,
	Range     = RANGE,
	ManaCost  = MANA_COST,
	CastLock = 0,
	MoveSlow = 0,

	Execute = function(ctx)
		return Core.Line.Static(ctx, {
			Origin = ctx.StartPos,
			Width = RADIUS * 2,
			Range = RANGE,
			Damage = DAMAGE,
		})
	end,
}