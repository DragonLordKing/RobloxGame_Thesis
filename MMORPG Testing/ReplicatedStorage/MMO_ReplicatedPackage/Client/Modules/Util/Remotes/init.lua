--[[
Name: Remotes
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Util.Remotes
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage
Clean source lines: 17
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")

local Remotes = {
	RequestMount = RemoteEvents:WaitForChild("RequestMount"),
	RequestDismount = RemoteEvents:WaitForChild("RequestDismount"),
	CurrentHorseEvent = RemoteEvents:WaitForChild("CurrentHorse"),
	ShowBoundaryIndicator = RemoteEvents:WaitForChild("ShowBoundaryIndicator"),
	UpdateHorseStatus = RemoteEvents:WaitForChild("UpdateHorseStatus"),
	CancelMount = RemoteEvents:WaitForChild("CancelMount"),
	RemountRequest = RemoteEvents:WaitForChild("RemountRequest"),
	UpdateHorseCFrame = RemoteEvents:WaitForChild("UpdateHorseCFrame"),
	AttackTarget = RemoteEvents:WaitForChild("AttackTarget"),
	UpdateBasicCooldown = RemoteEvents:WaitForChild("UpdateBasicCooldown"),
	UpdateBasicRange = RemoteEvents:WaitForChild("UpdateBasicRange"),
}
return Remotes