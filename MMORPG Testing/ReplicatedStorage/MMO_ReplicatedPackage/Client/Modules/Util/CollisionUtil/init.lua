--[[
Name: CollisionUtil
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Util.CollisionUtil
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Functions: CollisionUtil.setCollisionGroupForModel, CollisionUtil.setCharacterCollisionGroup, CollisionUtil.setModelUncollidable
Clean source lines: 21
]]
local CollisionUtil = {}

function CollisionUtil.setCollisionGroupForModel(model, groupName)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = groupName
		end
	end
end

function CollisionUtil.setCharacterCollisionGroup(character)
	CollisionUtil.setCollisionGroupForModel(character, "Character")
end

function CollisionUtil.setModelUncollidable(model)
	if model:FindFirstChild("Humanoid") or model:FindFirstChild("HumanoidRootPart") then
		CollisionUtil.setCollisionGroupForModel(model, "Character")
	end
end

return CollisionUtil