--[[
Name: MarketEconomyClient
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.MarketEconomyClient
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage, RunService, UserInputService
Requires:
  - local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
  - local ImageCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ImageCatalog"))
  - local Effects = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util"):WaitForCh...
Functions: catalogItemAllowed, blackMarketEligible, csvContains, comma, money, mk, corner, stroke, styleButton, clearGui, showToast, request, selectedCategory, selectedQuality, selectedPurity, rowCategory, passesFilters, sortedFiltered, catalogRows, rowKey, bestAuctionBuy, renderFilterText, updateScale, makeCycleButton, amountValue, priceValue, refreshFromResult, perform, setTab, renderTabs, addEmpty, addSection, makeRow, closeLootPopup, showLootPopup, openDetails, takeSlot, statText, openTradePopup, supportsQuality, supportsPurity, normalizeAction, matchingInventoryStack, reopen, makeDropdown, showSelector, refill, makeSliderRow, syncVisual, setValue, setFromPosition, beginSlider, percentFee, canConfirm, refreshTotals, makeBook, renderAuctionBuy, renderAuctionSell, renderAuctionBuyOrder, renderAuctionOrders
Clean source lines: 1482
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")
local MarketRequest = remotes:WaitForChild("EconomyMarketRequest")
local OpenMarketInterface = remotes:WaitForChild("OpenMarketInterface")
local MarketNotice = remotes:WaitForChild("MarketNotice")

local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local ImageCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ImageCatalog"))
local Effects = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util"):WaitForChild("Effects"))

local THEME = {
	background = Color3.fromRGB(18, 14, 13),
	panel = Color3.fromRGB(28, 21, 18),
	panel2 = Color3.fromRGB(39, 29, 24),
	line = Color3.fromRGB(188, 138, 54),
	lineDim = Color3.fromRGB(104, 78, 42),
	text = Color3.fromRGB(242, 229, 202),
	subtle = Color3.fromRGB(190, 176, 146),
	green = Color3.fromRGB(58, 126, 83),
	red = Color3.fromRGB(130, 45, 35),
	blue = Color3.fromRGB(54, 86, 124),
}

local AUCTION_TABS = { "Buy", "Sell", "Buy Order", "Orders", "Claim" }
local BLACK_TABS = { "Sell", "Orders", "Claim" }
local CATEGORIES = { "All", "Weapons", "Armor", "Resources", "Utility" }
local QUALITIES = { "All", "Dull", "Normal", "Fine", "Refined", "Superior", "Exceptional", "Legendary", "Artifact" }
local PURITIES = { "All", "None", "Faint", "Kindled", "Ignited", "Ashen Forged" }
local BLACK_MARKET_TYPES = { Weapon = true, Armor = true }

local state = {
	Mode = "Auction",
	HouseId = "GlobalAuction",
	Tab = "Buy",
	Snapshot = nil,
	OpenPosition = nil,
	OpenedAt = 0,
	Filters = { Search = "", CategoryIndex = 1, Tier = "All", QualityIndex = 1, PurityIndex = 1, SortHigh = false },
}

local function catalogItemAllowed(def)
	if type(def) ~= "table" or def.NotAuctionable == true then return false end
	if def.Type == "CoinSack" then return false end
	local tags = def.Tags or def.tags
	if type(tags) == "table" then
		for key, value in pairs(tags) do
			if key == "NotAuctionable" and value == true then return false end
			if value == "NotAuctionable" then return false end
		end
	end
	return true
end

local function blackMarketEligible(row)
	return type(row) == "table" and BLACK_MARKET_TYPES[tostring(row.Type or "")] == true
end

local function csvContains(csv, value)
	value = tostring(value or "")
	for entry in string.gmatch(tostring(csv or ""), "[^,]+") do
		if entry == value then return true end
	end
	return false
end

local deathSackParticleClock = 0
RunService.Heartbeat:Connect(function(dt)
	deathSackParticleClock += dt
	if deathSackParticleClock < 0.5 then return end
	deathSackParticleClock = 0
	local folder = workspace:FindFirstChild("DeathSacks")
	if not folder then return end
	local nowTime = os.time()
	for _, sack in ipairs(folder:GetChildren()) do
		if sack:GetAttribute("DeathSack") == true then
			local protectedUntil = math.floor(tonumber(sack:GetAttribute("ProtectedUntil")) or 0)
			local allowed = nowTime >= protectedUntil or csvContains(sack:GetAttribute("AllowedUserIds"), player.UserId)
			for _, emitter in ipairs(sack:GetDescendants()) do
				if emitter:IsA("ParticleEmitter") then
					emitter.Enabled = allowed
				end
			end
		end
	end
end)

local gui
local main
local uiScale
local titleLabel
local coinLabel
local coinExactTooltip
local closeButton
local tabRail
local content
local filterBar
local searchBox
local categoryButton
local tierButton
local qualityButton
local purityButton
local sortButton
local controls
local priceBox
local amountBox
local toast
local lootPopup
local lootOpenPosition
local lootOpenedAt = 0
local lootCloseDistance = 6
local tradePopup
local chestOpeningBar
local chestOpeningConn
local ensureGui

local function comma(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	local left, num, right = text:match("^([^%d]*%d)(%d*)(.-)$")
	if not num then return text end
	return left .. num:reverse():gsub("(%d%d%d)", "%1,"):reverse() .. right
end

local function money(value)
	local n = math.max(0, math.floor(tonumber(value) or 0))
	if n < 10000 then return comma(n) end
	local units = {
		{ Value = 1000000000000, Suffix = "t" },
		{ Value = 1000000000, Suffix = "b" },
		{ Value = 1000000, Suffix = "m" },
		{ Value = 1000, Suffix = "K" },
	}
	for _, unit in ipairs(units) do
		if n >= unit.Value then
			local scaled = n / unit.Value
			if scaled < 10 then
				return string.format("%.1f%s", math.floor(scaled * 10) / 10, unit.Suffix):gsub("%.0", "")
			end
			return tostring(math.floor(scaled)) .. unit.Suffix
		end
	end
	return tostring(n)
end

local function mk(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props or {}) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function stroke(parent, thickness, color, transparency)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 1
	s.Color = color or THEME.line
	s.Transparency = transparency or 0.2
	s.Parent = parent
	return s
end

local function styleButton(button, color)
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or THEME.panel2
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = THEME.text
	button.TextSize = 13
	button.TextWrapped = true
	corner(button, 7)
	stroke(button, 1, THEME.line, 0.35)
end

local function clearGui(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function showToast(message)
	if ensureGui then ensureGui() end
	if gui then gui.Enabled = true end
	message = tostring(message or "")
	if message == "" then return end
	if toast then toast:Destroy() end
	toast = mk("TextLabel", {
		Name = "MarketToast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(0.64, 0, 0, 38),
		BackgroundColor3 = THEME.panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = message,
		TextColor3 = THEME.text,
		TextSize = 14,
		TextWrapped = true,
		ZIndex = 300,
	}, gui)
	corner(toast, 8)
	stroke(toast, 1, THEME.line, 0.2)
	task.delay(4, function()
		if toast then toast:Destroy(); toast = nil end
	end)
end

local function request(action, payload)
	payload = type(payload) == "table" and payload or {}
	payload.Mode = state.Mode
	payload.HouseId = state.HouseId
	local ok, result = pcall(function()
		return MarketRequest:InvokeServer(action, payload)
	end)
	if not ok then
		showToast("Market request failed.")
		warn("[MarketEconomyClient] " .. tostring(result))
		return nil
	end
	if type(result) == "table" and result.Ok == false and result.Error then
		showToast(result.Error)
	end
	return result
end

local function selectedCategory()
	return CATEGORIES[state.Filters.CategoryIndex] or "All"
end

local function selectedQuality(defaultValue)
	local quality = QUALITIES[state.Filters.QualityIndex] or "All"
	if quality == "All" then return defaultValue or "Normal" end
	return quality
end

local function selectedPurity(defaultValue)
	local purity = PURITIES[state.Filters.PurityIndex] or "All"
	if purity == "All" then return defaultValue or "None" end
	return purity
end

local function rowCategory(row)
	local kind = tostring(row.Type or "")
	if kind == "Weapon" then return "Weapons" end
	if kind == "Armor" or kind == "Bag" then return "Armor" end
	if kind == "Resource" or kind == "RefinedResource" then return "Resources" end
	return "Utility"
end

local function passesFilters(row)
	local query = string.lower(state.Filters.Search or "")
	if query ~= "" then
		local hay = string.lower(tostring(row.DisplayName or row.Id or "") .. " " .. tostring(row.Id or ""))
		if not string.find(hay, query, 1, true) then return false end
	end
	local category = selectedCategory()
	if category ~= "All" and rowCategory(row) ~= category then return false end
	if state.Filters.Tier ~= "All" and tonumber(row.Tier) ~= tonumber(state.Filters.Tier) then return false end
	local qualityFilter = QUALITIES[state.Filters.QualityIndex] or "All"
	if qualityFilter ~= "All" and ItemCatalog.NormalizeQuality(row.Quality or "Normal") ~= qualityFilter then return false end
	local purityFilter = PURITIES[state.Filters.PurityIndex] or "All"
	if purityFilter ~= "All" and ItemCatalog.NormalizePurity(row.Purity or "None") ~= purityFilter then return false end
	return true
end

local function sortedFiltered(rows)
	local out = {}
	for _, row in ipairs(rows or {}) do
		if passesFilters(row) then table.insert(out, row) end
	end
	table.sort(out, function(a, b)
		local ap = tonumber(a.UnitPrice or a.EstimatedValue or a.Value or 0) or 0
		local bp = tonumber(b.UnitPrice or b.EstimatedValue or b.Value or 0) or 0
		if ap == bp then return tostring(a.DisplayName or a.Id) < tostring(b.DisplayName or b.Id) end
		if state.Filters.SortHigh then return ap > bp end
		return ap < bp
	end)
	return out
end

local function catalogRows()
	local rows = {}
	for id, def in pairs(ItemCatalog.Items or {}) do
		if catalogItemAllowed(def) then
			local row = {
				Id = id,
				Amount = 1,
				DisplayName = def.DisplayName or id,
				Type = def.Type or "Item",
				Tier = def.Tier or 1,
				Quality = selectedQuality("Normal"),
				Purity = selectedPurity("None"),
				Icon = def.Icon or "Default",
				Value = def.Value or 0,
				Power = ItemCatalog.ItemPower(id, selectedQuality("Normal"), selectedPurity("None")),
			}
			table.insert(rows, row)
		end
	end
	return rows
end

local function rowKey(row)
	return table.concat({ tostring(row.Id), ItemCatalog.NormalizeQuality(row.Quality or "Normal"), ItemCatalog.NormalizePurity(row.Purity or "None") }, "|")
end

local function bestAuctionBuy(row)
	local snapshot = state.Snapshot or {}
	local best
	for _, order in ipairs(snapshot.Auction and snapshot.Auction.BuyOrders or {}) do
		if rowKey(order) == rowKey(row) and (not best or order.UnitPrice > best.UnitPrice) then
			best = order
		end
	end
	return best
end

local function renderFilterText()
	if not categoryButton then return end
	categoryButton.Text = "Category: " .. selectedCategory()
	tierButton.Text = "Tier: " .. tostring(state.Filters.Tier)
	qualityButton.Text = "Quality: " .. (QUALITIES[state.Filters.QualityIndex] or "All")
	purityButton.Text = "Purity: " .. (PURITIES[state.Filters.PurityIndex] or "All")
	sortButton.Text = state.Filters.SortHigh and "Price: High" or "Price: Low"
	if searchBox and searchBox.Text ~= state.Filters.Search then searchBox.Text = state.Filters.Search end
end

local function updateScale()
	if not uiScale then return end
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	uiScale.Scale = math.clamp(math.min(viewport.X / 1120, viewport.Y / 720), 0.64, 1)
end

local render

local function makeCycleButton(parent, layoutOrder, text, onClick)
	local button = mk("TextButton", {
		Text = text,
		Size = UDim2.new(0, 128, 1, 0),
		LayoutOrder = layoutOrder,
		ZIndex = 42,
	}, parent)
	styleButton(button, THEME.panel2)
	button.Activated:Connect(function()
		onClick()
		renderFilterText()
		render()
	end)
	return button
end

ensureGui = function()
	if gui then return end
	gui = mk("ScreenGui", {
		Name = "MarketEconomyGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 80,
		Enabled = true,
	}, playerGui)

	main = mk("Frame", {
		Name = "MarketPanel",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.52, 0),
		Size = UDim2.new(0.88, 0, 0.78, 0),
		BackgroundColor3 = THEME.background,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Visible = false,
		ZIndex = 30,
	}, gui)
	corner(main, 8)
	stroke(main, 1.5, THEME.line, 0.08)
	uiScale = Instance.new("UIScale")
	uiScale.Parent = main
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(420, 330)
	sizeLimit.MaxSize = Vector2.new(1040, 690)
	sizeLimit.Parent = main

	titleLabel = mk("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "Auction House",
		TextColor3 = THEME.text,
		TextSize = 23,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 20, 0, 12),
		Size = UDim2.new(1, -270, 0, 34),
		ZIndex = 31,
	}, main)

	coinLabel = mk("TextLabel", {
		Name = "Coins",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Coin: 0",
		TextColor3 = THEME.text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -246, 0, 14),
		Size = UDim2.new(0, 196, 0, 28),
		ZIndex = 31,
	}, main)
	coinLabel.Active = true
	coinExactTooltip = mk("TextLabel", {
		Name = "CoinExactTooltip",
		BackgroundColor3 = THEME.panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Coin: 0",
		TextColor3 = THEME.text,
		TextSize = 13,
		Visible = false,
		Position = UDim2.new(1, -238, 0, -20),
		Size = UDim2.fromOffset(188, 28),
		ZIndex = 65,
	}, main)
	corner(coinExactTooltip, 7)
	stroke(coinExactTooltip, 1, THEME.line, 0.16)
	coinLabel.MouseEnter:Connect(function()
		coinExactTooltip.Visible = true
	end)
	coinLabel.MouseLeave:Connect(function()
		coinExactTooltip.Visible = false
	end)

	closeButton = mk("TextButton", {
		Name = "Close",
		Text = "X",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 2, 0, -2),
		Size = UDim2.fromOffset(34, 34),
		ZIndex = 60,
	}, main)
	styleButton(closeButton, THEME.red)
	closeButton.Activated:Connect(function()
		main.Visible = false
		if tradePopup then tradePopup:Destroy(); tradePopup = nil end
	end)

	filterBar = mk("Frame", {
		Name = "FilterBar",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 58),
		Size = UDim2.new(1, -124, 0, 34),
		ZIndex = 40,
	}, main)
	local filterLayout = Instance.new("UIListLayout")
	filterLayout.FillDirection = Enum.FillDirection.Horizontal
	filterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	filterLayout.Padding = UDim.new(0, 8)
	filterLayout.Parent = filterBar

	searchBox = mk("TextBox", {
		Name = "Search",
		PlaceholderText = "Search",
		Text = "",
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.text,
		PlaceholderColor3 = THEME.subtle,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = THEME.panel2,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 150, 1, 0),
		LayoutOrder = 1,
		ZIndex = 42,
	}, filterBar)
	corner(searchBox, 7); stroke(searchBox, 1, THEME.lineDim, 0.35)
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		state.Filters.Search = searchBox.Text
		render()
	end)

	categoryButton = makeCycleButton(filterBar, 2, "Category: All", function()
		state.Filters.CategoryIndex = (state.Filters.CategoryIndex % #CATEGORIES) + 1
	end)
	tierButton = makeCycleButton(filterBar, 3, "Tier: All", function()
		if state.Filters.Tier == "All" then
			state.Filters.Tier = 1
		elseif state.Filters.Tier >= 20 then
			state.Filters.Tier = "All"
		else
			state.Filters.Tier += 1
		end
	end)
	qualityButton = makeCycleButton(filterBar, 4, "Quality: All", function()
		state.Filters.QualityIndex = (state.Filters.QualityIndex % #QUALITIES) + 1
	end)
	purityButton = makeCycleButton(filterBar, 5, "Purity: All", function()
		state.Filters.PurityIndex = (state.Filters.PurityIndex % #PURITIES) + 1
	end)
	sortButton = makeCycleButton(filterBar, 6, "Price: Low", function()
		state.Filters.SortHigh = not state.Filters.SortHigh
	end)

	controls = mk("Frame", {
		Name = "OrderControls",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 18, 0, 100),
		Size = UDim2.new(1, -124, 0, 34),
		ZIndex = 40,
	}, main)
	local controlLayout = Instance.new("UIListLayout")
	controlLayout.FillDirection = Enum.FillDirection.Horizontal
	controlLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlLayout.Padding = UDim.new(0, 8)
	controlLayout.Parent = controls

	priceBox = mk("TextBox", {
		Name = "Price",
		PlaceholderText = "Price each",
		Text = "100",
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.text,
		PlaceholderColor3 = THEME.subtle,
		TextSize = 14,
		BackgroundColor3 = THEME.panel2,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(142, 34),
		LayoutOrder = 1,
		ZIndex = 42,
	}, controls)
	corner(priceBox, 7); stroke(priceBox, 1, THEME.lineDim, 0.35)
	amountBox = mk("TextBox", {
		Name = "Amount",
		PlaceholderText = "Amount",
		Text = "1",
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.text,
		PlaceholderColor3 = THEME.subtle,
		TextSize = 14,
		BackgroundColor3 = THEME.panel2,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(112, 34),
		LayoutOrder = 2,
		ZIndex = 42,
	}, controls)
	corner(amountBox, 7); stroke(amountBox, 1, THEME.lineDim, 0.35)

	content = mk("ScrollingFrame", {
		Name = "Content",
		Active = true,
		BackgroundColor3 = THEME.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 0, 100),
		Size = UDim2.new(1, -124, 1, -120),
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 32,
	}, main)
	corner(content, 8)
	stroke(content, 1, THEME.lineDim, 0.35)
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, 7)
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = content
	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 10)
	contentPadding.PaddingBottom = UDim.new(0, 10)
	contentPadding.PaddingLeft = UDim.new(0, 10)
	contentPadding.PaddingRight = UDim.new(0, 10)
	contentPadding.Parent = content

	tabRail = mk("Frame", {
		Name = "TabRail",
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -94, 0, 58),
		Size = UDim2.new(0, 76, 1, -76),
		ZIndex = 40,
	}, main)
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabRail

	local camera = workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end
	updateScale()
	renderFilterText()
end

local function amountValue(maxAmount)
	local amount = math.max(1, math.floor(tonumber(amountBox and amountBox.Text) or 1))
	if maxAmount then amount = math.min(amount, math.max(1, tonumber(maxAmount) or 1)) end
	return amount
end

local function priceValue(fallback)
	return math.max(1, math.floor(tonumber(priceBox and priceBox.Text) or tonumber(fallback) or 1))
end

local function refreshFromResult(result)
	if type(result) == "table" and type(result.Snapshot) == "table" then
		state.Snapshot = result.Snapshot
	elseif type(result) == "table" and result.Ok and result.Economy then
		state.Snapshot = result
	else
		local fresh = request("GetSnapshot", { Mode = state.Mode, HouseId = state.HouseId })
		if type(fresh) == "table" and fresh.Ok then state.Snapshot = fresh end
	end
	render()
end

local function perform(action, payload)
	local result = request(action, payload or {})
	refreshFromResult(result)
end

local function setTab(tab)
	state.Tab = tab
	render()
end

local function renderTabs()
	clearGui(tabRail)
	local tabs = state.Mode == "BlackMarket" and BLACK_TABS or AUCTION_TABS
	for i, tabName in ipairs(tabs) do
		local button = mk("TextButton", {
			Text = tabName,
			Size = UDim2.new(1, 0, 0, 42),
			LayoutOrder = i,
			ZIndex = 45,
		}, tabRail)
		styleButton(button, state.Tab == tabName and THEME.lineDim or THEME.panel2)
		button.Activated:Connect(function() setTab(tabName) end)
	end
end

local function addEmpty(text)
	mk("TextLabel", {
		Name = "Empty",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = text or "No results.",
		TextColor3 = THEME.subtle,
		TextSize = 14,
		TextWrapped = true,
		Size = UDim2.new(1, -8, 0, 34),
		ZIndex = 36,
	}, content)
end

local function addSection(text)
	mk("TextLabel", {
		Name = "Section",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = text,
		TextColor3 = THEME.text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -8, 0, 24),
		ZIndex = 36,
	}, content)
end

local function makeRow(row, buttons, note)
	local buttonCount = #buttons
	local rightWidth = buttonCount > 0 and (buttonCount * 78 + (buttonCount - 1) * 6 + 10) or 8
	local frame = mk("Frame", {
		Name = "Row",
		BackgroundColor3 = THEME.panel2,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -8, 0, 68),
		ZIndex = 36,
	}, content)
	corner(frame, 7)
	stroke(frame, 1, THEME.lineDim, 0.45)

	local icon = mk("ImageLabel", {
		BackgroundColor3 = THEME.background,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0.5, -24),
		Size = UDim2.fromOffset(48, 48),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 37,
	}, frame)
	corner(icon, 6)
	pcall(function() ImageCatalog.SetImage(icon, row.Icon or "Default") end)

	local name = mk("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = tostring(row.DisplayName or row.Id or "Item"),
		TextColor3 = THEME.text,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 64, 0, 8),
		Size = UDim2.new(1, -(72 + rightWidth), 0, 20),
		ZIndex = 37,
	}, frame)

	local quality = ItemCatalog.NormalizeQuality(row.Quality or "Normal")
	local purity = ItemCatalog.NormalizePurity(row.Purity or "None")
	local purityText = purity == "None" and "No Purity" or purity
	local detailText = string.format("T%s %s | %s | %s", tostring(row.Tier or 1), tostring(row.Type or "Item"), quality, purityText)
	if row.Power then detailText ..= " | Power " .. tostring(row.Power) end
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = detailText,
		TextColor3 = THEME.subtle,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 64, 0, 30),
		Size = UDim2.new(1, -(72 + rightWidth), 0, 16),
		ZIndex = 37,
	}, frame)
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = note or "",
		TextColor3 = THEME.text,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 64, 0, 48),
		Size = UDim2.new(1, -(72 + rightWidth), 0, 14),
		ZIndex = 37,
	}, frame)

	for i, info in ipairs(buttons) do
		local button = mk("TextButton", {
			Text = info.Text,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8 - ((buttonCount - i) * 84), 0.5, 0),
			Size = UDim2.fromOffset(78, 32),
			ZIndex = 38,
		}, frame)
		styleButton(button, info.Color or THEME.blue)
		button.TextSize = 12
		button.Activated:Connect(info.Action)
	end
end

local function closeLootPopup()
	if lootPopup then
		lootPopup:Destroy()
		lootPopup = nil
	end
	lootOpenPosition = nil
	lootOpenedAt = 0
end

local function showLootPopup(payload)
	ensureGui()
	gui.Enabled = true
	payload = type(payload) == "table" and payload or {}
	local rewards = payload.Rewards or payload
	local chestKey = payload.ChestKey
	closeLootPopup()
	if typeof(payload.Position) == "Vector3" then
		lootOpenPosition = payload.Position
	end
	lootOpenedAt = os.clock()
	lootCloseDistance = math.max(1, tonumber(payload.CloseDistance) or 6)
	local gridSlots = math.max(24, math.floor(tonumber(payload.GridSlots) or 24))
	lootPopup = mk("Frame", {
		Name = "LootPopup",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.5, 0, 0.58, 0),
		BackgroundColor3 = THEME.background,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
		ZIndex = 140,
	}, gui)
	corner(lootPopup, 8)
	stroke(lootPopup, 1.5, THEME.line, 0.08)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(340, 310)
	limit.MaxSize = Vector2.new(650, 520)
	limit.Parent = lootPopup
	mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = tostring(payload.Title or "Treasure Loot"), TextColor3 = THEME.text, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 18, 0, 12), Size = UDim2.new(1, -76, 0, 32), ZIndex = 141 }, lootPopup)
	local close = mk("TextButton", { Text = "X", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 2, 0, -2), Size = UDim2.fromOffset(34, 34), ZIndex = 145 }, lootPopup)
	styleButton(close, THEME.red)
	close.Activated:Connect(closeLootPopup)
	local valueLabel = mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "Estimated value: " .. money(payload.LootValue or 0), TextColor3 = THEME.text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 18, 1, -38), Size = UDim2.new(1, -36, 0, 24), ZIndex = 141 }, lootPopup)
	local grid = mk("ScrollingFrame", { Active = true, BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.1, BorderSizePixel = 0, Position = UDim2.new(0, 16, 0, 56), Size = UDim2.new(1, -32, 1, -104), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 5, ZIndex = 141 }, lootPopup)
	corner(grid, 8)
	stroke(grid, 1, THEME.lineDim, 0.35)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(66, 66)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = grid
	local bySlot = {}
	local highestSlot = gridSlots
	for index, reward in ipairs(rewards or {}) do
		local slot = math.max(1, math.floor(tonumber(reward.Slot) or index))
		bySlot[slot] = reward
		highestSlot = math.max(highestSlot, slot)
	end
	local function openDetails(row)
		local detail = ItemCatalog.BuildDetail(row, { Source = tostring(payload.Title or "Treasure Chest") })
		if detail and type(_G.OpenItemDetail) == "function" then
			_G.OpenItemDetail(detail)
		else
			showToast(tostring(row.DisplayName or row.Id or "Item"))
		end
	end
	local function takeSlot(row)
		if not chestKey or not row then return end
		local result = request("TakeChestLoot", { ChestKey = chestKey, Slot = row.Slot, Amount = row.Amount })
		if type(result) == "table" and result.Kind == "ChestLoot" then
			showLootPopup(result)
		end
		if type(result) == "table" and result.Error then showToast(result.Error) end
	end
	for slot = 1, highestSlot do
		local reward = bySlot[slot]
		local cell = mk("Frame", { Active = true, BackgroundColor3 = THEME.panel2, BackgroundTransparency = reward and 0.04 or 0.34, BorderSizePixel = 0, LayoutOrder = slot, ZIndex = 142 }, grid)
		corner(cell, 7)
		stroke(cell, 1, reward and THEME.lineDim or THEME.panel2, reward and 0.35 or 0.55)
		if reward then
			reward.Slot = slot
			local icon = mk("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.new(0, 9, 0, 7), Size = UDim2.fromOffset(48, 48), ScaleType = Enum.ScaleType.Fit, ZIndex = 143 }, cell)
			pcall(function() ImageCatalog.SetImage(icon, reward.Icon or "Default") end)
			local amount = math.max(1, math.floor(tonumber(reward.Amount) or 1))
			if amount > 1 then
				local count = mk("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(46, 18), BackgroundColor3 = Color3.fromRGB(10, 8, 7), BackgroundTransparency = 0.12, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, Text = "x" .. comma(amount), TextColor3 = THEME.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 145 }, cell)
				count.TextStrokeTransparency = 0.25
				count.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
				corner(count, 5)
			end
			local button = mk("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 146 }, cell)
			local beganAt
			local moved = false
			button.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
				beganAt = Vector2.new(input.Position.X, input.Position.Y)
				moved = false
				local moveConn
				local endConn
				moveConn = UserInputService.InputChanged:Connect(function(changed)
					if not beganAt then return end
					if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
						local current = Vector2.new(changed.Position.X, changed.Position.Y)
						if (current - beganAt).Magnitude > 8 then moved = true end
					end
				end)
				endConn = UserInputService.InputEnded:Connect(function(ended)
					if ended.UserInputType ~= input.UserInputType then return end
					if moveConn then moveConn:Disconnect() end
					if endConn then endConn:Disconnect() end
					local shiftDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
					if moved or shiftDown then
						takeSlot(reward)
					else
						openDetails(reward)
					end
					beganAt = nil
				end)
			end)
		end
	end
	if #(rewards or {}) == 0 then
		valueLabel.Text = "Estimated value: 0"
	end
end

local function statText(stats)
	if type(stats) ~= "table" or not stats.Average then return "-" end
	return string.format("%s avg / %s sold", money(stats.Average), comma(stats.Sold or 0))
end

local function openTradePopup(action, row)
	ensureGui()
	row = type(row) == "table" and row or {}
	if tradePopup then tradePopup:Destroy(); tradePopup = nil end
	local selectedId = ItemCatalog.NormalizeId(row.Id or row.ItemId)
	if not selectedId then return end
	local selectedDef = ItemCatalog.Get(selectedId)
	if not selectedDef or not catalogItemAllowed(selectedDef) then showToast("That item cannot be traded here."); return end

	local function supportsQuality(def)
		local itemType = tostring(def and def.Type or "")
		return itemType == "Weapon" or itemType == "Armor" or itemType == "Bag"
	end
	local function supportsPurity(def)
		local tier = math.floor(tonumber(def and def.Tier) or 1)
		return tier >= 4 and supportsQuality(def)
	end
	local function normalizeAction(value)
		value = tostring(value or "Buy")
		if value == "SellNow" then return "Sell" end
		if value == "BuyOrder" or value == "SellOrder" or value == "BlackDirect" or value == "BlackSellOrder" then return value end
		if value == "Sell" or value == "Buy" then return value end
		return state.Mode == "BlackMarket" and "BlackDirect" or "Buy"
	end

	local currentAction = normalizeAction(action)
	if state.Mode == "BlackMarket" and currentAction ~= "BlackDirect" and currentAction ~= "BlackSellOrder" then currentAction = "BlackDirect" end
	if state.Mode ~= "BlackMarket" and (currentAction == "BlackDirect" or currentAction == "BlackSellOrder") then currentAction = "Sell" end
	local selectedQuality = ItemCatalog.NormalizeQuality(row.Quality or selectedDef.Quality or "Normal")
	local selectedPurity = ItemCatalog.NormalizePurity(row.Purity or selectedDef.Purity or "None")
	if not supportsQuality(selectedDef) then selectedQuality = "Normal" end
	if not supportsPurity(selectedDef) then selectedPurity = "None" end

	local view = request("GetItemMarketView", { ItemId = selectedId, Quality = selectedQuality, Purity = selectedPurity, Mode = state.Mode, HouseId = state.HouseId })
	if not (type(view) == "table" and view.Ok) then return end
	local books = state.Mode == "BlackMarket" and view.BlackMarket or view.Auction
	local history = (state.Mode == "BlackMarket" and view.History.BlackMarket or view.History.Auction) or {}
	local item = view.Item or row
	local sellOrders = books and books.SellOrders or {}
	local buyOrders = books and books.BuyOrders or {}

	local function matchingInventoryStack()
		local best
		for _, inv in ipairs((state.Snapshot and state.Snapshot.Inventory) or {}) do
			if inv.Id == selectedId and ItemCatalog.NormalizeQuality(inv.Quality or "Normal") == selectedQuality and ItemCatalog.NormalizePurity(inv.Purity or "None") == selectedPurity then
				if not best or (tonumber(inv.Amount) or 0) > (tonumber(best.Amount) or 0) then best = inv end
			end
		end
		return best
	end
	local inventoryRow = matchingInventoryStack()
	local currentRow = inventoryRow or {
		Id = selectedId,
		Amount = 1,
		DisplayName = selectedDef.DisplayName or selectedId,
		Type = selectedDef.Type or "Item",
		Tier = selectedDef.Tier or 1,
		Quality = selectedQuality,
		Purity = selectedPurity,
		Icon = selectedDef.Icon or "Default",
		Value = selectedDef.Value or 0,
		Power = ItemCatalog.ItemPower(selectedId, selectedQuality, selectedPurity),
	}

	local function reopen(nextAction, nextId, nextQuality, nextPurity)
		openTradePopup(nextAction or currentAction, { Id = nextId or selectedId, Quality = nextQuality or selectedQuality, Purity = nextPurity or selectedPurity })
	end

	local bestSell = sellOrders[1]
	local bestBuy = buyOrders[1]
	local maxAmount = 1
	local defaultAmount = 1
	if currentAction == "BuyOrder" then
		maxAmount = 9999
	elseif currentAction == "Buy" then
		maxAmount = math.min(999, math.max(1, tonumber(bestSell and bestSell.Remaining) or 1))
		defaultAmount = 1
	elseif currentAction == "Sell" then
		local ownedAmount = math.max(1, tonumber(inventoryRow and inventoryRow.Amount) or 1)
		maxAmount = math.min(999, ownedAmount, math.max(1, tonumber(bestBuy and bestBuy.Remaining) or 1))
		defaultAmount = inventoryRow and math.min(999, ownedAmount) or 1
	elseif currentAction == "SellOrder" or currentAction == "BlackDirect" or currentAction == "BlackSellOrder" then
		maxAmount = math.min(999, math.max(1, tonumber(inventoryRow and inventoryRow.Amount) or 1))
		defaultAmount = inventoryRow and maxAmount or 1
	end
	defaultAmount = math.clamp(defaultAmount, 1, maxAmount)
	local defaultPrice = math.max(1, math.floor(tonumber(currentRow.EstimatedValue or currentRow.UnitPrice or currentRow.Value or item.Value) or 1))
	if currentAction == "Buy" and bestSell then defaultPrice = math.max(1, tonumber(bestSell.UnitPrice) or defaultPrice) end
	if (currentAction == "Sell" or currentAction == "BlackDirect") and bestBuy then defaultPrice = math.max(1, tonumber(bestBuy.UnitPrice) or defaultPrice) end
	local priceMax = (currentAction == "Buy" or currentAction == "Sell" or currentAction == "BlackDirect") and defaultPrice or math.max(10, defaultPrice * 3, defaultPrice + 1000)

	tradePopup = mk("Frame", { Name = "TradePopup", Active = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.84), BackgroundColor3 = THEME.background, BackgroundTransparency = 0.01, BorderSizePixel = 0, ZIndex = 110 }, gui)
	corner(tradePopup, 8)
	stroke(tradePopup, 1.5, THEME.line, 0.08)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(260, 360)
	limit.MaxSize = Vector2.new(1120, 720)
	limit.Parent = tradePopup
	local close = mk("TextButton", { Text = "X", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1.01, -0.01), Size = UDim2.fromScale(0.045, 0.07), ZIndex = 160 }, tradePopup)
	styleButton(close, THEME.red)
	close.Activated:Connect(function() if tradePopup then tradePopup:Destroy(); tradePopup = nil end end)

	local left = mk("Frame", { Active = true, BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Position = UDim2.fromScale(0.025, 0.035), Size = UDim2.fromScale(0.385, 0.93), ZIndex = 111 }, tradePopup)
	corner(left, 8); stroke(left, 1, THEME.lineDim, 0.35)
	local icon = mk("ImageLabel", { BackgroundColor3 = THEME.background, BackgroundTransparency = 0.1, BorderSizePixel = 0, Position = UDim2.fromScale(0.04, 0.035), Size = UDim2.fromScale(0.18, 0.13), ScaleType = Enum.ScaleType.Fit, ZIndex = 112 }, left)
	corner(icon, 7)
	pcall(function() ImageCatalog.SetImage(icon, item.Icon or currentRow.Icon or "Default") end)
	mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = tostring(item.DisplayName or currentRow.DisplayName or selectedId), TextColor3 = THEME.text, TextSize = 17, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.26, 0.035), Size = UDim2.fromScale(0.70, 0.09), ZIndex = 112 }, left)
	mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = string.format("T%s %s | %s | %s", tostring(item.Tier or currentRow.Tier or 1), tostring(item.Type or currentRow.Type or "Item"), selectedQuality, selectedPurity == "None" and "No Purity" or selectedPurity), TextColor3 = THEME.subtle, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.26, 0.12), Size = UDim2.fromScale(0.70, 0.045), ZIndex = 112 }, left)

	local function makeDropdown(label, text, xScale, enabled, callback)
		local button = mk("TextButton", { Text = label .. "\n" .. tostring(text), AutoButtonColor = enabled, Font = Enum.Font.GothamBold, TextColor3 = enabled and THEME.text or Color3.fromRGB(120, 112, 96), TextSize = 11, TextWrapped = true, BackgroundColor3 = enabled and THEME.panel2 or Color3.fromRGB(25, 23, 22), BorderSizePixel = 0, Position = UDim2.fromScale(xScale + 0.035, 0.205), Size = UDim2.fromScale(0.28, 0.09), ZIndex = 112 }, left)
		corner(button, 7); stroke(button, 1, enabled and THEME.lineDim or Color3.fromRGB(65, 58, 48), 0.35)
		if enabled then button.Activated:Connect(callback) end
		return button
	end

	local function showSelector(title, options, onSelect, searchable)
		local overlay = mk("Frame", { Active = true, BackgroundColor3 = THEME.background, BackgroundTransparency = 0.02, BorderSizePixel = 0, Position = UDim2.fromScale(0.04, 0.11), Size = UDim2.fromScale(0.43, 0.78), ZIndex = 170 }, tradePopup)
		corner(overlay, 8); stroke(overlay, 1, THEME.line, 0.08)
		mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = title, TextColor3 = THEME.text, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -58, 0, 28), ZIndex = 171 }, overlay)
		local x = mk("TextButton", { Text = "X", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(30, 30), ZIndex = 172 }, overlay)
		styleButton(x, THEME.red)
		x.Activated:Connect(function() overlay:Destroy() end)
		local search = searchable and mk("TextBox", { ClearTextOnFocus = false, PlaceholderText = "Search", Text = "", Font = Enum.Font.Gotham, TextColor3 = THEME.text, PlaceholderColor3 = THEME.subtle, TextSize = 13, BackgroundColor3 = THEME.panel2, BorderSizePixel = 0, Position = UDim2.new(0, 14, 0, 46), Size = UDim2.new(1, -28, 0, 32), ZIndex = 171 }, overlay) or nil
		if search then corner(search, 7); stroke(search, 1, THEME.lineDim, 0.35) end
		local scrollTop = searchable and 86 or 46
		local scroll = mk("ScrollingFrame", { Active = true, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 14, 0, scrollTop), Size = UDim2.new(1, -28, 1, -(scrollTop + 12)), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 5, ZIndex = 171 }, overlay)
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 5)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = scroll
		local function refill()
			for _, child in ipairs(scroll:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
			local query = string.lower(search and search.Text or "")
			for i, opt in ipairs(options) do
				local label = tostring(opt.Text or opt.DisplayName or opt.Id or opt.Value)
				if query == "" or string.find(string.lower(label), query, 1, true) then
					local button = mk("TextButton", { Text = label, Font = Enum.Font.GothamMedium, TextColor3 = THEME.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = THEME.panel2, BackgroundTransparency = 0.08, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 30), LayoutOrder = i, ZIndex = 172 }, scroll)
					corner(button, 6)
					button.Activated:Connect(function()
						overlay:Destroy()
						onSelect(opt)
					end)
				end
			end
		end
		if search then search:GetPropertyChangedSignal("Text"):Connect(refill) end
		refill()
	end

	makeDropdown("Item", item.DisplayName or selectedId, 0, true, function()
		local options = {}
		for id, def in pairs(ItemCatalog.Items or {}) do
			if catalogItemAllowed(def) and (state.Mode ~= "BlackMarket" or BLACK_MARKET_TYPES[tostring(def.Type or "")] == true) then
				table.insert(options, { Id = id, Text = string.format("T%s  %s", tostring(def.Tier or 1), tostring(def.DisplayName or id)) })
			end
		end
		table.sort(options, function(a, b) return tostring(a.Text) < tostring(b.Text) end)
		showSelector("Choose Item", options, function(opt) reopen(currentAction, opt.Id, nil, nil) end, true)
	end)
	makeDropdown("Quality", selectedQuality, 1/3, supportsQuality(selectedDef), function()
		local options = {}
		for _, quality in ipairs(ItemCatalog.QualityOrder or { "Dull", "Normal", "Fine", "Refined", "Superior", "Exceptional", "Legendary", "Artifact" }) do table.insert(options, { Value = quality, Text = quality }) end
		showSelector("Choose Quality", options, function(opt) reopen(currentAction, selectedId, opt.Value, selectedPurity) end, false)
	end)
	makeDropdown("Purity", selectedPurity == "None" and "None" or selectedPurity, 2/3, supportsPurity(selectedDef), function()
		local options = {}
		for _, purity in ipairs({ "None", "Faint", "Kindled", "Ignited", "Ashen Forged" }) do table.insert(options, { Value = purity, Text = purity }) end
		showSelector("Choose Purity", options, function(opt) reopen(currentAction, selectedId, selectedQuality, opt.Value) end, false)
	end)

	local actionOptions = state.Mode == "BlackMarket" and {
		{ Label = "Sell", Value = "BlackDirect" },
		{ Label = "Sell order", Value = "BlackSellOrder" },
	} or {
		{ Label = "Buy", Value = "Buy" },
		{ Label = "Buy order", Value = "BuyOrder" },
		{ Label = "Sell", Value = "Sell" },
		{ Label = "Sell order", Value = "SellOrder" },
	}
	for i, opt in ipairs(actionOptions) do
		local col = (i - 1) % 2
		local rowIndex = math.floor((i - 1) / 2)
		local selected = currentAction == opt.Value
		local button = mk("TextButton", { Text = (selected and "(x) " or "( ) ") .. opt.Label, Font = Enum.Font.GothamBold, TextColor3 = THEME.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = selected and THEME.lineDim or THEME.panel2, BorderSizePixel = 0, Position = UDim2.fromScale(0.035 + col * 0.49, 0.325 + rowIndex * 0.065), Size = UDim2.fromScale(0.45, 0.052), ZIndex = 112 }, left)
		corner(button, 7); stroke(button, 1, THEME.lineDim, 0.35)
		button.Activated:Connect(function() reopen(opt.Value) end)
	end

	local function makeSliderRow(title, y, defaultValue, minValue, maxValue, allowExpand)
		local changedCallback
		local frame = mk("Frame", { Active = true, BackgroundTransparency = 1, Position = UDim2.fromScale(0.04, y), Size = UDim2.fromScale(0.92, 0.125), ZIndex = 112 }, left)
		mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = title, TextColor3 = THEME.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.33), ZIndex = 113 }, frame)
		local box = mk("TextBox", { Text = tostring(defaultValue), ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextColor3 = THEME.text, PlaceholderColor3 = THEME.subtle, TextSize = 13, BackgroundColor3 = THEME.panel2, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.42), Size = UDim2.fromScale(0.25, 0.52), ZIndex = 113 }, frame)
		corner(box, 7); stroke(box, 1, THEME.lineDim, 0.35)
		local bar = mk("Frame", { Active = true, BackgroundColor3 = THEME.background, BackgroundTransparency = 0.12, BorderSizePixel = 0, Position = UDim2.fromScale(0.31, 0.60), Size = UDim2.fromScale(0.69, 0.15), ZIndex = 113 }, frame)
		corner(bar, 5)
		local fill = mk("Frame", { BackgroundColor3 = THEME.line, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), ZIndex = 114 }, bar)
		corner(fill, 5)
		local knob = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = THEME.text, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(15, 15), ZIndex = 115 }, bar)
		corner(knob, 8)
		local min = math.max(1, math.floor(tonumber(minValue) or 1))
		local max = math.max(min, math.floor(tonumber(maxValue) or min))
		local value = min
		local function syncVisual()
			local alpha = max == min and 1 or math.clamp((value - min) / (max - min), 0, 1)
			fill.Size = UDim2.new(alpha, 0, 1, 0)
			knob.Position = UDim2.new(alpha, 0, 0.5, 0)
			if box.Text ~= tostring(value) then box.Text = tostring(value) end
		end
		local function setValue(raw)
			local n = math.floor(tonumber(raw) or value or min)
			if allowExpand and n > max then max = math.min(1000000000, n) end
			value = math.clamp(n, min, max)
			syncVisual()
			if changedCallback then changedCallback() end
		end
		local function setFromPosition(input)
			local width = math.max(1, bar.AbsoluteSize.X)
			local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / width, 0, 1)
			setValue(min + ((max - min) * alpha))
		end
		local function beginSlider(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			setFromPosition(input)
			local moveConn
			local endConn
			moveConn = UserInputService.InputChanged:Connect(function(changed)
				if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then setFromPosition(changed) end
			end)
			endConn = UserInputService.InputEnded:Connect(function(ended)
				if ended.UserInputType ~= input.UserInputType then return end
				if moveConn then moveConn:Disconnect() end
				if endConn then endConn:Disconnect() end
			end)
		end
		bar.InputBegan:Connect(beginSlider)
		knob.InputBegan:Connect(beginSlider)
		box.FocusLost:Connect(function() setValue(box.Text) end)
		setValue(defaultValue)
		return { Get = function() return value end, OnChanged = function(fn) changedCallback = fn end }
	end

	local amountControl = makeSliderRow("Amount", 0.455, defaultAmount, 1, maxAmount, false)
	local priceControl = makeSliderRow("Price each", 0.585, defaultPrice, 1, priceMax, currentAction == "BuyOrder" or currentAction == "SellOrder" or currentAction == "BlackSellOrder")
	local summaryPanel = mk("Frame", { Active = true, BackgroundColor3 = THEME.background, BackgroundTransparency = 0.18, BorderSizePixel = 0, Position = UDim2.fromScale(0.04, 0.735), Size = UDim2.fromScale(0.92, 0.23), ZIndex = 112 }, left)
	corner(summaryPanel, 7); stroke(summaryPanel, 1, THEME.lineDim, 0.55)
	local taxLabel = mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = "Marketplace Tax (10%): 0", TextColor3 = THEME.subtle, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.04, 0.08), Size = UDim2.fromScale(0.92, 0.22), ZIndex = 113 }, summaryPanel)
	local setupLabel = mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = "Set up fee (3%): 0", TextColor3 = THEME.subtle, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.04, 0.32), Size = UDim2.fromScale(0.92, 0.22), ZIndex = 113 }, summaryPanel)
	local totalLabel = mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "Total: 0", TextColor3 = THEME.text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromScale(0.04, 0.62), Size = UDim2.fromScale(0.50, 0.28), ZIndex = 113 }, summaryPanel)
	local confirm = mk("TextButton", { Text = "Confirm", Position = UDim2.fromScale(0.60, 0.58), Size = UDim2.fromScale(0.36, 0.32), ZIndex = 113 }, summaryPanel)
	styleButton(confirm, THEME.green)

	local function percentFee(total, rate)
		total = math.max(0, math.floor(tonumber(total) or 0))
		if total <= 0 then return 0 end
		return math.max(1, math.floor(total * rate + 0.5))
	end
	local function canConfirm()
		if currentAction == "Buy" then return bestSell ~= nil end
		if currentAction == "BuyOrder" then return true end
		if currentAction == "Sell" then return inventoryRow ~= nil and bestBuy ~= nil end
		if currentAction == "SellOrder" then return inventoryRow ~= nil end
		if currentAction == "BlackDirect" then return inventoryRow ~= nil and bestBuy ~= nil end
		if currentAction == "BlackSellOrder" then return inventoryRow ~= nil end
		return false
	end
	local function refreshTotals()
		local amount = amountControl.Get()
		local price = math.max(1, priceControl.Get())
		local gross = amount * price
		local setup = (currentAction == "BuyOrder" or currentAction == "SellOrder") and percentFee(gross, 0.03) or 0
		local tax = (currentAction == "Sell" or currentAction == "SellOrder") and percentFee(gross, 0.10) or 0
		setupLabel.Text = "Set up fee (3%): " .. money(setup)
		taxLabel.Text = "Marketplace Tax (10%): " .. money(tax)
		if currentAction == "Buy" then
			totalLabel.Text = "Total cost: " .. money(gross)
		elseif currentAction == "BuyOrder" then
			totalLabel.Text = "Total locked: " .. money(gross + setup)
		elseif currentAction == "Sell" or currentAction == "SellOrder" then
			totalLabel.Text = "Total earned: " .. money(math.max(0, gross - tax))
		else
			totalLabel.Text = "Total: " .. money(gross)
		end
		local enabled = canConfirm()
		confirm.Active = enabled
		confirm.AutoButtonColor = enabled
		confirm.BackgroundColor3 = enabled and THEME.green or Color3.fromRGB(64, 58, 50)
		confirm.TextTransparency = enabled and 0 or 0.45
	end
	amountControl.OnChanged(refreshTotals)
	priceControl.OnChanged(refreshTotals)
	refreshTotals()
	confirm.Activated:Connect(function()
		if not canConfirm() then return end
		local amount = amountControl.Get()
		local price = math.max(1, priceControl.Get())
		if currentAction == "Buy" then
			perform("BuyAuctionOrder", { OrderId = bestSell.OrderId, Amount = math.min(amount, bestSell.Remaining or amount) })
		elseif currentAction == "BuyOrder" then
			perform("PlaceAuctionBuy", { ItemId = selectedId, Amount = math.min(amount, 9999), Price = price, Quality = selectedQuality, Purity = selectedPurity })
		elseif currentAction == "Sell" then
			perform("SellToAuctionBuy", { Slot = inventoryRow.Slot, Amount = math.min(amount, inventoryRow.Amount or amount, bestBuy.Remaining or amount), OrderId = bestBuy.OrderId })
		elseif currentAction == "SellOrder" then
			perform("PlaceAuctionSell", { Slot = inventoryRow.Slot, Amount = math.min(amount, inventoryRow.Amount or amount, 999), Price = price })
		elseif currentAction == "BlackDirect" then
			perform("BlackDirectSell", { Slot = inventoryRow.Slot, Amount = math.min(amount, inventoryRow.Amount or amount, 999) })
		elseif currentAction == "BlackSellOrder" then
			perform("PlaceBlackSellOrder", { Slot = inventoryRow.Slot, Amount = math.min(amount, inventoryRow.Amount or amount, 999), Price = price })
		end
		if tradePopup then tradePopup:Destroy(); tradePopup = nil end
	end)

	local right = mk("Frame", { Active = true, BackgroundTransparency = 1, Position = UDim2.fromScale(0.425, 0.035), Size = UDim2.fromScale(0.55, 0.93), ZIndex = 111 }, tradePopup)
	local function makeBook(title, rows, xScale, isBuy)
		local frame = mk("Frame", { Active = true, BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.08, BorderSizePixel = 0, Position = UDim2.fromScale(xScale, 0), Size = UDim2.fromScale(0.49, 0.58), ZIndex = 112 }, right)
		corner(frame, 8); stroke(frame, 1, THEME.lineDim, 0.35)
		mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = title, TextColor3 = THEME.text, TextSize = 14, Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(1, -20, 0, 22), ZIndex = 113 }, frame)
		local scroll = mk("ScrollingFrame", { Active = true, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 10, 0, 34), Size = UDim2.new(1, -20, 1, -42), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 4, ZIndex = 113 }, frame)
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 5)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = scroll
		if #(rows or {}) == 0 then
			mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "No orders", TextColor3 = THEME.subtle, TextSize = 12, Size = UDim2.new(1, -4, 0, 26), ZIndex = 114 }, scroll)
		end
		for i, order in ipairs(rows or {}) do
			local text = string.format("%s each  x%s", money(order.UnitPrice), comma(order.Remaining or order.Amount or 1))
			mk("TextLabel", { BackgroundColor3 = THEME.panel2, BackgroundTransparency = 0.1, BorderSizePixel = 0, Font = Enum.Font.GothamMedium, Text = text, TextColor3 = isBuy and THEME.green or THEME.text, TextSize = 12, Size = UDim2.new(1, -4, 0, 26), LayoutOrder = i, ZIndex = 114 }, scroll)
		end
	end
	makeBook("Sell Orders", sellOrders, 0, false)
	makeBook("Buy Orders", buyOrders, 0.5, true)
	local historyFrame = mk("Frame", { Active = true, BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.08, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0.60), Size = UDim2.fromScale(1, 0.40), ZIndex = 112 }, right)
	corner(historyFrame, 8); stroke(historyFrame, 1, THEME.lineDim, 0.35)
	mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "Market History", TextColor3 = THEME.text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -24, 0, 24), ZIndex = 113 }, historyFrame)
	local historyRows = { { "24h", history.H24 }, { "7d", history.D7 }, { "30d", history.D30 } }
	for i, data in ipairs(historyRows) do
		mk("TextLabel", { BackgroundColor3 = THEME.panel2, BackgroundTransparency = 0.1, BorderSizePixel = 0, Font = Enum.Font.GothamMedium, Text = data[1] .. "  " .. statText(data[2]), TextColor3 = THEME.text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 12, 0, 40 + (i - 1) * 34), Size = UDim2.new(1, -24, 0, 28), ZIndex = 113 }, historyFrame)
	end
end

local function renderAuctionBuy(snapshot)
	local rows = sortedFiltered(snapshot.Auction and snapshot.Auction.SellOrders or {})
	if #rows == 0 then addEmpty("No matching sell orders.") return end
	for _, row in ipairs(rows) do
		makeRow(row, {
			{ Text = "Buy", Color = THEME.green, Action = function()
				openTradePopup("Buy", row)
			end },
		}, string.format("%s Coin each | %s available", money(row.UnitPrice), comma(row.Remaining or row.Amount or 1)))
	end
end

local function renderAuctionSell(snapshot)
	local rows = sortedFiltered(snapshot.Inventory or {})
	if #rows == 0 then addEmpty("No tradeable inventory items.") return end
	for _, row in ipairs(rows) do
		local best = bestAuctionBuy(row)
		local buttons = {}
		if best then
			table.insert(buttons, { Text = "Sell Now", Color = THEME.green, Action = function()
				openTradePopup("SellNow", row)
			end })
		end
		table.insert(buttons, { Text = "List", Color = THEME.blue, Action = function()
			openTradePopup("SellOrder", row)
		end })
		local note = string.format("Value %s", money(row.EstimatedValue or row.Value or 0))
		if best then note ..= string.format(" | Best buy %s", money(best.UnitPrice)) end
		makeRow(row, buttons, note)
	end
end

local function renderAuctionBuyOrder()
	local rows = sortedFiltered(catalogRows())
	if #rows == 0 then addEmpty("No matching catalog items.") return end
	for _, row in ipairs(rows) do
		makeRow(row, {
			{ Text = "Order", Color = THEME.green, Action = function()
				openTradePopup("BuyOrder", row)
			end },
		}, string.format("Buy order for %s / %s", row.Quality or "Normal", row.Purity or "None"))
	end
end

local function renderAuctionOrders(snapshot)
	addSection("Your Sell Orders")
	local sells = snapshot.Auction and snapshot.Auction.MySellOrders or {}
	if #sells == 0 then addEmpty("No sell orders.") end
	for _, row in ipairs(sells) do
		makeRow(row, {
			{ Text = "Cancel", Color = THEME.red, Action = function()
				perform("CancelAuctionOrder", { OrderId = row.OrderId })
			end },
		}, string.format("%s Coin each | %s left", money(row.UnitPrice), comma(row.Remaining or 1)))
	end
	addSection("Your Buy Orders")
	local buys = snapshot.Auction and snapshot.Auction.MyBuyOrders or {}
	if #buys == 0 then addEmpty("No buy orders.") end
	for _, row in ipairs(buys) do
		makeRow(row, {
			{ Text = "Cancel", Color = THEME.red, Action = function()
				perform("CancelAuctionOrder", { OrderId = row.OrderId })
			end },
		}, string.format("%s Coin each | %s wanted", money(row.UnitPrice), comma(row.Remaining or 1)))
	end
end

local function renderClaims(snapshot)
	local coin = math.max(0, tonumber(snapshot.ClaimCoin) or 0)
	if coin > 0 then
		local coinRow = { Id = "Coin", DisplayName = "Claimable Coin", Type = "Currency", Tier = 1, Quality = "Normal", Purity = "None", Icon = "Coin", Value = coin }
		makeRow(coinRow, {
			{ Text = "Claim", Color = THEME.green, Action = function() perform("ClaimCoin", {}) end },
		}, money(coin) .. " Coin")
	end
	local rows = snapshot.Claims or {}
	if #rows == 0 and coin <= 0 then addEmpty("Nothing to claim.") return end
	for _, row in ipairs(rows) do
		makeRow(row, {
			{ Text = "Claim", Color = THEME.green, Action = function()
				perform("ClaimItem", { ClaimId = row.ClaimId })
			end },
		}, string.format("%s | %s item(s)", tostring(row.Source or "Market"), comma(row.Amount or 1)))
	end
end

local function demandFor(row, snapshot)
	for _, demand in ipairs(snapshot.BlackMarket and snapshot.BlackMarket.Demand or {}) do
		if rowKey(demand) == rowKey(row) then return demand end
	end
	return nil
end

local function renderBlackSell(snapshot)
	local rows = {}
	for _, row in ipairs(sortedFiltered(snapshot.Inventory or {})) do
		if blackMarketEligible(row) then table.insert(rows, row) end
	end
	if #rows == 0 then addEmpty("No black-market eligible items.") return end
	for _, row in ipairs(rows) do
		local demand = demandFor(row, snapshot)
		local direct = demand and demand.UnitPrice or row.EstimatedValue or row.Value or 1
		makeRow(row, {
			{ Text = "Direct", Color = THEME.green, Action = function()
				openTradePopup("BlackDirect", row)
			end },
			{ Text = "Order", Color = THEME.blue, Action = function()
				openTradePopup("BlackSellOrder", row)
			end },
		}, string.format("Black price %s | Value %s", money(direct), money(row.EstimatedValue or row.Value or 0)))
	end
end

local function renderBlackOrders(snapshot)
	addSection("Your Black Market Orders")
	local myOrders = snapshot.BlackMarket and snapshot.BlackMarket.MySellOrders or {}
	if #myOrders == 0 then addEmpty("No black market sell orders.") end
	for _, row in ipairs(myOrders) do
		makeRow(row, {
			{ Text = "Cancel", Color = THEME.red, Action = function()
				perform("CancelBlackOrder", { OrderId = row.OrderId })
			end },
		}, string.format("%s Coin each | %s left", money(row.UnitPrice), comma(row.Remaining or 1)))
	end
	addSection("Black Market Demand")
	local demand = sortedFiltered(snapshot.BlackMarket and snapshot.BlackMarket.Demand or {})
	if #demand == 0 then addEmpty("No demand yet.") end
	for _, row in ipairs(demand) do
		local avg24 = row.Avg24h and money(row.Avg24h) or "-"
		local avg7 = row.Avg7d and money(row.Avg7d) or "-"
		local avg30 = row.Avg30d and money(row.Avg30d) or "-"
		makeRow(row, {}, string.format("Demand %s | 24h %s | 7d %s | 30d %s", money(row.UnitPrice), avg24, avg7, avg30))
	end
end

render = function()
	ensureGui()
	local snapshot = state.Snapshot or {}
	titleLabel.Text = state.Mode == "BlackMarket" and "Black Market" or "Auction House"
	local coinAmount = snapshot.Economy and snapshot.Economy.Coin or 0
	coinLabel.Text = "Coin: " .. money(coinAmount)
	if coinExactTooltip then coinExactTooltip.Text = "Coin: " .. comma(coinAmount) end
	renderTabs()
	renderFilterText()
	controls.Visible = false
	priceBox.Visible = false
	amountBox.Visible = false
	clearGui(content)
	if state.Mode == "Auction" then
		if state.Tab == "Buy" then renderAuctionBuy(snapshot)
		elseif state.Tab == "Sell" then renderAuctionSell(snapshot)
		elseif state.Tab == "Buy Order" then renderAuctionBuyOrder(snapshot)
		elseif state.Tab == "Orders" then renderAuctionOrders(snapshot)
		elseif state.Tab == "Claim" then renderClaims(snapshot)
		end
	else
		if state.Tab == "Sell" then renderBlackSell(snapshot)
		elseif state.Tab == "Orders" then renderBlackOrders(snapshot)
		elseif state.Tab == "Claim" then renderClaims(snapshot)
		end
	end
end

local function openMarket(info)
	ensureGui()
	info = type(info) == "table" and info or {}
	state.Mode = info.Mode == "BlackMarket" and "BlackMarket" or "Auction"
	state.HouseId = info.HouseId or (state.Mode == "BlackMarket" and "BlackMarket" or "GlobalAuction")
	state.Tab = state.Mode == "BlackMarket" and "Sell" or "Buy"
	state.OpenPosition = info.Position
	state.OpenedAt = os.clock()
	gui.Enabled = true
	main.Visible = true
	refreshFromResult(nil)
end

OpenMarketInterface.OnClientEvent:Connect(openMarket)

local function stopChestOpeningBar()
	if chestOpeningConn then chestOpeningConn:Disconnect(); chestOpeningConn = nil end
	if chestOpeningBar then chestOpeningBar.destroy(); chestOpeningBar = nil end
end

local function startChestOpeningBar(payload)
	stopChestOpeningBar()
	local duration = math.max(0.1, tonumber(payload and payload.Duration) or 2)
	chestOpeningBar = Effects.createProgressBar(duration, payload and payload.Text or "Opening chest")
	chestOpeningConn = RunService.RenderStepped:Connect(function()
		if not chestOpeningBar then return end
		local progress = chestOpeningBar.update()
		if progress >= 1 then stopChestOpeningBar() end
	end)
end

MarketNotice.OnClientEvent:Connect(function(payload)
	if type(payload) == "string" then
		showToast(payload)
		return
	end
	if type(payload) ~= "table" then return end
	if payload.Kind == "ChestLoot" then
		stopChestOpeningBar()
		showLootPopup(payload)
	elseif payload.Kind == "ChestOpening" then
		startChestOpeningBar(payload)
	elseif payload.Text then
		showToast(payload.Text)
	end
end)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if lootPopup and root and typeof(lootOpenPosition) == "Vector3" and os.clock() - lootOpenedAt >= 0.45 then
		if (root.Position - lootOpenPosition).Magnitude > lootCloseDistance then
			closeLootPopup()
			stopChestOpeningBar()
		end
	end

	if not (main and main.Visible) then return end
	if os.clock() - state.OpenedAt < 0.45 then return end
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.05 then
		main.Visible = false
		if tradePopup then tradePopup:Destroy(); tradePopup = nil end
		return
	end
	if root and typeof(state.OpenPosition) == "Vector3" and (root.Position - state.OpenPosition).Magnitude > 6 then
		main.Visible = false
		if tradePopup then tradePopup:Destroy(); tradePopup = nil end
	end
end)

_G.OpenEconomyMarket = openMarket
