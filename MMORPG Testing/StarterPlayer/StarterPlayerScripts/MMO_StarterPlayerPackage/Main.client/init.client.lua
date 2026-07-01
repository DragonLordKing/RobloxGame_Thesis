--[[
Name: Main.client
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.Main.client
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: RunService, UserInputService, ReplicatedStorage
Requires:
  - local Remotes = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Remotes)
  - local GameState = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.GameState)
  - local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Config)
  - local Selection = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Selection)
  - local MovementController = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Controllers.MovementController)
  - local MountController = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Controllers.MountController)
  - local OcclusionController = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Controllers.OcclusionController)
  - local InputController = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Controllers.InputController)
Clean source lines: 37
]]
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local Remotes = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Remotes)
local GameState = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.GameState)
local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Config)

local Selection = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Selection)
local MovementController = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Controllers.MovementController)
local MountController = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Controllers.MountController)
local OcclusionController = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Controllers.OcclusionController)
local InputController = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Controllers.InputController)


RunService.RenderStepped:Connect(function()
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)


Selection.startHoverLoop()
MovementController.start()
MountController.init()
OcclusionController.start()
InputController.bind()


Remotes.UpdateBasicCooldown.OnClientEvent:Connect(function(cd)
	GameState.ATTACK_COOLDOWN = cd
end)
Remotes.UpdateBasicRange.OnClientEvent:Connect(function(range)
	GameState.INTERACT_DISTANCE = range
end)
