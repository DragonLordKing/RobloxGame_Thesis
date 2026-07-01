--[[
Name: NPCAbilities
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Abilities.NPCAbilities
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ServerScriptService, ReplicatedStorage
Requires:
  - local Core = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))
  - local T    = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
Functions: dirTo, CanHitNow, Execute
Clean source lines: 151
]]
local Core = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))
local T    = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)

local function dirTo(a: Vector3, b: Vector3)
	local v = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	return (v.Magnitude > 1e-4) and v.Unit or Vector3.new(1,0,0)
end

local A = {}


A.MobCleave = {
	Key        = "MobCleave",
	TargetType = T.U_ENEMY,


	Range      = 15,
	Width      = 3,


	Delay      = 0.55,
	Recovery   = 0.15,
	Cooldown   = 2.0,
	Weight     = 1,
	VFX        = "MobSlash",


	Duration     = 0.2,
	PredictPhase = 0.6,
	CanHitNow = function(npc, target, distHit)
		return distHit <= 10.5
	end,


	MoveLock   = 0.55,

	Execute = function(ctx, target)

		return Core.Line.StaticDelayed(ctx, {
			Range    = 15,
			Width    = 3,
			Damage   = 50,
			Duration = 0.55,
			VFX      = "MobSlash",
			TargetFilter = "Enemies",
		})
	end,
}


A.MobShockwave = {
	Key="MobShockwave",
	TargetType = T.SELF,

	Radius   = 7,
	Range    = 9,
	Delay    = 0.6,
	Recovery = 0.15,
	Cooldown = 5.0,
	Weight   = 1,
	VFX      = "GuardLeap",

	PredictPhase = 1.0,
	CanHitNow = function(npc, target, distHit)
		return distHit <= 7.5
	end,

	MoveLock = 0.6,

	Execute = function(ctx)

		return Core.Cylinder.StaticDelayed(ctx, {
			Radius   = 7,
			Damage   = 50,
			Duration = 0.6,
			TargetFilter = "Enemies",
		})
	end,
}


A.MobLeapSmash = {
	Key              = "MobLeapSmash",
	TargetType       = T.U_ENEMY,
	MinRange         = 8,
	MaxRange         = 20,
	Cooldown         = 7.0,
	GapCloser        = true,
	MovesCaster      = true,
	MoveLock         = 1.05,
	CastTime         = 0.10,
	Recovery         = 0.15,
	ManagesAnchoring = true,
	Duration         = 0.9,
	PredictPhase     = 1,
	VFX              = "GuardLeap",

	CanHitNow = function(npc, target, distHit)
		local IMPACT_RADIUS = 8
		return distHit >= 8 and distHit <= 20 and distHit <= (IMPACT_RADIUS + 2)
	end,

	Execute = function(ctx, target)
		local fallback = target and target:FindFirstChild("HumanoidRootPart") and target.HumanoidRootPart.Position
		local landing  = (ctx.TargetPred and ctx.TargetPred.Pos) or fallback
		if not landing then return end
		return Core.JumpImpact(ctx, {
			TargetPos = landing,
			Duration  = 0.9,
			Radius    = 8,
			Damage    = 500,
		})
	end
}


A.MobSlamBlink = {
	Key        = "MobSlamBlink",
	TargetType = T.U_ENEMY,

	Range      = 18,
	Width      = 5,
	Delay      = 0.7,
	Recovery   = 0.2,
	Cooldown   = 6.0,
	Weight     = 1,
	VFX        = "MobSlash",


	MovesCaster = true,
	MoveLock    = 0.7,

	PredictPhase = 0.75,
	CanHitNow = function(npc, target, distHit)
		return distHit <= 18
	end,

	Execute = function(ctx, target)
		return Core.Experimental.SlamBlink(ctx, {
			Range  = 18,
			Width  = 5,
			Delay  = 0.7,
			Damage = 80,
			VFX    = "MobSlash",
			TargetFilter = "Enemies",
		})
	end
}

return A
