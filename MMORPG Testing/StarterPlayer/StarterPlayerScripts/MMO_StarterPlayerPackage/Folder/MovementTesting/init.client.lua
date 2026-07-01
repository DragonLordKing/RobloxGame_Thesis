--[[
Name: MovementTesting
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.Folder.MovementTesting
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=false, LinkedSource="", Disabled=true, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ContextActionService, RunService, Players, UserInputService, ReplicatedStorage, GuiService, PhysicsService, Debris
Requires:
  - local AbilityIndex = require(replicatedPackage:WaitForChild("Shared"):WaitForChild("AbilityIndex"))
  - local TargetTypes = require(replicatedPackage:WaitForChild("Shared"):WaitForChild("TargetTypes"))
  - local Relation = require(replicatedPackage:WaitForChild("Client"):WaitForChild("RelationClient"))
Functions: setCollisionGroupForModel, setCharacterCollisionGroup, setModelUncollidable, clearMountGui, showBillboardPopup, isMouseOverAnyGui, spawnExpandingCircle, getTargetModel, getHighlightedUnit, unitFits, acquirePair, buildTargetArg, fireAbility, leftClickAction, rightClickAction, createProgressBar, update, destroy, getMouseTargetPosition
Clean source lines: 1143
]]
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local PhysicsService = game:GetService("PhysicsService")
local replicatedPackage = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
local RemoteEvents = replicatedPackage:WaitForChild("RemoteEvents")

local AbilityIndex = require(replicatedPackage:WaitForChild("Shared"):WaitForChild("AbilityIndex"))
local TargetTypes = require(replicatedPackage:WaitForChild("Shared"):WaitForChild("TargetTypes"))
local Relation = require(replicatedPackage:WaitForChild("Client"):WaitForChild("RelationClient"))

local RequestMount = RemoteEvents:WaitForChild("RequestMount")
local RequestDismount = RemoteEvents:WaitForChild("RequestDismount")
local CurrentHorseEvent = RemoteEvents:WaitForChild("CurrentHorse")
local ShowBoundaryIndicator = RemoteEvents:WaitForChild("ShowBoundaryIndicator")
local UpdateHorseStatus = RemoteEvents:WaitForChild("UpdateHorseStatus")
local CancelMount = RemoteEvents:WaitForChild("CancelMount")
local RemountRequest = RemoteEvents:WaitForChild("RemountRequest")
local UpdateHorseCFrame = RemoteEvents:WaitForChild("UpdateHorseCFrame")
local AttackTarget = RemoteEvents:WaitForChild("AttackTarget")
local UpdateBasicCooldown = RemoteEvents:WaitForChild("UpdateBasicCooldown")
local UpdateBasicRange = RemoteEvents:WaitForChild("UpdateBasicRange")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera


local boundaryIndicator = nil

local GROUND_Y = 0
local INTERACT_DISTANCE = 5
local HIGH_PRIORITY = Enum.ContextActionPriority.High.Value

local isMounted = false
local currentHorse = nil
local seatWeld = nil

local interactTargetPart = nil
local interactTargetPosition = nil
local isWalkingToInteract = false

local mountSpeedTimer = 0
local idleTimer = 0
local speedThreshold = 1

local mounting = false

local lastAttackTime = 0
local ATTACK_COOLDOWN = 1

local disableMovement = false
local continuousAttackMode = false

local currentQ = 1
local currentW = 1

local mountingBar = nil
local mountingBarClose = nil


local function setCollisionGroupForModel(model, groupName)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = groupName
		end
	end
end


local function setCharacterCollisionGroup(character)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Character"
		end
	end
end


local function setModelUncollidable(model)
	if model:FindFirstChild("Humanoid") or model:FindFirstChild("HumanoidRootPart") then
		setCollisionGroupForModel(model, "Character")
	end
end

local function clearMountGui()
	local old = player.PlayerGui:FindFirstChild("MountProgressGui")
	if old then
		old:Destroy()
	end
end


local function showBillboardPopup(targetAdornee)
	if not targetAdornee then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "InteractionPopup"
	billboard.Adornee = targetAdornee
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel", billboard)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = "This object has been interacted with!"

	game:GetService("Debris"):AddItem(billboard, 2)
end

local function isMouseOverAnyGui()
	local mouseLoc = UserInputService:GetMouseLocation()
	local inset    = GuiService:GetGuiInset()
	local testX    = mouseLoc.X
	local testY    = mouseLoc.Y - inset.Y

	local guis = player.PlayerGui:GetGuiObjectsAtPosition(testX, testY)
	return #guis > 0
end


RunService.RenderStepped:Connect(function()
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

local leftEffectSpawned = false
local rightEffectSpawned = false


local detectorInteractionActive = false
local detectorInteractionTarget = nil

local function spawnExpandingCircle(position)
	local circle = Instance.new("Part")
	circle.Shape = Enum.PartType.Cylinder
	circle.Anchored = true
	circle.CanCollide = false
	circle.Transparency = 0.5
	circle.Color = Color3.new(1, 0, 0)
	circle.Position = position
	circle.Parent = workspace

	circle.Size = Vector3.new(0.2, 1, 1)
	circle.Orientation = Vector3.new(0, 90, 90)

	local duration = 1.0
	local elapsed = 0
	local initialSize = circle.Size
	local targetSize = Vector3.new(0.1, 4, 4)

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed = elapsed + dt
		local progress = math.clamp(elapsed / duration, 0, 1)
		circle.Size = initialSize:Lerp(targetSize, progress)
		circle.Transparency = 0.5 + progress * 0.5
		if progress >= 1 then
			connection:Disconnect()
			circle:Destroy()
		end
	end)
end


local persistentSelectedCharacter = nil
local persistentHighlightInstance = nil

local transientHighlightedCharacter = nil
local transientHighlightInstance = nil

local function getTargetModel(targetPart)
	if not targetPart then return nil end
	local mdl = targetPart:FindFirstAncestorOfClass("Model")

	if mdl and mdl:GetAttribute("IsMount") then
		local ownerId = mdl:GetAttribute("OwnerUserId")
		if ownerId then
			local ownerPlr = Players:GetPlayerByUserId(ownerId)
			if ownerPlr and ownerPlr.Character then
				mdl = ownerPlr.Character
			end
		end
	end
	return mdl
end

local function getHighlightedUnit()
	return persistentSelectedCharacter
end

local function unitFits(tt, model)
	if not model then return false end
	if tt == TargetTypes.U_ANY   then return true end
	if tt == TargetTypes.U_ALLY  then return Relation:Get(model) ~= "Hostile" end
	if tt == TargetTypes.U_ENEMY then return Relation:Get(model) == "Hostile" end
	return false
end

local function acquirePair(tt)
	local a = getHighlightedUnit()
	if not a or not unitFits(TargetTypes.U_ANY, a) then return nil end

	local desiredSecondIsEnemy =
		(tt == TargetTypes.P_AE and Relation:Get(a) ~= "Hostile") or
		(tt == TargetTypes.P_EE)

	local best, bestDist = nil, math.huge
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, mdl in ipairs(workspace:GetChildren()) do
			if mdl:IsA("Model") and mdl ~= a then
				if desiredSecondIsEnemy  and Relation:Get(mdl) == "Hostile"
					or not desiredSecondIsEnemy and Relation:Get(mdl) ~= "Hostile" then
					local p = mdl:FindFirstChild("HumanoidRootPart") or mdl:FindFirstChildWhichIsA("BasePart")
					if p then
						local d = (root.Position - p.Position).Magnitude
						if d < bestDist then best, bestDist = mdl, d end
					end
				end
			end
		end
	end
	if best then

		return {a, best}
	end
end

local function buildTargetArg(tt)
	if tt == TargetTypes.DIR then
		local pos = getMouseTargetPosition()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return (pos and hrp) and (pos - hrp.Position).Unit or nil

	elseif tt == TargetTypes.LOC then
		return getMouseTargetPosition()

	elseif tt == TargetTypes.SELF then
		return nil

	elseif tt == TargetTypes.U_ANY
		or tt == TargetTypes.U_ALLY
		or tt == TargetTypes.U_ENEMY then
		local unit = getHighlightedUnit()
		if unitFits(tt, unit) then return unit end
		return nil

	elseif tt == TargetTypes.P_AE
		or tt == TargetTypes.P_AA
		or tt == TargetTypes.P_EE then
		return acquirePair(tt)
	end
end

local function fireAbility(slot, idx)
	local weaponType = "Sword"
	local tt = AbilityIndex.GetTargetType(weaponType, slot, idx or 1)
	local targ = buildTargetArg(tt)
	local hrp   = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local origin = hrp and hrp.Position
	local payload = {
		Origin = origin,
		Target = targ
	}
	if tt and (tt == TargetTypes.SELF or targ) then
		AttackTarget:FireServer(payload, slot, idx)
	end
end


function getMouseTargetPosition()
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	if math.abs(ray.Direction.Y) < 0.001 then return nil end
	local t = (GROUND_Y - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then return nil end
	return ray.Origin + ray.Direction * t
end


local function leftClickAction(actionName, inputState, inputObject)
	if isMouseOverAnyGui() then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		if mounting then
			CancelMount:FireServer()
		end

		if not leftEffectSpawned then
			local targetPos = getMouseTargetPosition() or (mouse.Hit and mouse.Hit.Position)
			if targetPos then
				spawnExpandingCircle(targetPos)
			end
			leftEffectSpawned = true
		end

		local detectorTriggered = false

		local ray = camera:ViewportPointToRay(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {player.Character}
		rayParams.FilterType = Enum.RaycastFilterType.Blacklist

		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)
		if result and result.Instance then
			local part = result.Instance
			local parent = part:FindFirstAncestorOfClass("Model") or part.Parent

			if parent and parent:FindFirstChild("Detector") then
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then

					local interactionRange = INTERACT_DISTANCE
					if isMounted then
						interactionRange = interactionRange * 2
					end
					local dist = (hrp.Position - part.Position).Magnitude
					if dist > interactionRange then
						interactTargetPart = part
						isWalkingToInteract = true
						detectorInteractionActive = true
						detectorInteractionTarget = parent
					else

						showBillboardPopup(parent)
					end
					detectorTriggered = true
				end
			end
		end

		if not detectorTriggered then

			local clickedModel = getTargetModel(mouse.Target)
			local isRigClick = false
			if clickedModel and clickedModel ~= player.Character then
				isRigClick = true
				persistentSelectedCharacter = clickedModel

				setModelUncollidable(persistentSelectedCharacter)
				if persistentHighlightInstance then
					persistentHighlightInstance:Destroy()
					persistentHighlightInstance = nil
				end
				persistentHighlightInstance = Instance.new("Highlight")
				local relation = clickedModel.Name
				persistentHighlightInstance.FillColor = Relation:GetColor(clickedModel)
				persistentHighlightInstance.OutlineTransparency = 1
				persistentHighlightInstance.Adornee = clickedModel
				persistentHighlightInstance.Parent = clickedModel
			end

			if isRigClick then
				local targetBasePart = persistentSelectedCharacter:FindFirstChild("HumanoidRootPart")
					or persistentSelectedCharacter:FindFirstChildWhichIsA("BasePart")
				if targetBasePart then
					local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						local interactionRange = INTERACT_DISTANCE
						if isMounted then
							return Enum.ContextActionResult.Pass
						end
						local dist = (hrp.Position - targetBasePart.Position).Magnitude

						if Relation:Get(persistentSelectedCharacter) == "Hostile" then

							continuousAttackMode = true
							if dist <= interactionRange then
								local canAttackNow = (time() - lastAttackTime >= ATTACK_COOLDOWN)
								if canAttackNow then
									lastAttackTime = time()
									AttackTarget:FireServer(persistentSelectedCharacter, "basic")
								end
								disableMovement = true
								return Enum.ContextActionResult.Sink
							else

								continuousAttackMode = true
								interactTargetPart = targetBasePart
								isWalkingToInteract = true
								return Enum.ContextActionResult.Sink
							end
						else

							continuousAttackMode = false
							local direction = (hrp.Position - targetBasePart.Position).Unit
							interactTargetPosition = targetBasePart.Position + direction * 5
							isWalkingToInteract = true
							return Enum.ContextActionResult.Sink
						end
					end
				end
				return Enum.ContextActionResult.Sink
			end
				isWalkingToInteract = false
				interactTargetPart = nil
				interactTargetPosition = nil
				detectorInteractionActive = false
				detectorInteractionTarget = nil
				continuousAttackMode = false

				local targetPos = getMouseTargetPosition() or (mouse.Hit and mouse.Hit.Position)
				if targetPos then

					local moverCharacter = (isMounted and currentHorse) or player.Character
					if moverCharacter then
						local humanoid = moverCharacter:FindFirstChildWhichIsA("Humanoid")
						if humanoid then
							humanoid:MoveTo(targetPos)
						end
					end
				end
		end

	elseif inputState == Enum.UserInputState.End then
		leftEffectSpawned = false
		disableMovement = false
	end

	return Enum.ContextActionResult.Sink
end


local function rightClickAction(actionName, inputState, inputObject)
	if isMouseOverAnyGui() then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		if mounting then
			CancelMount:FireServer()
		end
		isWalkingToInteract = false
		interactTargetPart = nil
		detectorInteractionActive = false
		detectorInteractionTarget = nil
		continuousAttackMode = false
		if not rightEffectSpawned then
			local target = getMouseTargetPosition() or (mouse.Hit and mouse.Hit.Position)
			if target then
				spawnExpandingCircle(target)
			end
			rightEffectSpawned = true
		end
	elseif inputState == Enum.UserInputState.End then
		rightEffectSpawned = false
		disableMovement = false
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority("LeftClickMovement", leftClickAction, false, HIGH_PRIORITY, Enum.UserInputType.MouseButton1)
ContextActionService:BindActionAtPriority("RightClickMovement", rightClickAction, false, HIGH_PRIORITY, Enum.UserInputType.MouseButton2)


local currentObstruction = nil

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local camPos = camera.CFrame.Position
	local targetPos = hrp.Position

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {character}

	local direction = targetPos - camPos
	local rayResult = workspace:Raycast(camPos, direction, rayParams)

	if rayResult then
		local obstructPart = rayResult.Instance
		local hitDist = (targetPos - rayResult.Position).Magnitude
		local threshold = 5
		local newTransparency = (hitDist < threshold) and 1 or 0.8

		if obstructPart:GetAttribute("NoOccull") == true then
			return
		end


		local skipTransparency = false
		local candidateModel = obstructPart:FindFirstAncestorOfClass("Model") or obstructPart.Parent
		if candidateModel then
			if candidateModel:FindFirstChild("HumanoidRootPart") or candidateModel:FindFirstChild("Detector") then
				skipTransparency = true
			end
		end

		if not skipTransparency then
			obstructPart.LocalTransparencyModifier = newTransparency
		else
			obstructPart.LocalTransparencyModifier = 0
		end

		if currentObstruction and currentObstruction ~= obstructPart then

			local prevCandidate = currentObstruction:FindFirstAncestorOfClass("Model") or currentObstruction.Parent
			local prevSkip = false
			if prevCandidate then
				if prevCandidate:FindFirstChild("HumanoidRootPart") or prevCandidate:FindFirstChild("Detector") then
					prevSkip = true
				end
			end
			if not prevSkip then
				currentObstruction.LocalTransparencyModifier = 0
			end
		end

		currentObstruction = obstructPart
	else
		if currentObstruction then
			currentObstruction.LocalTransparencyModifier = 0
			currentObstruction = nil
		end
	end
end)


RunService.RenderStepped:Connect(function()
	local targetPart = mouse.Target
	local targetCharacter = getTargetModel(targetPart)
	if targetCharacter and targetCharacter ~= player.Character and Relation:Get(targetCharacter) then
		if targetCharacter == persistentSelectedCharacter then
			if transientHighlightInstance then
				transientHighlightInstance:Destroy()
				transientHighlightInstance = nil
				transientHighlightedCharacter = nil
			end
		else
			if transientHighlightedCharacter ~= targetCharacter then
				if transientHighlightInstance then
					transientHighlightInstance:Destroy()
					transientHighlightInstance = nil
				end
				transientHighlightedCharacter = targetCharacter
				transientHighlightInstance = Instance.new("Highlight")
				local relation = targetCharacter.Name
				transientHighlightInstance.FillColor = Relation:GetColor(targetCharacter)
				transientHighlightInstance.OutlineTransparency = 0.2
				transientHighlightInstance.Adornee = targetCharacter
				transientHighlightInstance.Parent = targetCharacter
			else
				if transientHighlightInstance then
					local relation = targetCharacter.Name
					transientHighlightInstance.FillColor = Relation:GetColor(targetCharacter)
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


local aIndicator = nil
local aIndicatorConnection = nil

ContextActionService:BindAction("MoveToRigViaA", function(actionName, inputState, inputObject)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return Enum.ContextActionResult.Pass end

	local INDICATOR_DIAMETER = (INTERACT_DISTANCE * 2) + 1
	local INDICATOR_THICKNESS = 1


	if isMounted then
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Begin then
		if hrp then
			local verticalOffset = hrp.Size.Y / 2 + 0.2
			aIndicator = Instance.new("Part")
			aIndicator.Name = "ACircleIndicator"
			aIndicator.Size = Vector3.new(INDICATOR_THICKNESS, INDICATOR_DIAMETER, INDICATOR_DIAMETER)
			aIndicator.Shape = Enum.PartType.Cylinder
			aIndicator.Anchored = true
			aIndicator.CanCollide = false
			aIndicator.Transparency = 0.5
			aIndicator.Color = Color3.new(0, 1, 0)
			aIndicator.CFrame = CFrame.new(hrp.Position - Vector3.new(0, verticalOffset + 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			aIndicator.Parent = workspace

			aIndicatorConnection = RunService.Heartbeat:Connect(function()
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if hrp and aIndicator then
					aIndicator.CFrame = CFrame.new(hrp.Position - Vector3.new(0, verticalOffset + 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
				end
			end)
		end

		return Enum.ContextActionResult.Pass

	elseif inputState == Enum.UserInputState.End then
		if aIndicatorConnection then
			aIndicatorConnection:Disconnect()
			aIndicatorConnection = nil
		end
		if aIndicator then
			aIndicator:Destroy()
			aIndicator = nil
		end

		if hrp and not persistentSelectedCharacter then
			local closestRig = nil
			local closestDistance = INDICATOR_DIAMETER / 2
			local hrpFlatPos = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)

			for _, obj in pairs(workspace:GetChildren()) do
				if obj:IsA("Model") and Relation:Get(obj) == "Hostile" and obj ~= player.Character then
					local rigPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
					if rigPart then
						local rigFlatPos = Vector3.new(rigPart.Position.X, 0, rigPart.Position.Z)
						local dist = (hrpFlatPos - rigFlatPos).Magnitude
						if dist <= closestDistance then
							closestDistance = dist
							closestRig = obj
						end
					end
				end
			end

			if closestRig then
				persistentSelectedCharacter = closestRig
				if persistentHighlightInstance then
					persistentHighlightInstance:Destroy()
					persistentHighlightInstance = nil
				end
				persistentHighlightInstance = Instance.new("Highlight")
				persistentHighlightInstance.FillColor = Relation:GetColor(closestRig)
				persistentHighlightInstance.OutlineTransparency = 1
				persistentHighlightInstance.Adornee = closestRig
				persistentHighlightInstance.Parent = closestRig
			end
		end

		if persistentSelectedCharacter and persistentSelectedCharacter ~= player.Character and Relation:Get(persistentSelectedCharacter) == "Hostile" then
			continuousAttackMode = true
			local targetBasePart = persistentSelectedCharacter:FindFirstChild("HumanoidRootPart") or persistentSelectedCharacter:FindFirstChildWhichIsA("BasePart")
			if targetBasePart then
				interactTargetPart = targetBasePart
				isWalkingToInteract = true
				detectorInteractionActive = false
				detectorInteractionTarget = nil
			end
		end

		return Enum.ContextActionResult.Pass
	end

	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.A)


local function createProgressBar(duration)
	local screenGui = player:WaitForChild("PlayerGui"):FindFirstChild("MountProgressGui")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "MountProgressGui"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.DisplayOrder = 220
		screenGui.Parent = player:WaitForChild("PlayerGui")
	end

	local d = math.max(0.1, tonumber(duration) or 1)
	local bar = Instance.new("Frame")
	bar.Name = "ActionProgressBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Size = UDim2.new(0.34, 0, 0, 42)
	bar.Position = UDim2.new(0.5, 0, 1, -72)
	bar.BackgroundColor3 = Color3.fromRGB(18, 14, 13)
	bar.BackgroundTransparency = 0.03
	bar.BorderSizePixel = 0
	bar.Parent = screenGui
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(260, 42)
	sizeLimit.MaxSize = Vector2.new(520, 42)
	sizeLimit.Parent = bar
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.fromRGB(188, 138, 54)
	barStroke.Thickness = 1.5
	barStroke.Transparency = 0.12
	barStroke.Parent = bar

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 8, 0, 8)
	track.Size = UDim2.new(1, -16, 1, -16)
	track.BackgroundColor3 = Color3.fromRGB(35, 28, 24)
	track.BackgroundTransparency = 0.05
	track.BorderSizePixel = 0
	track.Parent = bar
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 6)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(188, 138, 54)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local timerLabel = Instance.new("TextLabel")
	timerLabel.BackgroundTransparency = 1
	timerLabel.Font = Enum.Font.GothamBlack
	timerLabel.TextColor3 = Color3.fromRGB(242, 229, 202)
	timerLabel.TextStrokeTransparency = 0.55
	timerLabel.TextSize = 15
	timerLabel.Size = UDim2.fromScale(1, 1)
	timerLabel.Parent = track

	local startTime = time()
	local function update()
		local elapsed = time() - startTime
		local progress = math.clamp(elapsed / d, 0, 1)
		fill.Size = UDim2.new(progress, 0, 1, 0)
		timerLabel.Text = string.format("Channeling  %.1fs", math.max(0, d - elapsed))
		return progress
	end

	local function destroy()
		bar:Destroy()
	end

	update()
	return {
		update = update,
		destroy = destroy,
	}
end


local mountingInProgress = false

ContextActionService:BindAction("MountHorse", function(actionName, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local character = player.Character
	if not character then return Enum.ContextActionResult.Pass end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return Enum.ContextActionResult.Pass end


	if not isMounted then
		if player:GetAttribute("Downed") == true or character:GetAttribute("Downed") == true then
			if mountingBarClose then mountingBarClose:Disconnect(); mountingBarClose = nil end
			if mountingBar then mountingBar.destroy(); mountingBar = nil end
			return Enum.ContextActionResult.Sink
		end
		if currentHorse then
			if mounting then
				return
			end
			local vehicleSeat = currentHorse:FindFirstChild("VehicleSeat", true)
			if vehicleSeat then
				local seatOffset = vehicleSeat.Size.Y / 2 + 2.7
				local humanoid = character:FindFirstChildWhichIsA("Humanoid")
				if humanoid then

					humanoid:MoveTo(hrp.Position)
					humanoid:MoveTo(vehicleSeat.Position)
					local reached = false
					local conn
					conn = humanoid.MoveToFinished:Connect(function(success)
						reached = success
						conn:Disconnect()
					end)
					local startTime = tick()
					while tick() - startTime < 5 and not reached do
						wait(0.1)
					end
				end


				if (hrp.Position - vehicleSeat.Position).Magnitude <= 4 then
					mountingBar = createProgressBar(1.5)
					local stableTime = 0
					local baseline = hrp.Position
					mountingBarClose = RunService.RenderStepped:Connect(function()
						if mountingBar then
							mountingBar.update()
						else
							if mountingBarClose then
								mountingBarClose:Disconnect()
								mountingBarClose = nil
							end
						end
					end)
					while stableTime < 1.5 do
						if player:GetAttribute("Downed") == true or character:GetAttribute("Downed") == true then
							if mountingBarClose then mountingBarClose:Disconnect(); mountingBarClose = nil end
							if mountingBar then mountingBar.destroy(); mountingBar = nil end
							return Enum.ContextActionResult.Sink
						end
						if (hrp.Position - vehicleSeat.Position).Magnitude > 4
							or hrp.Velocity.Magnitude > 0.1
							or (hrp.Position - baseline).Magnitude > 1 then
							if mountingBarClose then
								mountingBarClose:Disconnect()
								mountingBarClose = nil
							end
							if mountingBar then
								mountingBar.destroy()
								mountingBar = nil
							end
							return Enum.ContextActionResult.Pass
						else
							stableTime = stableTime + 0.1
						end
						wait(0.1)
					end
					if mountingBarClose then
						mountingBarClose:Disconnect()
						mountingBarClose = nil
					end
					if mountingBar then
						mountingBar.destroy()
						mountingBar = nil
					end
					RemountRequest:FireServer({ ChannelComplete = true })
				else
					return Enum.ContextActionResult.Pass
				end

			else
				return Enum.ContextActionResult.Pass
			end

		else
			if mounting then
				return
			end
			local humanoid = character:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid:MoveTo(hrp.Position)
			end

			RequestMount:FireServer()

			local duration = 4
			clearMountGui()
			mountingBar  = createProgressBar(duration)
			local startTime = tick()
			local initialPos = hrp.Position

			mountingBarClose = RunService.RenderStepped:Connect(function()
				if player:GetAttribute("Downed") == true or character:GetAttribute("Downed") == true then
					if mountingBarClose then mountingBarClose:Disconnect(); mountingBarClose = nil end
					if mountingBar then mountingBar.destroy(); mountingBar = nil end
					return
				end
				local currentPos = hrp.Position

				if (currentPos - initialPos).Magnitude > 0.5 then
					mountingBarClose:Disconnect()
					mountingBar.destroy()
					mountingBar = nil
					mountingBarClose = nil
					return Enum.ContextActionResult.Pass
				end
				local elapsed = tick() - startTime
				mountingBar.update()
				if elapsed >= duration then
					mountingBarClose:Disconnect()
					mountingBar.destroy()
					mountingBar = nil
					mountingBarClose = nil
				end
			end)
		end


	else

		mountingInProgress = false
		if seatWeld then
			seatWeld:Destroy()
			seatWeld = nil
		end
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
		RequestDismount:FireServer()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Z)

ContextActionService:BindAction("AbilityQ", function(_, state)
	if state == Enum.UserInputState.Begin and not isMounted then
		if mounting then
			CancelMount:FireServer()
		end
		fireAbility("Q", currentQ)
		return Enum.ContextActionResult.Sink
	end
end, false, Enum.KeyCode.Q)

ContextActionService:BindAction("StopAllActions", function(actionName, inputState, inputObject)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	isWalkingToInteract = false
	interactTargetPart = nil
	interactTargetPosition = nil
	detectorInteractionActive = false
	detectorInteractionTarget = nil
	continuousAttackMode = false
	disableMovement = false

	local mover = (isMounted and currentHorse) or player.Character
	if mover then
		local humanoid = mover:FindFirstChildWhichIsA("Humanoid")
		local hrp = mover:FindFirstChild("HumanoidRootPart")
		if humanoid and hrp then
			humanoid:MoveTo(hrp.Position)
		end
	end

	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.S)


ContextActionService:BindAction("AbilityW", function(_, state)
	if state == Enum.UserInputState.Begin and not isMounted then
		if mounting then
			CancelMount:FireServer()
		end
		local pos = getMouseTargetPosition()
		if pos then
			fireAbility("W", currentW)
		end
		return Enum.ContextActionResult.Sink
	end
end, false, Enum.KeyCode.W)


ContextActionService:BindAction("AbilityE", function(actionName, inputState, inputObject)
	if isMounted then return end
	if inputState == Enum.UserInputState.Begin then
		if mounting then
			CancelMount:FireServer()
		end
		local targetPos = getMouseTargetPosition() or (mouse.Hit and mouse.Hit.Position)
		if targetPos then
			fireAbility("E")
		end
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.E)


RunService.RenderStepped:Connect(function(dt)

	local moverCharacter = (isMounted and currentHorse) or player.Character
	if not moverCharacter then return end

	local humanoid = moverCharacter:FindFirstChildWhichIsA("Humanoid")
	local hrp = moverCharacter:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return end


	if continuousAttackMode and persistentSelectedCharacter and Relation:Get(persistentSelectedCharacter) == "Hostile" then
		local targetBasePart = persistentSelectedCharacter:FindFirstChild("HumanoidRootPart") or persistentSelectedCharacter:FindFirstChildWhichIsA("BasePart")
		if targetBasePart then
			local dist = (hrp.Position - targetBasePart.Position).Magnitude
			if dist > INTERACT_DISTANCE then
				humanoid:MoveTo(targetBasePart.Position)

				isWalkingToInteract = true
			else
				humanoid:MoveTo(hrp.Position)
				if (time() - lastAttackTime >= ATTACK_COOLDOWN) then
					lastAttackTime = time()
					AttackTarget:FireServer(persistentSelectedCharacter, "basic")
				end

			end
		end
	elseif isWalkingToInteract and interactTargetPart then
		local targetPos = interactTargetPart.Position
		local dist = (hrp.Position - targetPos).Magnitude
		if dist > INTERACT_DISTANCE then
			humanoid:MoveTo(targetPos)
		else
			humanoid:MoveTo(hrp.Position)
			local canAttackNow = (time() - lastAttackTime >= ATTACK_COOLDOWN)
			if canAttackNow and persistentSelectedCharacter and Relation:Get(persistentSelectedCharacter) == "Hostile" and persistentSelectedCharacter ~= player.Character then
				lastAttackTime = time()
				AttackTarget:FireServer(persistentSelectedCharacter, "basic")
			end
			if detectorInteractionActive and detectorInteractionTarget then
				showBillboardPopup(detectorInteractionTarget)
				detectorInteractionActive = false
				detectorInteractionTarget = nil
			end
			isWalkingToInteract = false
			interactTargetPart = nil
		end
	else
		if not disableMovement and not isMouseOverAnyGui() then
			if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
				or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
				local rawPos = getMouseTargetPosition() or (mouse.Hit and mouse.Hit.Position)
				if rawPos then
					humanoid:MoveTo(rawPos)
				end
			end
		end
	end
end)


RunService.RenderStepped:Connect(function()
	local targetPart = mouse.Target
	local targetCharacter = getTargetModel(targetPart)
	if targetCharacter and targetCharacter ~= player.Character then
		if targetCharacter == persistentSelectedCharacter then
			if transientHighlightInstance then
				transientHighlightInstance:Destroy()
				transientHighlightInstance = nil
				transientHighlightedCharacter = nil
			end
		else
			if transientHighlightedCharacter ~= targetCharacter then
				if transientHighlightInstance then
					transientHighlightInstance:Destroy()
					transientHighlightInstance = nil
				end
				transientHighlightedCharacter = targetCharacter
				transientHighlightInstance = Instance.new("Highlight")
				local relation = targetCharacter.Name
				transientHighlightInstance.FillColor = Relation:GetColor(targetCharacter)
				transientHighlightInstance.OutlineTransparency = 0.2
				transientHighlightInstance.Adornee = targetCharacter
				transientHighlightInstance.Parent = targetCharacter
			else
				if transientHighlightInstance then
					local relation = targetCharacter.Name
					transientHighlightInstance.FillColor = Relation:GetColor(targetCharacter)
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

CurrentHorseEvent.OnClientEvent:Connect(function(horse, status)
	print(horse)
	print(status)
	currentHorse = horse
	isMounted = status or false
	print(isMounted)
	print(currentHorse)
end)


ShowBoundaryIndicator.OnClientEvent:Connect(function(horse)
	if horse and horse.PrimaryPart then
		if boundaryIndicator then
			boundaryIndicator:Destroy()
			boundaryIndicator = nil
		end
		boundaryIndicator = Instance.new("Part")
		boundaryIndicator.Name = "BoundaryIndicator"
		boundaryIndicator.Shape = Enum.PartType.Cylinder
		boundaryIndicator.Anchored = true
		boundaryIndicator.CanCollide = false
		boundaryIndicator.Transparency = 0.5
		boundaryIndicator.Color = Color3.new(1, 1, 1)

		boundaryIndicator.Size = Vector3.new(1, 50, 50)
		boundaryIndicator.CFrame = horse.PrimaryPart.CFrame
			* CFrame.new(0, -horse.PrimaryPart.Size.Y/2 - 3, 0)
			* CFrame.Angles(0, math.rad(90), math.rad(90))
		boundaryIndicator.Parent = workspace
	end
end)

UpdateHorseStatus.OnClientEvent:Connect(function(status)
	mounting = status
	if not status then
		clearMountGui()
		if mountingBar then
			mountingBar.destroy()
			mountingBar = nil
		end
		if mountingBarClose then
			mountingBarClose:Disconnect()
			mountingBarClose = nil
		end
	end
end)

UpdateHorseCFrame.OnClientEvent:Connect(function(serverCFrame)

	if currentHorse and currentHorse.PrimaryPart then
		currentHorse:SetPrimaryPartCFrame(serverCFrame)
	end
end)

UpdateBasicCooldown.OnClientEvent:Connect(function(cd)
	print("Happens")
	ATTACK_COOLDOWN = cd
	print(ATTACK_COOLDOWN)
end)

UpdateBasicRange.OnClientEvent:Connect(function(range)
	print("Happens")
	INTERACT_DISTANCE = range
	print(INTERACT_DISTANCE)
end)