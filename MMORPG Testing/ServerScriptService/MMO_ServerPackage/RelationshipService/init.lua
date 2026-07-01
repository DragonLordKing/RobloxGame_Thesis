--[[
Name: RelationshipService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.RelationshipService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, HttpService, ServerScriptService
Requires:
  - local MapInfo        = require(script.Parent.MapSettings)
  - local CombatState    = require(script.Parent:WaitForChild("PlayerCombatStateService"))
  - local WorldBus   = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("WorldBus"))
Functions: getOrAssignNPCId, zoneRelation, immunityKey, _playerAttackingNPC, _npcTowardPlayer, makeRec, RS:SetPartyImmunity, RS:ArePartyImmune, RS:GetRelation, RS:CanDamage, RS:_sendSnapshot, RS:BroadcastDelta
Clean source lines: 194
]]
local Players        = game:GetService("Players")
local ReplicatedStor = game:GetService("ReplicatedStorage")
local MapInfo        = require(script.Parent.MapSettings)
local CombatState    = require(script.Parent:WaitForChild("PlayerCombatStateService"))
local HttpService    = game:GetService("HttpService")

local WorldBus   = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("WorldBus"))


local PartyOf     = {}
local GuildOf     = {}
local AllianceOf  = {}
local FriendlyTag = {}
local FactionOf   = {}
local PartyImmunity = {}


local NPCIdMap = {}

local function getOrAssignNPCId(mdl)
	if not NPCIdMap[mdl] then
		local existing = mdl:GetAttribute("RelationId")
		local guid = existing or HttpService:GenerateGUID(false)
		NPCIdMap[mdl] = guid
		mdl:SetAttribute("RelationId", guid)
	end
	return NPCIdMap[mdl]
end


local function zoneRelation(zone, pvpActive)
	if zone == "Safe" then return "Neutral" end
	if zone == "Death" then return "Hostile" end
	if zone == "Warn" or zone == "Danger" then
		return pvpActive and "Hostile" or "Neutral"
	end
	return "Neutral"
end

local RS = {}

local function immunityKey(a, b)
	local idA = typeof(a) == "Instance" and a:IsA("Player") and a.UserId or tonumber(a)
	local idB = typeof(b) == "Instance" and b:IsA("Player") and b.UserId or tonumber(b)
	if not (idA and idB) then return nil end
	if idA > idB then idA, idB = idB, idA end
	return tostring(idA) .. ":" .. tostring(idB)
end

function RS:SetPartyImmunity(a, b, durationSeconds)
	local key = immunityKey(a, b)
	if not key then return end
	PartyImmunity[key] = os.clock() + math.max(1, tonumber(durationSeconds) or 60)
end

function RS:ArePartyImmune(a, b)
	local key = immunityKey(a, b)
	if not key then return false end
	local expiresAt = PartyImmunity[key]
	if not expiresAt then return false end
	if expiresAt <= os.clock() then
		PartyImmunity[key] = nil
		return false
	end
	return true
end

local function _playerAttackingNPC(player, npcModel)
	local fac = FactionOf[npcModel]
	if fac == "Guard" then
		return npcModel:GetAttribute("Hostile") and "Hostile" or "Neutral"
	end
	if fac == "Mob" then
		if CombatState.IsDowned(player) then return "Neutral" end
		return "Hostile"
	end
	return "Neutral"
end

local function _npcTowardPlayer(player, npcModel)
	local fac = FactionOf[npcModel]
	if fac == "Guard" then
		return npcModel:GetAttribute("Hostile") and "Hostile" or "Neutral"
	end
	if fac == "Mob" then
		if CombatState.ShouldMobIgnorePlayer(player) then return "Neutral" end
		return "Hostile"
	end
	return "Neutral"
end

function RS:GetRelation(a, b)
	local pa, pb = Players:GetPlayerFromCharacter(a), Players:GetPlayerFromCharacter(b)
	if a == b then return "Party" end


	if pa and pb then
		if PartyOf[pa]    == PartyOf[pb]    and PartyOf[pa]    then return "Party"    end
		if RS:ArePartyImmune(pa, pb) then return "Neutral" end
		if GuildOf[pa]    == GuildOf[pb]    and GuildOf[pa]    then return "Guild"    end
		if AllianceOf[pa] == AllianceOf[pb] and AllianceOf[pa] then return "Alliance" end
		local pvpActive = CombatState.IsPvPFlagged(pa) or CombatState.IsPvPFlagged(pb) or FriendlyTag[pa] == false or FriendlyTag[pb] == false
		return zoneRelation(MapInfo.ZoneType, pvpActive)
	end


	if pa and not pb then
		return _playerAttackingNPC(pa, b)
	end


	if pb and not pa then
		return _npcTowardPlayer(pb, a)
	end


	local fa, fb = FactionOf[a], FactionOf[b]
	if fa and fb then
		if fa == fb then return "Neutral" end
		if (fa == "Guard" and fb == "Mob") or (fa == "Mob" and fb == "Guard") then
			return "Hostile"
		end
	end
	return "Neutral"
end

function RS:CanDamage(att, vic)
	return self:GetRelation(att, vic) == "Hostile"
end


local Snapshot  = ReplicatedStor:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents").RelationSnapshot
local Delta     = ReplicatedStor:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents").RelationDelta

local function makeRec(viewer, obj)
	local viewerChar = viewer.Character
	if not viewerChar then return nil end

	local isPlayer = obj:IsA("Player")
	local target   = isPlayer and obj.Character or obj
	if isPlayer and not target then return nil end

	local id = isPlayer and obj.UserId or getOrAssignNPCId(obj)
	return { Id = id, IsPlayer = isPlayer, Relation = RS:GetRelation(viewerChar, target) }
end

function RS:_sendSnapshot(toPlr)

	local snap = {}

	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			local rec = makeRec(toPlr, p)
			if rec then snap[#snap+1] = rec end
		end
	end

	for mdl in pairs(FactionOf) do
		local rec = makeRec(toPlr, mdl)
		if rec then snap[#snap+1] = rec end
	end
	Snapshot:FireClient(toPlr, snap)
end

function RS:BroadcastDelta(entity, remove)
	for _, viewer in ipairs(Players:GetPlayers()) do
		local rec = makeRec(viewer, entity)
		if rec then
			rec.Remove = remove or false
			WorldBus.Rel(viewer, rec)
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Once(function()
		task.wait(0.2)
		RS:_sendSnapshot(plr)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	RS:BroadcastDelta(plr, true)
end)

RS.PartyOf = PartyOf
RS.GuildOf = GuildOf
RS.AllianceOf = AllianceOf
RS.FriendlyTag = FriendlyTag
RS.FactionOf   = FactionOf
RS.PartyImmunity = PartyImmunity

return RS
