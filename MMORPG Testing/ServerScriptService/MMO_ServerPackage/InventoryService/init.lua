--[[
Name: InventoryService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.InventoryService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, ServerScriptService
Requires:
  - local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
  - local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
Functions: ensureRemote, cleanupRemovedSystems, defaultInventory, slotKey, encodeStack, decodeStack, setSlot, normalizeSlots, getInventory, addToSlots, place, countItem, migrateLegacy, stackForClient, slotMapForClient, calculateWeight, buildSnapshot, fireSnapshot, moveInventory, handleRequest, InventoryService.AddItem, InventoryService.Start
Signal classes referenced: RemoteFunction, RemoteEvent
Clean source lines: 371
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))

local InventoryService = {}

local INVENTORY_SLOTS = 40
local BASE_CARRY_KG = 50
local started = false

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
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remoteFolder
	return remote
end

local InventoryRequest = ensureRemote("RemoteFunction", "InventoryRequest")
local InventoryUpdated = ensureRemote("RemoteEvent", "InventoryUpdated")

local function cleanupRemovedSystems()
	local openStorage = remoteFolder:FindFirstChild("OpenStorage")
	if openStorage then openStorage:Destroy() end
	local generated = workspace:FindFirstChild("InventoryInteractables")
	if generated then generated:Destroy() end
end

local function defaultInventory()
	return {
		Version = 3,
		Slots = {},
		StarterGranted = false,
		MigratedEquipmentSlots = false,
		MigratedGathering = false,
	}
end

local function slotKey(slot)
	local n = math.floor(tonumber(slot) or 0)
	if n < 1 or n > INVENTORY_SLOTS then return nil end
	return tostring(n), n
end

local function encodeStack(stack)
	if type(stack) ~= "table" then return nil end
	local id = ItemCatalog.NormalizeId(stack.Id or stack.id)
	if not id then return nil end
	local amount = math.max(1, math.floor(tonumber(stack.Amount or stack.amount) or 1))
	local quality = tostring(stack.Quality or stack.quality or "Normal")
	local purity = tostring(stack.Purity or stack.purity or "None")
	if quality == "Normal" and purity == "None" then
		return table.concat({ id, tostring(amount) }, "|")
	end
	return table.concat({ id, tostring(amount), quality, purity }, "|")
end

local function decodeStack(raw)
	if raw == nil then return nil end
	if type(raw) == "table" then
		local id = ItemCatalog.NormalizeId(raw.Id or raw.id or raw.ItemId or raw.itemId or raw[1])
		if not id then return nil end
		return {
			Id = id,
			Amount = math.max(1, math.floor(tonumber(raw.Amount or raw.amount or raw.Count or raw.count or raw[2]) or 1)),
			Quality = raw.Quality or raw.quality or "Normal",
			Purity = raw.Purity or raw.purity or "None",
		}
	end
	if type(raw) ~= "string" then return nil end
	local parts = string.split(raw, "|")
	local id = ItemCatalog.NormalizeId(parts[1])
	if not id then return nil end
	return {
		Id = id,
		Amount = math.max(1, math.floor(tonumber(parts[2]) or 1)),
		Quality = parts[3] ~= "" and parts[3] or "Normal",
		Purity = parts[4] ~= "" and parts[4] or "None",
	}
end

local function setSlot(slots, key, stack)
	slots[key] = encodeStack(stack)
end

local function normalizeSlots(slots)
	local changed = false
	local clean = {}
	if type(slots) ~= "table" then return clean, true end
	for key, value in pairs(slots) do
		local cleanKey = slotKey(key)
		if not cleanKey and type(key) == "string" then
			cleanKey = slotKey(key:match("slot(%d+)"))
		end
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
	if type(inv.Slots) ~= "table" then
		inv.Slots = {}
		ProfileService.MarkDirty(player)
	end
	local clean, changed = normalizeSlots(inv.Slots)
	if changed then
		inv.Slots = clean
		ProfileService.MarkDirty(player)
	end
	return inv
end

local function addToSlots(slots, itemId, amount, preferredSlot, quality, purity)
	local id = ItemCatalog.NormalizeId(itemId)
	if not id then return 0 end
	amount = math.max(1, math.floor(tonumber(amount) or 1))
	local remaining = amount
	local def = ItemCatalog.Get(id)
	local stackable = def and def.Stackable == true
	local maxStack = ItemCatalog.MaxStack(id)
	quality = quality or (def and def.Quality) or "Normal"
	purity = purity or (def and def.Purity) or "None"

	if stackable then
		for i = 1, INVENTORY_SLOTS do
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
		setSlot(slots, key, { Id = id, Amount = added, Quality = quality, Purity = purity })
		remaining -= added
	end

	place(slotKey(preferredSlot))
	for i = 1, INVENTORY_SLOTS do
		if remaining <= 0 then break end
		place(tostring(i))
	end
	return amount - remaining
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
					if stack then
						addToSlots(inv.Slots, stack.Id, stack.Amount, nil, stack.Quality, stack.Purity)
					elseif type(raw) == "string" and ItemCatalog.Exists(raw) then
						addToSlots(inv.Slots, raw, 1)
					end
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
				if amount > 0 then
					addToSlots(inv.Slots, ItemCatalog.ResourceId(name, name, 1), amount)
				end
			end
		end
		inv.MigratedGathering = true
		ProfileService.MarkDirty(player)
	end

	if inv.StarterGranted ~= true then
		addToSlots(inv.Slots, "T1_Ore", 10, 1)
		addToSlots(inv.Slots, "T1_Wood", 8, 2)
		addToSlots(inv.Slots, "T1_Stone", 8, 3)
		addToSlots(inv.Slots, "T1_Fiber", 6, 4)
		addToSlots(inv.Slots, "T1_Hide", 6, 5)
		addToSlots(inv.Slots, "NoviceBag", 1, 6)
		inv.StarterGranted = true
		ProfileService.MarkDirty(player)
	end
end

local function stackForClient(raw)
	local stack = decodeStack(raw)
	if not stack then return nil end
	local def = ItemCatalog.Get(stack.Id)
	if not def then return nil end
	return {
		Id = stack.Id,
		Amount = stack.Amount,
		Quality = stack.Quality or "Normal",
		Purity = stack.Purity or "None",
		DisplayName = def.DisplayName,
		Type = def.Type,
		Slot = def.Slot,
		Stackable = def.Stackable,
		MaxStack = def.MaxStack,
		Weight = def.Weight,
		Value = def.Value,
		Icon = def.Icon,
		Tier = def.Tier,
	}
end

local function slotMapForClient(slots)
	local out = {}
	for i = 1, INVENTORY_SLOTS do
		local stack = stackForClient(slots[tostring(i)])
		if stack then out[tostring(i)] = stack end
	end
	return out
end

local function calculateWeight(slots)
	local total = 0
	for _, raw in pairs(slots) do
		total += ItemCatalog.StackWeight(decodeStack(raw))
	end
	return total, BASE_CARRY_KG, (total / BASE_CARRY_KG) * 100
end

local function buildSnapshot(player)
	migrateLegacy(player)
	local inv = getInventory(player)
	local weight, capacity, percent = calculateWeight(inv.Slots)
	return {
		Ok = true,
		Inventory = {
			Slots = slotMapForClient(inv.Slots),
			MaxSlots = INVENTORY_SLOTS,
		},
		Weight = {
			Current = weight,
			Capacity = capacity,
			Percent = percent,
		},
		ServerTime = os.time(),
	}
end

local function fireSnapshot(player)
	InventoryUpdated:FireClient(player, buildSnapshot(player))
end

local function moveInventory(player, payload)
	local fromKey = slotKey(payload and payload.From)
	local toKey = slotKey(payload and payload.To)
	if not fromKey or not toKey then return false, "Invalid inventory slot." end
	if fromKey == toKey then return true end
	local inv = getInventory(player)
	local source = decodeStack(inv.Slots[fromKey])
	if not source then return false, "Source slot is empty." end
	local target = decodeStack(inv.Slots[toKey])
	local def = ItemCatalog.Get(source.Id)

	if target and def and def.Stackable and source.Id == target.Id and (source.Quality or "Normal") == (target.Quality or "Normal") and (source.Purity or "None") == (target.Purity or "None") then
		local maxStack = ItemCatalog.MaxStack(source.Id)
		local moved = math.min(source.Amount, math.max(0, maxStack - target.Amount))
		if moved <= 0 then return false, "Target stack is full." end
		target.Amount += moved
		source.Amount -= moved
		setSlot(inv.Slots, toKey, target)
		if source.Amount <= 0 then inv.Slots[fromKey] = nil else setSlot(inv.Slots, fromKey, source) end
	else
		setSlot(inv.Slots, toKey, source)
		if target then setSlot(inv.Slots, fromKey, target) else inv.Slots[fromKey] = nil end
	end
	ProfileService.MarkDirty(player)
	return true
end

function InventoryService.AddItem(player, itemId, amount, preferredSlot)
	if not (player and player:IsA("Player")) then return 0, 0 end
	migrateLegacy(player)
	local inv = getInventory(player)
	local added = addToSlots(inv.Slots, itemId, amount, preferredSlot)
	if added > 0 then
		ProfileService.MarkDirty(player)
		fireSnapshot(player)
	end
	return added, countItem(inv.Slots, itemId)
end

local function handleRequest(player, action, payload)
	payload = type(payload) == "table" and payload or {}
	if action == "GetSnapshot" then
		return buildSnapshot(player)
	elseif action == "MoveInventory" then
		local ok, err = moveInventory(player, payload)
		local snapshot = buildSnapshot(player)
		if ok then fireSnapshot(player) end
		return { Ok = ok, Error = err, Snapshot = snapshot }
	end
	return { Ok = false, Error = "Inventory-only mode is active." }
end

function InventoryService.Start()
	if started then return end
	started = true
	cleanupRemovedSystems()
	InventoryRequest.OnServerInvoke = handleRequest
	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			migrateLegacy(player)
			fireSnapshot(player)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(function()
			migrateLegacy(player)
			fireSnapshot(player)
		end)
	end
end

return InventoryService
