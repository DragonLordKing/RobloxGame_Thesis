--[[
Name: PlayerProfileService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.PlayerProfileService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, DataStoreService, RunService
Functions: dataKey, defaultEquipment, defaultSlots, defaultProfile, cloneValue, sanitizeProfile, buildSavePayload, PlayerProfileService.GetStoreName, PlayerProfileService.GetProfile, PlayerProfileService.GetSection, PlayerProfileService.SetSection, PlayerProfileService.MarkDirty, PlayerProfileService.Save, PlayerProfileService.HoldRelease, PlayerProfileService.ReleaseHold, PlayerProfileService.HasReleaseHold, PlayerProfileService.SaveAndRelease, PlayerProfileService.SaveAll
Clean source lines: 370
]]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local STORE_NAME = "MMO_PlayerProfile_V1"
local store = DataStoreService:GetDataStore(STORE_NAME)

local PlayerProfileService = {}

local profiles = {}
local dirty = {}
local loading = {}
local loadOk = {}
local saving = {}
local released = {}
local releaseHolds = {}

local function dataKey(userId)
	return "player:" .. tostring(userId)
end

local function defaultEquipment()
	return {
		Armor = nil,
		Helmet = nil,
		Boots = nil,
		Cape = nil,
		Food = nil,
		Potion = nil,
		Weapon = nil,
		Offhand = nil,
		Bag = nil,
		Mount = nil,
	}
end

local function defaultSlots()
	local slots = {}
	for i = 1, 40 do
		slots["slot" .. i] = nil
	end
	return slots
end

local function defaultProfile()
	return {
		Version = 1,
		CreatedAt = os.time(),
		LastSeen = os.time(),
		Equipment = {
			Equipment = defaultEquipment(),
			Slots = defaultSlots(),
			Mount = nil,
		},
		Gathering = {
			Inventory = {},
		},
		Inventory = {
			Version = 5,
			Slots = {},
			Banks = {},
			StarterGranted = false,
			StarterSwordGranted = false,
			StarterQualityPurityGranted = false,
			StarterEAbilitySwordsGranted = false,
			MigratedEquipmentSlots = false,
			MigratedGathering = false,
			DevMaterialGrantVersion = 0,
		},
		Economy = {
			Version = 1,
			Coin = 2500,
			CharredToken = 5,
			DevCoinGrantVersion = 0,
		},
		Valor = {
			Version = 1,
			Skills = {},
		},
		City = nil,
		Settings = {},
	}
end

local function cloneValue(value, depth, seen)
	depth = depth or 0
	if depth > 30 then
		return nil
	end

	local valueType = typeof(value)
	if valueType == "table" then
		seen = seen or {}
		if seen[value] then
			return nil
		end
		seen[value] = true

		local copy = {}
		for key, child in pairs(value) do
			local cleanKey = cloneValue(key, depth + 1, seen)
			local cleanChild = cloneValue(child, depth + 1, seen)
			if cleanKey ~= nil and cleanChild ~= nil then
				copy[cleanKey] = cleanChild
			end
		end
		seen[value] = nil
		return copy
	elseif valueType == "string" or valueType == "number" or valueType == "boolean" then
		return value
	elseif valueType == "Vector3" then
		return { x = value.X, y = value.Y, z = value.Z }
	elseif valueType == "Vector2" then
		return { x = value.X, y = value.Y }
	end

	return nil
end

local function sanitizeProfile(raw)
	local profile = defaultProfile()

	if type(raw) == "table" then
		for key, value in pairs(raw) do
			local copy = cloneValue(value)
			if copy ~= nil then
				profile[key] = copy
			end
		end
	end

	profile.Version = 1
	profile.LastSeen = os.time()

	if type(profile.Equipment) ~= "table" then
		profile.Equipment = {}
	end
	if type(profile.Equipment.Equipment) ~= "table" then
		profile.Equipment.Equipment = defaultEquipment()
	end
	if type(profile.Equipment.Slots) ~= "table" then
		profile.Equipment.Slots = defaultSlots()
	end

	if type(profile.Gathering) ~= "table" then
		profile.Gathering = {}
	end
	if type(profile.Gathering.Inventory) ~= "table" then
		profile.Gathering.Inventory = {}
	end

	if type(profile.Inventory) ~= "table" then
		profile.Inventory = {}
	end
	profile.Inventory.Version = 5
	if type(profile.Inventory.Slots) ~= "table" then
		profile.Inventory.Slots = {}
	end
	if type(profile.Inventory.Banks) ~= "table" then
		profile.Inventory.Banks = {}
	end

	if type(profile.Economy) ~= "table" then
		profile.Economy = {}
	end
	profile.Economy.Version = 1
	profile.Economy.Coin = math.max(0, math.floor(tonumber(profile.Economy.Coin) or 2500))
	profile.Economy.CharredToken = math.max(0, math.floor(tonumber(profile.Economy.CharredToken) or 5))

	if type(profile.Valor) ~= "table" then
		profile.Valor = {}
	end
	profile.Valor.Version = 1
	if type(profile.Valor.Skills) ~= "table" then
		profile.Valor.Skills = {}
	end

	if profile.City ~= nil and type(profile.City) ~= "table" then
		profile.City = nil
	end

	if type(profile.Settings) ~= "table" then
		profile.Settings = {}
	end

	return profile
end

local function buildSavePayload(profile)
	local payload = cloneValue(profile) or defaultProfile()
	payload.Version = 1
	payload.LastSeen = os.time()
	payload.LastSaved = os.time()
	return payload
end

function PlayerProfileService.GetStoreName()
	return STORE_NAME
end

function PlayerProfileService.GetProfile(player)
	if profiles[player] then
		return profiles[player]
	end

	while loading[player] do
		task.wait()
	end
	if profiles[player] then
		return profiles[player]
	end

	loading[player] = true
	released[player] = nil

	local raw
	local ok, err = pcall(function()
		raw = store:GetAsync(dataKey(player.UserId))
	end)

	if not ok then
		warn(("[PlayerProfile] Load failed for %s: %s"):format(player.Name, tostring(err)))
	end

	local profile = sanitizeProfile(ok and raw or nil)
	profiles[player] = profile
	loadOk[player] = ok == true
	dirty[player] = raw == nil and ok == true
	loading[player] = nil
	return profile
end

function PlayerProfileService.GetSection(player, sectionName, defaultFactory)
	local profile = PlayerProfileService.GetProfile(player)
	local section = profile[sectionName]
	if type(section) ~= "table" then
		section = defaultFactory and defaultFactory() or {}
		profile[sectionName] = section
		dirty[player] = true
	end
	return section
end

function PlayerProfileService.SetSection(player, sectionName, value)
	local profile = PlayerProfileService.GetProfile(player)
	profile[sectionName] = cloneValue(value) or value
	dirty[player] = true
	return profile[sectionName]
end

function PlayerProfileService.MarkDirty(player)
	if profiles[player] and not released[player] then
		dirty[player] = true
	end
end

function PlayerProfileService.Save(player)
	local profile = profiles[player]
	if not profile or saving[player] then
		return false
	end
	if loadOk[player] == false then
		warn(("[PlayerProfile] Skipping save for %s because the profile did not load cleanly."):format(player.Name))
		return false
	end

	saving[player] = true
	profile.LastSeen = os.time()
	local payload = buildSavePayload(profile)

	local ok, err = pcall(function()
		store:SetAsync(dataKey(player.UserId), payload)
	end)

	if ok then
		dirty[player] = nil
	else
		warn(("[PlayerProfile] Save failed for %s: %s"):format(player.Name, tostring(err)))
	end

	saving[player] = nil
	return ok
end

function PlayerProfileService.HoldRelease(player, token)
	if not player then return false end
	token = tostring(token or "default")
	releaseHolds[player] = releaseHolds[player] or {}
	releaseHolds[player][token] = true
	released[player] = nil
	return true
end

function PlayerProfileService.ReleaseHold(player, token)
	if not player then return false end
	token = tostring(token or "default")
	local holds = releaseHolds[player]
	if holds then
		holds[token] = nil
		if next(holds) == nil then
			releaseHolds[player] = nil
		end
	end
	if not player.Parent then
		PlayerProfileService.SaveAndRelease(player, true)
	end
	return true
end

function PlayerProfileService.HasReleaseHold(player)
	local holds = releaseHolds[player]
	return holds ~= nil and next(holds) ~= nil
end

function PlayerProfileService.SaveAndRelease(player, force)
	if released[player] then
		return
	end
	if not force and PlayerProfileService.HasReleaseHold(player) then
		return false
	end
	released[player] = true
	PlayerProfileService.Save(player)
	profiles[player] = nil
	dirty[player] = nil
	loading[player] = nil
	loadOk[player] = nil
	saving[player] = nil
	releaseHolds[player] = nil
	return true
end

function PlayerProfileService.SaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerProfileService.SaveAndRelease(player, true)
	end
	for player in pairs(profiles) do
		PlayerProfileService.SaveAndRelease(player, true)
	end
end

if RunService:IsServer() then
	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			PlayerProfileService.GetProfile(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)

		task.defer(function()
			PlayerProfileService.SaveAndRelease(player)
		end)
	end)

	game:BindToClose(function()
		task.wait(0.1)
		PlayerProfileService.SaveAll()
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(function()
			PlayerProfileService.GetProfile(player)
		end)
	end
end


return PlayerProfileService
