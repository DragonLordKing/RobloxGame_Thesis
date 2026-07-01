--[[
Name: PlayerCombatStateService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.PlayerCombatStateService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, ServerScriptService, ServerStorage
Requires:
  - local MapInfo = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("MapSettings"))
  - local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
  - local HumanoidStats = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("HumanoidStats"))
  - local SpatialGrid = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("SpatialGrid"))
  - local InventoryStorageService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("InventoryStorageService"))
  - return require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
  - local EconomyMarketService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("EconomyMarketService"))
Functions: getZoneType, sourceToPlayer, getState, getReputation, setCharacterAttribute, syncPlayerAttributes, refreshRelations, setPvPFlag, setLiveHealth, freezePlayer, applyDowned, clearCharacterStats, applyLethalDeath, applyPlayerDefeatHonor, PlayerCombatStateService.GetZoneType, PlayerCombatStateService.IsPvPFlagged, PlayerCombatStateService.GetHonor, PlayerCombatStateService.IsRed, PlayerCombatStateService.IsDowned, PlayerCombatStateService.ShouldMobIgnorePlayer, PlayerCombatStateService.CanMobDamage, PlayerCombatStateService.IsInCombat, PlayerCombatStateService.IsAggressiveCombat, PlayerCombatStateService.GetAggressiveCombatRemaining, PlayerCombatStateService.MarkDamageReceived, PlayerCombatStateService.ClearPvECombat, PlayerCombatStateService.ClearCombat, PlayerCombatStateService.RegeneratePlayer, PlayerCombatStateService.GrantHonor, PlayerCombatStateService.OnHostileAction, PlayerCombatStateService.HandlePlayerDefeat, PlayerCombatStateService.HandleHumanoidDeath, PlayerCombatStateService.Start, DEFAULT_REPUTATION
Signal classes referenced: RemoteEvent, BindableEvent
Clean source lines: 504
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local MapInfo = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("MapSettings"))
local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
local HumanoidStats = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("HumanoidStats"))
local SpatialGrid = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("SpatialGrid"))
local InventoryStorageService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("InventoryStorageService"))

local remoteFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
end

local SetPvPFlag = remoteFolder:FindFirstChild("SetPvPFlag")
if not SetPvPFlag then
	SetPvPFlag = Instance.new("RemoteEvent")
	SetPvPFlag.Name = "SetPvPFlag"
	SetPvPFlag.Parent = remoteFolder
end

local beFolder = ServerStorage:WaitForChild("MMO_ServerStoragePackage"):FindFirstChild("BindableEvents")
if not beFolder then
	beFolder = Instance.new("Folder")
	beFolder.Name = "BindableEvents"
	beFolder.Parent = ServerStorage:WaitForChild("MMO_ServerStoragePackage")
end
local NPCDied = beFolder:FindFirstChild("NPCDied")
if not NPCDied then
	NPCDied = Instance.new("BindableEvent")
	NPCDied.Name = "NPCDied"
	NPCDied.Parent = beFolder
end

local PlayerCombatStateService = {}
local states = {}
local started = false
local COMBAT_TIMER_SECONDS = 16
local HEALTH_REGEN_PERCENT_PER_SECOND = 0.02
local MANA_REGEN_PERCENT_PER_SECOND = 0.05

local DEFAULT_REPUTATION = function()
	return { Version = 1, Honor = 0 }
end

local function getZoneType()
	return tostring(MapInfo.ZoneType or "Safe")
end

local function sourceToPlayer(source)
	if typeof(source) ~= "Instance" then return nil end
	if source:IsA("Player") then return source end
	if source:IsA("Model") then return Players:GetPlayerFromCharacter(source) end
	return nil
end

local function getState(player)
	if not player then return nil end
	local state = states[player]
	if not state then
		state = { Downed = false, DownedUntil = 0, DownedBy = "", KilledBy = "", DeathCityName = MapInfo.Name or "City", MobGraceUntil = 0, PvPFlagged = false, PvECombatUntil = 0, PvPCombatUntil = 0, AggressiveCombatUntil = 0, AggressiveCombatKind = "" }
		states[player] = state
	end
	return state
end

local function getReputation(player)
	local section = ProfileService.GetSection(player, "Reputation", DEFAULT_REPUTATION)
	section.Version = 1
	section.Honor = math.floor(tonumber(section.Honor) or 0)
	return section
end

local function setCharacterAttribute(player, name, value)
	local character = player and player.Character
	if character then
		character:SetAttribute(name, value)
	end
end

local function syncPlayerAttributes(player)
	if not player then return end
	local state = getState(player)
	local reputation = getReputation(player)
	local pveUntil = tonumber(state.PvECombatUntil) or 0
	local pvpUntil = tonumber(state.PvPCombatUntil) or 0
	local aggressiveUntil = tonumber(state.AggressiveCombatUntil) or 0
	local inCombat = os.clock() < math.max(pveUntil, pvpUntil)
	local aggressiveCombat = os.clock() < aggressiveUntil
	player:SetAttribute("Honor", reputation.Honor)
	player:SetAttribute("PvPFlagged", state.PvPFlagged == true)
	player:SetAttribute("Downed", state.Downed == true)
	player:SetAttribute("DownedUntil", tonumber(state.DownedUntil) or 0)
	player:SetAttribute("DownedDuration", tonumber(state.DownedDuration) or 0)
	player:SetAttribute("DownedBy", tostring(state.DownedBy or ""))
	player:SetAttribute("KilledBy", tostring(state.KilledBy or ""))
	player:SetAttribute("DeathCityName", tostring(state.DeathCityName or MapInfo.Name or "City"))
	player:SetAttribute("MobGraceUntil", state.MobGraceUntil or 0)
	player:SetAttribute("PvECombatUntil", pveUntil)
	player:SetAttribute("PvPCombatUntil", pvpUntil)
	player:SetAttribute("AggressiveCombatUntil", aggressiveUntil)
	player:SetAttribute("AggressiveCombat", aggressiveCombat)
	player:SetAttribute("AggressiveCombatKind", state.AggressiveCombatKind or "")
	player:SetAttribute("InCombat", inCombat)
	setCharacterAttribute(player, "Honor", reputation.Honor)
	setCharacterAttribute(player, "PvPFlagged", state.PvPFlagged == true)
	setCharacterAttribute(player, "Downed", state.Downed == true)
	setCharacterAttribute(player, "DownedUntil", tonumber(state.DownedUntil) or 0)
	setCharacterAttribute(player, "DownedDuration", tonumber(state.DownedDuration) or 0)
	setCharacterAttribute(player, "DownedBy", tostring(state.DownedBy or ""))
	setCharacterAttribute(player, "KilledBy", tostring(state.KilledBy or ""))
	setCharacterAttribute(player, "DeathCityName", tostring(state.DeathCityName or MapInfo.Name or "City"))
	setCharacterAttribute(player, "MobGraceUntil", state.MobGraceUntil or 0)
	setCharacterAttribute(player, "PvECombatUntil", pveUntil)
	setCharacterAttribute(player, "PvPCombatUntil", pvpUntil)
	setCharacterAttribute(player, "AggressiveCombatUntil", aggressiveUntil)
	setCharacterAttribute(player, "AggressiveCombat", aggressiveCombat)
	setCharacterAttribute(player, "AggressiveCombatKind", state.AggressiveCombatKind or "")
	setCharacterAttribute(player, "InCombat", inCombat)
	setCharacterAttribute(player, "ZoneType", getZoneType())
end

local function refreshRelations()
	local ok, RelationshipService = pcall(function()
		return require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
	end)
	if not ok or type(RelationshipService) ~= "table" then return end
	for _, viewer in ipairs(Players:GetPlayers()) do
		pcall(function() RelationshipService:_sendSnapshot(viewer) end)
	end
end

local function setPvPFlag(player, enabled)
	local state = getState(player)
	local zone = getZoneType()
	if zone == "Safe" then
		enabled = false
	end
	state.PvPFlagged = enabled == true
	syncPlayerAttributes(player)
	refreshRelations()
end

function PlayerCombatStateService.GetZoneType()
	return getZoneType()
end

function PlayerCombatStateService.IsPvPFlagged(player)
	local state = getState(player)
	return state and state.PvPFlagged == true or false
end

function PlayerCombatStateService.GetHonor(player)
	if not player then return 0 end
	return getReputation(player).Honor
end

function PlayerCombatStateService.IsRed(player)
	return PlayerCombatStateService.IsPvPFlagged(player) or PlayerCombatStateService.GetHonor(player) < 0
end

function PlayerCombatStateService.IsDowned(player)
	local state = getState(player)
	return state and state.Downed == true or false
end

function PlayerCombatStateService.ShouldMobIgnorePlayer(player)
	local state = getState(player)
	if not state then return false end
	return state.Downed == true or os.clock() < (state.MobGraceUntil or 0)
end

function PlayerCombatStateService.CanMobDamage(player)
	return not PlayerCombatStateService.ShouldMobIgnorePlayer(player)
end

function PlayerCombatStateService.IsInCombat(player)
	local state = getState(player)
	if not state then return false end
	return os.clock() < math.max(tonumber(state.PvECombatUntil) or 0, tonumber(state.PvPCombatUntil) or 0)
end

function PlayerCombatStateService.IsAggressiveCombat(player)
	local state = getState(player)
	if not state then return false end
	return os.clock() < (tonumber(state.AggressiveCombatUntil) or 0)
end

function PlayerCombatStateService.GetAggressiveCombatRemaining(player)
	local state = getState(player)
	if not state then return 0 end
	return math.max(0, (tonumber(state.AggressiveCombatUntil) or 0) - os.clock())
end

function PlayerCombatStateService.MarkDamageReceived(victimPlayer, sourcePlayer)
	local state = getState(victimPlayer)
	if not state or state.Downed == true then return end
	local untilTime = os.clock() + COMBAT_TIMER_SECONDS
	if sourcePlayer and sourcePlayer ~= victimPlayer then
		state.PvPCombatUntil = math.max(tonumber(state.PvPCombatUntil) or 0, untilTime)
	else
		state.PvECombatUntil = math.max(tonumber(state.PvECombatUntil) or 0, untilTime)
	end
	syncPlayerAttributes(victimPlayer)
end

function PlayerCombatStateService.ClearPvECombat(player)
	local state = getState(player)
	if not state then return end
	state.PvECombatUntil = 0
	if state.AggressiveCombatKind == "Mob" then
		state.AggressiveCombatUntil = 0
		state.AggressiveCombatKind = ""
	end
	syncPlayerAttributes(player)
end

function PlayerCombatStateService.ClearCombat(player)
	local state = getState(player)
	if not state then return end
	state.PvECombatUntil = 0
	state.PvPCombatUntil = 0
	state.AggressiveCombatUntil = 0
	state.AggressiveCombatKind = ""
	syncPlayerAttributes(player)
end

function PlayerCombatStateService.RegeneratePlayer(player, dt)
	dt = math.clamp(tonumber(dt) or 0, 0, 0.5)
	if dt <= 0 or not player or not player.Parent then return end
	local state = getState(player)
	if not state or state.Downed == true then return end
	local character = player.Character
	local stats = character and HumanoidStats.humanoidStats and HumanoidStats.humanoidStats[character]
	if not stats then return end
	local maxMana = math.max(1, tonumber(stats.MaxWill) or 100)
	local mana = math.clamp(tonumber(stats.Will) or maxMana, 0, maxMana)
	local manaRegen = math.max(tonumber(stats.WillRegen) or 0, maxMana * MANA_REGEN_PERCENT_PER_SECOND)
	if mana < maxMana then
		stats.Will = math.min(maxMana, mana + manaRegen * dt)
		character:SetAttribute("Mana", math.floor(stats.Will + 0.5))
		character:SetAttribute("MaxMana", maxMana)
	end
	local maxHealth = math.max(1, tonumber(stats.MaxHealth) or 1)
	local health = math.clamp(tonumber(stats.Health) or maxHealth, 0, maxHealth)
	if health > 0 and health < maxHealth and not PlayerCombatStateService.IsInCombat(player) then
		stats.Health = math.min(maxHealth, health + maxHealth * HEALTH_REGEN_PERCENT_PER_SECOND * dt)
		character:SetAttribute("Health", math.floor(stats.Health + 0.5))
		character:SetAttribute("MaxHealth", maxHealth)
	end
end

function PlayerCombatStateService.GrantHonor(player, amount, reason)
	if not player or getZoneType() == "Death" then return PlayerCombatStateService.GetHonor(player) end
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then return PlayerCombatStateService.GetHonor(player) end
	local reputation = getReputation(player)
	reputation.Honor = math.clamp((tonumber(reputation.Honor) or 0) + amount, -1000000, 1000000)
	reputation.LastReason = tostring(reason or "honor")
	ProfileService.MarkDirty(player)
	syncPlayerAttributes(player)
	return reputation.Honor
end

function PlayerCombatStateService.OnHostileAction(player, targetModel)
	local state = getState(player)
	if not state then return end
	local targetPlayer = sourceToPlayer(targetModel)
	local character = player.Character
	player:SetAttribute("WorldSpawnBarrier", false)
	player:SetAttribute("WorldBarrierUntil", 0)
	if character then
		character:SetAttribute("WorldSpawnBarrier", false)
		character:SetAttribute("WorldBarrierUntil", 0)
		local forceField = character:FindFirstChild("WorldSpawnBarrierForceField")
		if forceField then forceField:Destroy() end
	end
	state.AggressiveCombatUntil = math.max(tonumber(state.AggressiveCombatUntil) or 0, os.clock() + COMBAT_TIMER_SECONDS)
	state.AggressiveCombatKind = targetPlayer and "Player" or "Mob"
	if os.clock() < (state.MobGraceUntil or 0) then
		state.MobGraceUntil = 0
	end
	syncPlayerAttributes(player)
end

local function setLiveHealth(player, value)
	local character = player and player.Character
	local stats = character and HumanoidStats.humanoidStats and HumanoidStats.humanoidStats[character]
	if stats then
		local maxHealth = math.max(1, tonumber(stats.MaxHealth) or 1)
		stats.Health = math.clamp(math.floor(tonumber(value) or 0), 0, maxHealth)
		character:SetAttribute("Health", stats.Health)
		character:SetAttribute("MaxHealth", maxHealth)
	end
end

local function freezePlayer(player, frozen)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if frozen then
		humanoid:SetAttribute("PreDownedWalkSpeed", humanoid.WalkSpeed)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
	else
		local stats = HumanoidStats.humanoidStats and HumanoidStats.humanoidStats[character]
		humanoid.WalkSpeed = stats and (stats.Speed or 18) or (humanoid:GetAttribute("PreDownedWalkSpeed") or 18)
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
	end
end

local function applyDowned(player, seconds, mobGraceSeconds, sourceName)
	local state = getState(player)
	if state.Downed then return end
	local now = os.clock()
	state.Downed = true
	state.DownedUntil = now + seconds
	state.DownedDuration = seconds
	state.DownedBy = tostring(sourceName or "Unknown")
	state.KilledBy = ""
	state.MobGraceUntil = 0
	setLiveHealth(player, 0)
	freezePlayer(player, true)
	syncPlayerAttributes(player)
	task.spawn(function()
		while player.Parent and state.Downed == true and os.clock() < (state.DownedUntil or 0) do
			local character = player.Character
			local stats = character and HumanoidStats.humanoidStats and HumanoidStats.humanoidStats[character]
			if stats then
				local maxHealth = math.max(1, tonumber(stats.MaxHealth) or 1)
				local progress = math.clamp(1 - ((state.DownedUntil - os.clock()) / math.max(1, seconds)), 0, 1)
				stats.Health = math.max(1, math.floor(maxHealth * progress + 0.5))
				character:SetAttribute("Health", stats.Health)
				character:SetAttribute("MaxHealth", maxHealth)
			end
			task.wait(0.2)
		end
	end)

	task.delay(seconds, function()
		local current = states[player]
		if not current or not player.Parent then return end
		if not current.Downed or os.clock() < (current.DownedUntil or 0) then return end
		current.Downed = false
		current.DownedUntil = 0
		current.DownedDuration = 0
		current.DownedBy = ""
		current.KilledBy = ""
		current.MobGraceUntil = mobGraceSeconds and mobGraceSeconds > 0 and (os.clock() + mobGraceSeconds) or 0
		local character = player.Character
		local stats = character and HumanoidStats.humanoidStats and HumanoidStats.humanoidStats[character]
		if stats then
			stats.Health = stats.MaxHealth or 1500
			character:SetAttribute("Health", stats.Health)
			character:SetAttribute("MaxHealth", stats.MaxHealth or stats.Health)
		end
		freezePlayer(player, false)
		syncPlayerAttributes(player)
	end)
end

local function clearCharacterStats(character)
	if not character then return end
	pcall(function() SpatialGrid.Remove(character) end)
	if HumanoidStats.humanoidStats then
		HumanoidStats.humanoidStats[character] = nil
	end
end

local function applyLethalDeath(player, killer)
	local state = getState(player)
	state.Downed = true
	state.DownedUntil = os.clock() + 8
	state.DownedDuration = 8
	state.DownedBy = ""
	state.KilledBy = killer and (killer.DisplayName or killer.Name) or "Unknown"
	state.DeathCityName = MapInfo.Name or "City"
	state.MobGraceUntil = 0
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local deathPosition = root and root.Position or nil
	setLiveHealth(player, 0)
	freezePlayer(player, true)
	syncPlayerAttributes(player)
	local extracted, deathLoot = pcall(function()
		return InventoryStorageService.ExtractDeathLoot(player)
	end)
	if extracted and type(deathLoot) == "table" and #deathLoot > 0 then
		pcall(function()
			local EconomyMarketService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("EconomyMarketService"))
			if type(EconomyMarketService.CreateDeathSack) == "function" then
				EconomyMarketService.CreateDeathSack(player, killer, deathLoot, deathPosition)
			end
		end)
	elseif not extracted then
		pcall(function()
			InventoryStorageService.ClearInventoryAndEquipment(player)
		end)
	end
	task.delay(8, function()
		if not player.Parent then return end
		local character = player.Character
		clearCharacterStats(character)
		states[player] = { Downed = false, DownedUntil = 0, DownedBy = "", KilledBy = "", DeathCityName = MapInfo.Name or "City", MobGraceUntil = 0, PvPFlagged = false, PvECombatUntil = 0, PvPCombatUntil = 0, AggressiveCombatUntil = 0, AggressiveCombatKind = "" }
		player:LoadCharacter()
		task.defer(function()
			syncPlayerAttributes(player)
		end)
	end)
end

local function applyPlayerDefeatHonor(attacker, victim, zone)
	if not attacker or attacker == victim or zone == "Death" then return end
	if zone ~= "Warn" and zone ~= "Danger" then return end
	if PlayerCombatStateService.IsRed(victim) then
		PlayerCombatStateService.GrantHonor(attacker, 25, "red_player_defeat")
	else
		PlayerCombatStateService.GrantHonor(attacker, -75, "unflagged_player_defeat")
	end
end

function PlayerCombatStateService.HandlePlayerDefeat(victimPlayer, source, meta)
	if not victimPlayer or not victimPlayer.Parent then return false end
	local state = getState(victimPlayer)
	if state.Downed then return true end
	local zone = getZoneType()
	local attacker = sourceToPlayer(source)

	if attacker and attacker ~= victimPlayer then
		applyPlayerDefeatHonor(attacker, victimPlayer, zone)
		if zone == "Warn" then
			applyDowned(victimPlayer, 40, 0, attacker.DisplayName or attacker.Name)
			return true
		elseif zone == "Danger" or zone == "Death" then
			applyLethalDeath(victimPlayer, attacker)
			return true
		else
			setLiveHealth(victimPlayer, 1)
			return true
		end
	end

	applyDowned(victimPlayer, 13, 10, (type(meta) == "table" and meta.SourceName) or "Mob")
	return true
end

function PlayerCombatStateService.HandleHumanoidDeath(player)
	if not player then return end
	local zone = getZoneType()
	if zone == "Danger" or zone == "Death" then
		applyLethalDeath(player, nil)
	else
		applyDowned(player, 13, 10, "Mob")
	end
end

function PlayerCombatStateService.Start()
	if started then return end
	started = true

	SetPvPFlag.OnServerEvent:Connect(function(player, payload)
		local enabled = payload == true
		if type(payload) == "table" then
			enabled = payload.Enabled == true
		end
		setPvPFlag(player, enabled)
	end)

	NPCDied.Event:Connect(function(npcModel, source, meta)
		local player = type(meta) == "table" and meta.KillerPlayer or sourceToPlayer(source)
		if not player then return end
		local tier = math.clamp(math.floor(tonumber((type(meta) == "table" and meta.Tier) or (npcModel and npcModel:GetAttribute("Tier")) or 1) or 1), 1, 20)
		PlayerCombatStateService.GrantHonor(player, math.max(1, tier), "npc_kill")
	end)

	Players.PlayerAdded:Connect(function(player)
		getState(player)
		syncPlayerAttributes(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				syncPlayerAttributes(player)
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		getState(player)
		syncPlayerAttributes(player)
	end
end

return PlayerCombatStateService
