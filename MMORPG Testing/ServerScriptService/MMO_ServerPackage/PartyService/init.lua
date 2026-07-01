--[[
Name: PartyService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.PartyService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, HttpService, ServerScriptService
Requires:
  - local RelationshipService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
Functions: ensureRemote, displayName, notify, setParty, partyMembers, memberPayload, snapshotFor, sendSnapshot, broadcastSnapshot, broadcastRelations, createParty, addMember, applyExitImmunity, clearPartyIfSingle, removeMember, targetPlayerByUserId, handleInvite, handleInviteResponse, handleKick, handlePromote, PartyService.GetParty, PartyService.GetSnapshot, PartyService.GetNearbyMembers, PartyService.GrantPartyCombatValor, PartyService.Start, PartyRequest.OnServerInvoke
Signal classes referenced: RemoteFunction, RemoteEvent
Clean source lines: 369
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local RelationshipService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))

local PartyService = {}

local MAX_PARTY_SIZE = 20
local INVITE_TIMEOUT = 30
local IMMUNITY_SECONDS = 60
local SHARE_RADIUS = 220

local remoteFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
end

local function ensureRemote(className, name)
	local existing = remoteFolder:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then existing:Destroy() end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = remoteFolder
	return inst
end

local PartyRequest = ensureRemote("RemoteFunction", "PartyRequest")
local PartyInvite = ensureRemote("RemoteEvent", "PartyInvite")
local PartySnapshot = ensureRemote("RemoteEvent", "PartySnapshot")
local PartyNotice = ensureRemote("RemoteEvent", "PartyNotice")

local parties = {}
local partyByPlayer = {}
local pendingInvites = {}
local started = false

local function displayName(player)
	return player and ((player.DisplayName ~= "" and player.DisplayName) or player.Name) or "Someone"
end

local function notify(player, text, kind)
	if player and player.Parent == Players then
		PartyNotice:FireClient(player, { Text = tostring(text or ""), Kind = kind or "Info" })
	end
end

local function setParty(player, party)
	partyByPlayer[player] = party
	RelationshipService.PartyOf[player] = party and party.Id or nil
	if player and player.Parent then
		player:SetAttribute("PartyId", party and party.Id or "")
		player:SetAttribute("PartyLeader", party and party.Leader == player or false)
	end
end

local function partyMembers(party)
	local members = {}
	if type(party) ~= "table" then return members end
	for member in pairs(party.Members) do
		if member and member.Parent == Players then
			table.insert(members, member)
		else
			party.Members[member] = nil
		end
	end
	table.sort(members, function(a, b) return a.UserId < b.UserId end)
	return members
end

local function memberPayload(member, leader, viewer)
	local character = member.Character
	local health = tonumber(character and character:GetAttribute("Health")) or 0
	local maxHealth = tonumber(character and character:GetAttribute("MaxHealth")) or math.max(1, health)
	return {
		UserId = member.UserId,
		Name = member.Name,
		DisplayName = displayName(member),
		Health = math.max(0, health),
		MaxHealth = math.max(1, maxHealth),
		IsLeader = member == leader,
		IsSelf = member == viewer,
	}
end

local function snapshotFor(viewer)
	local party = partyByPlayer[viewer]
	if not party then
		return { Members = {}, LeaderUserId = 0, Size = 0, MaxSize = MAX_PARTY_SIZE }
	end
	local members = partyMembers(party)
	local rows = {}
	for _, member in ipairs(members) do
		table.insert(rows, memberPayload(member, party.Leader, viewer))
	end
	return {
		PartyId = party.Id,
		Members = rows,
		LeaderUserId = party.Leader and party.Leader.UserId or 0,
		Size = #members,
		MaxSize = MAX_PARTY_SIZE,
	}
end

local function sendSnapshot(player)
	if player and player.Parent == Players then
		local party = partyByPlayer[player]
		player:SetAttribute("PartyLeader", party and party.Leader == player or false)
		PartySnapshot:FireClient(player, snapshotFor(player))
	end
end

local function broadcastSnapshot(party)
	for _, member in ipairs(partyMembers(party)) do
		member:SetAttribute("PartyLeader", party.Leader == member)
		sendSnapshot(member)
	end
end

local function broadcastRelations(playersToRefresh)
	for _, member in ipairs(playersToRefresh or {}) do
		if member and member.Parent == Players then
			RelationshipService:BroadcastDelta(member)
		end
	end
end

local function createParty(leader)
	local party = {
		Id = HttpService:GenerateGUID(false),
		Leader = leader,
		Members = {},
		CreatedAt = os.time(),
	}
	parties[party.Id] = party
	party.Members[leader] = true
	setParty(leader, party)
	return party
end

local function addMember(party, player)
	if not (party and player) then return false, "Party not found." end
	if partyByPlayer[player] then return false, "That player is already in a party." end
	local members = partyMembers(party)
	if #members >= MAX_PARTY_SIZE then return false, "That party is full." end
	party.Members[player] = true
	setParty(player, party)
	broadcastSnapshot(party)
	broadcastRelations(partyMembers(party))
	return true
end

local function applyExitImmunity(player, oldMembers)
	for _, other in ipairs(oldMembers or {}) do
		if other ~= player and other.Parent == Players then
			RelationshipService:SetPartyImmunity(player, other, IMMUNITY_SECONDS)
		end
	end
end

local function clearPartyIfSingle(party)
	local members = partyMembers(party)
	if #members == 0 then
		parties[party.Id] = nil
		return true
	end
	if #members == 1 then
		local last = members[1]
		party.Members[last] = nil
		setParty(last, nil)
		parties[party.Id] = nil
		notify(last, "Party disbanded.", "Info")
		sendSnapshot(last)
		broadcastRelations({ last })
		return true
	end
	return false
end

local function removeMember(player, reason, withImmunity)
	local party = partyByPlayer[player]
	if not party then return false, "You are not in a party." end
	local oldMembers = partyMembers(party)
	party.Members[player] = nil
	setParty(player, nil)
	if withImmunity then
		applyExitImmunity(player, oldMembers)
	end
	if party.Leader == player then
		local remaining = partyMembers(party)
		party.Leader = remaining[1]
	end
	notify(player, reason or "You left the party.", "Info")
	sendSnapshot(player)
	if not clearPartyIfSingle(party) then
		broadcastSnapshot(party)
		broadcastRelations(oldMembers)
		if party.Leader then
			notify(party.Leader, "You are now the party leader.", "Info")
		end
	else
		broadcastRelations(oldMembers)
	end
	return true
end

local function targetPlayerByUserId(userId)
	userId = tonumber(userId)
	if not userId then return nil end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then return player end
	end
	return nil
end

function PartyService.GetParty(player)
	return partyByPlayer[player]
end

function PartyService.GetSnapshot(player)
	return snapshotFor(player)
end

function PartyService.GetNearbyMembers(player, position, radius)
	local party = partyByPlayer[player]
	local members = party and partyMembers(party) or { player }
	local out = {}
	radius = tonumber(radius) or SHARE_RADIUS
	for _, member in ipairs(members) do
		local character = member.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local health = tonumber(character and character:GetAttribute("Health")) or 0
		if root and health > 0 and character:GetAttribute("Downed") ~= true then
			if typeof(position) ~= "Vector3" or (root.Position - position).Magnitude <= radius then
				table.insert(out, member)
			end
		end
	end
	return out
end

function PartyService.GrantPartyCombatValor(valorService, killer, amount, reason, meta)
	local party = partyByPlayer[killer]
	if not party then return false end
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return false end
	meta = type(meta) == "table" and meta or {}
	local position = meta.Position
	local members = PartyService.GetNearbyMembers(killer, position, SHARE_RADIUS)
	if #members <= 1 then return false end
	local partySizeForBonus = math.min(#members, MAX_PARTY_SIZE)
	local total = math.max(1, math.floor(amount * (1 + math.max(0, partySizeForBonus - 1) * 0.05) + 0.5))
	local baseShare = math.floor(total / #members)
	local remainder = total - baseShare * #members
	for index, member in ipairs(members) do
		local share = baseShare + (index <= remainder and 1 or 0)
		if share > 0 then
			local memberMeta = {}
			for k, v in pairs(meta) do memberMeta[k] = v end
			memberMeta.PartyShare = true
			memberMeta.PartySize = #members
			memberMeta.OriginalValor = amount
			memberMeta.SharedTotalValor = total
			valorService.GrantCombatValor(member, share, reason or "npc_kill_party", memberMeta)
		end
	end
	return true
end

local function handleInvite(player, payload)
	local target = targetPlayerByUserId(type(payload) == "table" and payload.TargetUserId)
	if not target or target == player then return { Ok = false, Error = "Choose another online player." } end
	if partyByPlayer[target] then return { Ok = false, Error = displayName(target) .. " is already in a party." } end
	local party = partyByPlayer[player] or createParty(player)
	if party.Leader ~= player then return { Ok = false, Error = "Only the party leader can invite." } end
	if #partyMembers(party) >= MAX_PARTY_SIZE then return { Ok = false, Error = "Your party is full." } end
	pendingInvites[target] = { From = player, PartyId = party.Id, Expires = os.clock() + INVITE_TIMEOUT }
	PartyInvite:FireClient(target, { FromUserId = player.UserId, FromName = displayName(player), Expires = INVITE_TIMEOUT })
	notify(player, "Invited " .. displayName(target) .. " to your party.", "Info")
	sendSnapshot(player)
	return { Ok = true }
end

local function handleInviteResponse(player, payload)
	local invite = pendingInvites[player]
	pendingInvites[player] = nil
	if not invite or invite.Expires <= os.clock() then return { Ok = false, Error = "That invite expired." } end
	local inviter = invite.From
	local accepted = type(payload) == "table" and payload.Accept == true
	if not accepted then
		notify(inviter, displayName(player) .. " declined your party invite.", "Info")
		return { Ok = true }
	end
	if partyByPlayer[player] then return { Ok = false, Error = "You are already in a party." } end
	local party = parties[invite.PartyId]
	if not party and inviter and inviter.Parent == Players then
		party = partyByPlayer[inviter] or createParty(inviter)
	end
	local ok, err = addMember(party, player)
	if not ok then return { Ok = false, Error = err } end
	notify(player, "Joined " .. displayName(party.Leader) .. "'s party.", "Info")
	notify(inviter, displayName(player) .. " joined your party.", "Info")
	return { Ok = true }
end

local function handleKick(player, payload)
	local party = partyByPlayer[player]
	if not party then return { Ok = false, Error = "You are not in a party." } end
	if party.Leader ~= player then return { Ok = false, Error = "Only the party leader can kick." } end
	local target = targetPlayerByUserId(type(payload) == "table" and payload.TargetUserId)
	if not target or partyByPlayer[target] ~= party or target == player then return { Ok = false, Error = "That player is not in your party." } end
	removeMember(target, "You were kicked from the party.", true)
	notify(player, "Kicked " .. displayName(target) .. " from the party.", "Info")
	return { Ok = true }
end

local function handlePromote(player, payload)
	local party = partyByPlayer[player]
	if not party then return { Ok = false, Error = "You are not in a party." } end
	if party.Leader ~= player then return { Ok = false, Error = "Only the party leader can promote." } end
	local target = targetPlayerByUserId(type(payload) == "table" and payload.TargetUserId)
	if not target or partyByPlayer[target] ~= party or target == player then return { Ok = false, Error = "That player is not in your party." } end
	party.Leader = target
	for _, member in ipairs(partyMembers(party)) do
		member:SetAttribute("PartyLeader", member == target)
	end
	broadcastSnapshot(party)
	notify(target, "You are now the party leader.", "Info")
	notify(player, "Made " .. displayName(target) .. " party leader.", "Info")
	return { Ok = true }
end

function PartyService.Start()
	if started then return end
	started = true
	PartyRequest.OnServerInvoke = function(player, actionName, payload)
		if actionName == "Invite" then return handleInvite(player, payload) end
		if actionName == "RespondInvite" then return handleInviteResponse(player, payload) end
		if actionName == "Leave" then
			local ok, err = removeMember(player, "You left the party.", true)
			return { Ok = ok, Error = err }
		end
		if actionName == "Kick" then return handleKick(player, payload) end
		if actionName == "Promote" then return handlePromote(player, payload) end
		if actionName == "Snapshot" then return { Ok = true, Snapshot = snapshotFor(player) } end
		return { Ok = false, Error = "Unknown party action." }
	end
	Players.PlayerAdded:Connect(function(player)
		task.defer(sendSnapshot, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pendingInvites[player] = nil
		if partyByPlayer[player] then
			removeMember(player, "You left the party.", false)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(sendSnapshot, player)
	end
end

return PartyService
