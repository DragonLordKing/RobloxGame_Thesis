--[[
Name: MountController
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Controllers.MountController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ContextActionService, RunService, Players, ReplicatedStorage
Requires:
  - local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Remotes)
  - local Effects = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Effects)
  - local MouseUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.MouseUtil)
  - local GameState = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.GameState)
  - local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Config)
  - local GatheringController = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Controllers.Gat...
Functions: destroyBar, isDowned, approachSeat, bindKey, hookRemotes, MountController.init
Clean source lines: 176
]]
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Remotes)
local Effects = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Effects)
local MouseUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.MouseUtil)
local GameState = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.GameState)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Config)
local GatheringController = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Controllers.GatheringController)

local MountController = {}

local mountingBar
local mountingBarConn : RBXScriptConnection?
local boundaryIndicator : BasePart?

local function destroyBar()
	if mountingBarConn then mountingBarConn:Disconnect(); mountingBarConn = nil end
	if mountingBar then mountingBar.destroy(); mountingBar = nil end
	Effects.clearMountGui()
end

local function isDowned(character)
	character = character or player.Character
	return player:GetAttribute("Downed") == true or (character and character:GetAttribute("Downed") == true) or false
end

local function approachSeat(vehicleSeat)
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
	if not (hrp and humanoid) then return end
	humanoid:MoveTo(hrp.Position)
	humanoid:MoveTo(vehicleSeat.Position)
	local reached = false
	local conn
	conn = humanoid.MoveToFinished:Connect(function(success)
		reached = success
		conn:Disconnect()
	end)
	local start = tick()
	while tick() - start < 5 and not reached do task.wait(0.1) end
end

local function bindKey()
	ContextActionService:BindAction("MountHorse", function(_, state)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		GatheringController.cancel()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not (char and hrp) then return Enum.ContextActionResult.Pass end

		if not GameState.isMounted then
			if isDowned(char) then
				destroyBar()
				return Enum.ContextActionResult.Sink
			end

			if GameState.currentHorse then
				if GameState.mounting then return Enum.ContextActionResult.Pass end
				local vehicleSeat = GameState.currentHorse:FindFirstChild("VehicleSeat", true)
				if vehicleSeat then
					approachSeat(vehicleSeat)
					if (hrp.Position - vehicleSeat.Position).Magnitude <= 4 then
						mountingBar = Effects.createProgressBar(1.5, "Mounting")
						local startPos = hrp.Position
						mountingBarConn = RunService.RenderStepped:Connect(function()
							if mountingBar then mountingBar.update() end
						end)
						local stable = 0
						while stable < 1.5 do
							if isDowned(char) then
								destroyBar()
								return Enum.ContextActionResult.Sink
							end
							if (hrp.Position - vehicleSeat.Position).Magnitude > 4 or hrp.Velocity.Magnitude > 0.1 or (hrp.Position - startPos).Magnitude > 1 then
								destroyBar()
								return Enum.ContextActionResult.Pass
							else
								stable += 0.1
							end
							task.wait(0.1)
						end
						destroyBar()
						Remotes.RemountRequest:FireServer({ ChannelComplete = true })
					end
					return Enum.ContextActionResult.Pass
				end
				return Enum.ContextActionResult.Pass
			end


			if GameState.mounting then return Enum.ContextActionResult.Pass end
			local humanoid = char:FindFirstChildWhichIsA("Humanoid")
			if humanoid then humanoid:MoveTo(hrp.Position) end
			Remotes.RequestMount:FireServer()
			Effects.clearMountGui()
			local duration = 4
			mountingBar = Effects.createProgressBar(duration)
			local startTime = tick()
			local initialPos = hrp.Position
			mountingBarConn = RunService.RenderStepped:Connect(function()
				if isDowned(char) then
					destroyBar()
					return
				end
				local currentPos = hrp.Position
				if (currentPos - initialPos).Magnitude > 0.5 then
					mountingBarConn:Disconnect(); mountingBarConn = nil
					if mountingBar then mountingBar.destroy(); mountingBar = nil end
					return
				end
				mountingBar.update()
				if (tick() - startTime) >= duration then
					mountingBarConn:Disconnect(); mountingBarConn = nil
					if mountingBar then mountingBar.destroy(); mountingBar = nil end
				end
			end)

		else

			if GameState.seatWeld then GameState.seatWeld:Destroy(); GameState.seatWeld = nil end
			local humanoid = char:FindFirstChildWhichIsA("Humanoid")
			if humanoid then humanoid.Sit = false end
			Remotes.RequestDismount:FireServer()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Z)
end

local function hookRemotes()
	Remotes.CurrentHorseEvent.OnClientEvent:Connect(function(horse, status)
		GameState.currentHorse = horse
		GameState.isMounted = status or false
	end)

	Remotes.ShowBoundaryIndicator.OnClientEvent:Connect(function(horse)
		if horse and horse.PrimaryPart then
			if boundaryIndicator then boundaryIndicator:Destroy(); boundaryIndicator = nil end
			local part = Instance.new("Part")
			part.Name = "BoundaryIndicator"
			part.Shape = Enum.PartType.Cylinder
			part.Anchored = true
			part.CanCollide = false
			part.Transparency = 0.5
			part.Color = Color3.new(1,1,1)
			part.Size = Vector3.new(1, 50, 50)
			part.CFrame = horse.PrimaryPart.CFrame
				* CFrame.new(0, -horse.PrimaryPart.Size.Y/2 - 3, 0)
				* CFrame.Angles(0, math.rad(90), math.rad(90))
			part.Parent = workspace
			boundaryIndicator = part
		end
	end)

	Remotes.UpdateHorseStatus.OnClientEvent:Connect(function(status)
		GameState.mounting = status
		if not status then destroyBar() end
	end)

	Remotes.UpdateHorseCFrame.OnClientEvent:Connect(function(serverCFrame)
		if GameState.currentHorse and GameState.currentHorse.PrimaryPart then
			GameState.currentHorse:SetPrimaryPartCFrame(serverCFrame)
		end
	end)
end

function MountController.init()
	bindKey()
	hookRemotes()
end

return MountController