--[[
Name: GameState
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Util.GameState
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players
Functions: GameState:GetMover
Clean source lines: 46
]]
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local GameState = {

	isMounted = false,
	currentHorse = nil,
	mounting = false,
	seatWeld = nil,


	interactTargetPart = nil,
	interactTargetPosition = nil,
	isWalkingToInteract = false,
	detectorInteractionActive = false,
	detectorInteractionTarget = nil,
	interactCallback = nil,
	interactCallbackTarget = nil,
	interactDistanceOverride = nil,


	disableMovement = false,
	continuousAttackMode = false,
	gathering = false,
	buildPlacementActive = false,
	inventoryDragActive = false,


	currentQ = 1,
	currentW = 1,
	abilitySelections = {},


	lastAttackTime = 0,
	ATTACK_COOLDOWN = 1,
	INTERACT_DISTANCE = 5,
}

function GameState:GetMover()

	local mover = (self.isMounted and self.currentHorse) or player.Character
	return mover
end

return GameState
