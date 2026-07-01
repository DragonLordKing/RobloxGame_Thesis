--[[
Name: Collisions
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.Collisions
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: PhysicsService, Workspace
Functions: setModelUncollidable
Clean source lines: 43
]]
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")


pcall(function()
	PhysicsService:RegisterCollisionGroup("Horse")
	PhysicsService:RegisterCollisionGroup("Character")
end)


PhysicsService:CollisionGroupSetCollidable("Horse", "Character", false)

PhysicsService:CollisionGroupSetCollidable("Horse", "Default", true)

PhysicsService:CollisionGroupSetCollidable("Character", "Character", false)


local function setModelUncollidable(model)
	if model:FindFirstChild("Humanoid") or model:FindFirstChild("HumanoidRootPart") then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = "Character"
			end
		end
	end
end


for _, obj in ipairs(Workspace:GetChildren()) do
	if obj:IsA("Model") then
		setModelUncollidable(obj)
	end
end


Workspace.ChildAdded:Connect(function(child)
	if child:IsA("Model") then

		wait(0.1)
		setModelUncollidable(child)
	end
end)
