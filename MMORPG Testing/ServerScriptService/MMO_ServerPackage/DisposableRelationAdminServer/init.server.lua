--[[
Name: DisposableRelationAdminServer
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.DisposableRelationAdminServer
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ReplicatedStorage, Players, ServerScriptService
Requires:
  - local RelationshipService = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
  - local MapInfo = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("MapSettings"))
Functions: getPlayerData, sendSnapshot
Clean source lines: 79
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RelationshipService = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
local MapInfo = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("MapSettings"))

local DisposableFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Disposable")
local RequestRelationUpdate = DisposableFolder:WaitForChild("RequestRelationUpdate")
local RequestMapTypeChange = DisposableFolder:WaitForChild("RequestMapTypeChange")
local RelationAdminSnapshot = DisposableFolder:WaitForChild("RelationAdminSnapshot")


local PartyOf     = RelationshipService.PartyOf
local GuildOf     = RelationshipService.GuildOf
local AllianceOf  = RelationshipService.AllianceOf
local FriendlyTag = RelationshipService.FriendlyTag

local function getPlayerData()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, {
			UserId = p.UserId,
			Name = p.Name,
			Party = PartyOf and PartyOf[p] or nil,
			Guild = GuildOf and GuildOf[p] or nil,
			Alliance = AllianceOf and AllianceOf[p] or nil,
			Friendly = FriendlyTag and (FriendlyTag[p] ~= false) or false,
		})
	end
	return list
end

local function sendSnapshot(plr)
	RelationAdminSnapshot:FireClient(plr, {
		Players = getPlayerData(),
		MapType = MapInfo.ZoneType
	})
end


Players.PlayerAdded:Connect(function(plr)
	sendSnapshot(plr)
end)

RequestRelationUpdate.OnServerEvent:Connect(function(plr, payload)

	local target = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == payload.UserId then target = p break end
	end
	if not target then return end

	if payload.Party then PartyOf[target] = payload.Party else PartyOf[target] = nil end
	if payload.Guild then GuildOf[target] = payload.Guild else GuildOf[target] = nil end
	if payload.Alliance then AllianceOf[target] = payload.Alliance else AllianceOf[target] = nil end
	if payload.Friendly ~= nil then FriendlyTag[target] = payload.Friendly end


	for _, viewer in ipairs(Players:GetPlayers()) do
		sendSnapshot(viewer)
		RelationshipService:_sendSnapshot(viewer)
	end

	RelationshipService:BroadcastDelta(target)
end)

RequestMapTypeChange.OnServerEvent:Connect(function(plr, newType)
	if typeof(newType) ~= "string" then return end
	local allowed = {Safe=true,Warn=true,Danger=true,Death=true}
	if not allowed[newType] then return end

	MapInfo.ZoneType = newType

	for _, viewer in ipairs(Players:GetPlayers()) do
		sendSnapshot(viewer)
		RelationshipService:_sendSnapshot(viewer)
	end
end)
