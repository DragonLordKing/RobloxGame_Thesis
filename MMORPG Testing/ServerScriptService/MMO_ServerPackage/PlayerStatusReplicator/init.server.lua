--[[
Name: PlayerStatusReplicator
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.PlayerStatusReplicator
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage, ServerScriptService
Requires:
  - local HumanoidStats = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("HumanoidStats"))
  - local MountInfo = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("MountInfo"))
  - local CombatState = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
  - local RelationshipService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
  - local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
  - local ValorService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("Progression"):WaitForChild("ValorService"))
  - local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
Functions: numberAttr, setAttr, syncPlayer, findPlayerByUserId, displayNameFor, equipmentProfile, abilitySelectionFor, markInspectAbilities, detailForItem, buildStatsPayload, buildInspectPayload, PlayerStatusRequest.OnServerInvoke
Signal classes referenced: RemoteFunction, RemoteEvent
Clean source lines: 248
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HumanoidStats = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("HumanoidStats"))
local MountInfo = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("MountInfo"))
local CombatState = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
local RelationshipService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
local ValorService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("Progression"):WaitForChild("ValorService"))
local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))

local remoteFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
end
local PlayerStatusRequest = remoteFolder:FindFirstChild("PlayerStatusRequest")
if not PlayerStatusRequest then
	PlayerStatusRequest = Instance.new("RemoteFunction")
	PlayerStatusRequest.Name = "PlayerStatusRequest"
	PlayerStatusRequest.Parent = remoteFolder
end

local AbilitySelectionUpdate = remoteFolder:FindFirstChild("AbilitySelectionUpdate")
if not AbilitySelectionUpdate or not AbilitySelectionUpdate:IsA("RemoteEvent") then
	if AbilitySelectionUpdate then AbilitySelectionUpdate:Destroy() end
	AbilitySelectionUpdate = Instance.new("RemoteEvent")
	AbilitySelectionUpdate.Name = "AbilitySelectionUpdate"
	AbilitySelectionUpdate.Parent = remoteFolder
end

local EQUIPMENT_SLOT_NAMES = { "Cape", "Helmet", "Bag", "Weapon", "Armor", "Offhand", "Food", "Boots", "Potion", "Mount" }

local function numberAttr(value, fallback)
	return math.floor(tonumber(value) or fallback or 0)
end

local function setAttr(inst, name, value)
	if inst and inst:GetAttribute(name) ~= value then
		inst:SetAttribute(name, value)
	end
end

local function syncPlayer(player)
	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	local legacyTopBar = head and head:FindFirstChild("TopBar")
	if legacyTopBar then
		legacyTopBar:Destroy()
	end
	local stats = HumanoidStats.humanoidStats and HumanoidStats.humanoidStats[character]
	if stats then
		local maxHealth = numberAttr(stats.MaxHealth, 1500)
		local health = numberAttr(stats.Health, maxHealth)
		if health <= 0 and character:GetAttribute("Downed") ~= true then
			health = maxHealth
			stats.Health = health
		end
		setAttr(character, "Health", health)
		setAttr(character, "MaxHealth", maxHealth)
		setAttr(character, "Mana", numberAttr(stats.Will, stats.MaxWill or 100))
		setAttr(character, "MaxMana", numberAttr(stats.MaxWill, 100))
		setAttr(character, "ItemPower", math.floor((tonumber(stats.ItemPower) or 0) + 0.5))
		setAttr(character, "PhysicalAbilityBonus", math.floor((tonumber(stats.PhysicalAbilityBonus) or 0) + 0.5))
		setAttr(character, "DestinyItemPowerBonus", math.floor((tonumber(stats.DestinyItemPowerBonus) or 0) + 0.5))
	end

	local horse = MountInfo.mountedHorses[player.UserId]
	local mounted = horse and horse.Parent and horse:GetAttribute("Mounted") == true
	setAttr(character, "Mounted", mounted == true)
	if mounted then
		setAttr(character, "MountHealth", numberAttr(horse:GetAttribute("Health"), 0))
		setAttr(character, "MaxMountHealth", numberAttr(horse:GetAttribute("MaxHealth"), 0))
	else
		setAttr(character, "MountHealth", 0)
		setAttr(character, "MaxMountHealth", 0)
	end

	setAttr(character, "Honor", CombatState.GetHonor(player))
	setAttr(character, "PvPFlagged", CombatState.IsPvPFlagged(player))
	setAttr(character, "Downed", CombatState.IsDowned(player))
	setAttr(character, "ZoneType", CombatState.GetZoneType())
	setAttr(character, "GuildName", RelationshipService.GuildOf[player] or "")
	setAttr(character, "AllianceAlias", RelationshipService.AllianceOf[player] or "")
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		syncPlayer(player)
	end)
end)

local function findPlayerByUserId(userId)
	userId = tonumber(userId)
	if not userId then return nil end
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.UserId == userId then return candidate end
	end
	return nil
end

local function displayNameFor(target)
	if not target then return "Unknown" end
	return target.DisplayName ~= "" and target.DisplayName or target.Name
end

local function equipmentProfile(target)
	local section = ProfileService.GetSection(target, "Equipment", function()
		return { Equipment = {}, Slots = {}, Mount = nil }
	end)
	if type(section.Equipment) ~= "table" then section.Equipment = {} end
	return section
end

local function abilitySelectionFor(section, itemId, slotName)
	local source = type(section) == "table" and (section.SelectedAbilities or section.AbilitySelections or section.Abilities) or nil
	if type(source) ~= "table" then return nil end
	local bySlot = source[slotName]
	if type(bySlot) == "table" then return bySlot end
	local byItem = source[itemId]
	if type(byItem) == "table" then return byItem end
	return source
end

local function markInspectAbilities(detail, selection)
	if type(detail) ~= "table" then return end
	detail.ReadOnlyAbilities = true
	detail.InspectReadOnly = true
	local grid = detail.abilitiesGrid or detail.abilityRows
	if type(grid) ~= "table" then return end
	for rowKey, list in pairs(grid) do
		if type(list) == "table" then
			local selectedIndex = 1
			if type(selection) == "table" then
				selectedIndex = math.max(1, math.floor(tonumber(selection[rowKey] or selection[string.lower(tostring(rowKey))]) or 1))
			end
			for index, ability in ipairs(list) do
				if type(ability) == "table" then
					ability.selectable = true
					ability.selected = index == selectedIndex
				end
			end
		end
	end
end

local function detailForItem(itemId, slotName, section)
	local id = ItemCatalog.NormalizeId(itemId)
	if not id or not ItemCatalog.Get(id) then return nil end
	local ok, detail = pcall(function()
		return ItemCatalog.BuildDetail({ Id = id, Amount = 1 }, { Slot = slotName, Source = "Inspect" })
	end)
	if not ok then
		warn(("[PlayerStatus] Could not build detail for '%s': %s"):format(tostring(id), tostring(detail)))
		return nil
	end
	if detail then
		detail.equipSlot = slotName
		detail.EquipSlot = slotName
		markInspectAbilities(detail, abilitySelectionFor(section, id, slotName))
	end
	return detail
end

local function buildStatsPayload(target)
	local totals = ValorService.GetValorTotals(target)
	return {
		Ok = true,
		UserId = target.UserId,
		Name = target.Name,
		DisplayName = displayNameFor(target),
		Honor = CombatState.GetHonor(target),
		Valor = {
			Total = totals.Total or 0,
			PvP = totals.PvP or 0,
			PvE = totals.PvE or 0,
			Gathering = totals.Gathering or 0,
			Crafting = totals.Crafting or 0,
		},
	}
end

local function buildInspectPayload(target)
	local section = equipmentProfile(target)
	local equipment = section.Equipment
	local slots = {}
	for _, slotName in ipairs(EQUIPMENT_SLOT_NAMES) do
		local detail = detailForItem(equipment[slotName], slotName, section)
		table.insert(slots, {
			Slot = slotName,
			ItemId = equipment[slotName],
			Detail = detail,
		})
	end
	return {
		Ok = true,
		UserId = target.UserId,
		Name = target.Name,
		DisplayName = displayNameFor(target),
		Slots = slots,
	}
end

PlayerStatusRequest.OnServerInvoke = function(requester, action, payload)
	payload = type(payload) == "table" and payload or {}
	local target = findPlayerByUserId(payload.UserId) or requester
	if not target then return { Ok = false, Error = "Player not found." } end
	if action == "Stats" then
		return buildStatsPayload(target)
	elseif action == "Inspect" then
		return buildInspectPayload(target)
	end
	return { Ok = false, Error = "Unknown status request." }
end

AbilitySelectionUpdate.OnServerEvent:Connect(function(player, itemKey, itemType, rowKey, selectedIndex)
	itemKey = ItemCatalog.NormalizeId(itemKey) or tostring(itemKey or "")
	rowKey = tostring(rowKey or "")
	selectedIndex = math.clamp(math.floor(tonumber(selectedIndex) or 1), 1, 9)
	if itemKey == "" or rowKey == "" then return end
	local section = equipmentProfile(player)
	if type(section.AbilitySelections) ~= "table" then section.AbilitySelections = {} end
	local bucket = section.AbilitySelections[itemKey]
	if type(bucket) ~= "table" then
		bucket = {}
		section.AbilitySelections[itemKey] = bucket
	end
	bucket[rowKey] = selectedIndex
	bucket[string.lower(rowKey)] = selectedIndex
	if itemType == "Weapon" then
		section.AbilitySelections.Weapon = section.AbilitySelections.Weapon or {}
		section.AbilitySelections.Weapon[rowKey] = selectedIndex
		section.AbilitySelections.Weapon[string.lower(rowKey)] = selectedIndex
	end
	ProfileService.MarkDirty(player)
end)

while true do
	for _, player in ipairs(Players:GetPlayers()) do
		syncPlayer(player)
	end
	task.wait(0.25)
end
