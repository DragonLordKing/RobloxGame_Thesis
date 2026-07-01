--[[
Name: InputController
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Controllers.InputController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ContextActionService, RunService, Players, UserInputService, ReplicatedStorage
Requires:
  - local Config = require(utilModules:WaitForChild("Config"))
  - local MouseUtil = require(utilModules:WaitForChild("MouseUtil"))
  - local Effects = require(utilModules:WaitForChild("Effects"))
  - local Selection = require(utilModules:WaitForChild("Selection"))
  - local GameState = require(utilModules:WaitForChild("GameState"))
  - local Remotes = require(utilModules:WaitForChild("Remotes"))
  - local GatheringConfig = require(replicatedPackage:WaitForChild("GatheringConfig"))
  - local AbilityController = require(controllerModules:WaitForChild("AbilityController"))
  - local GatheringController = require(controllerModules:WaitForChild("GatheringController"))
  - local CraftingController = require(controllerModules:WaitForChild("CraftingController"))
  - if require(replicatedPackage:WaitForChild("Client"):WaitForChild("RelationClient")):Get(clickedModel) == "Hostile" then
  - if obj:IsA("Model") and require(replicatedPackage:WaitForChild("Client"):WaitForChild("RelationClient")):Get(obj) == "Hostile" and obj ~= player.Character then
  - if sel and sel ~= player.Character and require(replicatedPackage:WaitForChild("Client"):WaitForChild("RelationClient")):Get(sel) == "Hostile" then
Functions: raycastFromMouse, isCityMonolithPart, promptPartFor, distanceToPartBounds, findEconomyInteractable, sendEconomyInteract, interactEconomyTarget, onLeftClick, onRightClick, onKeyA, onKeyS, onKeyQ, onKeyW, onKeyE, InputController.bind, GameState.interactCallback
Clean source lines: 473
]]
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local CAMERA_OVERRIDE_ATTR = "BuildCameraOverride"

local replicatedPackage = game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage")
local clientModules = replicatedPackage:WaitForChild("Client"):WaitForChild("Modules")
local utilModules = clientModules:WaitForChild("Util")
local controllerModules = clientModules:WaitForChild("Controllers")

local Config = require(utilModules:WaitForChild("Config"))
local MouseUtil = require(utilModules:WaitForChild("MouseUtil"))
local Effects = require(utilModules:WaitForChild("Effects"))
local Selection = require(utilModules:WaitForChild("Selection"))
local GameState = require(utilModules:WaitForChild("GameState"))
local Remotes = require(utilModules:WaitForChild("Remotes"))
local EconomyMarketRequest = replicatedPackage:WaitForChild("RemoteEvents"):WaitForChild("EconomyMarketRequest")
local GatheringConfig = require(replicatedPackage:WaitForChild("GatheringConfig"))
local AbilityController = require(controllerModules:WaitForChild("AbilityController"))
local GatheringController = require(controllerModules:WaitForChild("GatheringController"))
local CraftingController = require(controllerModules:WaitForChild("CraftingController"))

local InputController = {}


local leftEffect = false
local rightEffect = false


local aIndicator : BasePart?
local aConn : RBXScriptConnection?

local function raycastFromMouse()
	local loc = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(loc.X, loc.Y)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {player.Character}
	params.FilterType = Enum.RaycastFilterType.Exclude
	return workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
end

local function isCityMonolithPart(part)
	local current = part
	while current and current ~= workspace do
		if current.Name == "CityClaimMonolith" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function promptPartFor(inst, preferredName)
	if inst and inst:IsA("BasePart") then return inst end
	if not inst then return nil end
	local names = { preferredName or "MainPrompt", "MainPrompt", "AuctionOpener", "BlackMarketOpener", "Opener", "Prompt" }
	for _, name in ipairs(names) do
		local found = inst:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then return found end
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function distanceToPartBounds(part, position)
	if not part or typeof(position) ~= "Vector3" then return math.huge end
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size * 0.5
	local clamped = Vector3.new(
		math.clamp(localPos.X, -half.X, half.X),
		math.clamp(localPos.Y, -half.Y, half.Y),
		math.clamp(localPos.Z, -half.Z, half.Z)
	)
	local nearest = part.CFrame:PointToWorldSpace(clamped)
	return (position - nearest).Magnitude
end

local function findEconomyInteractable(part)
	local current = part
	while current and current ~= workspace do
		if current:IsA("Model") or current:IsA("BasePart") then
			local name = string.lower(current.Name)
			local marketType = tostring(current:GetAttribute("MarketType") or "")
			if current:GetAttribute("LootChest") == true or current:GetAttribute("DeathSack") == true or current:GetAttribute("ChestType") == "DeathSack" or (current:IsA("Model") and (name:find("treasurechesttype", 1, true) or name:find("deathsack", 1, true) or name:find("death_sack", 1, true))) then
				return current, promptPartFor(current, current:GetAttribute("DeathSack") == true and "DeathSackPrompt" or "MainPrompt")
			end
			if marketType == "Auction" or (current:IsA("Model") and name:find("auction", 1, true)) then
				return current, promptPartFor(current, "AuctionOpener")
			end
			if marketType == "BlackMarket" or (current:IsA("Model") and (name:find("blackmarket", 1, true) or name:find("black_market", 1, true))) then
				return current, promptPartFor(current, "BlackMarketOpener")
			end
		end
		current = current.Parent
	end
	return nil, nil
end

local function sendEconomyInteract(target)
	task.spawn(function()
		local ok, result = pcall(function()
			return EconomyMarketRequest:InvokeServer("WorldInteract", { Target = target })
		end)
		if not ok then warn("[Input] WorldInteract failed: " .. tostring(result)) end
	end)
end

local function interactEconomyTarget(target, targetPart)
	if not target or not targetPart then return false end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local range = 6.5 * (GameState.isMounted and 2 or 1)
	if distanceToPartBounds(targetPart, hrp.Position) > range then
		GameState.interactTargetPart = targetPart
		GameState.isWalkingToInteract = true
		GameState.interactDistanceOverride = range
		GameState.interactCallback = function()
			sendEconomyInteract(target)
		end
		GameState.interactCallbackTarget = target
	else
		sendEconomyInteract(target)
	end
	return true
end

local function onLeftClick(_, state)
	if player:GetAttribute(CAMERA_OVERRIDE_ATTR) then
		return Enum.ContextActionResult.Sink
	end
	if GameState.buildPlacementActive or player:GetAttribute("BuildPlacementActive") then
		return Enum.ContextActionResult.Sink
	end
	if MouseUtil.isMouseOverAnyGui() then return Enum.ContextActionResult.Sink end
	if state == Enum.UserInputState.Begin then
		if GameState.mounting then Remotes.CancelMount:FireServer() end
		GatheringController.cancel()
		if not leftEffect then
			Effects.spawnExpandingCircle(MouseUtil.getMouseClickEffectPosition())
			leftEffect = true
		end

		local result = MouseUtil.raycastInteractionFromMouse()
		local detectorTriggered = false
		if result and result.Instance then
			local part = result.Instance
			if isCityMonolithPart(part) and type(_G.OpenCityMonolithPanel) == "function" then
				_G.OpenCityMonolithPanel()
				return Enum.ContextActionResult.Sink
			end
			local economyTarget, economyPart = findEconomyInteractable(part)
			if economyTarget and interactEconomyTarget(economyTarget, economyPart) then
				return Enum.ContextActionResult.Sink
			end
			local gatherNode = GatheringController.getGatheringNode(part)
			if gatherNode then
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local targetPart = gatherNode:IsA("Model") and (gatherNode.PrimaryPart or gatherNode:FindFirstChildWhichIsA("BasePart", true)) or gatherNode
				if hrp and targetPart and targetPart:IsA("BasePart") then
					local range = (tonumber(GatheringConfig.InteractDistance) or 8) * (GameState.isMounted and 2 or 1)
					local dist = (hrp.Position - targetPart.Position).Magnitude
					if dist > range then
						GameState.interactTargetPart = targetPart
						GameState.isWalkingToInteract = true
						GameState.interactDistanceOverride = range
						GameState.interactCallback = function(target)
							GatheringController.startGathering(target)
						end
						GameState.interactCallbackTarget = gatherNode
					else
						GatheringController.startGathering(gatherNode)
					end
					detectorTriggered = true
				end
			else
				local parent = part:FindFirstAncestorOfClass("Model") or part.Parent
				local detector = parent and parent:FindFirstChild("Detector")
				if detector then
					if detector:GetAttribute("BuildingKey") then
						leftEffect = false
						if detector:GetAttribute("Completed") ~= true and type(_G.OpenBuildingManagePanel) == "function" then
							_G.OpenBuildingManagePanel(detector)
							return Enum.ContextActionResult.Sink
						end
						if CraftingController.openFromDetector(detector) then
							return Enum.ContextActionResult.Sink
						end
						return Enum.ContextActionResult.Pass
					end

					local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						local range = GameState.INTERACT_DISTANCE * (GameState.isMounted and 2 or 1)
						local dist = (hrp.Position - part.Position).Magnitude
						if dist > range then
							GameState.interactTargetPart = part
							GameState.isWalkingToInteract = true
							GameState.detectorInteractionActive = true
							GameState.detectorInteractionTarget = parent
						else
							Effects.showBillboardPopup(parent)
						end
						detectorTriggered = true
					end
				end
			end
		end

		if not detectorTriggered then

			local clickedModel = Selection.getTargetModel(result and result.Instance)
			local isRigClick = Selection.isSelectableUnit(clickedModel)
			if isRigClick then
				Selection.setPersistent(clickedModel)
				local targetPart = clickedModel:FindFirstChild("HumanoidRootPart") or clickedModel:FindFirstChildWhichIsA("BasePart")
				if targetPart then
					local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						if GameState.isMounted then
							return Enum.ContextActionResult.Pass
						end
						local dist = (hrp.Position - targetPart.Position).Magnitude
						if require(replicatedPackage:WaitForChild("Client"):WaitForChild("RelationClient")):Get(clickedModel) == "Hostile" then
							GameState.continuousAttackMode = true
							if dist <= GameState.INTERACT_DISTANCE then
								if time() - GameState.lastAttackTime >= GameState.ATTACK_COOLDOWN then
									GameState.lastAttackTime = time()
									local serverModel = Selection.resolveServerModel(clickedModel)
									Remotes.AttackTarget:FireServer(serverModel, "basic")
								end
								GameState.disableMovement = true
								return Enum.ContextActionResult.Sink
							else
								GameState.continuousAttackMode = true
								GameState.interactTargetPart = targetPart
								GameState.isWalkingToInteract = true
								return Enum.ContextActionResult.Sink
							end
						else
							GameState.continuousAttackMode = false
							local dir = (hrp.Position - targetPart.Position).Unit
							GameState.interactTargetPosition = targetPart.Position + dir * 5
							GameState.isWalkingToInteract = true
							return Enum.ContextActionResult.Sink
						end
					end
				end
				return Enum.ContextActionResult.Sink
			end


			GameState.isWalkingToInteract = false
			GameState.interactTargetPart = nil
			GameState.interactTargetPosition = nil
			GameState.detectorInteractionActive = false
			GameState.detectorInteractionTarget = nil
			GameState.interactCallback = nil
			GameState.interactCallbackTarget = nil
			GameState.interactDistanceOverride = nil
			GameState.continuousAttackMode = false
			local targetPos = MouseUtil.getMouseTargetPosition()
			local mover = GameState:GetMover()
			if mover and targetPos then
				local humanoid = mover:FindFirstChildWhichIsA("Humanoid")
				if humanoid then humanoid:MoveTo(targetPos) end
			end
		end
	elseif state == Enum.UserInputState.End then
		leftEffect = false
		if not GameState.gathering then
			GameState.disableMovement = false
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onRightClick(_, state)
	if player:GetAttribute(CAMERA_OVERRIDE_ATTR) then
		return Enum.ContextActionResult.Sink
	end
	if GameState.buildPlacementActive or player:GetAttribute("BuildPlacementActive") then
		return Enum.ContextActionResult.Sink
	end
	if MouseUtil.isMouseOverAnyGui() then return Enum.ContextActionResult.Sink end
	if state == Enum.UserInputState.Begin then
		if GameState.mounting then Remotes.CancelMount:FireServer() end
		GatheringController.cancel()
		GameState.isWalkingToInteract = false
		GameState.interactTargetPart = nil
		GameState.detectorInteractionActive = false
		GameState.detectorInteractionTarget = nil
		GameState.interactCallback = nil
		GameState.interactCallbackTarget = nil
		GameState.interactDistanceOverride = nil
		GameState.continuousAttackMode = false
		if not rightEffect then
			Effects.spawnExpandingCircle(MouseUtil.getMouseGroundClickEffectPosition())
			rightEffect = true
		end
	elseif state == Enum.UserInputState.End then
		rightEffect = false
		GameState.disableMovement = false
	end
	return Enum.ContextActionResult.Sink
end

local function onKeyA(_, state)
	if player:GetAttribute(CAMERA_OVERRIDE_ATTR) then
		return Enum.ContextActionResult.Sink
	end

	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return Enum.ContextActionResult.Pass end
	if GameState.isMounted then return Enum.ContextActionResult.Pass end

	local IND_DIAM = (GameState.INTERACT_DISTANCE * 2) + 1
	local THICK = 1

	if state == Enum.UserInputState.Begin then
		local verticalOffset = (hrp.Size and hrp.Size.Y or 2) / 2 + 0.2
		aIndicator = Instance.new("Part")
		aIndicator.Name = "ACircleIndicator"
		aIndicator.Size = Vector3.new(THICK, IND_DIAM, IND_DIAM)
		aIndicator.Shape = Enum.PartType.Cylinder
		aIndicator.Anchored = true
		aIndicator.CanCollide = false
		aIndicator.Transparency = 0.5
		aIndicator.Color = Color3.new(0,1,0)
		aIndicator.CFrame = CFrame.new(hrp.Position - Vector3.new(0, verticalOffset + 2, 0)) * CFrame.Angles(0,0, math.rad(90))
		aIndicator.Parent = workspace
		aConn = RunService.Heartbeat:Connect(function()
			local hrp2 = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp2 and aIndicator then
				aIndicator.CFrame = CFrame.new(hrp2.Position - Vector3.new(0, verticalOffset + 2, 0)) * CFrame.Angles(0,0, math.rad(90))
			end
		end)
		return Enum.ContextActionResult.Pass
	elseif state == Enum.UserInputState.End then
		if aConn then aConn:Disconnect(); aConn = nil end
		if aIndicator then aIndicator:Destroy(); aIndicator = nil end

		if hrp and not Selection.getPersistent() then
			local closest, minDist = nil, IND_DIAM / 2
			local hrpFlat = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("Model") and require(replicatedPackage:WaitForChild("Client"):WaitForChild("RelationClient")):Get(obj) == "Hostile" and obj ~= player.Character then
					local p = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
					if p then
						local pf = Vector3.new(p.Position.X, 0, p.Position.Z)
						local d = (hrpFlat - pf).Magnitude
						if d <= minDist then
							minDist = d
							closest = obj
						end
					end
				end
			end
			if closest then
				Selection.setPersistent(closest)
			end
		end

		local sel = Selection.getPersistent()
		if sel and sel ~= player.Character and require(replicatedPackage:WaitForChild("Client"):WaitForChild("RelationClient")):Get(sel) == "Hostile" then
			GameState.continuousAttackMode = true
			local t = sel:FindFirstChild("HumanoidRootPart") or sel:FindFirstChildWhichIsA("BasePart")
			if t then
				GameState.interactTargetPart = t
				GameState.isWalkingToInteract = true
				GameState.detectorInteractionActive = false
				GameState.detectorInteractionTarget = nil
				GameState.interactCallback = nil
				GameState.interactCallbackTarget = nil
				GameState.interactDistanceOverride = nil
			end
		end
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Pass
end

local function onKeyS(_, state)
	if player:GetAttribute(CAMERA_OVERRIDE_ATTR) then
		return Enum.ContextActionResult.Sink
	end
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	GatheringController.cancel()
	GameState.isWalkingToInteract = false
	GameState.interactTargetPart = nil
	GameState.interactTargetPosition = nil
	GameState.detectorInteractionActive = false
	GameState.detectorInteractionTarget = nil
	GameState.interactCallback = nil
	GameState.interactCallbackTarget = nil
	GameState.interactDistanceOverride = nil
	GameState.continuousAttackMode = false
	GameState.disableMovement = false

	local mover = GameState:GetMover()
	if mover then
		local humanoid = mover:FindFirstChildWhichIsA("Humanoid")
		local hrp = mover:FindFirstChild("HumanoidRootPart")
		if humanoid and hrp then humanoid:MoveTo(hrp.Position) end
	end
	return Enum.ContextActionResult.Sink
end

local function onKeyQ(_, state)
	if player:GetAttribute(CAMERA_OVERRIDE_ATTR) then
		return Enum.ContextActionResult.Sink
	end
	if GameState.buildPlacementActive or player:GetAttribute("BuildPlacementActive") then
		return Enum.ContextActionResult.Sink
	end
	if state == Enum.UserInputState.Begin and not GameState.isMounted then
		if GameState.mounting then Remotes.CancelMount:FireServer() end
		GatheringController.cancel()
		AbilityController.fireAbility("Q", GameState.currentQ)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function onKeyW(_, state)
	if player:GetAttribute(CAMERA_OVERRIDE_ATTR) then
		return Enum.ContextActionResult.Sink
	end
	if GameState.buildPlacementActive or player:GetAttribute("BuildPlacementActive") then
		return Enum.ContextActionResult.Sink
	end
	if state == Enum.UserInputState.Begin and not GameState.isMounted then
		if GameState.mounting then Remotes.CancelMount:FireServer() end
		GatheringController.cancel()
		if MouseUtil.getMouseTargetPosition() then
			AbilityController.fireAbility("W", GameState.currentW)
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function onKeyE(_, state)
	if player:GetAttribute(CAMERA_OVERRIDE_ATTR) then
		return Enum.ContextActionResult.Sink
	end
	if GameState.isMounted then return Enum.ContextActionResult.Pass end
	if GameState.buildPlacementActive or player:GetAttribute("BuildPlacementActive") then
		return Enum.ContextActionResult.Sink
	end
	if state == Enum.UserInputState.Begin then
		if GameState.mounting then Remotes.CancelMount:FireServer() end
		GatheringController.cancel()
		if MouseUtil.getMouseTargetPosition() then
			AbilityController.fireAbility("E")
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function InputController.bind()
	ContextActionService:BindActionAtPriority("LeftClickMovement", onLeftClick, false, Config.HIGH_PRIORITY, Enum.UserInputType.MouseButton1)
	ContextActionService:BindActionAtPriority("RightClickMovement", onRightClick, false, Config.HIGH_PRIORITY, Enum.UserInputType.MouseButton2)
	ContextActionService:BindAction("MoveToRigViaA", onKeyA, false, Enum.KeyCode.A)
	ContextActionService:BindAction("StopAllActions", onKeyS, false, Enum.KeyCode.S)
	ContextActionService:BindAction("AbilityQ", onKeyQ, false, Enum.KeyCode.Q)
	ContextActionService:BindAction("AbilityW", onKeyW, false, Enum.KeyCode.W)
	ContextActionService:BindAction("AbilityE", onKeyE, false, Enum.KeyCode.E)
end

return InputController