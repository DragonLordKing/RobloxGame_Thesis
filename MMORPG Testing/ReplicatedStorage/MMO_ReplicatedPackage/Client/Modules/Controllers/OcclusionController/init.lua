--[[
Name: OcclusionController
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Controllers.OcclusionController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: RunService, Players
Functions: OcclusionController.start, OcclusionController.stop
Clean source lines: 74
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local OcclusionController = {}

local currentObstruction : BasePart?
local conn : RBXScriptConnection?

function OcclusionController.start()
	if conn then return end
	conn = RunService.RenderStepped:Connect(function()
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not (character and hrp) then return end

		local camPos = camera.CFrame.Position
		local targetPos = hrp.Position

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Blacklist
		params.FilterDescendantsInstances = {character}

		local direction = targetPos - camPos
		local hit = workspace:Raycast(camPos, direction, params)
		if hit then
			local part = hit.Instance
			if part:GetAttribute("NoOccull") == true then return end

			local mdl = part:FindFirstAncestorOfClass("Model") or part.Parent
			local skip = false
			if mdl then
				if mdl:FindFirstChild("HumanoidRootPart") or mdl:FindFirstChild("Detector") then
					skip = true
				end
			end

			if not skip then
				local hitDist = (targetPos - hit.Position).Magnitude
				local newT = (hitDist < 5) and 1 or 0.8
				part.LocalTransparencyModifier = newT
			else
				part.LocalTransparencyModifier = 0
			end

			if currentObstruction and currentObstruction ~= part then
				local prevMdl = currentObstruction:FindFirstAncestorOfClass("Model") or currentObstruction.Parent
				local prevSkip = false
				if prevMdl then
					if prevMdl:FindFirstChild("HumanoidRootPart") or prevMdl:FindFirstChild("Detector") then
						prevSkip = true
					end
				end
				if not prevSkip then
					currentObstruction.LocalTransparencyModifier = 0
				end
			end
			currentObstruction = part
		else
			if currentObstruction then
				currentObstruction.LocalTransparencyModifier = 0
				currentObstruction = nil
			end
		end
	end)
end

function OcclusionController.stop()
	if conn then conn:Disconnect(); conn = nil end
	if currentObstruction then currentObstruction.LocalTransparencyModifier = 0; currentObstruction = nil end
end

return OcclusionController