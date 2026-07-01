--[[
Name: VFXRunner.client
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.VFXRunner.client
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ReplicatedStorage
Requires:
  - local VFXCatalog = require(Replicated:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("VFXCatalog"))
Functions: findModelByGuid, playAnimOn, Handlers.PlayMeleeSlash, Handlers.PlayLeapImpact
Clean source lines: 74
]]
local Replicated = game:GetService("ReplicatedStorage")
local RE = Replicated:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents"):WaitForChild("AbilityVisual")

local VFXCatalog = require(Replicated:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("VFXCatalog"))

local NPC_FOLDER = workspace:FindFirstChild("NPCS")

local PoolFolder = workspace:FindFirstChild("Ignore") or workspace

local function findModelByGuid(guid: string): Model?
	if not guid then return nil end


	for _, m in ipairs(PoolFolder:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("RelationId") == guid then
			return m
		end
	end


	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("RelationId") == guid then
			return m
		end
	end
	return nil
end

local function playAnimOn(model: Model, animId: string, speed: number?)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = animator:LoadAnimation(anim)
	track:Play(0.05, 1.0, speed or 1.0)
	return track
end


local Handlers = {}

Handlers.PlayMeleeSlash = function(casterModel: Model, data, info)
	if info.Animation then
		playAnimOn(casterModel, info.Animation, 1.0)
	end

end

Handlers.PlayLeapImpact = function(casterModel: Model, data, info)
	if info.Animation then
		playAnimOn(casterModel, info.Animation, 1.0)
	end

end

RE.OnClientEvent:Connect(function(caster, effectName, data)

	local key = data and data.VFX
	if not key then return end

	local info = VFXCatalog[key]
	if not info then return end


	local casterModel = (typeof(caster) == "Instance" and caster)
		or findModelByGuid(data.Caster)

	local fn = Handlers[info.Handler]
	if fn and casterModel then
		fn(casterModel, data, info)
	end
end)
