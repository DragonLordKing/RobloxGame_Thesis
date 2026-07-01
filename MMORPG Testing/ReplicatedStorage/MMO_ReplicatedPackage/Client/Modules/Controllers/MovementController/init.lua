--[[
Name: MovementController
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Controllers.MovementController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: RunService, Players, ReplicatedStorage, UserInputService
Requires:
  - local MouseUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.MouseUtil)
  - local Selection = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Selection)
  - local GameState = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.GameState)
  - local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Remotes)
  - if GameState.continuousAttackMode and sel and sel ~= player.Character and (require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage")...
  - if canAttack and sel and (require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").RelationClient):Get(sel) ...
  - require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Effects).showBillboardPopup(GameState....
Functions: moveTo, nearestPointOnPart, MovementController.start, MovementController.stop
Clean source lines: 117
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local CAMERA_OVERRIDE_ATTR = "BuildCameraOverride"

local MouseUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.MouseUtil)
local Selection = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Selection)
local GameState = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.GameState)
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Remotes)

local MovementController = {}

local moveConn : RBXScriptConnection? = nil

local function moveTo(model, position)
	if not model then return end
	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if humanoid then humanoid:MoveTo(position) end
end

local function nearestPointOnPart(part, position)
	if not part or typeof(position) ~= "Vector3" then return part and part.Position or position end
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size * 0.5
	local clamped = Vector3.new(
		math.clamp(localPos.X, -half.X, half.X),
		math.clamp(localPos.Y, -half.Y, half.Y),
		math.clamp(localPos.Z, -half.Z, half.Z)
	)
	return part.CFrame:PointToWorldSpace(clamped)
end

function MovementController.start()
	if moveConn then return end
	moveConn = RunService.RenderStepped:Connect(function(dt)
		if player:GetAttribute(CAMERA_OVERRIDE_ATTR) then
			return
		end
		local mover = GameState:GetMover()
		if not mover then return end
		local humanoid = mover:FindFirstChildWhichIsA("Humanoid")
		local hrp = mover:FindFirstChild("HumanoidRootPart")
		if not humanoid or not hrp then return end
		if GameState.inventoryDragActive then
			moveTo(mover, hrp.Position)
			return
		end


		local sel = Selection.getPersistent()
		if GameState.continuousAttackMode and sel and sel ~= player.Character and (require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").RelationClient):Get(sel) == "Hostile") then
			local targetBase = sel:FindFirstChild("HumanoidRootPart") or sel:FindFirstChildWhichIsA("BasePart")
			if targetBase then
				local dist = (hrp.Position - targetBase.Position).Magnitude
				if dist > GameState.INTERACT_DISTANCE then
					moveTo(mover, targetBase.Position)
					GameState.isWalkingToInteract = true
				else
					moveTo(mover, hrp.Position)
					if (time() - GameState.lastAttackTime >= GameState.ATTACK_COOLDOWN) then
						GameState.lastAttackTime = time()
						Remotes.AttackTarget:FireServer(Selection.resolveServerModel(sel), "basic")
					end
				end
			end


		elseif GameState.isWalkingToInteract and GameState.interactTargetPart then
			local tpos = nearestPointOnPart(GameState.interactTargetPart, hrp.Position)
			local dist = (hrp.Position - tpos).Magnitude
			local interactDistance = GameState.interactDistanceOverride or GameState.INTERACT_DISTANCE
			if dist > interactDistance then
				moveTo(mover, tpos)
			else
				moveTo(mover, hrp.Position)
				local canAttack = (time() - GameState.lastAttackTime >= GameState.ATTACK_COOLDOWN)
				if canAttack and sel and (require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").RelationClient):Get(sel) == "Hostile") and sel ~= player.Character then
					GameState.lastAttackTime = time()
					Remotes.AttackTarget:FireServer(Selection.resolveServerModel(sel), "basic")
				end
				if GameState.interactCallback then
					local callback = GameState.interactCallback
					local callbackTarget = GameState.interactCallbackTarget
					GameState.interactCallback = nil
					GameState.interactCallbackTarget = nil
					GameState.interactDistanceOverride = nil
					callback(callbackTarget)
				elseif GameState.detectorInteractionActive and GameState.detectorInteractionTarget then
					require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Effects).showBillboardPopup(GameState.detectorInteractionTarget)
					GameState.detectorInteractionActive = false
					GameState.detectorInteractionTarget = nil
				end
				GameState.isWalkingToInteract = false
				GameState.interactTargetPart = nil
				GameState.interactDistanceOverride = nil
			end


		elseif not GameState.disableMovement then
			local uis = game:GetService("UserInputService")
			local mapOpen = player.PlayerGui:FindFirstChild("WorldMapUI") and player.PlayerGui.WorldMapUI:FindFirstChild("WorldMapRoot") and player.PlayerGui.WorldMapUI.WorldMapRoot.Visible
			local rightHeld = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
			local leftHeld = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			if (not MouseUtil.isMouseOverAnyGui() and (leftHeld or rightHeld)) or (mapOpen and rightHeld) then
				local rawPos = MouseUtil.getMouseTargetPosition()
				if rawPos then moveTo(mover, rawPos) end
			end
		end
	end)
end

function MovementController.stop()
	if moveConn then moveConn:Disconnect(); moveConn = nil end
end

return MovementController