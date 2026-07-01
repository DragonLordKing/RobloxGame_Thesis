--[[
Name: InventoryStorageService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.InventoryStorageService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, ServerScriptService, Workspace
Requires:
  - local ProfileService = require(ServerPackage:WaitForChild("PlayerProfileService"))
  - local ItemCatalog = require(ReplicatedPackage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))
  - local DestinyBoardConfig = require(ReplicatedPackage:WaitForChild("DestinyBoardConfig"))
  - return require(ServerPackage:WaitForChild("HumanoidStats"))
  - return require(ServerPackage:WaitForChild("PlayerCoreLean"):WaitForChild("Stats"))
Functions: ensureRemote, defaultInventory, defaultEquipmentSection, defaultEconomy, slotKey, encodeStack, decodeStack, sameStack, setSlot, normalizeSlots, getInventory, getEconomy, getEquipment, refreshPlayerStats, addToSlots, place, addStackToSlots, countItem, migrateLegacy, stackForClient, slotMapForClient, equipmentMapForClient, calculateWeight, buildMarketSnapshot, buildSnapshot, fireSnapshot, getBank, getBankTab, hashString, seedRandomChest, ensureChest, storageSlots, buildStorageSnapshot, moveBetweenSlots, quickTransfer, storageInstanceDistance, validateStorage, handleStorageMove, deleteInventory, moveInventory, validEquipSlot, getValorSkills, combatLineForItem, validateTierUnlock, equipInventory, quickEquipInventory, useInventoryItem, unequipToInventory, quickTransferEquipment, moveEquipment, findPlayerByUserId, refundOrder, removeOrder, matchingOrders, settleTrade, matchOrder, placeMarketOrder, cancelMarketOrder, cancelPlayerOrders, normalizeCostItems
Signal classes referenced: RemoteFunction, RemoteEvent
Clean source lines: 1318
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ServerPackage = ServerScriptService:WaitForChild("MMO_ServerPackage")
local ReplicatedPackage = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
local ProfileService = require(ServerPackage:WaitForChild("PlayerProfileService"))
local ItemCatalog = require(ReplicatedPackage:WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local DestinyBoardConfig = require(ReplicatedPackage:WaitForChild("DestinyBoardConfig"))

local InventoryStorageService = {}

local INVENTORY_SLOTS = 40
local BANK_TABS = 4
local BANK_SLOTS = 250
local CHEST_SLOTS = 30
local BASE_CARRY_KG = 50
local STORAGE_DISTANCE = 6
local EQUIPMENT_SLOT_NAMES = { "Cape", "Helmet", "Bag", "Weapon", "Armor", "Offhand", "Food", "Boots", "Potion", "Mount" }
local EQUIPMENT_SLOT_SET = {}
for _, slotName in ipairs(EQUIPMENT_SLOT_NAMES) do
	EQUIPMENT_SLOT_SET[slotName] = true
end
local started = false
local DEV_GRANT_USER_ID = 475178488
local DEV_ECONOMY_GRANT_VERSION = 1
local DEV_MATERIAL_GRANT_VERSION = 1

local chestCache = {}
local activeStorage = {}
local marketOrders = {}
local nextOrderId = 1

local remoteFolder = ReplicatedPackage:FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedPackage
end

local function ensureRemote(className, name)
	local existing = remoteFolder:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then existing:Destroy() end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remoteFolder
	return remote
end

local InventoryRequest = ensureRemote("RemoteFunction", "InventoryRequest")
local InventoryUpdated = ensureRemote("RemoteEvent", "InventoryUpdated")
local OpenStorage = ensureRemote("RemoteEvent", "OpenStorage")

local function defaultInventory()
	return { Version = 5, Slots = {}, Banks = {}, StarterGranted = false, StarterSwordGranted = false, StarterHorseGranted = false, StarterQualityPurityGranted = false, StarterEAbilitySwordsGranted = false, MigratedEquipmentSlots = false, MigratedGathering = false, DevMaterialGrantVersion = 0 }
end

local function defaultEquipmentSection()
	return { Equipment = {}, Slots = {}, Mount = nil }
end

local function defaultEconomy()
	return { Version = 1, Coin = 2500, CharredToken = 5, DevCoinGrantVersion = 0 }
end

local function slotKey(slot, maxSlots)
	local n = math.floor(tonumber(slot) or 0)
	if n < 1 or n > maxSlots then return nil end
	return tostring(n), n
end

local function encodeStack(stack)
	if type(stack) ~= "table" then return nil end
	local id = ItemCatalog.NormalizeId(stack.Id or stack.id)
	if not id then return nil end
	local amount = math.max(1, math.floor(tonumber(stack.Amount or stack.amount) or 1))
	local quality = ItemCatalog.NormalizeQuality(stack.Quality or stack.quality or "Normal")
	local purity = ItemCatalog.NormalizePurity(stack.Purity or stack.purity or "None")
	local craftedBy = tostring(stack.CraftedBy or stack.craftedBy or "")
	if quality == "Normal" and purity == "None" and craftedBy == "" then
		return table.concat({ id, tostring(amount) }, "|")
	end
	return table.concat({ id, tostring(amount), quality, purity, craftedBy }, "|")
end

local function decodeStack(raw)
	if raw == nil then return nil end
	if type(raw) == "table" then
		local id = ItemCatalog.NormalizeId(raw.Id or raw.id or raw.ItemId or raw.itemId or raw[1])
		if not id then return nil end
		return { Id = id, Amount = math.max(1, math.floor(tonumber(raw.Amount or raw.amount or raw.Count or raw.count or raw[2]) or 1)), Quality = ItemCatalog.NormalizeQuality(raw.Quality or raw.quality or "Normal"), Purity = ItemCatalog.NormalizePurity(raw.Purity or raw.purity or "None"), CraftedBy = raw.CraftedBy or raw.craftedBy }
	end
	if type(raw) ~= "string" then return nil end
	local parts = string.split(raw, "|")
	local id = ItemCatalog.NormalizeId(parts[1])
	if not id then return nil end
	local def = ItemCatalog.Get(id)
	local quality = ItemCatalog.NormalizeQuality((parts[3] and parts[3] ~= "") and parts[3] or (def and def.Quality) or "Normal")
	local purity = ItemCatalog.NormalizePurity((parts[4] and parts[4] ~= "") and parts[4] or (def and def.Purity) or "None")
	local craftedBy = (parts[5] and parts[5] ~= "") and parts[5] or nil
	return { Id = id, Amount = math.max(1, math.floor(tonumber(parts[2]) or 1)), Quality = quality, Purity = purity, CraftedBy = craftedBy }
end

local function sameStack(a, b)
	return a and b and a.Id == b.Id and ItemCatalog.NormalizeQuality(a.Quality or "Normal") == ItemCatalog.NormalizeQuality(b.Quality or "Normal") and ItemCatalog.NormalizePurity(a.Purity or "None") == ItemCatalog.NormalizePurity(b.Purity or "None") and tostring(a.CraftedBy or "") == tostring(b.CraftedBy or "")
end

local function setSlot(slots, key, stack)
	slots[key] = stack and encodeStack(stack) or nil
end

local function normalizeSlots(slots, maxSlots)
	local changed = false
	local clean = {}
	if type(slots) ~= "table" then return clean, true end
	for key, value in pairs(slots) do
		local cleanKey = slotKey(key, maxSlots)
		if not cleanKey and type(key) == "string" then cleanKey = slotKey(key:match("slot(%d+)"), maxSlots) end
		if cleanKey then
			local stack = decodeStack(value)
			if stack then
				local encoded = encodeStack(stack)
				clean[cleanKey] = encoded
				if encoded ~= value or cleanKey ~= key then changed = true end
			else
				changed = true
			end
		else
			changed = true
		end
	end
	return clean, changed
end

local function getInventory(player)
	local inv = ProfileService.GetSection(player, "Inventory", defaultInventory)
	if type(inv.Slots) ~= "table" then inv.Slots = {} end
	if type(inv.Banks) ~= "table" then inv.Banks = {} end
	local clean, changed = normalizeSlots(inv.Slots, INVENTORY_SLOTS)
	if changed then
		inv.Slots = clean
		ProfileService.MarkDirty(player)
	end
	return inv
end

local function getEconomy(player)
	local economy = ProfileService.GetSection(player, "Economy", defaultEconomy)
	economy.Version = 1
	economy.Coin = math.max(0, math.floor(tonumber(economy.Coin) or 2500))
	economy.CharredToken = math.max(0, math.floor(tonumber(economy.CharredToken) or 5))
	economy.DevCoinGrantVersion = math.max(0, math.floor(tonumber(economy.DevCoinGrantVersion) or 0))
	if player and player.UserId == DEV_GRANT_USER_ID and economy.DevCoinGrantVersion < DEV_ECONOMY_GRANT_VERSION then
		economy.Coin = math.max(economy.Coin, 200000000)
		economy.DevCoinGrantVersion = DEV_ECONOMY_GRANT_VERSION
		ProfileService.MarkDirty(player)
	end
	return economy
end

local function getEquipment(player)
	local section = ProfileService.GetSection(player, "Equipment", defaultEquipmentSection)
	if type(section.Equipment) ~= "table" then section.Equipment = {} end
	local changed = false
	for slotName, value in pairs(section.Equipment) do
		if not EQUIPMENT_SLOT_SET[slotName] then
			section.Equipment[slotName] = nil
			changed = true
		elseif value ~= nil then
			local id = type(value) == "table" and ItemCatalog.NormalizeId(value.Id or value.id or value.ItemId or value.itemId or value[1]) or ItemCatalog.NormalizeId(value)
			if id then
				if section.Equipment[slotName] ~= id then changed = true end
				section.Equipment[slotName] = id
			else
				section.Equipment[slotName] = nil
				changed = true
			end
		end
	end
	if changed then ProfileService.MarkDirty(player) end
	return section.Equipment, section
end

local function refreshPlayerStats(player, equipment)
	local character = player and player.Character
	if character then
		local okHumanoidStats, HumanoidStats = pcall(function()
			return require(ServerPackage:WaitForChild("HumanoidStats"))
		end)
		local liveStats = okHumanoidStats and HumanoidStats.humanoidStats and HumanoidStats.humanoidStats[character]
		if liveStats then
			liveStats.Equipment = equipment
		end
	end
	local okStats, Stats = pcall(function()
		return require(ServerPackage:WaitForChild("PlayerCoreLean"):WaitForChild("Stats"))
	end)
	if okStats and type(Stats) == "table" and type(Stats.RefreshPlayerStats) == "function" then
		pcall(Stats.RefreshPlayerStats, player)
	end
end

local function addToSlots(slots, maxSlots, itemId, amount, preferredSlot, quality, purity, craftedBy)
	local id = ItemCatalog.NormalizeId(itemId)
	if not id then return 0 end
	amount = math.max(1, math.floor(tonumber(amount) or 1))
	local remaining = amount
	local def = ItemCatalog.Get(id)
	local stackable = def and def.Stackable == true
	local maxStack = ItemCatalog.MaxStack(id)
	quality = ItemCatalog.NormalizeQuality(quality or (def and def.Quality) or "Normal")
	purity = ItemCatalog.NormalizePurity(purity or (def and def.Purity) or "None")
	if stackable then
		for i = 1, maxSlots do
			if remaining <= 0 then break end
			local key = tostring(i)
			local stack = decodeStack(slots[key])
			if stack and stack.Id == id and (stack.Quality or "Normal") == quality and (stack.Purity or "None") == purity and stack.Amount < maxStack then
				local added = math.min(remaining, maxStack - stack.Amount)
				stack.Amount += added
				remaining -= added
				setSlot(slots, key, stack)
			end
		end
	end
	local function place(key)
		if remaining <= 0 or not key or slots[key] ~= nil then return end
		local added = stackable and math.min(remaining, maxStack) or 1
		setSlot(slots, key, { Id = id, Amount = added, Quality = quality, Purity = purity, CraftedBy = craftedBy })
		remaining -= added
	end
	place(slotKey(preferredSlot, maxSlots))
	for i = 1, maxSlots do
		if remaining <= 0 then break end
		place(tostring(i))
	end
	return amount - remaining
end

local function addStackToSlots(slots, maxSlots, stack, preferredSlot)
	if not stack then return 0 end
	return addToSlots(slots, maxSlots, stack.Id, stack.Amount, preferredSlot, stack.Quality, stack.Purity, stack.CraftedBy)
end

local function countItem(slots, itemId)
	local id = ItemCatalog.NormalizeId(itemId)
	if not id then return 0 end
	local total = 0
	for _, raw in pairs(slots) do
		local stack = decodeStack(raw)
		if stack and stack.Id == id then total += stack.Amount end
	end
	return total
end

local function migrateLegacy(player)
	local inv = getInventory(player)
	if inv.MigratedEquipmentSlots ~= true then
		local equipment = ProfileService.GetSection(player, "Equipment", function() return { Equipment = {}, Slots = {} } end)
		if type(equipment.Slots) == "table" then
			for key, raw in pairs(equipment.Slots) do
				if raw ~= nil then
					local stack = decodeStack(raw)
					if stack then addStackToSlots(inv.Slots, INVENTORY_SLOTS, stack) elseif type(raw) == "string" and ItemCatalog.Exists(raw) then addToSlots(inv.Slots, INVENTORY_SLOTS, raw, 1) end
					equipment.Slots[key] = nil
				end
			end
		end
		inv.MigratedEquipmentSlots = true
		ProfileService.MarkDirty(player)
	end
	if inv.MigratedGathering ~= true then
		local gathering = ProfileService.GetSection(player, "Gathering", function() return { Inventory = {} } end)
		if type(gathering.Inventory) == "table" then
			for name, count in pairs(gathering.Inventory) do
				local amount = math.floor(tonumber(count) or 0)
				if amount > 0 then addToSlots(inv.Slots, INVENTORY_SLOTS, ItemCatalog.ResourceId(name, name, 1), amount) end
			end
		end
		inv.MigratedGathering = true
		ProfileService.MarkDirty(player)
	end
	if inv.StarterGranted ~= true then
		addToSlots(inv.Slots, INVENTORY_SLOTS, "T1_Ore", 10, 1)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "T1_Wood", 8, 2)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "T1_Stone", 8, 3)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "T1_Fiber", 6, 4)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "T1_Hide", 6, 5)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "NoviceBag", 1, 6)
		inv.StarterGranted = true
		ProfileService.MarkDirty(player)
	end
	if inv.StarterSwordGranted ~= true then
		addToSlots(inv.Slots, INVENTORY_SLOTS, "TestSword", 1, 7)
		inv.StarterSwordGranted = true
		ProfileService.MarkDirty(player)
	end
	if inv.StarterHorseGranted ~= true then
		local horseId = ItemCatalog.NormalizeId("BrownRidingHorse")
		local equipment = getEquipment(player)
		if horseId and not equipment.Mount then
			equipment.Mount = horseId
		end
		inv.StarterHorseGranted = true
		ProfileService.MarkDirty(player)
	end
	if inv.StarterQualityPurityGranted ~= true then
		addToSlots(inv.Slots, INVENTORY_SLOTS, "MasterpieceQualityBlade", 1, 7)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "RadiantPurityBlade", 1, 8)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "TranscendentPurityBlade", 1, 9)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "AshForgedBroadsword", 1, 10)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "PristineGatherersPack", 1, 11)
		inv.StarterQualityPurityGranted = true
		ProfileService.MarkDirty(player)
	end
	if inv.StarterEAbilitySwordsGranted ~= true then
		addToSlots(inv.Slots, INVENTORY_SLOTS, "StormstepSaber", 1, 12)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "EarthsplitterGreatsword", 1, 13)
		addToSlots(inv.Slots, INVENTORY_SLOTS, "GuardianLongsword", 1, 14)
		inv.StarterEAbilitySwordsGranted = true
		ProfileService.MarkDirty(player)
	end
	inv.DevMaterialGrantVersion = math.max(0, math.floor(tonumber(inv.DevMaterialGrantVersion) or 0))
	if player and player.UserId == DEV_GRANT_USER_ID and inv.DevMaterialGrantVersion < DEV_MATERIAL_GRANT_VERSION then
		for tier = 1, 5 do
			addToSlots(inv.Slots, INVENTORY_SLOTS, "T" .. tostring(tier) .. "_Ore", 999)
			addToSlots(inv.Slots, INVENTORY_SLOTS, "T" .. tostring(tier) .. "_Wood", 999)
			addToSlots(inv.Slots, INVENTORY_SLOTS, "T" .. tostring(tier) .. "_Stone", 999)
			addToSlots(inv.Slots, INVENTORY_SLOTS, "T" .. tostring(tier) .. "_Fiber", 999)
			addToSlots(inv.Slots, INVENTORY_SLOTS, "T" .. tostring(tier) .. "_Hide", 999)
		end
		inv.DevMaterialGrantVersion = DEV_MATERIAL_GRANT_VERSION
		ProfileService.MarkDirty(player)
	end
end

local function stackForClient(raw)
	local stack = decodeStack(raw)
	if not stack then return nil end
	local def = ItemCatalog.Get(stack.Id)
	if not def then return nil end
	local quality = ItemCatalog.NormalizeQuality(stack.Quality or def.Quality or "Normal")
	local purity = ItemCatalog.NormalizePurity(stack.Purity or def.Purity or "None")
	return { Id = stack.Id, Amount = stack.Amount, Quality = quality, Purity = purity, CraftedBy = stack.CraftedBy, DisplayName = def.DisplayName, Type = def.Type, Slot = def.Slot, EquipSlot = def.EquipSlot, Stackable = def.Stackable, MaxStack = def.MaxStack, Weight = def.Weight, Value = def.Value, Icon = def.Icon, Tier = def.Tier, CarryCapacity = def.CarryCapacity, Power = ItemCatalog.ItemPower(stack.Id, quality, purity) }
end

local function slotMapForClient(slots, maxSlots)
	local out = {}
	for i = 1, maxSlots do
		local stack = stackForClient(slots[tostring(i)])
		if stack then out[tostring(i)] = stack end
	end
	return out
end

local function equipmentMapForClient(equipment)
	local out = {}
	for _, slotName in ipairs(EQUIPMENT_SLOT_NAMES) do
		local id = ItemCatalog.NormalizeId(equipment and equipment[slotName])
		local stack = stackForClient(id)
		if stack then out[slotName] = stack end
	end
	return out
end

local function calculateWeight(slots, equipment)
	local total = 0
	local capacity = BASE_CARRY_KG
	for _, raw in pairs(slots) do total += ItemCatalog.StackWeight(decodeStack(raw)) end
	for _, raw in pairs(equipment or {}) do
		local id = ItemCatalog.NormalizeId(raw)
		local def = id and ItemCatalog.Get(id)
		if def then
			total += tonumber(def.Weight) or 0
			capacity += tonumber(def.CarryCapacity) or 0
		end
	end
	return total, capacity, capacity > 0 and (total / capacity) * 100 or 0
end

local function buildMarketSnapshot(player)
	local buys, sells = {}, {}
	for _, order in pairs(marketOrders) do
		local row = { Id = order.Id, Side = order.Side, Price = order.Price, Amount = order.Remaining, PlayerName = order.PlayerName, Mine = player and order.UserId == player.UserId or false }
		if order.Side == "Buy" then table.insert(buys, row) else table.insert(sells, row) end
	end
	table.sort(buys, function(a, b) return a.Price == b.Price and a.Id < b.Id or a.Price > b.Price end)
	table.sort(sells, function(a, b) return a.Price == b.Price and a.Id < b.Id or a.Price < b.Price end)
	return { Buys = buys, Sells = sells }
end

local function buildSnapshot(player)
	migrateLegacy(player)
	local inv = getInventory(player)
	local equipment = getEquipment(player)
	local economy = getEconomy(player)
	local weight, capacity, percent = calculateWeight(inv.Slots, equipment)
	return { Ok = true, Inventory = { Slots = slotMapForClient(inv.Slots, INVENTORY_SLOTS), MaxSlots = INVENTORY_SLOTS }, Equipment = { Slots = equipmentMapForClient(equipment), SlotOrder = EQUIPMENT_SLOT_NAMES }, Weight = { Current = weight, Capacity = capacity, Percent = percent }, Economy = { Coin = economy.Coin, CharredToken = economy.CharredToken }, Market = buildMarketSnapshot(player), ServerTime = os.time() }
end

local function fireSnapshot(player)
	InventoryUpdated:FireClient(player, buildSnapshot(player))
end

local function getBank(player, bankId)
	local inv = getInventory(player)
	bankId = tostring(bankId or "Bank_Player")
	if type(inv.Banks[bankId]) ~= "table" then
		inv.Banks[bankId] = { Version = 1, Tabs = {} }
		ProfileService.MarkDirty(player)
	end
	local bank = inv.Banks[bankId]
	if type(bank.Tabs) ~= "table" then bank.Tabs = {} end
	for tab = 1, BANK_TABS do
		local key = tostring(tab)
		local clean, changed = normalizeSlots(bank.Tabs[key], BANK_SLOTS)
		bank.Tabs[key] = clean
		if changed then ProfileService.MarkDirty(player) end
	end
	return bank
end

local function getBankTab(player, bankId, tab)
	local bank = getBank(player, bankId)
	local tabIndex = math.clamp(math.floor(tonumber(tab) or 1), 1, BANK_TABS)
	return bank.Tabs[tostring(tabIndex)], tabIndex
end

local function hashString(text)
	local hash = 0
	for i = 1, #text do
		hash = (hash * 31 + string.byte(text, i)) % 2147483647
	end
	return hash
end

local CHEST_LOOT_TABLE = {
	{ Id = "T2_Ore", Min = 18, Max = 42, Quality = "Fine", Purity = "Glowing" },
	{ Id = "T2_Wood", Min = 14, Max = 34 },
	{ Id = "T2_Stone", Min = 14, Max = 34 },
	{ Id = "T2_Fiber", Min = 10, Max = 28 },
	{ Id = "T2_Hide", Min = 10, Max = 28 },
	{ Id = "SimpleTokenPouch", Min = 1, Max = 1 },
	{ Id = "AshForgedBroadsword", Min = 1, Max = 1 },
	{ Id = "MasterpieceQualityBlade", Min = 1, Max = 1 },
	{ Id = "RadiantPurityBlade", Min = 1, Max = 1 },
	{ Id = "TranscendentPurityBlade", Min = 1, Max = 1 },
	{ Id = "PristineGatherersPack", Min = 1, Max = 1 },
}

local function seedRandomChest(slots, chestId)
	local rng = Random.new(hashString(chestId))
	local slotIndex = 1
	for _, entry in ipairs(CHEST_LOOT_TABLE) do
		if slotIndex > CHEST_SLOTS then break end
		local includeChance = entry.Min == entry.Max and 0.45 or 0.85
		if rng:NextNumber() <= includeChance then
			local amount = rng:NextInteger(entry.Min, entry.Max)
			addToSlots(slots, CHEST_SLOTS, entry.Id, amount, slotIndex, entry.Quality, entry.Purity)
			slotIndex += 1
		end
	end
end

local function ensureChest(chestId)
	chestId = tostring(chestId or "TreasureChest_Test")
	if not chestCache[chestId] then
		local slots = {}
		if chestId == "TreasureChest_Test" then
			addToSlots(slots, CHEST_SLOTS, "T2_Ore", 30, 1, "Fine", "Glowing")
			addToSlots(slots, CHEST_SLOTS, "T2_Wood", 24, 2)
			addToSlots(slots, CHEST_SLOTS, "T1_Hide", 16, 3)
			addToSlots(slots, CHEST_SLOTS, "SimpleTokenPouch", 1, 4)
			addToSlots(slots, CHEST_SLOTS, "AshForgedBroadsword", 1, 5)
			addToSlots(slots, CHEST_SLOTS, "PristineGatherersPack", 1, 6)
			addToSlots(slots, CHEST_SLOTS, "MasterpieceQualityBlade", 1, 7)
			addToSlots(slots, CHEST_SLOTS, "RadiantPurityBlade", 1, 8)
			addToSlots(slots, CHEST_SLOTS, "TranscendentPurityBlade", 1, 9)
		else
			seedRandomChest(slots, chestId)
		end
		chestCache[chestId] = { Slots = slots }
	end
	return chestCache[chestId]
end

local function storageSlots(player, storageType, storageId, tab)
	if storageType == "Bank" then
		local slots, tabIndex = getBankTab(player, storageId, tab)
		return slots, BANK_SLOTS, tabIndex
	elseif storageType == "Chest" then
		local chest = ensureChest(storageId)
		return chest.Slots, CHEST_SLOTS, 1
	end
	return nil
end

local function buildStorageSnapshot(player, payload)
	local storageType = tostring(payload and payload.StorageType or "")
	local storageId = tostring(payload and payload.StorageId or "")
	local slots, maxSlots, tabIndex = storageSlots(player, storageType, storageId, payload and payload.Tab or 1)
	if not slots then return { Ok = false, Error = "Invalid storage." } end
	return { Ok = true, Storage = { Type = storageType, Id = storageId, Tab = tabIndex, Tabs = storageType == "Bank" and BANK_TABS or 1, Slots = slotMapForClient(slots, maxSlots), MaxSlots = maxSlots, DisplayName = storageType == "Bank" and "Player Bank" or "Treasure Chest" } }
end

local function moveBetweenSlots(fromSlots, fromMax, fromSlot, toSlots, toMax, toSlot)
	local fromKey = slotKey(fromSlot, fromMax)
	local toKey = slotKey(toSlot, toMax)
	if not fromKey or not toKey then return false, "Invalid slot." end
	if fromSlots == toSlots and fromKey == toKey then return true end
	local source = decodeStack(fromSlots[fromKey])
	if not source then return false, "Source slot is empty." end
	local target = decodeStack(toSlots[toKey])
	local def = ItemCatalog.Get(source.Id)
	if target and def and def.Stackable and sameStack(source, target) then
		local maxStack = ItemCatalog.MaxStack(source.Id)
		local moved = math.min(source.Amount, math.max(0, maxStack - target.Amount))
		if moved <= 0 then return false, "Target stack is full." end
		target.Amount += moved
		source.Amount -= moved
		setSlot(toSlots, toKey, target)
		if source.Amount <= 0 then fromSlots[fromKey] = nil else setSlot(fromSlots, fromKey, source) end
	else
		setSlot(toSlots, toKey, source)
		if target then setSlot(fromSlots, fromKey, target) else fromSlots[fromKey] = nil end
	end
	return true
end

local function quickTransfer(fromSlots, fromMax, fromSlot, toSlots, toMax)
	local fromKey = slotKey(fromSlot, fromMax)
	if not fromKey then return false, "Invalid slot." end
	local source = decodeStack(fromSlots[fromKey])
	if not source then return false, "Source slot is empty." end
	local moved = addStackToSlots(toSlots, toMax, source)
	if moved <= 0 then return false, "No space available." end
	source.Amount -= moved
	if source.Amount <= 0 then fromSlots[fromKey] = nil else setSlot(fromSlots, fromKey, source) end
	return true
end

local function storageInstanceDistance(player, info)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local inst = info and info.Instance
	if not root or not inst then return math.huge end
	local part = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
	if not part then return math.huge end
	return (root.Position - part.Position).Magnitude
end

local function validateStorage(player, storageType, storageId)
	local info = activeStorage[player]
	if not info then return false, "Open this storage first." end
	if info.Type ~= storageType or info.Id ~= storageId then return false, "That storage is not open." end
	if storageInstanceDistance(player, info) > STORAGE_DISTANCE then return false, "Too far away." end
	return true
end

local function handleStorageMove(player, action, payload)
	local storageType = tostring(payload.StorageType or "")
	local storageId = tostring(payload.StorageId or "")
	local okAccess, accessErr = validateStorage(player, storageType, storageId)
	if not okAccess then return { Ok = false, Error = accessErr } end
	local inv = getInventory(player)
	local storage, storageMax = storageSlots(player, storageType, storageId, payload.Tab or 1)
	if not storage then return { Ok = false, Error = "Invalid storage." } end
	local ok, err
	if action == "MoveInventoryToStorage" then ok, err = moveBetweenSlots(inv.Slots, INVENTORY_SLOTS, payload.From, storage, storageMax, payload.To)
	elseif action == "MoveStorageToInventory" then ok, err = moveBetweenSlots(storage, storageMax, payload.From, inv.Slots, INVENTORY_SLOTS, payload.To)
	elseif action == "MoveStorage" then ok, err = moveBetweenSlots(storage, storageMax, payload.From, storage, storageMax, payload.To)
	elseif action == "QuickTransfer" then
		if payload.FromType == "Inventory" then ok, err = quickTransfer(inv.Slots, INVENTORY_SLOTS, payload.From, storage, storageMax) else ok, err = quickTransfer(storage, storageMax, payload.From, inv.Slots, INVENTORY_SLOTS) end
	end
	if ok then ProfileService.MarkDirty(player) end
	local snapshot = buildSnapshot(player)
	local storageSnapshot = buildStorageSnapshot(player, payload)
	if ok then fireSnapshot(player) end
	return { Ok = ok == true, Error = err, Snapshot = snapshot, StorageSnapshot = storageSnapshot.Storage }
end

local function deleteInventory(player, payload)
	local inv = getInventory(player)
	local key = slotKey(payload and payload.Slot, INVENTORY_SLOTS)
	if not key or not inv.Slots[key] then return false, "Invalid inventory slot." end
	inv.Slots[key] = nil
	ProfileService.MarkDirty(player)
	return true
end

local function moveInventory(player, payload)
	local inv = getInventory(player)
	local ok, err = moveBetweenSlots(inv.Slots, INVENTORY_SLOTS, payload and payload.From, inv.Slots, INVENTORY_SLOTS, payload and payload.To)
	if ok then ProfileService.MarkDirty(player) end
	return ok, err
end

local function validEquipSlot(slotName)
	slotName = tostring(slotName or "")
	return EQUIPMENT_SLOT_SET[slotName] and slotName or nil
end

local function getValorSkills(player)
	local section = ProfileService.GetSection(player, "Valor", function()
		return { Version = 1, Skills = {} }
	end)
	if type(section.Skills) ~= "table" then
		section.Skills = {}
		ProfileService.MarkDirty(player)
	end
	return section.Skills
end

local function combatLineForItem(itemId, def, equipSlot)
	if not def then return nil end
	if equipSlot == "Weapon" or def.Type == "Weapon" then
		return DestinyBoardConfig.CombatLineForWeapon(def.WeaponType or def.WeaponClass or def.DisplayName or itemId, itemId, def)
	end
	if equipSlot == "Helmet" or equipSlot == "Armor" or equipSlot == "Boots" then
		return DestinyBoardConfig.CombatLineForArmor(equipSlot, itemId, def)
	end
	return nil
end

local function validateTierUnlock(player, itemId, equipSlot)
	local def = ItemCatalog.Get(itemId)
	if not def then return false, "Unknown item." end
	local tier = math.clamp(math.floor(tonumber(def.Tier) or 1), 1, DestinyBoardConfig.MaxTier)
	if tier <= 1 then return true end
	local combatSlot = equipSlot == "Weapon" or equipSlot == "Helmet" or equipSlot == "Armor" or equipSlot == "Boots" or def.Type == "Weapon"
	if not combatSlot then
		return true
	end
	local line = combatLineForItem(itemId, def, equipSlot)
	if tier >= 4 and (not line or not line.MasteryKey) then
		return false, string.format("No Destiny Board combat line exists for T%d %s use yet.", tier, tostring(def.DisplayName or itemId))
	end
	local skills = getValorSkills(player)
	local ok, skillKey, requiredLevel, currentLevel = DestinyBoardConfig.CanUseCombatTier(skills, line, tier)
	if not ok then
		local skill = skillKey and DestinyBoardConfig.Skills[skillKey]
		local name = skill and skill.DisplayName or skillKey or "Destiny Board"
		return false, string.format("Requires %s level %d to equip T%d. Current level: %d.", name, requiredLevel or 0, tier, currentLevel or 0)
	end
	return true
end

local function equipInventory(player, payload)
	local inv = getInventory(player)
	local equipment = getEquipment(player)
	local fromKey = slotKey(payload and payload.From, INVENTORY_SLOTS)
	local equipSlot = validEquipSlot(payload and payload.EquipSlot)
	if not fromKey or not equipSlot then return false, "Invalid equipment slot." end
	local source = decodeStack(inv.Slots[fromKey])
	if not source then return false, "Source slot is empty." end
	if source.Amount ~= 1 then return false, "Only single equipment items can be equipped." end
	if not ItemCatalog.CanEquipTo(source.Id, equipSlot) then return false, "That item cannot be equipped there." end
	local tierOk, tierErr = validateTierUnlock(player, source.Id, equipSlot)
	if not tierOk then return false, tierErr end
	local previousId = ItemCatalog.NormalizeId(equipment[equipSlot])
	equipment[equipSlot] = source.Id
	if previousId then setSlot(inv.Slots, fromKey, { Id = previousId, Amount = 1 }) else inv.Slots[fromKey] = nil end
	ProfileService.MarkDirty(player)
	refreshPlayerStats(player, equipment)
	return true
end

local function quickEquipInventory(player, payload)
	local inv = getInventory(player)
	local fromKey = slotKey(payload and payload.From, INVENTORY_SLOTS)
	if not fromKey then return false, "Invalid inventory slot." end
	local source = decodeStack(inv.Slots[fromKey])
	local def = source and ItemCatalog.Get(source.Id)
	local equipSlot = def and validEquipSlot(def.EquipSlot or def.Slot)
	if not equipSlot and def and type(def.EquipSlots) == "table" then
		for _, candidate in ipairs(def.EquipSlots) do
			equipSlot = validEquipSlot(candidate)
			if equipSlot then break end
		end
	end
	if not equipSlot then return false, "That item cannot be equipped." end
	return equipInventory(player, { From = fromKey, EquipSlot = equipSlot })
end

local function useInventoryItem(player, payload)
	local inv = getInventory(player)
	local key = slotKey(payload and (payload.Slot or payload.From), INVENTORY_SLOTS)
	if not key then return false, "Invalid inventory slot." end
	local source = decodeStack(inv.Slots[key])
	local def = source and ItemCatalog.Get(source.Id)
	if not def then return false, "Source slot is empty." end
	if def.Type ~= "CoinSack" then return false, "That item cannot be used." end
	local amount = math.clamp(math.floor(tonumber(payload and payload.Amount) or source.Amount), 1, source.Amount)
	local payout = math.max(0, math.floor(tonumber(def.Value) or 0)) * amount
	if payout <= 0 then return false, "That coin sack has no value." end
	source.Amount -= amount
	if source.Amount <= 0 then inv.Slots[key] = nil else setSlot(inv.Slots, key, source) end
	local economy = getEconomy(player)
	economy.Coin += payout
	ProfileService.MarkDirty(player)
	return true, nil, payout
end

local function unequipToInventory(player, payload)
	local inv = getInventory(player)
	local equipment = getEquipment(player)
	local equipSlot = validEquipSlot(payload and payload.EquipSlot)
	local toKey = slotKey(payload and payload.To, INVENTORY_SLOTS)
	if not equipSlot or not toKey then return false, "Invalid slot." end
	local equippedId = ItemCatalog.NormalizeId(equipment[equipSlot])
	if not equippedId then return false, "Equipment slot is empty." end
	local target = decodeStack(inv.Slots[toKey])
	if target then
		if target.Amount ~= 1 or not ItemCatalog.CanEquipTo(target.Id, equipSlot) then return false, "Target slot must be empty or hold valid equipment for this slot." end
		local tierOk, tierErr = validateTierUnlock(player, target.Id, equipSlot)
		if not tierOk then return false, tierErr end
		equipment[equipSlot] = target.Id
		setSlot(inv.Slots, toKey, { Id = equippedId, Amount = 1 })
	else
		equipment[equipSlot] = nil
		setSlot(inv.Slots, toKey, { Id = equippedId, Amount = 1 })
	end
	ProfileService.MarkDirty(player)
	refreshPlayerStats(player, equipment)
	return true
end

local function quickTransferEquipment(player, payload)
	local inv = getInventory(player)
	local equipment = getEquipment(player)
	local equipSlot = validEquipSlot(payload and payload.EquipSlot)
	if not equipSlot then return false, "Invalid equipment slot." end
	local equippedId = ItemCatalog.NormalizeId(equipment[equipSlot])
	if not equippedId then return false, "Equipment slot is empty." end
	local moved = addToSlots(inv.Slots, INVENTORY_SLOTS, equippedId, 1)
	if moved <= 0 then return false, "No inventory space available." end
	equipment[equipSlot] = nil
	ProfileService.MarkDirty(player)
	refreshPlayerStats(player, equipment)
	return true
end

local function moveEquipment(player, payload)
	local equipment = getEquipment(player)
	local fromSlot = validEquipSlot(payload and payload.FromSlot)
	local toSlot = validEquipSlot(payload and payload.ToSlot)
	if not fromSlot or not toSlot then return false, "Invalid equipment slot." end
	if fromSlot == toSlot then return true end
	local sourceId = ItemCatalog.NormalizeId(equipment[fromSlot])
	local targetId = ItemCatalog.NormalizeId(equipment[toSlot])
	if not sourceId then return false, "Equipment slot is empty." end
	if not ItemCatalog.CanEquipTo(sourceId, toSlot) then return false, "That item cannot be equipped there." end
	if targetId and not ItemCatalog.CanEquipTo(targetId, fromSlot) then return false, "Those equipment slots cannot be swapped." end
	local sourceTierOk, sourceTierErr = validateTierUnlock(player, sourceId, toSlot)
	if not sourceTierOk then return false, sourceTierErr end
	if targetId then
		local targetTierOk, targetTierErr = validateTierUnlock(player, targetId, fromSlot)
		if not targetTierOk then return false, targetTierErr end
	end
	equipment[toSlot] = sourceId
	equipment[fromSlot] = targetId
	ProfileService.MarkDirty(player)
	refreshPlayerStats(player, equipment)
	return true
end

local function findPlayerByUserId(userId)
	for _, player in ipairs(Players:GetPlayers()) do if player.UserId == userId then return player end end
	return nil
end

local function refundOrder(order)
	local player = findPlayerByUserId(order.UserId)
	if not player then return end
	local economy = getEconomy(player)
	if order.Side == "Buy" then economy.Coin += order.Price * order.Remaining else economy.CharredToken += order.Remaining end
	ProfileService.MarkDirty(player)
	fireSnapshot(player)
end

local function removeOrder(orderId, refund)
	local order = marketOrders[orderId]
	if not order then return end
	if refund then refundOrder(order) end
	marketOrders[orderId] = nil
end

local function matchingOrders(order)
	local list = {}
	for _, other in pairs(marketOrders) do
		if other.UserId ~= order.UserId and other.Remaining > 0 then
			if order.Side == "Buy" and other.Side == "Sell" and other.Price <= order.Price then table.insert(list, other)
			elseif order.Side == "Sell" and other.Side == "Buy" and other.Price >= order.Price then table.insert(list, other) end
		end
	end
	if order.Side == "Buy" then table.sort(list, function(a, b) return a.Price == b.Price and a.Id < b.Id or a.Price < b.Price end)
	else table.sort(list, function(a, b) return a.Price == b.Price and a.Id < b.Id or a.Price > b.Price end) end
	return list
end

local function settleTrade(buyOrder, sellOrder, amount)
	local buyer = findPlayerByUserId(buyOrder.UserId)
	local seller = findPlayerByUserId(sellOrder.UserId)
	if not buyer or not seller then return false end
	local buyerEco = getEconomy(buyer)
	local sellerEco = getEconomy(seller)
	local price = sellOrder.Price
	buyerEco.CharredToken += amount
	buyerEco.Coin += math.max(0, buyOrder.Price - price) * amount
	sellerEco.Coin += price * amount
	buyOrder.Remaining -= amount
	sellOrder.Remaining -= amount
	ProfileService.MarkDirty(buyer)
	ProfileService.MarkDirty(seller)
	fireSnapshot(buyer)
	fireSnapshot(seller)
	return true
end

local function matchOrder(order)
	for _, other in ipairs(matchingOrders(order)) do
		if order.Remaining <= 0 then break end
		local amount = math.min(order.Remaining, other.Remaining)
		local buyOrder = order.Side == "Buy" and order or other
		local sellOrder = order.Side == "Sell" and order or other
		if settleTrade(buyOrder, sellOrder, amount) and other.Remaining <= 0 then marketOrders[other.Id] = nil end
	end
end

local function placeMarketOrder(player, payload)
	local side = tostring(payload.Side or "")
	local amount = math.max(1, math.floor(tonumber(payload.Amount) or 0))
	local price = math.max(1, math.floor(tonumber(payload.Price) or 0))
	if side ~= "Buy" and side ~= "Sell" then return false, "Choose buy or sell." end
	if amount <= 0 or price <= 0 then return false, "Invalid amount or price." end
	local economy = getEconomy(player)
	if side == "Buy" then
		local cost = amount * price
		if economy.Coin < cost then return false, "Not enough Coin." end
		economy.Coin -= cost
	else
		if economy.CharredToken < amount then return false, "Not enough Charred Token." end
		economy.CharredToken -= amount
	end
	local order = { Id = nextOrderId, UserId = player.UserId, PlayerName = player.DisplayName ~= "" and player.DisplayName or player.Name, Side = side, Price = price, Amount = amount, Remaining = amount, CreatedAt = os.time() }
	nextOrderId += 1
	ProfileService.MarkDirty(player)
	matchOrder(order)
	if order.Remaining > 0 then marketOrders[order.Id] = order end
	return true
end

local function cancelMarketOrder(player, payload)
	local orderId = math.floor(tonumber(payload.OrderId) or 0)
	local order = marketOrders[orderId]
	if not order or order.UserId ~= player.UserId then return false, "Order not found." end
	removeOrder(orderId, true)
	return true
end

local function cancelPlayerOrders(player)
	for orderId, order in pairs(marketOrders) do
		if order.UserId == player.UserId then removeOrder(orderId, true) end
	end
end

function InventoryStorageService.AddItem(player, itemId, amount, preferredSlot, quality, purity, craftedBy)
	if not (player and player:IsA("Player")) then return 0, 0 end
	migrateLegacy(player)
	local inv = getInventory(player)
	local added = addToSlots(inv.Slots, INVENTORY_SLOTS, itemId, amount, preferredSlot, quality, purity, craftedBy)
	if added > 0 then
		ProfileService.MarkDirty(player)
		fireSnapshot(player)
	end
	return added, countItem(inv.Slots, itemId)
end

function InventoryStorageService.AddStack(player, stack, preferredSlot)
	if not (player and player:IsA("Player")) or type(stack) ~= "table" then return 0 end
	migrateLegacy(player)
	local inv = getInventory(player)
	local added = addStackToSlots(inv.Slots, INVENTORY_SLOTS, stack, preferredSlot)
	if added > 0 then
		ProfileService.MarkDirty(player)
		fireSnapshot(player)
	end
	return added
end

function InventoryStorageService.RemoveStack(player, payload)
	if not (player and player:IsA("Player")) then return nil, "Invalid player." end
	payload = type(payload) == "table" and payload or {}
	migrateLegacy(player)
	local inv = getInventory(player)
	local key = slotKey(payload.Slot, INVENTORY_SLOTS)
	if not key then return nil, "Invalid inventory slot." end
	local stack = decodeStack(inv.Slots[key])
	if not stack then return nil, "Slot is empty." end
	local itemId = ItemCatalog.NormalizeId(payload.ItemId or payload.Id or stack.Id)
	if itemId ~= stack.Id then return nil, "That slot holds a different item." end
	local quality = ItemCatalog.NormalizeQuality(payload.Quality or stack.Quality)
	local purity = ItemCatalog.NormalizePurity(payload.Purity or stack.Purity)
	if quality ~= ItemCatalog.NormalizeQuality(stack.Quality) or purity ~= ItemCatalog.NormalizePurity(stack.Purity) then
		return nil, "That slot has a different roll."
	end
	local amount = math.max(1, math.floor(tonumber(payload.Amount) or 1))
	if stack.Amount < amount then return nil, "Not enough items in that slot." end
	local removed = { Id = stack.Id, Amount = amount, Quality = stack.Quality, Purity = stack.Purity, CraftedBy = stack.CraftedBy }
	stack.Amount -= amount
	if stack.Amount <= 0 then inv.Slots[key] = nil else setSlot(inv.Slots, key, stack) end
	ProfileService.MarkDirty(player)
	fireSnapshot(player)
	return removed
end

function InventoryStorageService.GetInventoryStacks(player)
	if not (player and player:IsA("Player")) then return {} end
	migrateLegacy(player)
	local inv = getInventory(player)
	local out = {}
	for i = 1, INVENTORY_SLOTS do
		local stack = decodeStack(inv.Slots[tostring(i)])
		local def = stack and ItemCatalog.Get(stack.Id)
		if stack and def then
			table.insert(out, {
				Slot = i,
				Id = stack.Id,
				Amount = stack.Amount,
				Quality = ItemCatalog.NormalizeQuality(stack.Quality),
				Purity = ItemCatalog.NormalizePurity(stack.Purity),
				CraftedBy = stack.CraftedBy,
				DisplayName = def.DisplayName,
				Type = def.Type,
				Tier = def.Tier,
				Value = def.Value,
				Icon = def.Icon,
				Stackable = def.Stackable,
			})
		end
	end
	return out
end

function InventoryStorageService.AddCoin(player, amount)
	if not (player and player:IsA("Player")) then return false end
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then return true end
	local economy = getEconomy(player)
	economy.Coin += amount
	ProfileService.MarkDirty(player)
	fireSnapshot(player)
	return true
end

function InventoryStorageService.RemoveCoin(player, amount)
	if not (player and player:IsA("Player")) then return false, "Invalid player." end
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	local economy = getEconomy(player)
	if economy.Coin < amount then return false, "Not enough Coin." end
	economy.Coin -= amount
	ProfileService.MarkDirty(player)
	fireSnapshot(player)
	return true
end

function InventoryStorageService.GetCoin(player)
	if not (player and player:IsA("Player")) then return 0 end
	return getEconomy(player).Coin
end

function InventoryStorageService.GetWeightSnapshot(player)
	if not (player and player:IsA("Player")) then return { Current = 0, Capacity = BASE_CARRY_KG, Percent = 0 } end
	migrateLegacy(player)
	local weight, capacity, percent = calculateWeight(getInventory(player).Slots, getEquipment(player))
	return { Current = weight, Capacity = capacity, Percent = percent }
end

function InventoryStorageService.ExtractDeathLoot(player)
	if not (player and player:IsA("Player")) then return {} end
	migrateLegacy(player)
	local rng = Random.new(math.floor(os.clock() * 100000) % 2147483647)
	local inv = getInventory(player)
	local loot = {}
	local preservedSlots = {}
	for _, stack in ipairs(InventoryStorageService.GetInventoryStacks(player)) do
		local def = ItemCatalog.Get(stack.Id)
		if def and def.Type == "CoinSack" then
			setSlot(preservedSlots, tostring(stack.Slot), { Id = stack.Id, Amount = stack.Amount, Quality = stack.Quality, Purity = stack.Purity, CraftedBy = stack.CraftedBy })
		else
			local amount = math.max(1, math.floor(tonumber(stack.Amount) or 1))
			local kept = 0
			if amount <= 1 then
				kept = rng:NextNumber() > 0.30 and 1 or 0
			else
				kept = math.max(1, math.floor(amount * 0.80 + 0.5))
			end
			if kept > 0 then
				table.insert(loot, { Id = stack.Id, Amount = kept, Quality = stack.Quality, Purity = stack.Purity, CraftedBy = stack.CraftedBy })
			end
		end
	end
	inv.Slots = preservedSlots
	local equipment, section = getEquipment(player)
	for _, slotName in ipairs(EQUIPMENT_SLOT_NAMES) do
		local itemId = equipment[slotName]
		if itemId and rng:NextNumber() > 0.20 then
			table.insert(loot, { Id = itemId, Amount = 1, Quality = "Normal", Purity = "None" })
		end
		equipment[slotName] = nil
	end
	section.Mount = nil
	ProfileService.MarkDirty(player)
	refreshPlayerStats(player, equipment)
	fireSnapshot(player)
	return loot
end

function InventoryStorageService.ClearInventoryAndEquipment(player)
	if not (player and player:IsA("Player")) then return false end
	migrateLegacy(player)
	local inv = getInventory(player)
	inv.Slots = {}
	local equipment, section = getEquipment(player)
	for _, slotName in ipairs(EQUIPMENT_SLOT_NAMES) do
		equipment[slotName] = nil
	end
	section.Mount = nil
	ProfileService.MarkDirty(player)
	refreshPlayerStats(player, equipment)
	fireSnapshot(player)
	return true
end

function InventoryStorageService.PushSnapshot(player)
	if player and player:IsA("Player") then fireSnapshot(player) end
end

local function normalizeCostItems(rawItems)
	local normalized = {}
	if type(rawItems) ~= "table" then return normalized end
	for key, value in pairs(rawItems) do
		local itemId
		local amount
		if type(value) == "table" then
			itemId = ItemCatalog.NormalizeId(value.Id or value.ItemId or value.Item or key)
			amount = value.Amount or value.Count or value[1]
		else
			itemId = ItemCatalog.NormalizeId(key)
			amount = value
		end
		amount = math.max(0, math.floor(tonumber(amount) or 0))
		if itemId and amount > 0 then
			normalized[itemId] = (normalized[itemId] or 0) + amount
		end
	end
	return normalized
end

local function removeFromSlots(slots, itemId, amount)
	local id = ItemCatalog.NormalizeId(itemId)
	if not id then return 0 end
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	local remaining = amount
	for i = 1, INVENTORY_SLOTS do
		if remaining <= 0 then break end
		local key = tostring(i)
		local stack = decodeStack(slots[key])
		if stack and stack.Id == id then
			local taken = math.min(stack.Amount, remaining)
			stack.Amount -= taken
			remaining -= taken
			if stack.Amount <= 0 then
				slots[key] = nil
			else
				setSlot(slots, key, stack)
			end
		end
	end
	return amount - remaining
end

function InventoryStorageService.CountItem(player, itemId)
	if not (player and player:IsA("Player")) then return 0 end
	migrateLegacy(player)
	return countItem(getInventory(player).Slots, itemId)
end

function InventoryStorageService.SpendCosts(player, costs)
	if not (player and player:IsA("Player")) then return false, "Invalid player." end
	costs = type(costs) == "table" and costs or {}
	migrateLegacy(player)
	local inv = getInventory(player)
	local economy = getEconomy(player)
	local coinCost = math.max(0, math.floor(tonumber(costs.Coin) or 0))
	local itemCosts = normalizeCostItems(costs.Items or costs.Resources or costs)
	itemCosts.Coin = nil
	itemCosts.CharredToken = nil
	if coinCost > 0 and economy.Coin < coinCost then
		return false, "Not enough Coin."
	end
	for itemId, amount in pairs(itemCosts) do
		if countItem(inv.Slots, itemId) < amount then
			local def = ItemCatalog.Get(itemId)
			return false, "Not enough " .. ((def and def.DisplayName) or itemId) .. "."
		end
	end
	if coinCost > 0 then
		economy.Coin -= coinCost
	end
	for itemId, amount in pairs(itemCosts) do
		removeFromSlots(inv.Slots, itemId, amount)
	end
	ProfileService.MarkDirty(player)
	fireSnapshot(player)
	return true
end

local function handleRequest(player, action, payload)
	payload = type(payload) == "table" and payload or {}
	if action == "GetSnapshot" then return buildSnapshot(player)
	elseif action == "MoveInventory" then
		local ok, err = moveInventory(player, payload)
		local snapshot = buildSnapshot(player)
		if ok then fireSnapshot(player) end
		return { Ok = ok == true, Error = err, Snapshot = snapshot }
	elseif action == "EquipInventory" then
		local ok, err = equipInventory(player, payload)
		local snapshot = buildSnapshot(player)
		if ok then fireSnapshot(player) end
		return { Ok = ok == true, Error = err, Snapshot = snapshot }
	elseif action == "QuickEquipInventory" then
		local ok, err = quickEquipInventory(player, payload)
		local snapshot = buildSnapshot(player)
		if ok then fireSnapshot(player) end
		return { Ok = ok == true, Error = err, Snapshot = snapshot }
	elseif action == "UseInventory" then
		local ok, err, payout = useInventoryItem(player, payload)
		local snapshot = buildSnapshot(player)
		if ok then fireSnapshot(player) end
		return { Ok = ok == true, Error = err, Snapshot = snapshot, Payout = payout }
	elseif action == "UnequipToInventory" then
		local ok, err = unequipToInventory(player, payload)
		local snapshot = buildSnapshot(player)
		if ok then fireSnapshot(player) end
		return { Ok = ok == true, Error = err, Snapshot = snapshot }
	elseif action == "QuickTransferEquipment" then
		local ok, err = quickTransferEquipment(player, payload)
		local snapshot = buildSnapshot(player)
		if ok then fireSnapshot(player) end
		return { Ok = ok == true, Error = err, Snapshot = snapshot }
	elseif action == "MoveEquipment" then
		local ok, err = moveEquipment(player, payload)
		local snapshot = buildSnapshot(player)
		if ok then fireSnapshot(player) end
		return { Ok = ok == true, Error = err, Snapshot = snapshot }
	elseif action == "DeleteInventory" then
		local ok, err = deleteInventory(player, payload)
		local snapshot = buildSnapshot(player)
		if ok then fireSnapshot(player) end
		return { Ok = ok == true, Error = err, Snapshot = snapshot }
	elseif action == "GetStorageSnapshot" then
		local okAccess, accessErr = validateStorage(player, tostring(payload.StorageType or ""), tostring(payload.StorageId or ""))
		if not okAccess then return { Ok = false, Error = accessErr } end
		return buildStorageSnapshot(player, payload)
	elseif action == "MoveInventoryToStorage" or action == "MoveStorageToInventory" or action == "MoveStorage" or action == "QuickTransfer" then return handleStorageMove(player, action, payload)
	elseif action == "GetMarket" then return { Ok = true, Market = buildMarketSnapshot(player), Economy = buildSnapshot(player).Economy }
	elseif action == "PlaceMarketOrder" then
		local ok, err = placeMarketOrder(player, payload)
		return { Ok = ok == true, Error = err, Snapshot = buildSnapshot(player), Market = buildMarketSnapshot(player) }
	elseif action == "CancelMarketOrder" then
		local ok, err = cancelMarketOrder(player, payload)
		return { Ok = ok == true, Error = err, Snapshot = buildSnapshot(player), Market = buildMarketSnapshot(player) }
	end
	return { Ok = false, Error = "Unknown inventory action." }
end

local function sanitizeId(value)
	local text = tostring(value or "Storage")
	text = text:gsub("[^%w_%-]", "_")
	return text
end

local function stableStorageId(inst, prefix)
	local attrName = prefix == "Bank" and "BankId" or "ChestId"
	local existing = inst:GetAttribute(attrName) or inst:GetAttribute("StorageId")
	if existing and tostring(existing) ~= "" then return tostring(existing) end
	local pos = inst:GetPivot().Position
	local id = sanitizeId(inst.Name .. "_" .. tostring(math.floor(pos.X * 10)) .. "_" .. tostring(math.floor(pos.Z * 10)))
	inst:SetAttribute(attrName, id)
	inst:SetAttribute("StorageId", id)
	return id
end

local function connectPrompt(inst, storageType, storageId, displayName)
	local part = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
	if not part then return end
	local prompt = part:FindFirstChild("OpenStoragePrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "OpenStoragePrompt"
		prompt.ObjectText = displayName
		prompt.ActionText = "Open"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 5
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
	if prompt:GetAttribute("InventoryBound") then return end
	prompt:SetAttribute("InventoryBound", true)
	prompt.Triggered:Connect(function(player)
		activeStorage[player] = { Type = storageType, Id = storageId, Instance = inst }
		OpenStorage:FireClient(player, { StorageType = storageType, StorageId = storageId, DisplayName = displayName, Tab = 1 })
	end)
end

local function ensureSamplePart(folder, name, storageType, position, color)
	local part = folder:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = storageType == "Bank" and Vector3.new(5, 4, 2) or Vector3.new(4, 2, 3)
		part.Position = position
		part.Color = color
		part.Material = Enum.Material.WoodPlanks
		part.Parent = folder
	end
	return part
end

local function storageDisplayName(storageType)
	return storageType == "Bank" and "Player Bank" or "Treasure Chest"
end

local function tryBindStorage(inst)
	if not (inst and (inst:IsA("BasePart") or inst:IsA("Model"))) then return end
	local name = inst.Name:lower()
	if inst:GetAttribute("LootChest") == true or name:find("treasurechesttype", 1, true) then return end
	local storageType = inst:GetAttribute("StorageType")
	if not storageType then
		if name:find("bank") then storageType = "Bank" elseif name:find("chest") then storageType = "Chest" end
	end
	if storageType == "Bank" or storageType == "Chest" then
		local id = stableStorageId(inst, storageType)
		inst:SetAttribute("StorageType", storageType)
		connectPrompt(inst, storageType, id, storageDisplayName(storageType))
	end
end

local function setupInteractables()
	local folder = Workspace:FindFirstChild("InventoryInteractables")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "InventoryInteractables"
		folder.Parent = Workspace
	end
	ensureSamplePart(folder, "Bank_Player", "Bank", Vector3.new(8, 2, -8), Color3.fromRGB(58, 42, 30))
	ensureSamplePart(folder, "TreasureChest_Test", "Chest", Vector3.new(15, 1.2, -8), Color3.fromRGB(84, 48, 22))
	for _, inst in ipairs(Workspace:GetDescendants()) do
		tryBindStorage(inst)
	end
	Workspace.DescendantAdded:Connect(function(inst)
		task.defer(function()
			tryBindStorage(inst)
		end)
	end)
end

function InventoryStorageService.CreateStoragePart(storageType, position, storageId)
	storageType = storageType == "Bank" and "Bank" or "Chest"
	local folder = Workspace:FindFirstChild("InventoryInteractables")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "InventoryInteractables"
		folder.Parent = Workspace
	end
	local baseName = storageType == "Bank" and "Bank_Player" or "TreasureChest_Random"
	local part = ensureSamplePart(folder, baseName .. "_" .. sanitizeId(storageId or tostring(os.time())), storageType, position or Vector3.new(15, 1.2, -8), storageType == "Bank" and Color3.fromRGB(58, 42, 30) or Color3.fromRGB(84, 48, 22))
	part:SetAttribute("StorageType", storageType)
	if storageType == "Bank" then part:SetAttribute("BankId", storageId or stableStorageId(part, storageType)) else part:SetAttribute("ChestId", storageId or stableStorageId(part, storageType)) end
	tryBindStorage(part)
	return part
end

function InventoryStorageService.Start()
	if started then return end
	started = true
	InventoryRequest.OnServerInvoke = handleRequest
	setupInteractables()
	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			migrateLegacy(player)
			getEconomy(player)
			fireSnapshot(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		cancelPlayerOrders(player)
		activeStorage[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(function()
			migrateLegacy(player)
			getEconomy(player)
			fireSnapshot(player)
		end)
	end
end

return InventoryStorageService
