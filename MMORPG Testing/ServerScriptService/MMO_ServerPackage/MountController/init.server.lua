--[[
Name: MountController
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.MountController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ReplicatedStorage, Workspace, Players, RunService, ServerStorage, ServerScriptService
Requires:
  - local CombatLocks = require(ServerPackage:WaitForChild("CombatLocks"))
  - local CombatState = require(ServerPackage:WaitForChild("PlayerCombatStateService"))
  - local MountInfo = require(ServerPackage:WaitForChild("MountInfo"))
  - local UI = require(ServerPackage:WaitForChild("MountHelper"))
Functions: ensureBindableFunction, isPlayerDowned, clearMountAttempt, findBySlashPath, baseName, findUniqueModuleByName, requireMountModule, resolveMountTemplate, mountSpeedData, setCollisionGroupForModel, isHelperGroundPart, isCityBuildingSurface, shouldSkipMountGroundHit, disableInvisibleMountShadows, getMountRootClearance, configureMountGrounding, findMountGroundPosition, getGroundedMountCFrame, configureMountCollision, configureRiderCollision, isMountSpawnBlocked, getSafeMountSpawnCFrame, currentMountedState, spawnEquippedMountMounted, GetMountedStateBF.OnInvoke, RestoreMountedStateBF.OnInvoke
Signal classes referenced: BindableFunction
Clean source lines: 929
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local BindableFunctions = ServerStorage:WaitForChild("MMO_ServerStoragePackage"):WaitForChild("BindableFunctions")
local function ensureBindableFunction(name)
	local bindable = BindableFunctions:FindFirstChild(name)
	if not bindable or not bindable:IsA("BindableFunction") then
		if bindable then bindable:Destroy() end
		bindable = Instance.new("BindableFunction")
		bindable.Name = name
		bindable.Parent = BindableFunctions
	end
	return bindable
end
local GetPlayerMountBF = ensureBindableFunction("GetPlayerMount")
local GetMountedStateBF = ensureBindableFunction("GetMountedState")
local RestoreMountedStateBF = ensureBindableFunction("RestoreMountedState")

local ReplicatedPackage = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
local RemoteEvents = ReplicatedPackage:WaitForChild("RemoteEvents")
local RequestMount = RemoteEvents:WaitForChild("RequestMount")
local RemountRequest = RemoteEvents:WaitForChild("RemountRequest")
local RequestDismount = RemoteEvents:WaitForChild("RequestDismount")
local CancelMount = RemoteEvents:WaitForChild("CancelMount")
local CurrentHorseEvent = RemoteEvents:WaitForChild("CurrentHorse")
local ShowBoundaryIndicator = RemoteEvents:WaitForChild("ShowBoundaryIndicator")
local UpdateHorseStatus = RemoteEvents:WaitForChild("UpdateHorseStatus")
local UpdateHorseCFrame = RemoteEvents:WaitForChild("UpdateHorseCFrame")
local AttackTarget = RemoteEvents:WaitForChild("AttackTarget")

local MountTemplatesRoot = ReplicatedPackage:WaitForChild("Mounts")

local ServerPackage = game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage")
local EquipmentRoot = ServerPackage:WaitForChild("Equipment")
local CombatLocks = require(ServerPackage:WaitForChild("CombatLocks"))
local CombatState = require(ServerPackage:WaitForChild("PlayerCombatStateService"))
local MountInfo = require(ServerPackage:WaitForChild("MountInfo"))
local UI = require(ServerPackage:WaitForChild("MountHelper"))

local updateMountHealthBar = UI.updateMountHealthBar
local abortMounting = UI.abortMounting

local castLockUntil = CombatLocks.CastLockUntil
local gcdUntil = CombatLocks.GCDUntil


local mountedHorses = MountInfo.mountedHorses
local mountDebounce = MountInfo.mountDebounce
local mountingPlayers = MountInfo.mountingPlayers

local function isPlayerDowned(player, character)
	if not player then return false end
	if CombatState and type(CombatState.IsDowned) == "function" and CombatState.IsDowned(player) then
		return true
	end
	character = character or player.Character
	return player:GetAttribute("Downed") == true or (character and character:GetAttribute("Downed") == true) or false
end

local function clearMountAttempt(player, character)
	if not player then return end
	local uid = player.UserId
	mountingPlayers[uid] = nil
	mountDebounce[uid] = false
	UpdateHorseStatus:FireClient(player, false)
	local root = character and character.PrimaryPart
	if root then
		root.Anchored = false
	end
end


local movementTimers = MountInfo.movementTimers
local stationaryTimers = {}


local horseSpeeds = MountInfo.horseSpeeds

local function findBySlashPath(root, path)
	if not (root and path and tostring(path) ~= "") then return nil end
	local current = root
	for part in string.gmatch(tostring(path), "[^/]+") do
		current = current and current:FindFirstChild(part)
		if not current then return nil end
	end
	return current
end

local function baseName(path)
	return string.match(tostring(path or ""), "([^/]+)$") or tostring(path or "")
end

local function findUniqueModuleByName(root, name)
	local found = nil
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("ModuleScript") and inst.Name == name then
			if found then return nil end
			found = inst
		end
	end
	return found
end

local function requireMountModule(mountId)
	local id = tostring(mountId or "")
	if id == "" then return nil end
	local moduleScript = findBySlashPath(EquipmentRoot, id)
		or findBySlashPath(EquipmentRoot, "Mounts/Horses/" .. baseName(id))
		or findBySlashPath(EquipmentRoot, "Mounts/TransportMounts/" .. baseName(id))
		or findBySlashPath(EquipmentRoot, "Mounts/SpecialMounts/" .. baseName(id))
		or findUniqueModuleByName(EquipmentRoot, baseName(id))
	if not moduleScript then
		return nil
	end
	local ok, module = pcall(require, moduleScript)
	if not ok then
		warn("[Mounts] Failed to require mount module " .. moduleScript:GetFullName() .. ": " .. tostring(module))
		return nil
	end
	return module
end

local function resolveMountTemplate(mountModule, mountId)
	local templatePath = mountModule and (mountModule.TemplatePath or mountModule.AssetPath or mountModule.ModelPath) or mountId
	local template = findBySlashPath(ReplicatedPackage, templatePath)
	if not template and tostring(templatePath or ""):sub(1, 7) == "Mounts/" then
		template = findBySlashPath(MountTemplatesRoot, tostring(templatePath):sub(8))
	end
	if not template then
		template = MountTemplatesRoot:FindFirstChild(baseName(templatePath or mountId), true)
	end
	return template and template:IsA("Model") and template or nil
end

local function mountSpeedData(mountModule)
	return {
		BaseSpeed = math.max(1, tonumber(mountModule and mountModule.BaseSpeed) or 16),
		MaxSpeed = math.max(1, tonumber(mountModule and mountModule.MaxSpeed) or 40),
	}
end


local function setCollisionGroupForModel(model, groupName)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = groupName
		end
	end
end

local MOUNT_GROUND_CLEARANCE = 0.08
local MOUNT_RAYCAST_UP = 80
local MOUNT_RAYCAST_DOWN = 320

local function isHelperGroundPart(part)
	if not part or not part:IsA("BasePart") then
		return false
	end
	if part.Name == "CityReservedZone" then
		return true
	end

	local lowerName = string.lower(part.Name)
	local parentName = part.Parent and string.lower(part.Parent.Name) or ""
	return part.Transparency >= 0.95 and (
		string.find(lowerName, "collider", 1, true)
		or string.find(lowerName, "wall", 1, true)
		or string.find(lowerName, "zone", 1, true)
		or string.find(lowerName, "reserved", 1, true)
		or string.find(parentName, "collider", 1, true)
		or string.find(parentName, "wall", 1, true)
	)
end

local function isCityBuildingSurface(inst)
	local current = inst
	while current and current ~= Workspace do
		if current:GetAttribute("BuildingInstanceId") or current:GetAttribute("BuildingKey") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function shouldSkipMountGroundHit(inst)
	if inst == Workspace.Terrain then
		return false
	end
	if not inst or not inst:IsA("BasePart") then
		return true
	end
	if not inst.CanCollide or isHelperGroundPart(inst) or isCityBuildingSurface(inst) then
		return true
	end

	local model = inst:FindFirstAncestorOfClass("Model")
	return model and model:FindFirstChildWhichIsA("Humanoid") ~= nil
end

local function disableInvisibleMountShadows(horse)
	for _, part in ipairs(horse:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency >= 0.95 then
			part.CastShadow = false
		end
	end
end

local function getMountRootClearance(horse)
	local root = horse.PrimaryPart or horse:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0
	end

	local boundsCFrame, boundsSize = horse:GetBoundingBox()
	local visualBottomY = boundsCFrame.Position.Y - boundsSize.Y * 0.5
	local rootToVisualBottom = math.max(0, root.Position.Y - visualBottomY)
	return math.max(root.Size.Y * 0.5, rootToVisualBottom + MOUNT_GROUND_CLEARANCE)
end

local function configureMountGrounding(horse)
	if not horse or not horse.PrimaryPart then
		return 0
	end

	disableInvisibleMountShadows(horse)

	local humanoid = horse:FindFirstChildWhichIsA("Humanoid")
	local rootClearance = getMountRootClearance(horse)
	if humanoid then
		local baseHipHeight = horse:GetAttribute("BaseHipHeight")
		if typeof(baseHipHeight) ~= "number" then
			baseHipHeight = humanoid.HipHeight
			horse:SetAttribute("BaseHipHeight", baseHipHeight)
		end
		humanoid.HipHeight = baseHipHeight
		horse:SetAttribute("GroundedRootClearance", rootClearance)
	end
	return rootClearance
end

local function findMountGroundPosition(horse, desiredPosition)
	local ignored = { horse }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false

	local origin = desiredPosition + Vector3.new(0, MOUNT_RAYCAST_UP, 0)
	local direction = Vector3.new(0, -(MOUNT_RAYCAST_UP + MOUNT_RAYCAST_DOWN), 0)

	for _ = 1, 16 do
		params.FilterDescendantsInstances = ignored
		local result = Workspace:Raycast(origin, direction, params)
		if not result then
			return nil
		end
		if not shouldSkipMountGroundHit(result.Instance) then
			return result.Position
		end
		table.insert(ignored, result.Instance)
	end

	return nil
end

local function getGroundedMountCFrame(horse, desiredCFrame)
	local rootClearance = configureMountGrounding(horse)
	local groundPosition = findMountGroundPosition(horse, desiredCFrame.Position)
	if not groundPosition then
		return desiredCFrame
	end

	local rotationOnly = desiredCFrame - desiredCFrame.Position
	return CFrame.new(desiredCFrame.Position.X, groundPosition.Y + rootClearance, desiredCFrame.Position.Z) * rotationOnly
end

local function configureMountCollision(horse)
	if not horse then return end
	local body = horse:FindFirstChild("Body", true)
	for _, part in ipairs(horse:GetDescendants()) do
		if part:IsA("BasePart") then
			local isBody = part.Name == "Body"
			part.CanCollide = isBody or (not body and part == horse.PrimaryPart)
			if not isBody then
				part.CanTouch = false
			end
		end
	end
end

local function configureRiderCollision(character)
	if not character then return end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end
end

local MOUNT_SPAWN_OFFSETS = {
	CFrame.new(0, 0, -7),
	CFrame.new(4, 0, -6),
	CFrame.new(-4, 0, -6),
	CFrame.new(7, 0, 0),
	CFrame.new(-7, 0, 0),
	CFrame.new(0, 0, 7),
}

local function isMountSpawnBlocked(horse, character, cframe)
	local _, boundsSize = horse:GetBoundingBox()
	local querySize = Vector3.new(math.max(boundsSize.X, 5), math.max(boundsSize.Y, 5), math.max(boundsSize.Z, 5))
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { horse, character }
	local hits = Workspace:GetPartBoundsInBox(CFrame.new(cframe.Position), querySize, params)
	for _, part in ipairs(hits) do
		if part:IsA("BasePart") and part.CanCollide and isCityBuildingSurface(part) then
			return true
		end
	end
	return false
end

local function getSafeMountSpawnCFrame(horse, character)
	local root = character and character.PrimaryPart
	if not root then
		return horse.PrimaryPart and horse.PrimaryPart.CFrame or CFrame.new()
	end
	local rootCFrame = character:GetPrimaryPartCFrame()
	local rootY = root.Position.Y
	for _, offset in ipairs(MOUNT_SPAWN_OFFSETS) do
		local desired = rootCFrame * offset
		local grounded = getGroundedMountCFrame(horse, desired)
		if math.abs(grounded.Position.Y - rootY) <= 8 and not isMountSpawnBlocked(horse, character, grounded) then
			return grounded
		end
	end
	return getGroundedMountCFrame(horse, rootCFrame * CFrame.new(0, 0, -7))
end


CancelMount.OnServerEvent:Connect(function(player)
	if mountingPlayers[player.UserId] then
		if player.Character and player.Character.PrimaryPart then
			player.Character.PrimaryPart.Anchored = false
		end
		print("Mount cancelled due to player movement (CancelMount event).")
		mountingPlayers[player.UserId] = nil
		mountDebounce[player.UserId] = false
		UpdateHorseStatus:FireClient(player, false)
	end
end)


RemountRequest.OnServerEvent:Connect(function(player, options)
	local character = player.Character
	if isPlayerDowned(player, character) then
		clearMountAttempt(player, character)
		return
	end

	local horse = mountedHorses[player.UserId]
	if not horse or not horse.Parent or not horse.PrimaryPart then
		return
	end
	local equippedMountId = GetPlayerMountBF:Invoke(player)
	if not equippedMountId or tostring(equippedMountId) == "" then
		clearMountAttempt(player, character)
		return
	end


	movementTimers[player.UserId] = 0
	stationaryTimers[player.UserId] = 0

	if not character or not character.PrimaryPart then return end
	local hrp = character.PrimaryPart


	if (hrp.Position - horse.PrimaryPart.Position).Magnitude > 6 then
		return
	end

	mountingPlayers[player.UserId] = true
	local clientChannelComplete = type(options) == "table" and options.ChannelComplete == true


	local stable = true
	if not clientChannelComplete then
		hrp.Anchored = true
		UpdateHorseStatus:FireClient(player, true)
		local startTime = tick()
		local initialPos = hrp.Position

		while tick() - startTime < 1.5 do
			task.wait(0.1)

			if not mountingPlayers[player.UserId] then
				stable = false
				break
			end

			local currentPos = hrp.Position
			if (currentPos - initialPos).Magnitude > 0.5 then
				stable = false
				print("Remount cancelled: Player moved during stability check")
				break
			end
		end

		hrp.Anchored = false
	end

	if not stable then
		mountingPlayers[player.UserId] = nil
		UpdateHorseStatus:FireClient(player, false)
		return
	end
	if isPlayerDowned(player, character) then
		clearMountAttempt(player, character)
		return
	end


	local mountRoot = horse.PrimaryPart
	if mountRoot then
		configureMountCollision(horse)
		mountRoot.Anchored = true
		mountRoot.AssemblyLinearVelocity = Vector3.zero
		mountRoot.AssemblyAngularVelocity = Vector3.zero
		horse:PivotTo(getGroundedMountCFrame(horse, mountRoot.CFrame))
		UpdateHorseCFrame:FireClient(player, mountRoot.CFrame)
	end


	local vehicleSeat = horse:FindFirstChild("VehicleSeat", true)
	if not vehicleSeat then
		mountingPlayers[player.UserId] = nil
		return
	end

	local seatOffset = vehicleSeat.Size.Y/2 + 2.7
	character:SetPrimaryPartCFrame(vehicleSeat.CFrame * CFrame.new(0, seatOffset, 0))

	local existingWeld = vehicleSeat:FindFirstChild("SeatWeldConstraint")
	if existingWeld then
		existingWeld:Destroy()
	end
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Name = "SeatWeldConstraint"
	seatWeld.Part0 = vehicleSeat
	seatWeld.Part1 = hrp
	seatWeld.Parent = vehicleSeat

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.Sit = true
	end
	configureRiderCollision(character)
	if mountRoot then
		mountRoot.AssemblyLinearVelocity = Vector3.zero
		mountRoot.AssemblyAngularVelocity = Vector3.zero
		mountRoot.Anchored = false
		pcall(function()
			mountRoot:SetNetworkOwner(player)
		end)
		UpdateHorseCFrame:FireClient(player, mountRoot.CFrame)
	end

	horse:SetAttribute("Mounted", true)
	updateMountHealthBar(horse)
	CurrentHorseEvent:FireClient(player, horse, true)
	UpdateHorseStatus:FireClient(player, false)
	mountingPlayers[player.UserId] = nil
end)


local function currentMountedState(player)
	if not player then
		return { Mounted = false }
	end
	local horse = mountedHorses[player.UserId]
	if not (horse and horse.Parent and horse:GetAttribute("Mounted") == true) then
		return { Mounted = false }
	end
	return {
		Mounted = true,
		MountItemId = horse:GetAttribute("MountItemId") or GetPlayerMountBF:Invoke(player),
		Health = horse:GetAttribute("Health"),
		MaxHealth = horse:GetAttribute("MaxHealth"),
	}
end

local function spawnEquippedMountMounted(player, options)
	options = type(options) == "table" and options or {}
	local character = player and player.Character
	if not player or not player.Parent or isPlayerDowned(player, character) then
		return false, "Unavailable"
	end
	if not character or not character.PrimaryPart then
		return false, "No character"
	end

	local existingHorse = mountedHorses[player.UserId]
	if existingHorse then
		if existingHorse.Parent and existingHorse.PrimaryPart then
			return true, existingHorse
		end
		mountedHorses[player.UserId] = nil
	end

	local equippedMountId = GetPlayerMountBF:Invoke(player)
	local mountId = equippedMountId
	if not mountId or tostring(mountId) == "" then
		return false, "No equipped mount"
	end

	local mountModule = requireMountModule(mountId)
	local mountTemplate = resolveMountTemplate(mountModule, mountId)
	if not mountModule or not mountTemplate then
		warn(("[Mounts] %s tried to restore unresolved mount '%s'."):format(player.Name, tostring(mountId)))
		return false, "Unresolved mount"
	end

	local speedData = mountSpeedData(mountModule)
	local horse = mountTemplate:Clone()
	horse:SetAttribute("IsMount", true)
	horse:SetAttribute("OwnerUserId", player.UserId)
	horse:SetAttribute("MountItemId", tostring(mountId))
	horse:SetAttribute("MountTemplatePath", tostring(mountModule.TemplatePath or mountId))
	horse.Name = player.Name .. "+Horse"
	horse.Parent = Workspace

	if not horse.PrimaryPart then
		horse.PrimaryPart = horse:FindFirstChild("HumanoidRootPart")
			or horse:FindFirstChild("Torso")
			or horse:FindFirstChildWhichIsA("BasePart")
	end
	if not horse.PrimaryPart then
		horse:Destroy()
		return false, "Mount has no root"
	end

	local maxHealth = math.max(1, tonumber(options.MaxHealth) or tonumber(mountModule.MaxHealth or mountModule.Health) or 300)
	local health = math.clamp(tonumber(options.Health) or maxHealth, 1, maxHealth)
	horse:SetAttribute("Health", health)
	horse:SetAttribute("MaxHealth", maxHealth)
	configureMountCollision(horse)
	horse:PivotTo(getSafeMountSpawnCFrame(horse, character))
	horse.PrimaryPart.Anchored = false
	setCollisionGroupForModel(horse, "Horse")
	configureMountCollision(horse)

	horseSpeeds[horse] = {
		BaseSpeed = speedData.BaseSpeed,
		MaxSpeed = speedData.MaxSpeed,
	}
	local horseHumanoid = horse:FindFirstChildWhichIsA("Humanoid")
	if horseHumanoid then
		horseHumanoid.WalkSpeed = speedData.BaseSpeed
	end

	local vehicleSeat = horse:FindFirstChild("VehicleSeat", true)
	if not vehicleSeat then
		horse:Destroy()
		return false, "Mount has no seat"
	end

	local seatOffset = vehicleSeat.Size.Y / 2 + 2.7
	character:SetPrimaryPartCFrame(vehicleSeat.CFrame * CFrame.new(0, seatOffset, 0))
	local oldWeld = vehicleSeat:FindFirstChild("SeatWeldConstraint")
	if oldWeld then oldWeld:Destroy() end
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Name = "SeatWeldConstraint"
	seatWeld.Part0 = vehicleSeat
	seatWeld.Part1 = character.PrimaryPart
	seatWeld.Parent = vehicleSeat

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.Sit = true
	end
	configureRiderCollision(character)
	if horse.PrimaryPart then
		horse.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
		horse.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
		pcall(function()
			horse.PrimaryPart:SetNetworkOwner(player)
		end)
		UpdateHorseCFrame:FireClient(player, horse.PrimaryPart.CFrame)
	end

	horse:SetAttribute("Mounted", true)
	updateMountHealthBar(horse)
	mountedHorses[player.UserId] = horse
	MountInfo.horseToPlayer[horse] = player
	movementTimers[player.UserId] = 0
	stationaryTimers[player.UserId] = 0
	CurrentHorseEvent:FireClient(player, horse, true)
	UpdateHorseStatus:FireClient(player, false)
	mountDebounce[player.UserId] = false
	mountingPlayers[player.UserId] = nil
	return true, horse
end

GetMountedStateBF.OnInvoke = function(player)
	return currentMountedState(player)
end

RestoreMountedStateBF.OnInvoke = function(player, options)
	local ok, resultOrReason = spawnEquippedMountMounted(player, options)
	return { Success = ok == true, Reason = ok and nil or tostring(resultOrReason) }
end


RequestMount.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if castLockUntil[player.UserId] and now < castLockUntil[player.UserId] or gcdUntil[player.UserId] and now < gcdUntil[player.UserId] then
		UpdateHorseStatus:FireClient(player, false)
		mountDebounce[player.UserId] = false
		mountingPlayers[player.UserId] = nil
		return
	end
	local character = player.Character
	if isPlayerDowned(player, character) then
		clearMountAttempt(player, character)
		return
	end
	if mountDebounce[player.UserId] then return end
	mountDebounce[player.UserId] = true
	mountingPlayers[player.UserId] = true

	if not character or not character.PrimaryPart then
		mountDebounce[player.UserId] = false
		mountingPlayers[player.UserId] = nil
		return
	end


	if mountedHorses[player.UserId] then
		mountDebounce[player.UserId] = false
		mountingPlayers[player.UserId] = nil
		return
	end

	local preMountId = GetPlayerMountBF:Invoke(player)
	if not preMountId or tostring(preMountId) == "" then
		clearMountAttempt(player, character)
		return
	end

	local hrp = character.PrimaryPart


	hrp.Anchored = true
	UpdateHorseStatus:FireClient(player, true)
	local startTime = tick()
	local initialPos = hrp.Position
	local stable = true

	while tick() - startTime < 4 do
		task.wait(0.1)

		if not mountingPlayers[player.UserId] then
			stable = false
			break
		end
		if isPlayerDowned(player, character) then
			stable = false
			clearMountAttempt(player, character)
			break
		end

		local currentPos = hrp.Position
		if (currentPos - initialPos).Magnitude > 0.5 then
			stable = false
			print("Mount cancelled: Player moved during stability check")
			UpdateHorseStatus:FireClient(player, false)
			break
		end
	end

	hrp.Anchored = false
	if not stable then
		mountDebounce[player.UserId] = false
		mountingPlayers[player.UserId] = nil
		return
	end
	if isPlayerDowned(player, character) then
		clearMountAttempt(player, character)
		return
	end

	local mountId = preMountId
	local mountModule = requireMountModule(mountId)
	local mountTemplate = resolveMountTemplate(mountModule, mountId)
	if not mountModule or not mountTemplate then
		warn(("[Mounts] %s tried to mount unresolved mount '%s'."):format(player.Name, tostring(mountId)))
		clearMountAttempt(player, character)
		return
	end
	local speedData = mountSpeedData(mountModule)

	local primaryCFrame = character:GetPrimaryPartCFrame()
	local spawnCFrame = primaryCFrame * CFrame.new(0, 0, -5)
	local horseName = player.Name .. "+Horse"

	local horse = mountTemplate:Clone()
	horse:SetAttribute("IsMount", true)
	horse:SetAttribute("OwnerUserId", player.UserId)
	horse:SetAttribute("MountItemId", tostring(mountId))
	horse:SetAttribute("MountTemplatePath", tostring(mountModule.TemplatePath or mountId))
	horse.Name = horseName
	horse.Parent = Workspace

	if not horse.PrimaryPart then
		horse.PrimaryPart = horse:FindFirstChild("HumanoidRootPart")
			or horse:FindFirstChild("Torso")
			or horse:FindFirstChildWhichIsA("BasePart")
	end

	if horse.PrimaryPart then
		local maxHealth = math.max(1, tonumber(mountModule.MaxHealth or mountModule.Health) or 300)
		horse:SetAttribute("Health", maxHealth)
		horse:SetAttribute("MaxHealth", maxHealth)
		configureMountCollision(horse)
		spawnCFrame = getSafeMountSpawnCFrame(horse, character)
		horse:PivotTo(spawnCFrame)
		horse.PrimaryPart.Anchored = false
		UpdateHorseCFrame:FireClient(player, horse.PrimaryPart.CFrame)
		updateMountHealthBar(horse)
	end

	setCollisionGroupForModel(horse, "Horse")
	configureMountCollision(horse)


	horseSpeeds[horse] = {
		BaseSpeed = speedData.BaseSpeed,
		MaxSpeed  = speedData.MaxSpeed
	}


	local horseHumanoid = horse:FindFirstChildWhichIsA("Humanoid")
	if horseHumanoid then
		horseHumanoid.WalkSpeed = speedData.BaseSpeed
	end


	local vehicleSeat = horse:FindFirstChild("VehicleSeat", true)
	if vehicleSeat then
		local seatOffset = vehicleSeat.Size.Y/2 + 2.7
		if character and character.PrimaryPart then
			character:SetPrimaryPartCFrame(vehicleSeat.CFrame * CFrame.new(0, seatOffset, 0))

			local seatWeld = Instance.new("WeldConstraint")
			seatWeld.Name = "SeatWeldConstraint"
			seatWeld.Part0 = vehicleSeat
			seatWeld.Part1 = character.PrimaryPart
			seatWeld.Parent = vehicleSeat

			local humanoid = character:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid.Sit = true
			end
			configureRiderCollision(character)
			if horse.PrimaryPart then
				horse.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
				horse.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
				pcall(function()
					horse.PrimaryPart:SetNetworkOwner(player)
				end)
			end
		end
	end

	horse:SetAttribute("Mounted", true)
	updateMountHealthBar(horse)
	mountedHorses[player.UserId] = horse
	MountInfo.horseToPlayer[horse] = player
	CurrentHorseEvent:FireClient(player, horse, true)
	UpdateHorseStatus:FireClient(player, false)
	mountDebounce[player.UserId] = false
	mountingPlayers[player.UserId] = nil


	movementTimers[player.UserId] = 0
	stationaryTimers[player.UserId] = 0
end)

AttackTarget.OnServerEvent:Connect(function(player)
	abortMounting(player)
end)


RequestDismount.OnServerEvent:Connect(function(player)
	local horse = mountedHorses[player.UserId]
	if horse then
		local vehicleSeat = horse:FindFirstChild("VehicleSeat", true)
		if vehicleSeat then
			local weld = vehicleSeat:FindFirstChild("SeatWeldConstraint")
			if weld then
				weld:Destroy()
			end
		end

		if player.Character then
			local humanoid = player.Character:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid.Sit = false
			end
		end

		horse:SetAttribute("Mounted", false)
		updateMountHealthBar(horse)


		if player.Character and player.Character.PrimaryPart and vehicleSeat then
			local character = player.Character
			local rightVector = vehicleSeat.CFrame.RightVector
			local offsetDistance = vehicleSeat.Size.X/2 + 3
			local dismountPos = vehicleSeat.Position + rightVector * offsetDistance
			character:SetPrimaryPartCFrame(CFrame.new(dismountPos))
		end


		if horse.PrimaryPart then
			configureMountCollision(horse)
			horse:PivotTo(getGroundedMountCFrame(horse, horse.PrimaryPart.CFrame))
			local horseHumanoid = horse:FindFirstChildWhichIsA("Humanoid")
			if horseHumanoid then
				horseHumanoid:MoveTo(horse.PrimaryPart.Position)
				horseHumanoid.WalkSpeed = horseSpeeds[horse] and horseSpeeds[horse].BaseSpeed or 16
			end
			horse.PrimaryPart.Anchored = true
			UpdateHorseCFrame:FireClient(player, horse.PrimaryPart.CFrame)
		end

		movementTimers[player.UserId] = 0
		stationaryTimers[player.UserId] = 0

		CurrentHorseEvent:FireClient(player, horse, false)
	end
end)


Players.PlayerRemoving:Connect(function(player)
	local horse = mountedHorses[player.UserId]
	if horse then
		horse:Destroy()
		MountInfo.horseToPlayer[horse] = nil
		mountedHorses[player.UserId] = nil
	end
end)


RunService.Heartbeat:Connect(function(dt)
	for userId, horse in pairs(mountedHorses) do
		if horse and horse.Parent and horse.PrimaryPart then
			local mounted = horse:GetAttribute("Mounted")
			if mounted then
				local horseHumanoid = horse:FindFirstChildWhichIsA("Humanoid")
				if horseHumanoid then
					local speedInfo = horseSpeeds[horse]
					if not speedInfo then

						speedInfo = {BaseSpeed = 16, MaxSpeed = 40}
						horseSpeeds[horse] = speedInfo
					end

					local currentSpeed = horseHumanoid.WalkSpeed
					local velocity = horse.PrimaryPart.Velocity.Magnitude
					local baseSpeed = speedInfo.BaseSpeed
					local maxSpeed = speedInfo.MaxSpeed
					local threshold = 0.5

					if velocity > threshold then
						movementTimers[userId] = (movementTimers[userId] or 0) + dt
						stationaryTimers[userId] = 0


						if currentSpeed < maxSpeed and movementTimers[userId] >= 4 then
							horseHumanoid.WalkSpeed = maxSpeed
							movementTimers[userId] = 0
						end
					else
						movementTimers[userId] = 0

						if currentSpeed == maxSpeed then
							stationaryTimers[userId] = (stationaryTimers[userId] or 0) + dt
							if stationaryTimers[userId] >= 2 then
								horseHumanoid.WalkSpeed = baseSpeed
								stationaryTimers[userId] = 0
							end
						else
							stationaryTimers[userId] = 0

							if currentSpeed ~= baseSpeed then
								horseHumanoid.WalkSpeed = baseSpeed
							end
						end
					end
				end
			end


			local player = Players:GetPlayerByUserId(userId)
			if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				and not horse:GetAttribute("Mounted") then

				local playerPos = player.Character.HumanoidRootPart.Position
				local horsePos = horse.PrimaryPart.Position
				local dist = (playerPos - horsePos).Magnitude
				if dist > 25 then
					CurrentHorseEvent:FireClient(player, nil, false)
					horse:Destroy()
					MountInfo.horseToPlayer[horse] = nil
					mountedHorses[userId] = nil
					movementTimers[userId] = nil
					stationaryTimers[userId] = nil
					horseSpeeds[horse] = nil
				end
			end
		end
	end
end)