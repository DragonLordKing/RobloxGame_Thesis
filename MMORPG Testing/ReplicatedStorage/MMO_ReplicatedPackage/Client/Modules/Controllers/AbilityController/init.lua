--[[
Name: AbilityController
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Controllers.AbilityController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage
Requires:
  - local AbilityIndex = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").AbilityIndex)
  - local TargetTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)
  - local Selection = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Selection)
  - local MouseUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.MouseUtil)
  - local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Remotes)
  - local GameState = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.GameState)
Functions: clearAbilityMovementLocks, buildTargetArg, AbilityController.fireAbility
Clean source lines: 67
]]
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local AbilityIndex = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").AbilityIndex)
local TargetTypes = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").TargetTypes)

local Selection = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Selection)
local MouseUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.MouseUtil)
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Remotes)
local GameState = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.GameState)

local AbilityController = {}

local function clearAbilityMovementLocks()
	GameState.disableMovement = false
	GameState.isWalkingToInteract = false
	GameState.interactTargetPart = nil
	GameState.interactTargetPosition = nil
	GameState.interactCallback = nil
	GameState.interactCallbackTarget = nil
	GameState.interactDistanceOverride = nil
	GameState.detectorInteractionActive = false
	GameState.detectorInteractionTarget = nil
end

local function buildTargetArg(tt)
	if tt == TargetTypes.DIR then
		local pos = MouseUtil.getMouseTargetPosition()
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		return (pos and hrp) and (pos - hrp.Position).Unit or nil

	elseif tt == TargetTypes.LOC then
		return MouseUtil.getMouseTargetPosition()

	elseif tt == TargetTypes.SELF then
		return nil

	elseif tt == TargetTypes.U_ANY or tt == TargetTypes.U_ALLY or tt == TargetTypes.U_ENEMY then
		local unit = Selection.getPersistent()
		if unit and Selection.unitFits(tt, unit) then
			return Selection.resolveServerModel(unit)
		end
		return nil

	elseif tt == TargetTypes.P_AE or tt == TargetTypes.P_AA or tt == TargetTypes.P_EE then
		local pair = Selection.acquirePair(tt)
		if pair and #pair == 2 then
			return { Selection.resolveServerModel(pair[1]), Selection.resolveServerModel(pair[2]) }
		end
	end
end

function AbilityController.fireAbility(slot, idx)
	clearAbilityMovementLocks()
	local weaponType = "Sword"
	local tt = AbilityIndex.GetTargetType(weaponType, slot, idx or 1)
	local targ = buildTargetArg(tt)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local origin = hrp and hrp.Position
	local payload = { Origin = origin, Target = targ }
	if tt and (tt == TargetTypes.SELF or targ) then
		Remotes.AttackTarget:FireServer(payload, slot, idx)
	end
end

return AbilityController
