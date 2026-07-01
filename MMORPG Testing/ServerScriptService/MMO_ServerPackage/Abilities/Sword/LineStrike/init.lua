--[[
Name: LineStrike
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Abilities.Sword.LineStrike
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: TweenService, Debris, RunService, ReplicatedStorage
Requires:
  - local Core = require(script.Parent.Parent.AbilityCore)
  - local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
Functions: Execute
Clean source lines: 39
]]
local workspace      = game.Workspace
local TweenService   = game:GetService("TweenService")
local Debris         = game:GetService("Debris")
local RunService     = game:GetService("RunService")

local Core = require(script.Parent.Parent.AbilityCore)
local T = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)

local DAMAGE = 35
local RANGE = 50
local MANA_COST = 0

return {
	Key      = "W",
	Index    = 1,
	Name     = "Line Strike",
	Description = "Send a fast, broad sword line toward your aim direction.",
	TargetType = T.DIR,
	Cooldown = 0.2,
	Damage   = DAMAGE,
	Range    = RANGE,
	ManaCost = MANA_COST,
	CastLock  = 0.12,
	MoveSlow  = 1,

	Execute = function(ctx)


		return Core.Line.Projectile(ctx, {
			Origin = ctx.StartPos,
			Dir = ctx.TargetArg,
			Width = 30,
			Height = 500,
			Range = RANGE,
			Damage = DAMAGE,
			Speed = 200
		})
	end,
}