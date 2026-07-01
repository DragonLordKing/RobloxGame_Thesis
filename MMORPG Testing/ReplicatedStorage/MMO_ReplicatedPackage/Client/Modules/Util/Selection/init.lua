--[[
Name: Selection
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Util.Selection
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, RunService, ReplicatedStorage
Requires:
  - local Relation = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").RelationClient)
  - local TargetTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
  - local CollisionUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.CollisionUtil)
  - local MouseUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.MouseUtil)
Functions: Selection.getTargetModel, Selection.isSelectableUnit, Selection.resolveServerModel, Selection.getPersistent, Selection.setPersistent, Selection.clearPersistent, Selection.unitFits, Selection.acquirePair, Selection.startHoverLoop, Selection.stopHoverLoop
Clean source lines: 198
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local Relation = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").RelationClient)
local TargetTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
local CollisionUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.CollisionUtil)
local MouseUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.MouseUtil)

local Selection = {}

local persistentSelectedCharacter : Model? = nil
local persistentHighlightInstance : Highlight? = nil

local transientHighlightedCharacter : Model? = nil
local transientHighlightInstance : Highlight? = nil

function Selection.getTargetModel(targetPart: BasePart?)
	if not targetPart then return nil end
	local mdl = targetPart:FindFirstAncestorOfClass("Model")
	if not mdl then return nil end


	if mdl:GetAttribute("IsMount") then
		local ownerId = mdl:GetAttribute("OwnerUserId")
		if ownerId then
			local ownerPlr = Players:GetPlayerByUserId(ownerId)
			if ownerPlr and ownerPlr.Character then
				return ownerPlr.Character
			end
		end
	end
	return mdl
end

function Selection.isSelectableUnit(model: Model?)
	if not model or model == player.Character then
		return false
	end

	if Players:GetPlayerFromCharacter(model) then
		return true
	end

	if model:GetAttribute("RelationId") or model:GetAttribute("IsMount") then
		return true
	end

	return model:FindFirstChildWhichIsA("Humanoid") ~= nil
end


function Selection.resolveServerModel(any: Instance?)
	if not any then return nil end
	local mdl = any:IsA("Model") and any or any:FindFirstAncestorOfClass("Model")
	if not mdl then return nil end


	if Players:GetPlayerFromCharacter(mdl) then
		return mdl
	end


	if mdl:GetAttribute("IsMount") then
		return mdl
	end


	local guid = mdl:GetAttribute("RelationId")
	if typeof(guid) == "string" and #guid > 0 then
		return guid
	end


	return mdl
end

function Selection.getPersistent()
	return persistentSelectedCharacter
end

function Selection.setPersistent(model: Model?)
	if persistentHighlightInstance then
		persistentHighlightInstance:Destroy()
		persistentHighlightInstance = nil
	end
	persistentSelectedCharacter = Selection.isSelectableUnit(model) and model or nil
	if persistentSelectedCharacter then
		model = persistentSelectedCharacter
		CollisionUtil.setModelUncollidable(model)
		local h = Instance.new("Highlight")

		h.FillColor = Relation:GetColor(model)
		h.OutlineTransparency = 1
		h.Adornee = model
		h.Parent = model
		persistentHighlightInstance = h
	end
end

function Selection.clearPersistent()
	Selection.setPersistent(nil)
end

function Selection.unitFits(tt, model)
	if not model then return false end
	if tt == TargetTypes.U_ANY then return true end
	if tt == TargetTypes.U_ALLY then return Relation:Get(model) ~= "Hostile" end
	if tt == TargetTypes.U_ENEMY then return Relation:Get(model) == "Hostile" end
	return false
end

function Selection.acquirePair(tt)
	local a = Selection.getPersistent()
	if not a or not Selection.unitFits(TargetTypes.U_ANY, a) then return nil end

	local desiredSecondIsEnemy =
		(tt == TargetTypes.P_AE and Relation:Get(a) ~= "Hostile")
		or (tt == TargetTypes.P_EE)

	local best, bestDist = nil, math.huge
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then

		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") and obj ~= a then
				local rel = Relation:Get(obj)
				if (desiredSecondIsEnemy and rel == "Hostile")
					or (not desiredSecondIsEnemy and rel ~= "Hostile") then
					local p = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
					if p then
						local d = (root.Position - p.Position).Magnitude
						if d < bestDist then best, bestDist = obj, d end
					end
				end
			end
		end
	end
	if best then return {a, best} end
end


local hoverConn : RBXScriptConnection? = nil
function Selection.startHoverLoop()
	if hoverConn then return end
	hoverConn = RunService.RenderStepped:Connect(function()
		local target = MouseUtil.getMouseInteractionTarget()
		local model = Selection.getTargetModel(target)
		if Selection.isSelectableUnit(model) then
			if model == persistentSelectedCharacter then
				if transientHighlightInstance then
					transientHighlightInstance:Destroy()
					transientHighlightInstance = nil
					transientHighlightedCharacter = nil
				end
			else
				if transientHighlightedCharacter ~= model then
					if transientHighlightInstance then
						transientHighlightInstance:Destroy()
						transientHighlightInstance = nil
					end
					transientHighlightedCharacter = model
					local h = Instance.new("Highlight")
					h.FillColor = Relation:GetColor(model)
					h.OutlineTransparency = 0.2
					h.Adornee = model
					h.Parent = model
					transientHighlightInstance = h
				else
					if transientHighlightInstance then
						transientHighlightInstance.FillColor = Relation:GetColor(model)
					end
				end
			end
		else
			if transientHighlightInstance then
				transientHighlightInstance:Destroy()
				transientHighlightInstance = nil
				transientHighlightedCharacter = nil
			end
		end
	end)
end

function Selection.stopHoverLoop()
	if hoverConn then hoverConn:Disconnect(); hoverConn = nil end
	if transientHighlightInstance then
		transientHighlightInstance:Destroy()
		transientHighlightInstance = nil
		transientHighlightedCharacter = nil
	end
end


Selection.resolveServerModel = Selection.resolveServerModel

return Selection
