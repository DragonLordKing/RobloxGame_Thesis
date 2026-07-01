--[[
Name: EconomyMarketService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.EconomyMarketService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, ServerScriptService, ServerStorage, Workspace, TweenService, DataStoreService, HttpService
Requires:
  - local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
  - local InventoryService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("InventoryStorageService"))
  - local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
  - local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("MarketEconomyConfig"))
  - local SmartChestService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("WorldRuntime"):WaitForChild("SmartChestService"))
  - return require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
Functions: ensureRemote, defaultClaims, getClaims, playerName, now, markHouseDirty, markBlackMarketDirty, markPendingClaimsDirty, dataKey, copyStack, stackKey, rowForStack, hasCatalogTag, marketItemAllowed, blackMarketItemAllowed, feeAmount, setupFeeFor, marketplaceTaxFor, applyMarketplaceTax, seedBlackMarketForTesting, chestItemAllowed, orderToData, orderFromData, ordersToData, ordersFromData, historyToData, historyFromData, stockToData, stockFromData, demandFromData, defaultHouse, serializeHouse, deserializeHouse, loadHouse, getHouse, serializeBlackMarket, deserializeBlackMarket, loadBlackMarket, defaultPendingClaims, serializePendingClaims, deserializePendingClaims, getPendingClaims, findPlayerByUserId, addHistory, averagePrice, historyStats, baseItemValue, weightedPick, addClaimItem, deliverStack, queueOfflineCoin, queueOfflineItem, creditCoinByUserId, deliverStackByUserId, applyPendingClaims, claimRows, claimItem, claimCoin, orderRow, sortedRows
Signal classes referenced: RemoteFunction, RemoteEvent, BindableEvent
Clean source lines: 1906
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ProfileService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
local InventoryService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("InventoryStorageService"))
local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("MarketEconomyConfig"))
local SmartChestService = require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("WorldRuntime"):WaitForChild("SmartChestService"))
local EconomyStore = DataStoreService:GetDataStore(Config.EconomyDataStoreName or "MMO_EconomyMarket_V1")

local EconomyMarketService = {}
local started = false

local remoteFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
end

local function ensureRemote(className, name)
	local remote = remoteFolder:FindFirstChild(name)
	if remote and remote.ClassName == className then return remote end
	if remote then remote:Destroy() end
	remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remoteFolder
	return remote
end

local MarketRequest = ensureRemote("RemoteFunction", "EconomyMarketRequest")
local OpenMarketInterface = ensureRemote("RemoteEvent", "OpenMarketInterface")
local MarketNotice = ensureRemote("RemoteEvent", "MarketNotice")

local bindableFolder = ServerStorage:WaitForChild("MMO_ServerStoragePackage"):FindFirstChild("BindableEvents")
if not bindableFolder then
	bindableFolder = Instance.new("Folder")
	bindableFolder.Name = "BindableEvents"
	bindableFolder.Parent = ServerStorage:WaitForChild("MMO_ServerStoragePackage")
end

local CityTaxDepositBindable = bindableFolder:FindFirstChild("CityTaxDeposit")
if not CityTaxDepositBindable then
	CityTaxDepositBindable = Instance.new("BindableEvent")
	CityTaxDepositBindable.Name = "CityTaxDeposit"
	CityTaxDepositBindable.Parent = bindableFolder
end

local SETUP_FEE_RATE = 0.03
local MARKETPLACE_TAX_RATE = 0.10
local CITY_TAX_SHARE_RATE = 0.05

local auctionHouses = {}
local blackMarket = { SellOrders = {}, Stock = {}, BuyDemand = {}, History = {}, SeedVersion = 0 }
local loadedAuctionHouses = {}
local dirtyAuctionHouses = {}
local blackMarketLoaded = false
local blackMarketDirty = false
local pendingClaims = {}
local loadedPendingClaims = {}
local dirtyPendingClaims = {}
local activeMarket = {}
local activeChestCooldown = {}
local activeChestOpening = {}
local activeChestLoot = {}
local savingMarkets = false
local nextOrderId = 1
local nextTradeId = 1

local function defaultClaims()
	return { Version = 1, NextId = 1, Items = {}, Coin = 0 }
end

local function getClaims(player)
	local claims = ProfileService.GetSection(player, "MarketClaims", defaultClaims)
	claims.Version = 1
	claims.NextId = math.max(1, math.floor(tonumber(claims.NextId) or 1))
	if type(claims.Items) ~= "table" then claims.Items = {} end
	claims.Coin = math.max(0, math.floor(tonumber(claims.Coin) or 0))
	return claims
end

local function playerName(player)
	return player and ((player.DisplayName ~= "" and player.DisplayName) or player.Name) or "Player"
end

local function now()
	return os.time()
end

local function markHouseDirty(houseId)
	dirtyAuctionHouses[tostring(houseId or "GlobalAuction")] = true
end

local function markBlackMarketDirty()
	blackMarketDirty = true
end

local function markPendingClaimsDirty(userId)
	dirtyPendingClaims[tostring(userId)] = true
end

local function dataKey(prefix, id)
	return string.format("%s_%s", prefix, tostring(id or "Global"):gsub("[^%w_%-]", "_"))
end

local function copyStack(stack, amount)
	return {
		Id = ItemCatalog.NormalizeId(stack.Id or stack.id),
		Amount = math.max(1, math.floor(tonumber(amount or stack.Amount or stack.amount) or 1)),
		Quality = ItemCatalog.NormalizeQuality(stack.Quality or stack.quality or "Normal"),
		Purity = ItemCatalog.NormalizePurity(stack.Purity or stack.purity or "None"),
		CraftedBy = stack.CraftedBy or stack.craftedBy,
	}
end

local function stackKey(stackOrId, quality, purity)
	if type(stackOrId) == "table" then
		return table.concat({ stackOrId.Id, ItemCatalog.NormalizeQuality(stackOrId.Quality), ItemCatalog.NormalizePurity(stackOrId.Purity) }, "|")
	end
	return table.concat({ tostring(stackOrId), ItemCatalog.NormalizeQuality(quality), ItemCatalog.NormalizePurity(purity) }, "|")
end

local function rowForStack(stack)
	local def = ItemCatalog.Get(stack.Id)
	return {
		Id = stack.Id,
		Amount = stack.Amount,
		Quality = ItemCatalog.NormalizeQuality(stack.Quality),
		Purity = ItemCatalog.NormalizePurity(stack.Purity),
		CraftedBy = stack.CraftedBy,
		DisplayName = def and def.DisplayName or stack.Id,
		Type = def and def.Type or "Item",
		Tier = def and def.Tier or 1,
		Icon = def and def.Icon or "Default",
		Value = def and def.Value or 0,
		Power = ItemCatalog.ItemPower(stack.Id, stack.Quality, stack.Purity),
	}
end

local function hasCatalogTag(def, tag)
	if not def then return false end
	if def[tag] == true then return true end
	local tags = def.Tags or def.tags
	if type(tags) == "table" then
		for key, value in pairs(tags) do
			if key == tag and value == true then return true end
			if value == tag then return true end
		end
	end
	return false
end

local function marketItemAllowed(id)
	local def = ItemCatalog.Get(id)
	if not def then return false end
	if def.Type == "CoinSack" then return false end
	if hasCatalogTag(def, "NotAuctionable") then return false end
	return true
end

local function blackMarketItemAllowed(id)
	local def = ItemCatalog.Get(id)
	if not def or not marketItemAllowed(id) then return false end
	return def.Type == "Weapon" or def.Type == "Armor"
end

local function feeAmount(total, rate)
	total = math.max(0, math.floor(tonumber(total) or 0))
	if total <= 0 then return 0 end
	return math.max(1, math.floor(total * rate + 0.5))
end

local function setupFeeFor(total)
	return feeAmount(total, SETUP_FEE_RATE)
end

local function marketplaceTaxFor(total)
	return feeAmount(total, MARKETPLACE_TAX_RATE)
end

local function applyMarketplaceTax(total, source)
	local gross = math.max(0, math.floor(tonumber(total) or 0))
	local tax = math.min(gross, marketplaceTaxFor(gross))
	local cityShare = math.min(tax, feeAmount(tax, CITY_TAX_SHARE_RATE))
	if cityShare > 0 then
		CityTaxDepositBindable:Fire(cityShare, source or {})
	end
	return gross - tax, tax, cityShare
end

local function seedBlackMarketForTesting()
	local seedVersion = math.max(0, math.floor(tonumber(blackMarket.SeedVersion) or 0))
	local targetVersion = math.max(0, math.floor(tonumber(Config.BlackMarketSeedVersion) or 0))
	if targetVersion <= 0 or seedVersion >= targetVersion then return end
	local copies = math.max(1, math.floor(tonumber(Config.BlackMarketSeedCopiesPerItem) or 2))
	local seeded = 0
	local ids = {}
	for id, def in pairs(ItemCatalog.Items) do
		local tier = math.clamp(math.floor(tonumber(def.Tier) or 1), 1, 20)
		if (tier == 1 or tier == 2) and blackMarketItemAllowed(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local key = stackKey(id, "Normal", "None")
		blackMarket.Stock[key] = blackMarket.Stock[key] or {}
		table.insert(blackMarket.Stock[key], { Id = id, Amount = copies, Quality = "Normal", Purity = "None", CraftedBy = "Testing" })
		seeded += copies
	end
	blackMarket.SeedVersion = targetVersion
	if seeded > 0 then markBlackMarketDirty() end
end

local function chestItemAllowed(id)
	return blackMarketItemAllowed(id)
end

local function orderToData(order)
	return {
		Id = tonumber(order.Id),
		UserId = tonumber(order.UserId),
		PlayerName = tostring(order.PlayerName or "Player"),
		Side = tostring(order.Side or "Sell"),
		Stack = copyStack(order.Stack or {}),
		Price = math.max(1, math.floor(tonumber(order.Price) or 1)),
		Remaining = math.max(0, math.floor(tonumber(order.Remaining) or 0)),
		CreatedAt = math.max(0, math.floor(tonumber(order.CreatedAt) or now())),
	}
end

local function orderFromData(raw)
	if type(raw) ~= "table" then return nil end
	local stack = type(raw.Stack) == "table" and copyStack(raw.Stack) or nil
	if not stack or not ItemCatalog.Get(stack.Id) then return nil end
	local id = math.floor(tonumber(raw.Id) or 0)
	if id <= 0 then return nil end
	local order = {
		Id = id,
		UserId = math.floor(tonumber(raw.UserId) or 0),
		PlayerName = tostring(raw.PlayerName or "Player"),
		Side = tostring(raw.Side or "Sell"),
		Stack = stack,
		Price = math.max(1, math.floor(tonumber(raw.Price) or 1)),
		Remaining = math.max(0, math.floor(tonumber(raw.Remaining) or stack.Amount)),
		CreatedAt = math.max(0, math.floor(tonumber(raw.CreatedAt) or now())),
	}
	nextOrderId = math.max(nextOrderId, order.Id + 1)
	return order
end

local function ordersToData(orders)
	local out = {}
	for _, order in pairs(orders or {}) do
		if order and (tonumber(order.Remaining) or 0) > 0 then
			table.insert(out, orderToData(order))
		end
	end
	table.sort(out, function(a, b) return (a.Id or 0) < (b.Id or 0) end)
	return out
end

local function ordersFromData(raw)
	local out = {}
	for _, entry in pairs(raw or {}) do
		local order = orderFromData(entry)
		if order and order.Remaining > 0 then out[order.Id] = order end
	end
	return out
end

local function historyToData(history)
	local out = {}
	local first = math.max(1, #history - 999)
	for i = first, #history do
		local entry = history[i]
		if type(entry) == "table" then
			table.insert(out, {
				Id = math.floor(tonumber(entry.Id) or 0),
				Market = tostring(entry.Market or "Market"),
				ItemId = tostring(entry.ItemId or ""),
				Quality = ItemCatalog.NormalizeQuality(entry.Quality),
				Purity = ItemCatalog.NormalizePurity(entry.Purity),
				Price = math.max(1, math.floor(tonumber(entry.Price) or 1)),
				Amount = math.max(1, math.floor(tonumber(entry.Amount) or 1)),
				Time = math.max(0, math.floor(tonumber(entry.Time) or now())),
			})
		end
	end
	return out
end

local function historyFromData(raw)
	local out = {}
	for _, entry in pairs(raw or {}) do
		if type(entry) == "table" and ItemCatalog.Get(entry.ItemId) then
			local clean = {
				Id = math.floor(tonumber(entry.Id) or 0),
				Market = tostring(entry.Market or "Market"),
				ItemId = ItemCatalog.NormalizeId(entry.ItemId),
				Quality = ItemCatalog.NormalizeQuality(entry.Quality),
				Purity = ItemCatalog.NormalizePurity(entry.Purity),
				Price = math.max(1, math.floor(tonumber(entry.Price) or 1)),
				Amount = math.max(1, math.floor(tonumber(entry.Amount) or 1)),
				Time = math.max(0, math.floor(tonumber(entry.Time) or now())),
			}
			nextTradeId = math.max(nextTradeId, clean.Id + 1)
			table.insert(out, clean)
		end
	end
	table.sort(out, function(a, b) return (a.Id or 0) < (b.Id or 0) end)
	return out
end

local function stockToData(stock)
	local out = {}
	for key, stacks in pairs(stock or {}) do
		local list = {}
		for _, stack in ipairs(stacks or {}) do
			if type(stack) == "table" and (tonumber(stack.Amount) or 0) > 0 and ItemCatalog.Get(stack.Id) then
				table.insert(list, copyStack(stack))
			end
		end
		if #list > 0 then out[key] = list end
	end
	return out
end

local function stockFromData(raw)
	local out = {}
	for _, stacks in pairs(raw or {}) do
		for _, stack in ipairs(stacks or {}) do
			if type(stack) == "table" and (tonumber(stack.Amount) or 0) > 0 and ItemCatalog.Get(stack.Id) then
				local clean = copyStack(stack)
				local key = stackKey(clean)
				out[key] = out[key] or {}
				table.insert(out[key], clean)
			end
		end
	end
	return out
end

local function demandFromData(raw)
	local out = {}
	for key, price in pairs(raw or {}) do
		local itemId, quality, purity = string.match(tostring(key), "^([^|]+)|([^|]+)|(.+)$")
		local id = ItemCatalog.NormalizeId(itemId)
		if id and ItemCatalog.Get(id) then
			out[stackKey(id, quality, purity)] = math.max(1, math.floor(tonumber(price) or 1))
		end
	end
	return out
end

local function defaultHouse()
	return { Version = 1, SellOrders = {}, BuyOrders = {}, History = {} }
end

local function serializeHouse(houseId, house)
	return {
		Version = 1,
		HouseId = tostring(houseId or "GlobalAuction"),
		NextOrderId = nextOrderId,
		SellOrders = ordersToData(house and house.SellOrders),
		BuyOrders = ordersToData(house and house.BuyOrders),
		History = historyToData(house and house.History or {}),
		SavedAt = now(),
	}
end

local function deserializeHouse(data)
	if type(data) ~= "table" then return defaultHouse() end
	nextOrderId = math.max(nextOrderId, math.floor(tonumber(data.NextOrderId) or 1))
	return {
		Version = 1,
		SellOrders = ordersFromData(data.SellOrders),
		BuyOrders = ordersFromData(data.BuyOrders),
		History = historyFromData(data.History),
	}
end

local function loadHouse(houseId)
	houseId = tostring(houseId or "GlobalAuction")
	if loadedAuctionHouses[houseId] then return end
	loadedAuctionHouses[houseId] = true
	local ok, data = pcall(function()
		return EconomyStore:GetAsync(dataKey("AuctionHouse_v1", houseId))
	end)
	if ok and type(data) == "table" then
		auctionHouses[houseId] = deserializeHouse(data)
	elseif not auctionHouses[houseId] then
		auctionHouses[houseId] = defaultHouse()
	end
	if not ok then warn("Auction house load failed for " .. houseId .. ": " .. tostring(data)) end
end

local function getHouse(houseId)
	houseId = tostring(houseId or "GlobalAuction")
	loadHouse(houseId)
	auctionHouses[houseId] = auctionHouses[houseId] or defaultHouse()
	return auctionHouses[houseId], houseId
end

local function serializeBlackMarket()
	return {
		Version = 1,
		NextOrderId = nextOrderId,
		NextTradeId = nextTradeId,
		SeedVersion = math.max(0, math.floor(tonumber(blackMarket.SeedVersion) or 0)),
		SellOrders = ordersToData(blackMarket.SellOrders),
		Stock = stockToData(blackMarket.Stock),
		BuyDemand = blackMarket.BuyDemand or {},
		History = historyToData(blackMarket.History or {}),
		SavedAt = now(),
	}
end

local function deserializeBlackMarket(data)
	if type(data) ~= "table" then return end
	nextOrderId = math.max(nextOrderId, math.floor(tonumber(data.NextOrderId) or 1))
	nextTradeId = math.max(nextTradeId, math.floor(tonumber(data.NextTradeId) or 1))
	blackMarket = {
		SellOrders = ordersFromData(data.SellOrders),
		Stock = stockFromData(data.Stock),
		BuyDemand = demandFromData(data.BuyDemand),
		History = historyFromData(data.History),
		SeedVersion = math.max(0, math.floor(tonumber(data.SeedVersion) or 0)),
	}
end

local function loadBlackMarket()
	if blackMarketLoaded then return end
	blackMarketLoaded = true
	local ok, data = pcall(function()
		return EconomyStore:GetAsync("BlackMarket_v1")
	end)
	if ok and type(data) == "table" then
		deserializeBlackMarket(data)
	elseif not ok then
		warn("Black market load failed: " .. tostring(data))
	end
	blackMarket.SellOrders = blackMarket.SellOrders or {}
	blackMarket.Stock = blackMarket.Stock or {}
	blackMarket.BuyDemand = blackMarket.BuyDemand or {}
	blackMarket.History = blackMarket.History or {}
	blackMarket.SeedVersion = math.max(0, math.floor(tonumber(blackMarket.SeedVersion) or 0))
end

local function defaultPendingClaims()
	return { Version = 1, Items = {}, Coin = 0 }
end

local function serializePendingClaims(claims)
	local out = defaultPendingClaims()
	out.Coin = math.max(0, math.floor(tonumber(claims and claims.Coin) or 0))
	for _, stack in ipairs(claims and claims.Items or {}) do
		if type(stack) == "table" and ItemCatalog.Get(stack.Id) then
			table.insert(out.Items, {
				Id = stack.Id,
				Amount = math.max(1, math.floor(tonumber(stack.Amount) or 1)),
				Quality = ItemCatalog.NormalizeQuality(stack.Quality),
				Purity = ItemCatalog.NormalizePurity(stack.Purity),
				CraftedBy = stack.CraftedBy,
				Source = stack.Source or "Market",
				Time = math.max(0, math.floor(tonumber(stack.Time) or now())),
			})
		end
	end
	return out
end

local function deserializePendingClaims(data)
	local out = defaultPendingClaims()
	if type(data) ~= "table" then return out end
	out.Coin = math.max(0, math.floor(tonumber(data.Coin) or 0))
	for _, stack in ipairs(data.Items or {}) do
		if type(stack) == "table" and ItemCatalog.Get(stack.Id) then
			table.insert(out.Items, {
				Id = ItemCatalog.NormalizeId(stack.Id),
				Amount = math.max(1, math.floor(tonumber(stack.Amount) or 1)),
				Quality = ItemCatalog.NormalizeQuality(stack.Quality),
				Purity = ItemCatalog.NormalizePurity(stack.Purity),
				CraftedBy = stack.CraftedBy,
				Source = stack.Source or "Market",
				Time = math.max(0, math.floor(tonumber(stack.Time) or now())),
			})
		end
	end
	return out
end

local function getPendingClaims(userId)
	userId = tostring(userId or "")
	if userId == "" then return defaultPendingClaims() end
	if not loadedPendingClaims[userId] then
		loadedPendingClaims[userId] = true
		local ok, data = pcall(function()
			return EconomyStore:GetAsync(dataKey("MarketPendingClaims_v1", userId))
		end)
		pendingClaims[userId] = ok and deserializePendingClaims(data) or defaultPendingClaims()
		if not ok then warn("Market claim load failed for " .. userId .. ": " .. tostring(data)) end
	end
	pendingClaims[userId] = pendingClaims[userId] or defaultPendingClaims()
	return pendingClaims[userId]
end

local function findPlayerByUserId(userId)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then return player end
	end
	return nil
end

local function addHistory(market, itemId, quality, purity, price, amount)
	local entry = { Id = nextTradeId, Market = market, ItemId = itemId, Quality = ItemCatalog.NormalizeQuality(quality), Purity = ItemCatalog.NormalizePurity(purity), Price = math.max(1, math.floor(tonumber(price) or 1)), Amount = math.max(1, math.floor(tonumber(amount) or 1)), Time = now() }
	nextTradeId += 1
	table.insert(blackMarket.History, entry)
	if #blackMarket.History > 1000 then table.remove(blackMarket.History, 1) end
	markBlackMarketDirty()
end

local function averagePrice(itemId, days)
	local cutoff = now() - (math.max(1, tonumber(days) or 1) * 86400)
	local total, amount = 0, 0
	for _, entry in ipairs(blackMarket.History) do
		if entry.ItemId == itemId and entry.Time >= cutoff then
			total += entry.Price * entry.Amount
			amount += entry.Amount
		end
	end
	if amount <= 0 then return nil end
	return math.floor(total / amount + 0.5)
end

local function historyStats(itemId, quality, purity, days, marketName)
	local cutoff = now() - (math.max(1, tonumber(days) or 1) * 86400)
	local total, amount, trades = 0, 0, 0
	local normalizedQuality = ItemCatalog.NormalizeQuality(quality or "Normal")
	local normalizedPurity = ItemCatalog.NormalizePurity(purity or "None")
	for _, entry in ipairs(blackMarket.History) do
		local marketOk = not marketName or entry.Market == marketName
		if marketOk and entry.ItemId == itemId and entry.Quality == normalizedQuality and entry.Purity == normalizedPurity and entry.Time >= cutoff then
			local entryAmount = math.max(1, math.floor(tonumber(entry.Amount) or 1))
			total += entry.Price * entryAmount
			amount += entryAmount
			trades += 1
		end
	end
	return {
		Average = amount > 0 and math.floor(total / amount + 0.5) or nil,
		Sold = amount,
		Trades = trades,
	}
end

local function baseItemValue(itemId, quality, purity)
	local def = ItemCatalog.Get(itemId)
	if not def then return 1 end
	local seven = averagePrice(itemId, 7)
	local base = seven or ItemCatalog.RecipeValue(itemId)
	local power = math.max(1, tonumber(def.Power or def.ItemPower) or ((tonumber(def.Tier) or 1) * 100))
	local bonus = ItemCatalog.QualityBonus(quality or def.Quality) + ItemCatalog.PurityBonus(purity or def.Purity)
	return math.max(1, math.floor(base * math.max(0.25, 1 + (bonus / math.max(300, power * 3))) + 0.5))
end

local function weightedPick(list, rng)
	local total = 0
	for _, entry in ipairs(list or {}) do total += math.max(0, tonumber(entry.Weight) or 0) end
	if total <= 0 then return nil end
	local roll = rng:NextNumber(0, total)
	local seen = 0
	for _, entry in ipairs(list) do
		seen += math.max(0, tonumber(entry.Weight) or 0)
		if roll <= seen then return entry end
	end
	return list[#list]
end

local function addClaimItem(player, stack, source)
	local claims = getClaims(player)
	local id = tostring(claims.NextId)
	claims.NextId += 1
	claims.Items[id] = { Id = stack.Id, Amount = stack.Amount, Quality = stack.Quality, Purity = stack.Purity, CraftedBy = stack.CraftedBy, Source = source or "Market", Time = now() }
	ProfileService.MarkDirty(player)
	return id
end

local function deliverStack(player, stack, source, allowOverweight)
	local def = ItemCatalog.Get(stack.Id)
	if not def then return false, "Unknown item." end
	if not allowOverweight then
		local weight = InventoryService.GetWeightSnapshot(player)
		local extra = ItemCatalog.StackWeight(stack)
		if weight.Current + extra > weight.Capacity then
			addClaimItem(player, stack, source)
			return true, "Sent to claim."
		end
	end
	local added = InventoryService.AddStack(player, stack)
	if added >= stack.Amount then return true end
	local remainder = copyStack(stack, stack.Amount - math.max(0, added))
	addClaimItem(player, remainder, source)
	return added > 0, added > 0 and "Partially sent to claim." or "Sent to claim."
end

local function queueOfflineCoin(userId, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then return end
	local claims = getPendingClaims(userId)
	claims.Coin += amount
	markPendingClaimsDirty(userId)
end

local function queueOfflineItem(userId, stack, source)
	if type(stack) ~= "table" or not ItemCatalog.Get(stack.Id) then return end
	local claims = getPendingClaims(userId)
	local queued = copyStack(stack)
	queued.Source = source or "Market"
	queued.Time = now()
	table.insert(claims.Items, queued)
	markPendingClaimsDirty(userId)
end

local function creditCoinByUserId(userId, amount)
	local player = findPlayerByUserId(userId)
	if player then
		InventoryService.AddCoin(player, amount)
	else
		queueOfflineCoin(userId, amount)
	end
end

local function deliverStackByUserId(userId, stack, source)
	local player = findPlayerByUserId(userId)
	if player then
		return deliverStack(player, stack, source)
	end
	queueOfflineItem(userId, stack, source)
	return true
end

local function applyPendingClaims(player)
	local claims = getPendingClaims(player.UserId)
	local changed = false
	local coin = math.max(0, math.floor(tonumber(claims.Coin) or 0))
	if coin > 0 then
		local profileClaims = getClaims(player)
		profileClaims.Coin += coin
		claims.Coin = 0
		changed = true
	end
	for _, stack in ipairs(claims.Items or {}) do
		addClaimItem(player, stack, stack.Source or "Market")
		changed = true
	end
	if changed then
		claims.Items = {}
		markPendingClaimsDirty(player.UserId)
		ProfileService.MarkDirty(player)
	end
end

local function claimRows(player)
	local claims = getClaims(player)
	local rows = {}
	for claimId, stack in pairs(claims.Items) do
		local row = rowForStack(stack)
		row.ClaimId = claimId
		row.Source = stack.Source or "Market"
		row.Time = stack.Time or 0
		table.insert(rows, row)
	end
	table.sort(rows, function(a, b) return tostring(a.ClaimId) < tostring(b.ClaimId) end)
	return rows, claims.Coin
end

local function claimItem(player, payload)
	local claims = getClaims(player)
	local claimId = tostring(payload.ClaimId or payload.claimId or "")
	local stack = claims.Items[claimId]
	if type(stack) ~= "table" then return false, "Claim not found." end
	local wanted = math.max(1, math.floor(tonumber(stack.Amount) or 1))
	local added = InventoryService.AddStack(player, stack)
	if added <= 0 then
		return false, "No inventory space available."
	end
	if added < wanted then
		stack.Amount = wanted - added
		ProfileService.MarkDirty(player)
		return false, "Inventory filled before the full claim could be moved."
	end
	claims.Items[claimId] = nil
	ProfileService.MarkDirty(player)
	return true
end

local function claimCoin(player)
	local claims = getClaims(player)
	local amount = math.max(0, math.floor(tonumber(claims.Coin) or 0))
	if amount <= 0 then return false, "No Coin to claim." end
	claims.Coin = 0
	ProfileService.MarkDirty(player)
	InventoryService.AddCoin(player, amount)
	return true
end

local function orderRow(order, player)
	local row = rowForStack(order.Stack)
	row.OrderId = order.Id
	row.Side = order.Side
	row.UnitPrice = order.Price
	row.Remaining = order.Remaining
	row.Amount = order.Remaining
	row.PlayerName = order.PlayerName
	row.Mine = player and order.UserId == player.UserId or false
	row.CreatedAt = order.CreatedAt
	return row
end

local function sortedRows(orders, player, side)
	local rows = {}
	for _, order in pairs(orders) do
		if order.Remaining > 0 and not (player and order.UserId == player.UserId) then table.insert(rows, orderRow(order, player)) end
	end
	if side == "Buy" then
		table.sort(rows, function(a, b) return a.UnitPrice == b.UnitPrice and a.OrderId < b.OrderId or a.UnitPrice > b.UnitPrice end)
	else
		table.sort(rows, function(a, b) return a.UnitPrice == b.UnitPrice and a.OrderId < b.OrderId or a.UnitPrice < b.UnitPrice end)
	end
	return rows
end

local function inventoryRows(player)
	local rows = {}
	for _, stack in ipairs(InventoryService.GetInventoryStacks(player)) do
		if marketItemAllowed(stack.Id) then
			local row = rowForStack(stack)
			row.Slot = stack.Slot
			row.Amount = stack.Amount
			row.EstimatedValue = baseItemValue(stack.Id, stack.Quality, stack.Purity)
			table.insert(rows, row)
		end
	end
	return rows
end

local function snapshot(player, mode, houseId)
	local house = getHouse(houseId)
	local claims, claimCoinAmount = claimRows(player)
	local myAuctionSell, myAuctionBuy = {}, {}
	for _, order in pairs(house.SellOrders) do if order.UserId == player.UserId then table.insert(myAuctionSell, orderRow(order, player)) end end
	for _, order in pairs(house.BuyOrders) do if order.UserId == player.UserId then table.insert(myAuctionBuy, orderRow(order, player)) end end
	local myBlackSell = {}
	for _, order in pairs(blackMarket.SellOrders) do if order.UserId == player.UserId then table.insert(myBlackSell, orderRow(order, player)) end end
	local demandRows = {}
	for key, price in pairs(blackMarket.BuyDemand) do
		local itemId, quality, purity = string.match(key, "^([^|]+)|([^|]+)|(.+)$")
		if itemId then
			local row = rowForStack({ Id = itemId, Amount = 1, Quality = quality, Purity = purity })
			row.UnitPrice = math.max(1, math.floor(tonumber(price) or baseItemValue(itemId, quality, purity)))
			row.Avg24h = averagePrice(itemId, 1)
			row.Avg7d = averagePrice(itemId, 7)
			row.Avg30d = averagePrice(itemId, 30)
			table.insert(demandRows, row)
		end
	end
	table.sort(demandRows, function(a, b) return a.DisplayName < b.DisplayName end)
	return {
		Ok = true,
		Mode = mode or "Auction",
		HouseId = houseId or "GlobalAuction",
		Economy = { Coin = InventoryService.GetCoin(player) },
		Inventory = inventoryRows(player),
		Claims = claims,
		ClaimCoin = claimCoinAmount,
		Auction = { SellOrders = sortedRows(house.SellOrders, player, "Sell"), BuyOrders = sortedRows(house.BuyOrders, player, "Buy"), MySellOrders = myAuctionSell, MyBuyOrders = myAuctionBuy },
		BlackMarket = { SellOrders = sortedRows(blackMarket.SellOrders, player, "Sell"), MySellOrders = myBlackSell, Demand = demandRows },
		Meta = { Qualities = ItemCatalog.QualityOrder, Purities = ItemCatalog.PurityOrder, Categories = Config.Categories },
	}
end

local function distanceToPartBounds(root, part)
	if not root or not part then return math.huge end
	local localPos = part.CFrame:PointToObjectSpace(root.Position)
	local half = part.Size * 0.5
	local clamped = Vector3.new(
		math.clamp(localPos.X, -half.X, half.X),
		math.clamp(localPos.Y, -half.Y, half.Y),
		math.clamp(localPos.Z, -half.Z, half.Z)
	)
	local nearest = part.CFrame:PointToWorldSpace(clamped)
	return (root.Position - nearest).Magnitude
end

local function validateActiveMarket(player, expectedType)
	local info = activeMarket[player]
	if not info or (expectedType and info.Type ~= expectedType) then return false, "Open the market first." end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local part = info.Part
	if not root or not part or distanceToPartBounds(root, part) > Config.MarketDistance then return false, "Move closer to the market." end
	return true, nil, info
end

local function reserveOrderId()
	local id = nextOrderId
	nextOrderId += 1
	return id
end

local function takeInventoryStack(player, payload)
	local stack, err = InventoryService.RemoveStack(player, payload)
	if not stack then return nil, err end
	if not marketItemAllowed(stack.Id) then
		InventoryService.AddStack(player, stack)
		return nil, "That item cannot be traded here."
	end
	stack.CraftedBy = stack.CraftedBy or playerName(player)
	return stack
end

local function takeBlackMarketStack(player, payload)
	local stack, err = takeInventoryStack(player, payload)
	if not stack then return nil, err end
	if not blackMarketItemAllowed(stack.Id) then
		InventoryService.AddStack(player, stack)
		return nil, "The Black Market only accepts weapons and armor."
	end
	return stack
end

local function createOrder(user, side, stack, price)
	return { Id = reserveOrderId(), UserId = user.UserId, PlayerName = playerName(user), Side = side, Stack = copyStack(stack), Price = math.max(1, math.floor(tonumber(price) or 1)), Remaining = math.max(1, math.floor(tonumber(stack.Amount) or 1)), CreatedAt = now() }
end

local function placeAuctionSell(player, payload, houseId)
	local ok, err = validateActiveMarket(player, "Auction")
	if not ok then return false, err end
	local price = math.clamp(math.floor(tonumber(payload.Price) or 0), 1, Config.MaxOrderPrice)
	payload.Amount = math.clamp(math.floor(tonumber(payload.Amount) or 1), 1, Config.MaxSellOrderAmount or Config.MaxOrderAmount or 999)
	local stack, takeErr = takeInventoryStack(player, payload)
	if not stack then return false, takeErr end
	local setupFee = setupFeeFor(price * stack.Amount)
	if setupFee > 0 then
		local paid, payErr = InventoryService.RemoveCoin(player, setupFee)
		if not paid then
			InventoryService.AddStack(player, stack)
			return false, payErr or "Not enough Coin for the setup fee."
		end
	end
	local house = getHouse(houseId)
	local order = createOrder(player, "Sell", stack, price)
	house.SellOrders[order.Id] = order
	markHouseDirty(houseId)
	return true
end

local function placeAuctionBuy(player, payload, houseId)
	local ok, err = validateActiveMarket(player, "Auction")
	if not ok then return false, err end
	local itemId = ItemCatalog.NormalizeId(payload.ItemId)
	if not itemId or not marketItemAllowed(itemId) then return false, "Choose a tradeable item." end
	local amount = math.clamp(math.floor(tonumber(payload.Amount) or 1), 1, Config.MaxBuyOrderAmount or Config.MaxOrderAmount)
	local price = math.clamp(math.floor(tonumber(payload.Price) or 0), 1, Config.MaxOrderPrice)
	local cost = amount * price
	local setupFee = setupFeeFor(cost)
	local paid, payErr = InventoryService.RemoveCoin(player, cost + setupFee)
	if not paid then return false, payErr end
	local house = getHouse(houseId)
	local order = createOrder(player, "Buy", { Id = itemId, Amount = amount, Quality = payload.Quality or "Normal", Purity = payload.Purity or "None" }, price)
	house.BuyOrders[order.Id] = order
	markHouseDirty(houseId)
	return true
end

local function buyAuctionOrder(player, payload, houseId)
	local ok, err = validateActiveMarket(player, "Auction")
	if not ok then return false, err end
	local house = getHouse(houseId)
	local order = house.SellOrders[math.floor(tonumber(payload.OrderId) or 0)]
	if not order or order.Remaining <= 0 then return false, "Order not found." end
	if order.UserId == player.UserId then return false, "You cannot buy your own auction listing." end
	local amount = math.clamp(math.floor(tonumber(payload.Amount) or 1), 1, order.Remaining)
	local cost = order.Price * amount
	local paid, payErr = InventoryService.RemoveCoin(player, cost)
	if not paid then return false, payErr end
	local sellerNet = applyMarketplaceTax(cost, { Market = "Auction", HouseId = houseId, SellerUserId = order.UserId, BuyerUserId = player.UserId })
	creditCoinByUserId(order.UserId, sellerNet)
	local stack = copyStack(order.Stack, amount)
	deliverStack(player, stack, "Auction House")
	order.Remaining -= amount
	if order.Remaining <= 0 then house.SellOrders[order.Id] = nil end
	addHistory("Auction", stack.Id, stack.Quality, stack.Purity, order.Price, amount)
	markHouseDirty(houseId)
	return true
end

local function sellToAuctionBuy(player, payload, houseId)
	local ok, err = validateActiveMarket(player, "Auction")
	if not ok then return false, err end
	local house = getHouse(houseId)
	local order = house.BuyOrders[math.floor(tonumber(payload.OrderId) or 0)]
	if not order or order.Remaining <= 0 then return false, "Buy order not found." end
	if order.UserId == player.UserId then return false, "You cannot fill your own auction buy order." end
	payload.Amount = math.clamp(math.floor(tonumber(payload.Amount) or 1), 1, Config.MaxSellOrderAmount or Config.MaxOrderAmount or 999)
	local stack, takeErr = takeInventoryStack(player, payload)
	if not stack then return false, takeErr end
	if stackKey(stack) ~= stackKey(order.Stack) then
		InventoryService.AddStack(player, stack)
		return false, "That item does not match the buy order."
	end
	local amount = math.min(stack.Amount, order.Remaining)
	if amount < stack.Amount then
		InventoryService.AddStack(player, copyStack(stack, stack.Amount - amount))
	end
	deliverStackByUserId(order.UserId, copyStack(stack, amount), "Auction House")
	local gross = order.Price * amount
	local sellerNet = applyMarketplaceTax(gross, { Market = "Auction", HouseId = houseId, SellerUserId = player.UserId, BuyerUserId = order.UserId })
	InventoryService.AddCoin(player, sellerNet)
	order.Remaining -= amount
	if order.Remaining <= 0 then house.BuyOrders[order.Id] = nil end
	addHistory("Auction", stack.Id, stack.Quality, stack.Purity, order.Price, amount)
	markHouseDirty(houseId)
	return true
end

local function cancelAuctionOrder(player, payload, houseId)
	local house = getHouse(houseId)
	local orderId = math.floor(tonumber(payload.OrderId) or 0)
	local order = house.SellOrders[orderId] or house.BuyOrders[orderId]
	if not order or order.UserId ~= player.UserId then return false, "Order not found." end
	if order.Side == "Sell" then
		deliverStack(player, copyStack(order.Stack, order.Remaining), "Canceled Order", true)
		house.SellOrders[orderId] = nil
	else
		InventoryService.AddCoin(player, order.Price * order.Remaining)
		house.BuyOrders[orderId] = nil
	end
	markHouseDirty(houseId)
	return true
end

local function blackDemandPrice(stack)
	local key = stackKey(stack)
	local price = blackMarket.BuyDemand[key]
	if not price then
		price = baseItemValue(stack.Id, stack.Quality, stack.Purity)
		blackMarket.BuyDemand[key] = price
		markBlackMarketDirty()
	end
	return math.max(1, math.floor(price))
end

local function blackDirectSell(player, payload)
	local ok, err = validateActiveMarket(player, "BlackMarket")
	if not ok then return false, err end
	payload.Amount = math.clamp(math.floor(tonumber(payload.Amount) or 1), 1, Config.MaxSellOrderAmount or Config.MaxOrderAmount or 999)
	local stack, takeErr = takeBlackMarketStack(player, payload)
	if not stack then return false, takeErr end
	local price = blackDemandPrice(stack)
	InventoryService.AddCoin(player, price * stack.Amount)
	local key = stackKey(stack)
	blackMarket.Stock[key] = blackMarket.Stock[key] or {}
	table.insert(blackMarket.Stock[key], copyStack(stack))
	markBlackMarketDirty()
	addHistory("BlackMarket", stack.Id, stack.Quality, stack.Purity, price, stack.Amount)
	return true
end

local function placeBlackSellOrder(player, payload)
	local ok, err = validateActiveMarket(player, "BlackMarket")
	if not ok then return false, err end
	local price = math.clamp(math.floor(tonumber(payload.Price) or 0), 1, Config.MaxOrderPrice)
	payload.Amount = math.clamp(math.floor(tonumber(payload.Amount) or 1), 1, Config.MaxSellOrderAmount or Config.MaxOrderAmount or 999)
	local stack, takeErr = takeBlackMarketStack(player, payload)
	if not stack then return false, takeErr end
	local order = createOrder(player, "Sell", stack, price)
	blackMarket.SellOrders[order.Id] = order
	markBlackMarketDirty()
	return true
end

local function cancelBlackOrder(player, payload)
	local orderId = math.floor(tonumber(payload.OrderId) or 0)
	local order = blackMarket.SellOrders[orderId]
	if not order or order.UserId ~= player.UserId then return false, "Order not found." end
	deliverStack(player, copyStack(order.Stack, order.Remaining), "Canceled Black Market Order", true)
	blackMarket.SellOrders[orderId] = nil
	markBlackMarketDirty()
	return true
end

local function priceChance(price, value)
	local premium = (price - value) / math.max(1, value)
	local chance = Config.BlackMarketPriceRoll.ChanceAtZero + (Config.BlackMarketPriceRoll.ChanceSlope * premium)
	return math.clamp(chance, Config.BlackMarketPriceRoll.MinChance, Config.BlackMarketPriceRoll.MaxChance)
end

local function increaseDemand(stack, value)
	local key = stackKey(stack)
	local current = blackMarket.BuyDemand[key] or value
	blackMarket.BuyDemand[key] = math.max(1, math.floor(current * (1 + Config.BlackMarketPriceRoll.DemandIncrease) + 0.5))
	markBlackMarketDirty()
end

local function chestLootStackKey(stack)
	return table.concat({ tostring(stack.Id), ItemCatalog.NormalizeQuality(stack.Quality), ItemCatalog.NormalizePurity(stack.Purity), tostring(stack.CraftedBy or "") }, "|")
end

local function firstOpenLootSlot(loot)
	local scanLimit = math.max(Config.ChestGridSlots or 24, #loot + 1)
	for slot = 1, scanLimit do
		if loot[slot] == nil then return slot end
	end
	return scanLimit + 1
end

local function addLootStack(loot, stack)
	if type(loot) ~= "table" or type(stack) ~= "table" then return end
	local def = ItemCatalog.Get(stack.Id)
	local amount = math.max(1, math.floor(tonumber(stack.Amount) or 1))
	if def and def.Stackable == true then
		local maxStack = math.max(1, math.floor(tonumber(def.MaxStack) or 999))
		local key = chestLootStackKey(stack)
		for _, existing in pairs(loot) do
			if existing and chestLootStackKey(existing) == key then
				local room = maxStack - math.max(0, math.floor(tonumber(existing.Amount) or 0))
				if room > 0 then
					local moved = math.min(room, amount)
					existing.Amount += moved
					amount -= moved
					if amount <= 0 then return end
				end
			end
		end
		while amount > 0 do
			local moved = math.min(maxStack, amount)
			loot[firstOpenLootSlot(loot)] = copyStack(stack, moved)
			amount -= moved
		end
		return
	end
	for _ = 1, amount do
		loot[firstOpenLootSlot(loot)] = copyStack(stack, 1)
	end
end

local function addCoinSacksToLoot(value, loot)
	value = math.max(1, math.floor(tonumber(value) or 1))
	local values = Config.CoinSackValues
	local remaining = value
	local sacks = {}
	for tier = #values, 1, -1 do
		local sackValue = values[tier]
		local count = math.floor(remaining / sackValue)
		if count > 0 then
			sacks[tier] = (sacks[tier] or 0) + count
			remaining -= count * sackValue
		end
	end
	if remaining > 0 then
		for tier, sackValue in ipairs(values) do
			if sackValue >= remaining then
				sacks[tier] = (sacks[tier] or 0) + 1
				break
			end
		end
	end
	for tier, count in pairs(sacks) do
		addLootStack(loot, { Id = string.format("T%d_CoinSack", tier), Amount = count, Quality = "Normal", Purity = "None" })
	end
end

local function rowsForLoot(loot)
	local rows = {}
	for slot, stack in pairs(loot or {}) do
		if type(stack) == "table" and (tonumber(stack.Amount) or 0) > 0 then
			local row = rowForStack(stack)
			row.Slot = slot
			row.UnitValue = baseItemValue(stack.Id, stack.Quality, stack.Purity)
			row.EstimatedValue = row.UnitValue * math.max(1, math.floor(tonumber(stack.Amount) or 1))
			table.insert(rows, row)
		end
	end
	table.sort(rows, function(a, b) return (tonumber(a.Slot) or 0) < (tonumber(b.Slot) or 0) end)
	return rows
end

local function lootValue(loot)
	local total = 0
	for _, stack in pairs(loot or {}) do
		if type(stack) == "table" then
			total += baseItemValue(stack.Id, stack.Quality, stack.Purity) * math.max(1, math.floor(tonumber(stack.Amount) or 1))
		end
	end
	return math.max(0, math.floor(total + 0.5))
end

local function chestKeyFor(chest)
	return tostring(chest and (chest:GetAttribute("ChestId") or chest:GetFullName()) or "")
end

local function collectChestTopParts(chest)
	local parts = {}
	if not chest then return parts, nil end
	for _, name in ipairs({ "MetalTop", "WoodTop" }) do
		local part = chest:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then table.insert(parts, part) end
	end
	return parts, chest:FindFirstChild("Hinge", true)
end

local function tweenChestLid(chest, isOpen, state)
	local parts, hinge = collectChestTopParts(chest)
	if #parts == 0 then return end
	state = state or {}
	state.ClosedCFrames = state.ClosedCFrames or {}
	local hingeCFrame = (hinge and hinge:IsA("BasePart") and hinge.CFrame) or (chest and chest:GetPivot()) or CFrame.new()
	for _, part in ipairs(parts) do
		local closed = state.ClosedCFrames[part] or part.CFrame
		state.ClosedCFrames[part] = closed
		local target = closed
		if isOpen then
			target = hingeCFrame * CFrame.Angles(math.rad(72), 0, 0) * hingeCFrame:Inverse() * closed
		end
		local ok = pcall(function()
			TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target }):Play()
		end)
		if not ok then part.CFrame = target end
	end
end

local function scheduleChestRespawn(chestKey, state)
	local seconds = math.max(1, tonumber(Config.ChestRespawnSeconds) or 30)
	state.RespawnAt = state.RespawnAt or (os.clock() + seconds)
	task.delay(math.max(0.1, state.RespawnAt - os.clock()), function()
		if activeChestLoot[chestKey] ~= state then return end
		tweenChestLid(state.Chest, false, state)
		if state.Chest then
			pcall(function()
				SmartChestService.ResetProgress(state.Chest)
			end)
		end
		activeChestLoot[chestKey] = nil
	end)
end

local function tryBlackMarketLoot(stack, value, rng, loot)
	local key = stackKey(stack)
	local stockList = blackMarket.Stock[key]
	if stockList and #stockList > 0 then
		local stocked = stockList[1]
		addLootStack(loot, copyStack(stocked, 1))
		stocked.Amount = math.max(0, math.floor(tonumber(stocked.Amount) or 1) - 1)
		if stocked.Amount <= 0 then table.remove(stockList, 1) end
		markBlackMarketDirty()
		return true
	end
	local candidates = {}
	for _, order in pairs(blackMarket.SellOrders) do
		if order.Remaining > 0 and stackKey(order.Stack) == key and order.Price <= value * (1 + Config.BlackMarketPriceRoll.MaxPremium) then
			table.insert(candidates, order)
		end
	end
	table.sort(candidates, function(a, b) return a.Price == b.Price and a.Id < b.Id or a.Price < b.Price end)
	for _, order in ipairs(candidates) do
		if rng:NextNumber() <= priceChance(order.Price, value) then
			creditCoinByUserId(order.UserId, order.Price)
			order.Remaining -= 1
			if order.Remaining <= 0 then blackMarket.SellOrders[order.Id] = nil end
			addLootStack(loot, copyStack(order.Stack, 1))
			markBlackMarketDirty()
			addHistory("BlackMarket", order.Stack.Id, order.Stack.Quality, order.Stack.Purity, order.Price, 1)
			return true
		end
	end
	increaseDemand(stack, value)
	addCoinSacksToLoot(math.floor(value * Config.BlackMarketPriceRoll.CompensationFactor), loot)
	return false
end

local function eligibleLootItems(chestTier, profile)
	local allowedCategories = {}
	for _, category in ipairs(profile.Categories or {}) do allowedCategories[category] = true end
	local specific = {}
	for _, id in ipairs(profile.SpecificItems or {}) do
		local normalized = ItemCatalog.NormalizeId(id)
		if normalized and chestItemAllowed(normalized) then specific[normalized] = true end
	end
	local out = {}
	for id, def in pairs(ItemCatalog.Items) do
		local tier = math.clamp(math.floor(tonumber(def.Tier) or 1), 1, 20)
		local inTier = tier >= math.max(1, chestTier - 1) and tier <= math.min(20, chestTier + 1)
		local categoryOk = specific[id] == true
		if not categoryOk then
			for category, spec in pairs(Config.Categories) do
				if allowedCategories[category] and spec.Types and spec.Types[def.Type] then categoryOk = true end
			end
		end
		if inTier and categoryOk and chestItemAllowed(id) then table.insert(out, id) end
	end
	table.sort(out)
	return out
end

local function rollCatalystToLoot(chestTier, quality, rng, loot)
	local prefixes = Config.PurityCatalystPrefixes
	if #prefixes <= 0 then return end
	local prefix = prefixes[rng:NextInteger(1, #prefixes)]
	local tier = math.clamp(chestTier + rng:NextInteger(-1, 1), 1, 20)
	local id = string.format("T%d_%s", tier, prefix)
	if not ItemCatalog.Get(id) then return end
	local mult = Config.ChestQualityMultiplier[ItemCatalog.NormalizeQuality(quality)] or 1
	local amount = math.max(1, math.floor((tier * 0.5 + 1) * mult + 0.5))
	addLootStack(loot, { Id = id, Amount = amount, Quality = "Normal", Purity = "None" })
end

local function splitAttributeList(value)
	local out = {}
	if type(value) == "table" then
		for _, entry in ipairs(value) do table.insert(out, tostring(entry)) end
	elseif value ~= nil and tostring(value) ~= "" then
		for entry in string.gmatch(tostring(value), "[^,%s]+") do
			table.insert(out, entry)
		end
	end
	return out
end

local function applyChestAttributeDefaults(chest)
	if not chest then return end
	local baseProfile = Config.ProfileForChestType(chest:GetAttribute("ChestType") or chest:GetAttribute("Type") or "Testing")
	if chest:GetAttribute("Tier") == nil then chest:SetAttribute("Tier", 1) end
	if chest:GetAttribute("Quality") == nil then chest:SetAttribute("Quality", "Normal") end
	if chest:GetAttribute("ChestType") == nil and chest:GetAttribute("Type") == nil then chest:SetAttribute("ChestType", "Testing") end
	if chest:GetAttribute("ItemRollChance") == nil then chest:SetAttribute("ItemRollChance", baseProfile.ItemRollChance or 0.35) end
	if chest:GetAttribute("MinItemRolls") == nil then chest:SetAttribute("MinItemRolls", baseProfile.MinItemRolls or 0) end
	if chest:GetAttribute("MaxItemRolls") == nil then chest:SetAttribute("MaxItemRolls", baseProfile.MaxItemRolls or math.max(1, baseProfile.MinItemRolls or 0)) end
	if chest:GetAttribute("CoinRolls") == nil then chest:SetAttribute("CoinRolls", baseProfile.CoinRolls or 2) end
	if chest:GetAttribute("CatalystRolls") == nil then chest:SetAttribute("CatalystRolls", baseProfile.CatalystRolls or 1) end
	if chest:GetAttribute("Categories") == nil then chest:SetAttribute("Categories", "Weapons,Armor,Utility") end
	if chest:GetAttribute("SpecificItems") == nil then chest:SetAttribute("SpecificItems", "") end
end

local function resolveChestProfile(chest)
	applyChestAttributeDefaults(chest)
	local chestType = tostring(chest:GetAttribute("ChestType") or chest:GetAttribute("Type") or "Testing")
	local profile = Config.ProfileForChestType(chestType)
	profile.Type = chestType
	profile.Tier = math.clamp(math.floor(tonumber(chest:GetAttribute("Tier") or profile.Tier) or 1), 1, 20)
	profile.Quality = ItemCatalog.NormalizeQuality(chest:GetAttribute("Quality") or profile.Quality or "Normal")
	profile.ItemRollChance = math.clamp(tonumber(chest:GetAttribute("ItemRollChance") or profile.ItemRollChance) or 0, 0, 1)
	profile.MinItemRolls = math.max(0, math.floor(tonumber(chest:GetAttribute("MinItemRolls") or profile.MinItemRolls) or 0))
	profile.MaxItemRolls = math.max(profile.MinItemRolls, math.floor(tonumber(chest:GetAttribute("MaxItemRolls") or profile.MaxItemRolls or profile.MinItemRolls) or profile.MinItemRolls))
	profile.CoinRolls = math.max(0, math.floor(tonumber(chest:GetAttribute("CoinRolls") or profile.CoinRolls) or 0))
	profile.CatalystRolls = math.max(0, math.floor(tonumber(chest:GetAttribute("CatalystRolls") or profile.CatalystRolls) or 0))
	local categories = splitAttributeList(chest:GetAttribute("Categories"))
	if #categories > 0 then profile.Categories = categories end
	local specificItems = splitAttributeList(chest:GetAttribute("SpecificItems"))
	if #specificItems > 0 then profile.SpecificItems = specificItems end
	return profile
end

local function checkChestRequirements(player, chest)
	local smartPass, smartMessage = SmartChestService.CanOpen(player, chest)
	if smartPass ~= true then
		return false, smartMessage or "You do not meet this chest requirement."
	end
	local context = SmartChestService.BuildContext(player, chest)
	for _, child in ipairs(chest:GetChildren()) do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if not ok then return false, "Chest requirement module failed." end
			if type(result) == "function" then
				local pass, message = result(player, chest, context)
				if pass ~= true then return false, message or "You do not meet this chest requirement." end
			elseif type(result) == "table" and type(result.CanOpen) == "function" then
				local pass, message = result.CanOpen(player, chest, context)
				if pass ~= true then return false, message or "You do not meet this chest requirement." end
			end
		end
	end
	return true
end

local function generateChestLoot(chest)
	local profile = resolveChestProfile(chest)
	local rng = Random.new(math.floor(os.clock() * 100000) % 2147483647)
	local loot = {}
	local qualityMult = Config.ChestQualityMultiplier[profile.Quality] or 1
	for _ = 1, math.max(1, profile.CoinRolls or 1) do
		local base = Config.CoinSackValues[profile.Tier] or 10
		addCoinSacksToLoot(math.floor(base * rng:NextNumber(0.8, 1.35) * qualityMult), loot)
	end
	for _ = 1, math.max(0, profile.CatalystRolls or 0) do
		rollCatalystToLoot(profile.Tier, profile.Quality, rng, loot)
	end
	local minItemRolls = math.max(0, math.floor(tonumber(profile.MinItemRolls) or 0))
	local maxItemRolls = math.max(minItemRolls, math.floor(tonumber(profile.MaxItemRolls) or minItemRolls))
	local itemRolls = maxItemRolls > 0 and rng:NextInteger(minItemRolls, maxItemRolls) or 0
	if itemRolls > 0 then
		local candidates = eligibleLootItems(profile.Tier, profile)
		for _ = 1, itemRolls do
			if #candidates > 0 and rng:NextNumber() <= (tonumber(profile.ItemRollChance) or 0) then
				local itemId = candidates[rng:NextInteger(1, #candidates)]
				local quality = (weightedPick(Config.QualityRolls, rng) or { Name = "Normal" }).Name
				local purity = (weightedPick(Config.PurityRolls, rng) or { Name = "None" }).Name
				local stack = { Id = itemId, Amount = 1, Quality = quality, Purity = purity }
				tryBlackMarketLoot(stack, baseItemValue(itemId, quality, purity), rng, loot)
			end
		end
	end
	return loot, profile
end

local function chestNoticePayload(chestKey, state, text)
	local title = state and state.IsDeathSack and "Death Sack" or "Treasure Loot"
	local promptPart = state and state.PromptPart
	return {
		Kind = "ChestLoot",
		ChestKey = chestKey,
		Rewards = rowsForLoot(state and state.Loot or {}),
		LootValue = lootValue(state and state.Loot or {}),
		GridSlots = Config.ChestGridSlots or 24,
		Title = title,
		Text = text,
		ProtectedUntil = state and state.ProtectedUntil or nil,
		Position = promptPart and promptPart.Position or nil,
		CloseDistance = Config.MarketDistance,
	}
end

local function lootHasAny(loot)
	for _, stack in pairs(loot or {}) do
		if type(stack) == "table" and (tonumber(stack.Amount) or 0) > 0 then return true end
	end
	return false
end

local function canLootState(player, state)
	if not state or state.IsDeathSack ~= true then return true end
	local protectedUntil = math.floor(tonumber(state.ProtectedUntil) or 0)
	if now() >= protectedUntil then return true end
	return state.AllowedUserIds and state.AllowedUserIds[player.UserId] == true or false
end

local function destroyDeathSackState(chestKey, state)
	activeChestLoot[chestKey] = nil
	if state and state.Chest and state.Chest.Parent then
		state.Chest:Destroy()
	end
end

local function lootChest(player, chest, promptPart)
	local chestKey = chestKeyFor(chest)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not promptPart or distanceToPartBounds(root, promptPart) > Config.MarketDistance then return { Ok = false, Error = "Move closer." } end
	local okReq, reqErr = checkChestRequirements(player, chest)
	if not okReq then MarketNotice:FireClient(player, reqErr); return { Ok = false, Error = reqErr } end
	local state = activeChestLoot[chestKey]
	if state and not canLootState(player, state) then
		local errorText = "This loot is protected."
		MarketNotice:FireClient(player, errorText)
		return { Ok = false, Error = errorText }
	end
	if not state then
		local loot, profile = generateChestLoot(chest)
		state = { Key = chestKey, Chest = chest, PromptPart = promptPart, Loot = loot, Profile = profile, OpenedAt = os.clock(), ClosedCFrames = {} }
		activeChestLoot[chestKey] = state
		tweenChestLid(chest, true, state)
	else
		state.Chest = chest
		state.PromptPart = promptPart
	end
	local notice = chestNoticePayload(chestKey, state, state.IsDeathSack and "Death sack opened." or "Treasure chest opened.")
	MarketNotice:FireClient(player, notice)
	return { Ok = true, Kind = "ChestLoot", ChestKey = chestKey, Rewards = notice.Rewards, LootValue = notice.LootValue, GridSlots = notice.GridSlots, Title = notice.Title }
end

local function sanitizeId(value)
	return tostring(value or "Market"):gsub("[^%w_%-]", "_")
end

local function promptPartFor(inst, preferredName)
	if inst:IsA("BasePart") then return inst end
	local names = { preferredName or "MainPrompt", "MainPrompt", "AuctionOpener", "BlackMarketOpener", "Opener", "Prompt" }
	for _, name in ipairs(names) do
		local preferred = inst:FindFirstChild(name, true)
		if preferred and preferred:IsA("BasePart") then return preferred end
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function ensurePrompt(part, name, objectText, actionText)
	local prompt = part:FindFirstChild(name)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.Parent = part
	end
	prompt.ObjectText = objectText
	prompt.ActionText = actionText or "Open"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	return prompt
end

local function deathSackFolder()
	local folder = Workspace:FindFirstChild("DeathSacks")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "DeathSacks"
		folder.Parent = Workspace
	end
	return folder
end

local function relationshipSnapshot()
	local ok, service = pcall(function()
		return require(ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
	end)
	return ok and type(service) == "table" and service or nil
end

local function partyOfPlayer(player)
	if not player then return nil end
	local relationships = relationshipSnapshot()
	return relationships and relationships.PartyOf and relationships.PartyOf[player] or nil
end

local function addPartyMembers(allowed, partyId)
	if not partyId then return end
	for _, candidate in ipairs(Players:GetPlayers()) do
		if partyOfPlayer(candidate) == partyId then
			allowed[candidate.UserId] = true
		end
	end
end

local function allowedUserCsv(allowed)
	local ids = {}
	for userId in pairs(allowed or {}) do table.insert(ids, tostring(userId)) end
	table.sort(ids)
	return table.concat(ids, ",")
end

function EconomyMarketService.CreateDeathSack(victim, killer, stacks, position)
	if type(stacks) ~= "table" or #stacks <= 0 then return nil end
	local assets = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("DeathSack")
	local model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		model.Name = "DeathSack"
		if template then
			for _, child in ipairs(template:GetChildren()) do
				child:Clone().Parent = model
			end
		end
	end
	model.Name = "DeathSack"
	model.Parent = deathSackFolder()
	local promptPart = promptPartFor(model, "Sack")
	if not promptPart then
		model:Destroy()
		return nil
	end
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
		elseif inst:IsA("ParticleEmitter") then
			inst.Enabled = true
		end
	end
	local dropPosition = position
	if typeof(dropPosition) ~= "Vector3" then
		local root = victim and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
		dropPosition = root and root.Position or Vector3.new(0, 5, 0)
	end
	model:PivotTo(CFrame.new(dropPosition + Vector3.new(0, 1.25, 0)))
	local chestKey = "DeathSack_" .. HttpService:GenerateGUID(false)
	local allowed = {}
	if victim then allowed[victim.UserId] = true end
	if killer and killer ~= victim then allowed[killer.UserId] = true end
	addPartyMembers(allowed, partyOfPlayer(victim))
	addPartyMembers(allowed, partyOfPlayer(killer))
	local protectedUntil = now() + math.max(0, math.floor(tonumber(Config.DeathSackProtectionSeconds) or 180))
	model:SetAttribute("DeathSack", true)
	model:SetAttribute("LootChest", true)
	model:SetAttribute("ChestId", chestKey)
	model:SetAttribute("ChestType", "DeathSack")
	model:SetAttribute("ProtectedUntil", protectedUntil)
	model:SetAttribute("AllowedUserIds", allowedUserCsv(allowed))
	local loot = {}
	for _, stack in ipairs(stacks) do addLootStack(loot, stack) end
	if not lootHasAny(loot) then
		model:Destroy()
		return nil
	end
	local state = {
		Key = chestKey,
		Chest = model,
		PromptPart = promptPart,
		Loot = loot,
		Profile = { Type = "DeathSack" },
		OpenedAt = os.clock(),
		ClosedCFrames = {},
		IsDeathSack = true,
		ProtectedUntil = protectedUntil,
		AllowedUserIds = allowed,
	}
	activeChestLoot[chestKey] = state
	local prompt = ensurePrompt(promptPart, "DeathSackPrompt", "Death Sack", "Loot")
	if not prompt:GetAttribute("MarketBound") then
		prompt:SetAttribute("MarketBound", true)
		prompt.Triggered:Connect(function(player)
			lootChest(player, model, promptPart)
		end)
	end
	task.delay(math.max(1, math.floor(tonumber(Config.DeathSackDespawnSeconds) or 1800)), function()
		if activeChestLoot[chestKey] == state then
			destroyDeathSackState(chestKey, state)
		end
	end)
	return model, chestKey
end

local function bindAuction(inst)
	local part = promptPartFor(inst, "MainPrompt")
	if not part then return end
	local prompt = ensurePrompt(part, "AuctionHousePrompt", "Auction House", "Trade")
	if prompt:GetAttribute("MarketBound") then return end
	prompt:SetAttribute("MarketBound", true)
	local houseId = tostring(inst:GetAttribute("AuctionHouseId") or inst:GetAttribute("MarketId") or sanitizeId(inst.Name))
	prompt.Triggered:Connect(function(player)
		activeMarket[player] = { Type = "Auction", HouseId = houseId, Part = part }
		OpenMarketInterface:FireClient(player, { Mode = "Auction", HouseId = houseId, Position = part.Position })
	end)
end

local function bindBlackMarket(inst)
	local part = promptPartFor(inst, "MainPrompt")
	if not part then return end
	local prompt = ensurePrompt(part, "BlackMarketPrompt", "Black Market", "Trade")
	if prompt:GetAttribute("MarketBound") then return end
	prompt:SetAttribute("MarketBound", true)
	prompt.Triggered:Connect(function(player)
		activeMarket[player] = { Type = "BlackMarket", HouseId = "BlackMarket", Part = part }
		OpenMarketInterface:FireClient(player, { Mode = "BlackMarket", HouseId = "BlackMarket", Position = part.Position })
	end)
end


local function ensureSampleMarketPart(folder, name, position, color, marketType)
	local part = folder:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = Vector3.new(4, 4, 3)
		part.Position = position
		part.Color = color
		part.Material = Enum.Material.Slate
		part.Parent = folder
	end
	part:SetAttribute("MarketType", marketType)
	return part
end

local function setupInteractables()
	local folder = Workspace:FindFirstChild("InventoryInteractables")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "InventoryInteractables"
		folder.Parent = Workspace
	end
	ensureSampleMarketPart(folder, "AuctionHouse_Test", Vector3.new(22, 2, -8), Color3.fromRGB(44, 70, 96), "Auction")
	ensureSampleMarketPart(folder, "BlackMarket_Test", Vector3.new(29, 2, -8), Color3.fromRGB(36, 28, 42), "BlackMarket")


end

local function clearPlayerSessionState(player)
	for key, state in pairs(activeChestOpening) do
		if state and state.UserId == player.UserId then
			activeChestOpening[key] = nil
		end
	end
	activeMarket[player] = nil
end

local function rowsForKey(orders, key, player, side)
	local rows = {}
	for _, order in pairs(orders or {}) do
		if order.Remaining > 0 and stackKey(order.Stack) == key and not (player and order.UserId == player.UserId) then
			table.insert(rows, orderRow(order, player))
		end
	end
	if side == "Buy" then
		table.sort(rows, function(a, b) return a.UnitPrice == b.UnitPrice and a.OrderId < b.OrderId or a.UnitPrice > b.UnitPrice end)
	else
		table.sort(rows, function(a, b) return a.UnitPrice == b.UnitPrice and a.OrderId < b.OrderId or a.UnitPrice < b.UnitPrice end)
	end
	return rows
end

local function itemMarketView(player, payload, houseId)
	local itemId = ItemCatalog.NormalizeId(payload.ItemId or payload.Id)
	if not itemId or not marketItemAllowed(itemId) then return { Ok = false, Error = "Choose a tradeable item." } end
	if tostring(payload.Mode or "") == "BlackMarket" and not blackMarketItemAllowed(itemId) then return { Ok = false, Error = "The Black Market only accepts weapons and armor." } end
	local quality = ItemCatalog.NormalizeQuality(payload.Quality or "Normal")
	local purity = ItemCatalog.NormalizePurity(payload.Purity or "None")
	local stack = { Id = itemId, Amount = 1, Quality = quality, Purity = purity }
	local key = stackKey(stack)
	local house = getHouse(houseId)
	local demandPrice = blackMarket.BuyDemand[key] or baseItemValue(itemId, quality, purity)
	local demandRow = rowForStack(stack)
	demandRow.UnitPrice = demandPrice
	demandRow.Remaining = 1
	return {
		Ok = true,
		Item = rowForStack(stack),
		Auction = {
			SellOrders = rowsForKey(house.SellOrders, key, player, "Sell"),
			BuyOrders = rowsForKey(house.BuyOrders, key, player, "Buy"),
		},
		BlackMarket = {
			SellOrders = rowsForKey(blackMarket.SellOrders, key, player, "Sell"),
			BuyOrders = { demandRow },
		},
		History = {
			Auction = {
				H24 = historyStats(itemId, quality, purity, 1, "Auction"),
				D7 = historyStats(itemId, quality, purity, 7, "Auction"),
				D30 = historyStats(itemId, quality, purity, 30, "Auction"),
			},
			BlackMarket = {
				H24 = historyStats(itemId, quality, purity, 1, "BlackMarket"),
				D7 = historyStats(itemId, quality, purity, 7, "BlackMarket"),
				D30 = historyStats(itemId, quality, purity, 30, "BlackMarket"),
			},
		},
	}
end

local function resolveWorldInteractable(target)
	if typeof(target) ~= "Instance" then return nil end
	local current = target
	while current and current ~= Workspace do
		if current:IsA("Model") or current:IsA("BasePart") then
			local name = string.lower(current.Name)
			local marketType = tostring(current:GetAttribute("MarketType") or "")
			if current:GetAttribute("LootChest") == true or (current:IsA("Model") and name:find("treasurechesttype", 1, true)) then
				return "Chest", current, promptPartFor(current, "MainPrompt")
			end
			if marketType == "Auction" or (current:IsA("Model") and name:find("auction", 1, true)) then
				return "Auction", current, promptPartFor(current, "AuctionOpener")
			end
			if marketType == "BlackMarket" or (current:IsA("Model") and (name:find("blackmarket", 1, true) or name:find("black_market", 1, true))) then
				return "BlackMarket", current, promptPartFor(current, "BlackMarketOpener")
			end
		end
		current = current.Parent
	end
	return nil
end

local function playerNearPart(player, part, distance)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not part then return false end
	return distanceToPartBounds(root, part) <= (distance or Config.MarketDistance)
end

local function openWorldMarket(player, mode, inst, part)
	if not playerNearPart(player, part, Config.MarketDistance) then return { Ok = false, Error = "Move closer." } end
	if mode == "Auction" then
		local houseId = tostring(inst:GetAttribute("AuctionHouseId") or inst:GetAttribute("MarketId") or sanitizeId(inst.Name))
		activeMarket[player] = { Type = "Auction", HouseId = houseId, Part = part }
		OpenMarketInterface:FireClient(player, { Mode = "Auction", HouseId = houseId, Position = part.Position })
		return { Ok = true, Kind = "MarketOpened" }
	end
	activeMarket[player] = { Type = "BlackMarket", HouseId = "BlackMarket", Part = part }
	OpenMarketInterface:FireClient(player, { Mode = "BlackMarket", HouseId = "BlackMarket", Position = part.Position })
	return { Ok = true, Kind = "MarketOpened" }
end

local function chestOpenKey(player, chest)
	return tostring(player.UserId) .. ":" .. chestKeyFor(chest)
end

local function interactLootChest(player, chest, part)
	if not playerNearPart(player, part, Config.MarketDistance) then return { Ok = false, Error = "Move closer." } end
	local okReq, reqErr = checkChestRequirements(player, chest)
	if not okReq then
		MarketNotice:FireClient(player, reqErr)
		return { Ok = false, Error = reqErr }
	end
	if activeChestLoot[chestKeyFor(chest)] then
		return lootChest(player, chest, part)
	end
	local key = chestOpenKey(player, chest)
	local state = activeChestOpening[key]
	local openSeconds = math.max(0.1, tonumber(Config.ChestOpenSeconds) or 2)
	if state and os.clock() - state.StartedAt <= openSeconds then
		local remaining = math.max(0.1, openSeconds - (os.clock() - state.StartedAt))
		MarketNotice:FireClient(player, { Kind = "ChestOpening", Text = "Opening treasure chest", Duration = remaining, StartedAt = state.StartedAt })
		return { Ok = true, Kind = "ChestOpening", Duration = remaining }
	end
	state = { UserId = player.UserId, StartedAt = os.clock() }
	activeChestOpening[key] = state
	MarketNotice:FireClient(player, { Kind = "ChestOpening", Text = "Opening treasure chest", Duration = openSeconds, StartedAt = state.StartedAt })
	task.delay(openSeconds, function()
		if activeChestOpening[key] ~= state then return end
		activeChestOpening[key] = nil
		if not player.Parent then return end
		if not playerNearPart(player, part, Config.MarketDistance) then
			MarketNotice:FireClient(player, "Move closer to finish opening the chest.")
			return
		end
		local reqOk, reqMessage = checkChestRequirements(player, chest)
		if not reqOk then
			MarketNotice:FireClient(player, reqMessage)
			return
		end
		lootChest(player, chest, part)
	end)
	return { Ok = true, Kind = "ChestOpening", Duration = openSeconds }
end

local function worldInteract(player, payload)
	local mode, inst, part = resolveWorldInteractable(payload.Target or payload.Instance)
	if not mode or not inst or not part then return { Ok = false, Error = "Nothing to interact with." } end
	if mode == "Chest" then return interactLootChest(player, inst, part) end
	return openWorldMarket(player, mode, inst, part)
end

local function takeChestLoot(player, payload)
	local chestKey = tostring(payload.ChestKey or payload.chestKey or "")
	local state = activeChestLoot[chestKey]
	if not state then return { Ok = false, Error = "That chest has respawned." } end
	local part = state.PromptPart or promptPartFor(state.Chest, "MainPrompt")
	if not playerNearPart(player, part, Config.MarketDistance) then return { Ok = false, Error = "Move closer." } end
	if not canLootState(player, state) then return { Ok = false, Error = "This loot is protected." } end
	local slot = math.floor(tonumber(payload.Slot or payload.slot) or 0)
	local stack = state.Loot and state.Loot[slot]
	if type(stack) ~= "table" or (tonumber(stack.Amount) or 0) <= 0 then
		local current = chestNoticePayload(chestKey, state)
		current.Ok = false
		current.Error = "That loot slot is empty."
		return current
	end
	local amount = math.clamp(math.floor(tonumber(payload.Amount or payload.amount) or stack.Amount), 1, math.max(1, math.floor(tonumber(stack.Amount) or 1)))
	local added = InventoryService.AddStack(player, copyStack(stack, amount))
	if added <= 0 then
		local current = chestNoticePayload(chestKey, state)
		current.Ok = false
		current.Error = "No inventory space available."
		return current
	end
	stack.Amount = math.max(0, math.floor(tonumber(stack.Amount) or 1) - added)
	if stack.Amount <= 0 then state.Loot[slot] = nil end
	InventoryService.PushSnapshot(player)
	if state.IsDeathSack and not lootHasAny(state.Loot) then
		destroyDeathSackState(chestKey, state)
		return { Ok = true, Kind = "ChestLoot", ChestKey = chestKey, Rewards = {}, LootValue = 0, GridSlots = Config.ChestGridSlots or 24, Title = "Death Sack", Added = added }
	end
	if not state.RespawnAt and not state.IsDeathSack then scheduleChestRespawn(chestKey, state) end
	local current = chestNoticePayload(chestKey, state)
	current.Ok = true
	current.Added = added
	if added < amount then current.Error = "Inventory filled before the whole stack moved." end
	return current
end

local function handleRequest(player, action, payload)
	payload = type(payload) == "table" and payload or {}
	local info = activeMarket[player]
	local houseId = tostring(payload.HouseId or (info and info.HouseId) or "GlobalAuction")
	local ok, err
	if action == "GetSnapshot" then return snapshot(player, payload.Mode or (info and info.Type) or "Auction", houseId) end
	if action == "GetItemMarketView" then return itemMarketView(player, payload, houseId) end
	if action == "WorldInteract" then return worldInteract(player, payload) end
	if action == "TakeChestLoot" then return takeChestLoot(player, payload) end
	if action == "PlaceAuctionSell" then ok, err = placeAuctionSell(player, payload, houseId)
	elseif action == "PlaceAuctionBuy" then ok, err = placeAuctionBuy(player, payload, houseId)
	elseif action == "BuyAuctionOrder" then ok, err = buyAuctionOrder(player, payload, houseId)
	elseif action == "SellToAuctionBuy" then ok, err = sellToAuctionBuy(player, payload, houseId)
	elseif action == "CancelAuctionOrder" then ok, err = cancelAuctionOrder(player, payload, houseId)
	elseif action == "BlackDirectSell" then ok, err = blackDirectSell(player, payload)
	elseif action == "PlaceBlackSellOrder" then ok, err = placeBlackSellOrder(player, payload)
	elseif action == "CancelBlackOrder" then ok, err = cancelBlackOrder(player, payload)
	elseif action == "ClaimItem" then ok, err = claimItem(player, payload)
	elseif action == "ClaimCoin" then ok, err = claimCoin(player)
	else return { Ok = false, Error = "Unknown market action." } end
	return { Ok = ok == true, Error = err, Snapshot = snapshot(player, payload.Mode or (info and info.Type) or "Auction", houseId) }
end

local function saveHouse(houseId)
	local house = auctionHouses[houseId]
	if not house then dirtyAuctionHouses[houseId] = nil return true end
	local data = serializeHouse(houseId, house)
	local ok, err = pcall(function()
		EconomyStore:UpdateAsync(dataKey("AuctionHouse_v1", houseId), function()
			return data
		end)
	end)
	if ok then
		dirtyAuctionHouses[houseId] = nil
	else
		warn("Auction house save failed for " .. tostring(houseId) .. ": " .. tostring(err))
	end
	return ok
end

local function saveBlackMarket()
	local data = serializeBlackMarket()
	local ok, err = pcall(function()
		EconomyStore:UpdateAsync("BlackMarket_v1", function()
			return data
		end)
	end)
	if ok then
		blackMarketDirty = false
	else
		warn("Black market save failed: " .. tostring(err))
	end
	return ok
end

local function savePendingClaimsForUser(userId)
	local claims = pendingClaims[tostring(userId)] or defaultPendingClaims()
	local data = serializePendingClaims(claims)
	local key = dataKey("MarketPendingClaims_v1", userId)
	local ok, err = pcall(function()
		EconomyStore:UpdateAsync(key, function()
			return data
		end)
	end)
	if ok then
		dirtyPendingClaims[tostring(userId)] = nil
	else
		warn("Market pending claim save failed for " .. tostring(userId) .. ": " .. tostring(err))
	end
	return ok
end

local function saveDirtyMarkets()
	if savingMarkets then return end
	savingMarkets = true
	for houseId in pairs(dirtyAuctionHouses) do
		saveHouse(houseId)
	end
	if blackMarketDirty then
		saveBlackMarket()
	end
	for userId in pairs(dirtyPendingClaims) do
		savePendingClaimsForUser(userId)
	end
	savingMarkets = false
end

local function startAutosaveLoop()
	local interval = math.max(30, math.floor(tonumber(Config.MarketSaveIntervalSeconds) or 120))
	task.spawn(function()
		while started do
			task.wait(interval)
			saveDirtyMarkets()
		end
	end)
end

function EconomyMarketService.Start()
	if started then return end
	started = true
	loadBlackMarket()
	seedBlackMarketForTesting()
	MarketRequest.OnServerInvoke = handleRequest
	setupInteractables()
	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(applyPendingClaims, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.defer(applyPendingClaims, player)
	end)
	Players.PlayerRemoving:Connect(clearPlayerSessionState)
	startAutosaveLoop()
	game:BindToClose(function()
		saveDirtyMarkets()
	end)
end

return EconomyMarketService