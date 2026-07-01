--[[
Name: InventoryController
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Controllers.InventoryController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, UserInputService, ContextActionService
Requires:
  - local ImageCatalog = require(sharedFolder:WaitForChild("ImageCatalog"))
  - local ItemCatalog = require(sharedFolder:WaitForChild("ItemCatalog"))
  - local GameState = require(utilFolder:WaitForChild("GameState"))
Functions: comma, formatCurrency, mk, corner, stroke, pointerPosition, primaryInput, secondaryInput, shiftDown, pointInside, resolveSlot, weightFillScale, styleButton, setInventoryVisible, ensureEquipCanvasLayout, ensureSlotFrame, ensureChip, ensureCurrencyTooltip, showCurrencyTooltip, hideCurrencyTooltip, wireCurrencyTooltip, invoke, stackAt, stopMover, sinkDragInput, setInventoryDragActive, beginDrag, applyWeight, applyEconomy, openDetail, shortBadge, qualityColor, purityColor, renderSlotFrame, requestSnapshot, ensureSlotView, ensureEquipmentSlotView, renderEquipmentSlot, renderInventorySlot, slotAt, inventorySurfaceAt, destroyGhost, ensureGhost, applyMoveResult, storagePayload, moveSourceToTarget, showDeletePrompt, ensureStorageWindow, ensureStorageSlot, renderTabs, ensureMarketWindow, makeList, place, fill, openMarket, Controller.Start, Controller.RenderMarket, _G.SetOvercap, render, quickTransfer
Clean source lines: 976
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local replicatedPackage = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
local sharedFolder = replicatedPackage:WaitForChild("Shared")
local utilFolder = replicatedPackage:WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util")

local ImageCatalog = require(sharedFolder:WaitForChild("ImageCatalog"))
local ItemCatalog = require(sharedFolder:WaitForChild("ItemCatalog"))
local GameState = require(utilFolder:WaitForChild("GameState"))

local Controller = {}
local started = false

local THEME = {
	gold = Color3.fromRGB(232, 176, 64),
	goldDim = Color3.fromRGB(156, 116, 48),
	text = Color3.fromRGB(242, 228, 198),
	subtle = Color3.fromRGB(210, 196, 166),
	panel = Color3.fromRGB(26, 18, 16),
	panel2 = Color3.fromRGB(18, 13, 12),
	inner = Color3.fromRGB(38, 26, 22),
	red = Color3.fromRGB(126, 38, 30),
	green = Color3.fromRGB(58, 125, 76),
}

local INVENTORY_SLOTS = 40
local DRAG_THRESHOLD = 7
local DRAG_SINK_ACTION = "InventoryDragMouseSink"
local DRAG_SINK_PRIORITY = Enum.ContextActionPriority.High.Value + 20
local EQUIPMENT_SLOTS = {
	{ Slot = "Cape", Frame = "r1c1", Label = "Cape" },
	{ Slot = "Helmet", Frame = "r1c2", Label = "Head" },
	{ Slot = "Bag", Frame = "r1c3", Label = "Bag" },
	{ Slot = "Weapon", Frame = "r2c1", Label = "Weapon" },
	{ Slot = "Armor", Frame = "r2c2", Label = "Armor" },
	{ Slot = "Offhand", Frame = "r2c3", Label = "Offhand" },
	{ Slot = "Food", Frame = "r3c1", Label = "Food" },
	{ Slot = "Boots", Frame = "r3c2", Label = "Boots" },
	{ Slot = "Potion", Frame = "r3c3", Label = "Potion" },
	{ Slot = "Mount", Frame = "Mount", Label = "Mount" },
}

local function comma(n)
	n = tostring(math.floor(tonumber(n) or 0))
	local left, num, right = n:match("^([^%d]*%d)(%d*)(.-)$")
	if not num then return n end
	return left .. num:reverse():gsub("(%d%d%d)", "%1,"):reverse() .. right
end

local function formatCurrency(value)
	local n = math.max(0, math.floor(tonumber(value) or 0))
	if n < 10000 then
		return comma(n)
	end
	local units = {
		{ value = 1000000000000, suffix = "t" },
		{ value = 1000000000, suffix = "b" },
		{ value = 1000000, suffix = "m" },
		{ value = 1000, suffix = "K" },
	}
	for _, unit in ipairs(units) do
		if n >= unit.value then
			local scaled = n / unit.value
			local text
			if scaled < 10 and math.floor(scaled) ~= scaled then
				text = string.format("%.1f", math.floor(scaled * 10) / 10):gsub("%.0$", "")
			else
				text = tostring(math.floor(scaled))
			end
			return text .. unit.suffix
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
	local c = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

local function stroke(parent, thickness, color, transparency)
	local s = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Thickness = thickness or 1
	s.Color = color or THEME.gold
	s.Transparency = transparency or 0.2
	s.Parent = parent
	return s
end

local function pointerPosition(input)
	local p = input and input.Position
	if typeof(p) == "Vector3" then return Vector2.new(p.X, p.Y) end
	if typeof(p) == "Vector2" then return p end
	local mouse = UserInputService:GetMouseLocation()
	return Vector2.new(mouse.X, mouse.Y)
end

local function primaryInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function secondaryInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton2
end

local function shiftDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function pointInside(guiObject, point)
	if not (guiObject and guiObject:IsA("GuiObject") and guiObject.Visible) then return false end
	local pos = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

local function resolveSlot(scroll, index)
	return scroll:FindFirstChild(string.format("Slot_%02d", index)) or scroll:FindFirstChild("Slot_" .. tostring(index))
end

local function weightFillScale(percent)
	percent = math.max(0, tonumber(percent) or 0)
	if percent <= 100 then return math.clamp((percent / 100) * 0.5, 0, 0.5) end
	if percent <= 200 then return 0.5 + ((percent - 100) / 100) * 0.3 end
	if percent <= 600 then return 0.8 + ((percent - 200) / 400) * 0.1 end
	if percent <= 800 then return 0.9 + ((percent - 600) / 200) * 0.1 end
	return 1
end

local function styleButton(button, bg)
	button.AutoButtonColor = true
	button.BackgroundColor3 = bg or THEME.inner
	button.TextColor3 = THEME.text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.BorderSizePixel = 0
	corner(button, 7)
	stroke(button, 1, THEME.gold, 0.25)
end

function Controller.Start(gui)
	if started then return end
	started = true
	gui = gui or script.Parent

	local player = Players.LocalPlayer
	local remotes = replicatedPackage:WaitForChild("RemoteEvents")
	local inventoryRequest = remotes:WaitForChild("InventoryRequest")
	local inventoryUpdated = remotes:WaitForChild("InventoryUpdated")
	local openStorage = remotes:WaitForChild("OpenStorage")

	local panel = gui:WaitForChild("InventoryPanel")
	gui.Enabled = false
	local function setInventoryVisible(visible)
		gui.Enabled = visible == true
	end
	ContextActionService:BindActionAtPriority("ToggleInventoryTab", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		setInventoryVisible(not gui.Enabled)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 200, Enum.KeyCode.Tab)
	local content = panel:WaitForChild("Content")
	local header = content:FindFirstChild("Header")
	local nameLabel = header and header:FindFirstChild("PlayerName", true)
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
	end

	local storageScroll = content:WaitForChild("StorageArea"):WaitForChild("StorageScroll")
	local overcapArea = content:WaitForChild("OvercapArea")
	local percentLabel = overcapArea:WaitForChild("PercentLabel")
	local barFill = overcapArea:WaitForChild("BarOuter"):WaitForChild("Fill")
	local equipCanvas = content:FindFirstChild("EquipArea") and content.EquipArea:FindFirstChild("EquipCanvas")
	local coinFrame = equipCanvas and equipCanvas:FindFirstChild("Coin")
	local tokenFrame = equipCanvas and equipCanvas:FindFirstChild("CharredToken")
	local coinText = coinFrame and coinFrame:FindFirstChild("Text")
	local tokenText = tokenFrame and tokenFrame:FindFirstChild("Text")

	local function ensureEquipCanvasLayout()
		if not equipCanvas then return end
		local slotLayout = {
			r1c1 = { Position = UDim2.new(0.08, 0, 0.02, 0), Size = UDim2.new(0.16, 0, 0.20, 0) },
			r1c2 = { Position = UDim2.new(0.27, 0, 0.02, 0), Size = UDim2.new(0.16, 0, 0.20, 0) },
			r1c3 = { Position = UDim2.new(0.46, 0, 0.02, 0), Size = UDim2.new(0.16, 0, 0.20, 0) },
			r2c1 = { Position = UDim2.new(0.08, 0, 0.26, 0), Size = UDim2.new(0.16, 0, 0.20, 0) },
			r2c2 = { Position = UDim2.new(0.27, 0, 0.26, 0), Size = UDim2.new(0.16, 0, 0.20, 0) },
			r2c3 = { Position = UDim2.new(0.46, 0, 0.26, 0), Size = UDim2.new(0.16, 0, 0.20, 0) },
			r3c1 = { Position = UDim2.new(0.08, 0, 0.50, 0), Size = UDim2.new(0.16, 0, 0.20, 0) },
			r3c2 = { Position = UDim2.new(0.27, 0, 0.50, 0), Size = UDim2.new(0.16, 0, 0.20, 0) },
			r3c3 = { Position = UDim2.new(0.46, 0, 0.50, 0), Size = UDim2.new(0.16, 0, 0.20, 0) },
			Mount = { Position = UDim2.new(0.27, 0, 0.74, 0), Size = UDim2.new(0.16, 0, 0.20, 0) },
		}
		local function ensureSlotFrame(name)
			local frame = equipCanvas:FindFirstChild(name)
			if not (frame and frame:IsA("Frame")) then
				frame = mk("Frame", { Name = name, BackgroundColor3 = THEME.inner, BackgroundTransparency = 0.06, BorderSizePixel = 0 }, equipCanvas)
				corner(frame, 8)
				stroke(frame, 1.2, THEME.gold, 0.22)
			end
			local info = slotLayout[name]
			frame.Position = info.Position
			frame.Size = info.Size
			frame.ClipsDescendants = false
			local inner = frame:FindFirstChild("Inner")
			if not (inner and inner:IsA("GuiObject")) then
				inner = mk("Frame", { Name = "Inner", BackgroundColor3 = THEME.inner, BackgroundTransparency = 0.08, BorderSizePixel = 0, Position = UDim2.new(0.08, 0, 0.08, 0), Size = UDim2.new(0.84, 0, 0.84, 0), ZIndex = frame.ZIndex + 1 }, frame)
				corner(inner, 6)
			end
			return frame
		end
		for name in pairs(slotLayout) do
			ensureSlotFrame(name)
		end
		local function ensureChip(name, position)
			local chip = equipCanvas:FindFirstChild(name)
			if not (chip and chip:IsA("Frame")) then
				chip = mk("Frame", { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 8 }, equipCanvas)
				corner(chip, 8)
			end
			chip.Position = position
			chip.Size = UDim2.new(0.33, 0, 0.16, 0)
			local icon = chip:FindFirstChild("Icon")
			if not (icon and icon:IsA("ImageLabel")) then
				icon = mk("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Image = "rbxassetid://0", ImageColor3 = THEME.gold, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.02, 0, 0.5, 0), Size = UDim2.new(0.22, 0, 0.82, 0), ZIndex = chip.ZIndex + 1 }, chip)
			end
			local text = chip:FindFirstChild("Text")
			if not (text and text:IsA("TextLabel")) then
				text = mk("TextLabel", { Name = "Text", BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextColor3 = THEME.text, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.27, 0, 0.5, 0), Size = UDim2.new(0.72, 0, 0.82, 0), ZIndex = chip.ZIndex + 1 }, chip)
			end
			return chip, text
		end
		coinFrame, coinText = ensureChip("Coin", UDim2.new(0.66, 0, 0.22, 0))
		tokenFrame, tokenText = ensureChip("CharredToken", UDim2.new(0.66, 0, 0.42, 0))
	end

	ensureEquipCanvasLayout()

	local currencyTooltip = nil
	local exactCoinText = "Coin: 0"
	local exactTokenText = "Charred Token: 0"
	local function ensureCurrencyTooltip()
		if currencyTooltip and currencyTooltip.Parent then return currencyTooltip end
		currencyTooltip = mk("TextLabel", {
			Name = "CurrencyExactTooltip",
			BackgroundColor3 = THEME.panel,
			BackgroundTransparency = 0.04,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			TextColor3 = THEME.text,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Visible = false,
			ZIndex = 1000,
			Size = UDim2.fromOffset(180, 30),
		}, gui)
		corner(currencyTooltip, 7)
		stroke(currencyTooltip, 1, THEME.gold, 0.16)
		return currencyTooltip
	end
	local function showCurrencyTooltip(anchor, text)
		local tooltip = ensureCurrencyTooltip()
		tooltip.Text = text
		local pos = anchor.AbsolutePosition
		local size = anchor.AbsoluteSize
		tooltip.Position = UDim2.fromOffset(math.floor(pos.X + (size.X / 2) - 90), math.floor(pos.Y - 34))
		tooltip.Visible = true
	end
	local function hideCurrencyTooltip()
		if currencyTooltip then currencyTooltip.Visible = false end
	end
	local function wireCurrencyTooltip(anchor, getText)
		if not (anchor and anchor:IsA("GuiObject")) or anchor:GetAttribute("CurrencyTooltipWired") then return end
		anchor.Active = true
		anchor.MouseEnter:Connect(function() showCurrencyTooltip(anchor, getText()) end)
		anchor.MouseLeave:Connect(hideCurrencyTooltip)
		anchor.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement and currencyTooltip and currencyTooltip.Visible then
				showCurrencyTooltip(anchor, getText())
			end
		end)
		anchor:SetAttribute("CurrencyTooltipWired", true)
	end
	wireCurrencyTooltip(coinFrame, function() return exactCoinText end)
	wireCurrencyTooltip(tokenFrame, function() return exactTokenText end)

	local snapshot = nil
	local currentStorage = nil
	local storageSnapshot = nil
	local slotViews = {}
	local storageViews = {}
	local equipViews = {}
	local drag = nil
	local ghost = nil
	local deletePrompt = nil
	local storageWindow = nil
	local storageTitle = nil
	local storageScrollFrame = nil
	local storageGrid = nil
	local tabBar = nil
	local marketWindow = nil

	local function invoke(action, payload)
		local ok, result = pcall(function()
			return inventoryRequest:InvokeServer(action, payload or {})
		end)
		if not ok then
			warn("[Inventory] " .. tostring(action) .. " failed: " .. tostring(result))
			return nil
		end
		if type(result) == "table" and result.Ok == false and result.Error then
			warn("[Inventory] " .. tostring(result.Error))
		end
		return result
	end

	local function stackAt(source)
		if not source then return nil end
		if source.Type == "Inventory" then
			local slots = snapshot and snapshot.Inventory and snapshot.Inventory.Slots
			return slots and slots[tostring(source.Slot)] or nil
		elseif source.Type == "Storage" then
			local slots = storageSnapshot and storageSnapshot.Slots
			return slots and slots[tostring(source.Slot)] or nil
		elseif source.Type == "Equipment" then
			local slots = snapshot and snapshot.Equipment and snapshot.Equipment.Slots
			return slots and slots[tostring(source.Slot)] or nil
		end
		return nil
	end

	local function stopMover()
		local mover = GameState:GetMover()
		local humanoid = mover and mover:FindFirstChildWhichIsA("Humanoid")
		local hrp = mover and mover:FindFirstChild("HumanoidRootPart")
		if humanoid and hrp then
			humanoid:MoveTo(hrp.Position)
		end
	end

	local function sinkDragInput()
		return GameState.inventoryDragActive and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end

	local function setInventoryDragActive(active)
		GameState.inventoryDragActive = active == true
		if active then
			ContextActionService:BindActionAtPriority(DRAG_SINK_ACTION, sinkDragInput, false, DRAG_SINK_PRIORITY, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
			GameState.disableMovement = true
			GameState.isWalkingToInteract = false
			GameState.interactTargetPart = nil
			GameState.interactTargetPosition = nil
			GameState.detectorInteractionActive = false
			GameState.detectorInteractionTarget = nil
			GameState.interactCallback = nil
			GameState.interactCallbackTarget = nil
			GameState.interactDistanceOverride = nil
			stopMover()
		else
			ContextActionService:UnbindAction(DRAG_SINK_ACTION)
			if not GameState.gathering then
				GameState.disableMovement = false
			end
		end
	end

	local function beginDrag(source, stack, input)
		drag = { Source = source, Start = pointerPosition(input), Last = pointerPosition(input), Moved = false, Icon = stack.Icon }
		setInventoryDragActive(true)
	end

	local function applyWeight()
		local weight = snapshot and snapshot.Weight or {}
		local percent = tonumber(weight.Percent) or 0
		percentLabel.Text = string.format("%d%%", math.floor(percent + 0.5))
		barFill.Size = UDim2.new(weightFillScale(percent), 0, 1, 0)
	end

	local function applyEconomy()
		local economy = snapshot and snapshot.Economy or {}
		exactCoinText = "Coin: " .. comma(economy.Coin or 0)
		exactTokenText = "Charred Token: " .. comma(economy.CharredToken or 0)
		if coinText and coinText:IsA("TextLabel") then coinText.Text = formatCurrency(economy.Coin or 0) end
		if tokenText and tokenText:IsA("TextLabel") then tokenText.Text = formatCurrency(economy.CharredToken or 0) end
	end

	_G.SetOvercap = function(percent)
		percentLabel.Text = string.format("%d%%", math.floor((tonumber(percent) or 0) + 0.5))
		barFill.Size = UDim2.new(weightFillScale(percent), 0, 1, 0)
	end

	local function openDetail(source)
		local stack = stackAt(source)
		if not stack or type(_G.OpenItemDetail) ~= "function" then return end
		local detail = ItemCatalog.BuildDetail(stack, {
			WeightPercent = snapshot and snapshot.Weight and snapshot.Weight.Percent or 0,
			Slot = source.Type == "Inventory" and source.Slot or nil,
		})
		if detail then _G.OpenItemDetail(detail) end
	end

	local function shortBadge(value)
		value = tostring(value or "")
		if value == "" then return "" end
		return string.upper(string.sub(value, 1, 1))
	end

	local function qualityColor(quality)
		quality = ItemCatalog.NormalizeQuality(quality or "Normal")
		if quality == "Artifact" then return Color3.fromRGB(255, 116, 70) end
		if quality == "Legendary" then return Color3.fromRGB(255, 214, 92) end
		if quality == "Exceptional" then return Color3.fromRGB(183, 117, 255) end
		if quality == "Superior" then return Color3.fromRGB(112, 151, 255) end
		if quality == "Refined" then return Color3.fromRGB(82, 172, 255) end
		if quality == "Fine" then return Color3.fromRGB(91, 204, 125) end
		if quality == "Dull" then return Color3.fromRGB(112, 105, 95) end
		return THEME.goldDim
	end

	local function purityColor(purity)
		purity = ItemCatalog.NormalizePurity(purity or "None")
		if purity == "Ashen Forged" then return Color3.fromRGB(255, 92, 216) end
		if purity == "Ignited" then return Color3.fromRGB(180, 126, 255) end
		if purity == "Kindled" then return Color3.fromRGB(119, 235, 221) end
		if purity == "Faint" then return Color3.fromRGB(255, 174, 72) end
		return THEME.goldDim
	end

	local function renderSlotFrame(view, stack)
		if stack then
			if view.Label then view.Label.Visible = false end
			view.Inner.BackgroundTransparency = 0.02
			view.Icon.Visible = true
			ImageCatalog.SetImage(view.Icon, stack.Icon or "Default")
			local amount = math.max(1, math.floor(tonumber(stack.Amount) or 1))
			view.Count.Visible = amount > 1
			view.Count.Text = amount > 999 and comma(amount) or tostring(amount)
			local quality = tostring(stack.Quality or "Normal")
			local purity = tostring(stack.Purity or "None")
			if view.Quality then
				view.Quality.Visible = quality ~= "Normal"
				view.Quality.Text = shortBadge(quality)
				view.Quality.BackgroundColor3 = qualityColor(quality)
			end
			if view.Purity then
				view.Purity.Visible = purity ~= "None"
				view.Purity.Text = shortBadge(purity)
				view.Purity.BackgroundColor3 = purityColor(purity)
			end
			stroke(view.Frame, 1, THEME.gold, 0.2)
		else
			if view.Label then view.Label.Visible = true end
			view.Inner.BackgroundTransparency = 0.18
			view.Icon.Visible = false
			view.Icon.Image = ""
			view.Count.Visible = false
			view.Count.Text = ""
			if view.Quality then view.Quality.Visible = false end
			if view.Purity then view.Purity.Visible = false end
			stroke(view.Frame, 1, THEME.goldDim, 0.55)
		end
	end

	local function requestSnapshot()
		local result = invoke("GetSnapshot")
		if type(result) == "table" and result.Ok then
			snapshot = result
		end
	end

	local renderStorage
	local requestStorage
	local render
	local quickTransfer

	local function ensureSlotView(slotFrame, slotIndex)
		local inner = slotFrame:FindFirstChild("Inner")
		if not (inner and inner:IsA("GuiObject")) then
			inner = mk("Frame", { Name = "Inner", BackgroundColor3 = THEME.inner, BackgroundTransparency = 0.08, BorderSizePixel = 0, Position = UDim2.new(0.08, 0, 0.08, 0), Size = UDim2.new(0.84, 0, 0.84, 0), ZIndex = slotFrame.ZIndex + 1 }, slotFrame)
			corner(inner, 6)
		end
		local icon = inner:FindFirstChild("ItemIcon")
		if not (icon and icon:IsA("ImageLabel")) then
			icon = mk("ImageLabel", { Name = "ItemIcon", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Position = UDim2.new(0.12, 0, 0.1, 0), Size = UDim2.new(0.76, 0, 0.76, 0), ZIndex = inner.ZIndex + 1, Visible = false }, inner)
		end
		local count = slotFrame:FindFirstChild("Count", true)
		if not (count and count:IsA("TextLabel")) then
			count = mk("TextLabel", { Name = "Count", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = THEME.text, TextStrokeTransparency = 0.45, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.96, 0, 0.96, 0), Size = UDim2.new(0.64, 0, 0.3, 0), ZIndex = inner.ZIndex + 2, Visible = false }, slotFrame)
		end
		local quality = slotFrame:FindFirstChild("QualityBadge")
		if not (quality and quality:IsA("TextLabel")) then
			quality = mk("TextLabel", { Name = "QualityBadge", BackgroundColor3 = THEME.goldDim, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(10, 8, 7), TextScaled = true, Position = UDim2.new(0.06, 0, 0.06, 0), Size = UDim2.new(0.27, 0, 0.22, 0), ZIndex = inner.ZIndex + 3, Visible = false }, slotFrame)
			corner(quality, 4)
		end
		local purity = slotFrame:FindFirstChild("PurityBadge")
		if not (purity and purity:IsA("TextLabel")) then
			purity = mk("TextLabel", { Name = "PurityBadge", BackgroundColor3 = THEME.goldDim, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(10, 8, 7), TextScaled = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.94, 0, 0.06, 0), Size = UDim2.new(0.27, 0, 0.22, 0), ZIndex = inner.ZIndex + 3, Visible = false }, slotFrame)
			corner(purity, 4)
		end
		local hit = slotFrame:FindFirstChild("InventoryHit")
		if not (hit and hit:IsA("TextButton")) then
			hit = mk("TextButton", { Name = "InventoryHit", Text = "", BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Selectable = false, Size = UDim2.fromScale(1, 1), ZIndex = inner.ZIndex + 8 }, slotFrame)
		end
		if not hit:GetAttribute("InventoryBound") then
			hit:SetAttribute("InventoryBound", true)
			hit.InputBegan:Connect(function(input)
				local source = { Type = "Inventory", Slot = slotIndex }
				local stack = stackAt(source)
				if not stack then return end
				if secondaryInput(input) then
					quickTransfer(source)
					return
				end
				if not primaryInput(input) then return end
				if shiftDown() then
					quickTransfer(source)
					return
				end
				beginDrag(source, stack, input)
			end)
		end
		return { Frame = slotFrame, Inner = inner, Icon = icon, Count = count, Quality = quality, Purity = purity, Hit = hit }
	end

	local function ensureEquipmentSlotView(slotFrame, equipSlot, labelText)
		local inner = slotFrame:FindFirstChild("Inner")
		if not (inner and inner:IsA("GuiObject")) then
			inner = mk("Frame", { Name = "Inner", BackgroundColor3 = THEME.inner, BackgroundTransparency = 0.08, BorderSizePixel = 0, Position = UDim2.new(0.08, 0, 0.08, 0), Size = UDim2.new(0.84, 0, 0.84, 0), ZIndex = slotFrame.ZIndex + 1 }, slotFrame)
			corner(inner, 6)
		end
		local icon = inner:FindFirstChild("ItemIcon")
		if not (icon and icon:IsA("ImageLabel")) then
			icon = mk("ImageLabel", { Name = "ItemIcon", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Position = UDim2.new(0.12, 0, 0.1, 0), Size = UDim2.new(0.76, 0, 0.76, 0), ZIndex = inner.ZIndex + 1, Visible = false }, inner)
		end
		local count = slotFrame:FindFirstChild("Count")
		if not (count and count:IsA("TextLabel")) then
			count = mk("TextLabel", { Name = "Count", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = THEME.text, TextStrokeTransparency = 0.45, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.96, 0, 0.96, 0), Size = UDim2.new(0.64, 0, 0.3, 0), ZIndex = inner.ZIndex + 2, Visible = false }, slotFrame)
		end
		local label = slotFrame:FindFirstChild("SlotLabel")
		if not (label and label:IsA("TextLabel")) then
			label = mk("TextLabel", { Name = "SlotLabel", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = labelText, TextColor3 = THEME.subtle, TextScaled = true, TextStrokeTransparency = 0.65, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.96, 0), Size = UDim2.new(0.9, 0, 0.22, 0), ZIndex = inner.ZIndex + 4 }, slotFrame)
		else
			label.Text = labelText
		end
		local quality = slotFrame:FindFirstChild("QualityBadge")
		if not (quality and quality:IsA("TextLabel")) then
			quality = mk("TextLabel", { Name = "QualityBadge", BackgroundColor3 = THEME.goldDim, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(10, 8, 7), TextScaled = true, Position = UDim2.new(0.06, 0, 0.06, 0), Size = UDim2.new(0.27, 0, 0.22, 0), ZIndex = inner.ZIndex + 5, Visible = false }, slotFrame)
			corner(quality, 4)
		end
		local purity = slotFrame:FindFirstChild("PurityBadge")
		if not (purity and purity:IsA("TextLabel")) then
			purity = mk("TextLabel", { Name = "PurityBadge", BackgroundColor3 = THEME.goldDim, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(10, 8, 7), TextScaled = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.94, 0, 0.06, 0), Size = UDim2.new(0.27, 0, 0.22, 0), ZIndex = inner.ZIndex + 5, Visible = false }, slotFrame)
			corner(purity, 4)
		end
		local hit = slotFrame:FindFirstChild("EquipmentHit")
		if not (hit and hit:IsA("TextButton")) then
			hit = mk("TextButton", { Name = "EquipmentHit", Text = "", BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Selectable = false, Size = UDim2.fromScale(1, 1), ZIndex = inner.ZIndex + 8 }, slotFrame)
		end
		if not hit:GetAttribute("InventoryBound") then
			hit:SetAttribute("InventoryBound", true)
			hit.InputBegan:Connect(function(input)
				local source = { Type = "Equipment", Slot = equipSlot }
				local stack = stackAt(source)
				if not stack then return end
				if secondaryInput(input) then
					quickTransfer(source)
					return
				end
				if not primaryInput(input) then return end
				if shiftDown() then
					quickTransfer(source)
					return
				end
				beginDrag(source, stack, input)
			end)
		end
		return { Frame = slotFrame, Inner = inner, Icon = icon, Count = count, Quality = quality, Purity = purity, Hit = hit, Label = label }
	end

	local function renderEquipmentSlot(info)
		if not equipCanvas then return end
		local slotFrame = equipCanvas:FindFirstChild(info.Frame)
		if not (slotFrame and slotFrame:IsA("Frame")) then return end
		equipViews[info.Slot] = equipViews[info.Slot] or ensureEquipmentSlotView(slotFrame, info.Slot, info.Label)
		local slots = snapshot and snapshot.Equipment and snapshot.Equipment.Slots
		renderSlotFrame(equipViews[info.Slot], slots and slots[info.Slot] or nil)
	end

	local function renderInventorySlot(slotIndex)
		local view = slotViews[slotIndex]
		if not view then return end
		local slots = snapshot and snapshot.Inventory and snapshot.Inventory.Slots
		renderSlotFrame(view, slots and slots[tostring(slotIndex)] or nil)
	end

	render = function()
		for _, info in ipairs(EQUIPMENT_SLOTS) do
			renderEquipmentSlot(info)
		end
		for slotIndex = 1, INVENTORY_SLOTS do
			local slotFrame = resolveSlot(storageScroll, slotIndex)
			if slotFrame and slotFrame:IsA("Frame") then
				slotViews[slotIndex] = slotViews[slotIndex] or ensureSlotView(slotFrame, slotIndex)
				renderInventorySlot(slotIndex)
			end
		end
		applyWeight()
		applyEconomy()
		if currentStorage and storageSnapshot then renderStorage() end
	end

	local function slotAt(point)
		for slotIndex = 1, INVENTORY_SLOTS do
			local view = slotViews[slotIndex]
			if view and pointInside(view.Frame, point) then return { Type = "Inventory", Slot = slotIndex } end
		end
		for _, info in ipairs(EQUIPMENT_SLOTS) do
			local view = equipViews[info.Slot]
			if view and pointInside(view.Frame, point) then return { Type = "Equipment", Slot = info.Slot } end
		end
		if storageWindow and storageWindow.Visible then
			for slotIndex, view in pairs(storageViews) do
				if view and pointInside(view.Frame, point) then return { Type = "Storage", Slot = slotIndex } end
			end
		end
		return nil
	end

	local function inventorySurfaceAt(point)
		if pointInside(panel, point) then return true end
		if storageWindow and storageWindow.Visible and pointInside(storageWindow, point) then return true end
		return false
	end

	local function destroyGhost()
		if ghost then ghost:Destroy(); ghost = nil end
	end

	local function ensureGhost(source)
		if ghost then return ghost end
		ghost = mk("ImageLabel", { Name = "InventoryDragGhost", BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.08, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(54, 54), ZIndex = 1000, ScaleType = Enum.ScaleType.Fit }, gui)
		corner(ghost, 8)
		stroke(ghost, 1, THEME.gold, 0.08)
		ImageCatalog.SetImage(ghost, source.Icon or "Default")
		return ghost
	end

	local function applyMoveResult(result)
		if type(result) ~= "table" then return end
		if type(result.Snapshot) == "table" then snapshot = result.Snapshot end
		if type(result.StorageSnapshot) == "table" then storageSnapshot = result.StorageSnapshot end
		render()
	end

	local function storagePayload(extra)
		local payload = extra or {}
		if currentStorage then
			payload.StorageType = currentStorage.StorageType
			payload.StorageId = currentStorage.StorageId
			payload.Tab = storageSnapshot and storageSnapshot.Tab or currentStorage.Tab or 1
		end
		return payload
	end

	local function moveSourceToTarget(source, target)
		if not source or not target then return end
		local result
		if source.Type == "Inventory" and target.Type == "Inventory" then
			result = invoke("MoveInventory", { From = source.Slot, To = target.Slot })
		elseif source.Type == "Inventory" and target.Type == "Equipment" then
			result = invoke("EquipInventory", { From = source.Slot, EquipSlot = target.Slot })
		elseif source.Type == "Equipment" and target.Type == "Inventory" then
			result = invoke("UnequipToInventory", { EquipSlot = source.Slot, To = target.Slot })
		elseif source.Type == "Equipment" and target.Type == "Equipment" then
			result = invoke("MoveEquipment", { FromSlot = source.Slot, ToSlot = target.Slot })
		elseif source.Type == "Inventory" and target.Type == "Storage" then
			result = invoke("MoveInventoryToStorage", storagePayload({ From = source.Slot, To = target.Slot }))
		elseif source.Type == "Storage" and target.Type == "Inventory" then
			result = invoke("MoveStorageToInventory", storagePayload({ From = source.Slot, To = target.Slot }))
		elseif source.Type == "Storage" and target.Type == "Storage" then
			result = invoke("MoveStorage", storagePayload({ From = source.Slot, To = target.Slot }))
		end
		applyMoveResult(result)
	end

	quickTransfer = function(source)
		if not source then return end
		local result
		if source.Type == "Equipment" then
			result = invoke("QuickTransferEquipment", { EquipSlot = source.Slot })
		elseif source.Type == "Inventory" and not currentStorage then
			result = invoke("QuickEquipInventory", { From = source.Slot })
		elseif currentStorage then
			result = invoke("QuickTransfer", storagePayload({ FromType = source.Type, From = source.Slot }))
		end
		applyMoveResult(result)
	end

	local function showDeletePrompt(slotIndex, point)
		if deletePrompt then deletePrompt:Destroy(); deletePrompt = nil end
		deletePrompt = mk("Frame", { Name = "DeleteConfirm", BackgroundColor3 = THEME.panel2, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(290, 118), ZIndex = 1100 }, gui)
		corner(deletePrompt, 8)
		stroke(deletePrompt, 1, THEME.gold, 0.08)
		mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "Are you sure you wish to delete this item?", TextColor3 = THEME.text, TextSize = 14, TextWrapped = true, Position = UDim2.new(0, 14, 0, 12), Size = UDim2.new(1, -28, 0, 44), ZIndex = 1101 }, deletePrompt)
		local yes = mk("TextButton", { Text = "Delete", Position = UDim2.new(0, 14, 1, -48), Size = UDim2.new(0.5, -20, 0, 34), ZIndex = 1101 }, deletePrompt)
		local no = mk("TextButton", { Text = "Cancel", Position = UDim2.new(0.5, 6, 1, -48), Size = UDim2.new(0.5, -20, 0, 34), ZIndex = 1101 }, deletePrompt)
		styleButton(yes, THEME.red)
		styleButton(no, THEME.inner)
		yes.Activated:Connect(function()
			local result = invoke("DeleteInventory", { Slot = slotIndex })
			applyMoveResult(result)
			if deletePrompt then deletePrompt:Destroy(); deletePrompt = nil end
		end)
		no.Activated:Connect(function()
			if deletePrompt then deletePrompt:Destroy(); deletePrompt = nil end
		end)
	end

	local function ensureStorageWindow()
		if storageWindow then return end
		storageWindow = mk("Frame", { Name = "StorageWindow", BackgroundColor3 = THEME.panel2, BackgroundTransparency = 0.04, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.42, 0, 0.52, 0), Size = UDim2.new(0, 610, 0, 520), Visible = false, ZIndex = 210 }, gui)
		corner(storageWindow, 8)
		stroke(storageWindow, 1.5, THEME.gold, 0.08)
		storageTitle = mk("TextLabel", { Name = "Title", BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "Storage", TextColor3 = THEME.text, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 18, 0, 10), Size = UDim2.new(1, -72, 0, 34), ZIndex = 211 }, storageWindow)
		local close = mk("TextButton", { Name = "Close", Text = "X", Position = UDim2.new(1, -44, 0, 10), Size = UDim2.fromOffset(30, 30), ZIndex = 212 }, storageWindow)
		styleButton(close, THEME.inner)
		close.Activated:Connect(function()
			storageWindow.Visible = false
			currentStorage = nil
			storageSnapshot = nil
		end)
		tabBar = mk("Frame", { Name = "TabBar", BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 52), Size = UDim2.new(1, -32, 0, 34), ZIndex = 211 }, storageWindow)
		local tabLayout = Instance.new("UIListLayout")
		tabLayout.FillDirection = Enum.FillDirection.Horizontal
		tabLayout.Padding = UDim.new(0, 8)
		tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
		tabLayout.Parent = tabBar
		storageScrollFrame = mk("ScrollingFrame", { Name = "StorageScroll", BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.1, BorderSizePixel = 0, Position = UDim2.new(0, 16, 0, 94), Size = UDim2.new(1, -32, 1, -110), ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 211 }, storageWindow)
		corner(storageScrollFrame, 8)
		stroke(storageScrollFrame, 1, THEME.goldDim, 0.35)
		storageGrid = Instance.new("UIGridLayout")
		storageGrid.CellPadding = UDim2.fromOffset(6, 6)
		storageGrid.CellSize = UDim2.fromOffset(48, 48)
		storageGrid.SortOrder = Enum.SortOrder.LayoutOrder
		storageGrid.Parent = storageScrollFrame
	end

	local function ensureStorageSlot(slotIndex)
		local frame = storageViews[slotIndex] and storageViews[slotIndex].Frame
		if not frame then
			frame = mk("Frame", { Name = string.format("StorageSlot_%03d", slotIndex), BackgroundColor3 = THEME.inner, BackgroundTransparency = 0.08, BorderSizePixel = 0, LayoutOrder = slotIndex, ZIndex = 212 }, storageScrollFrame)
			corner(frame, 7)
			stroke(frame, 1, THEME.goldDim, 0.55)
			local inner = mk("Frame", { Name = "Inner", BackgroundColor3 = THEME.inner, BackgroundTransparency = 0.16, BorderSizePixel = 0, Position = UDim2.new(0.08, 0, 0.08, 0), Size = UDim2.new(0.84, 0, 0.84, 0), ZIndex = 213 }, frame)
			corner(inner, 6)
			local icon = mk("ImageLabel", { Name = "ItemIcon", BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Position = UDim2.new(0.12, 0, 0.1, 0), Size = UDim2.new(0.76, 0, 0.76, 0), Visible = false, ZIndex = 214 }, inner)
			local count = mk("TextLabel", { Name = "Count", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = THEME.text, TextStrokeTransparency = 0.45, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.96, 0, 0.96, 0), Size = UDim2.new(0.7, 0, 0.3, 0), Visible = false, ZIndex = 215 }, frame)
			local quality = mk("TextLabel", { Name = "QualityBadge", BackgroundColor3 = THEME.goldDim, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(10, 8, 7), TextScaled = true, Position = UDim2.new(0.06, 0, 0.06, 0), Size = UDim2.new(0.27, 0, 0.22, 0), Visible = false, ZIndex = 215 }, frame)
			corner(quality, 4)
			local purity = mk("TextLabel", { Name = "PurityBadge", BackgroundColor3 = THEME.goldDim, BorderSizePixel = 0, Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(10, 8, 7), TextScaled = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.94, 0, 0.06, 0), Size = UDim2.new(0.27, 0, 0.22, 0), Visible = false, ZIndex = 215 }, frame)
			corner(purity, 4)
			local hit = mk("TextButton", { Name = "StorageHit", Text = "", BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Size = UDim2.fromScale(1, 1), ZIndex = 216 }, frame)
			hit.InputBegan:Connect(function(input)
				if not primaryInput(input) then return end
				local source = { Type = "Storage", Slot = slotIndex }
				local stack = stackAt(source)
				if not stack then return end
				if shiftDown() then
					quickTransfer(source)
					return
				end
				beginDrag(source, stack, input)
			end)
			storageViews[slotIndex] = { Frame = frame, Inner = inner, Icon = icon, Count = count, Quality = quality, Purity = purity, Hit = hit }
		end
		return storageViews[slotIndex]
	end

	local function renderTabs()
		for _, child in ipairs(tabBar:GetChildren()) do
			if child:IsA("GuiButton") then child:Destroy() end
		end
		local tabs = storageSnapshot and storageSnapshot.Tabs or 1
		tabBar.Visible = tabs > 1
		for i = 1, tabs do
			local b = mk("TextButton", { Text = "Tab " .. tostring(i), Size = UDim2.fromOffset(76, 30), LayoutOrder = i, ZIndex = 212 }, tabBar)
			styleButton(b, i == storageSnapshot.Tab and THEME.goldDim or THEME.inner)
			b.Activated:Connect(function()
				if not currentStorage then return end
				currentStorage.Tab = i
				requestStorage(i)
			end)
		end
	end

	renderStorage = function()
		if not currentStorage or not storageSnapshot then return end
		ensureStorageWindow()
		storageWindow.Visible = true
		local isBank = storageSnapshot.Type == "Bank"
		storageWindow.Size = isBank and UDim2.new(0, 610, 0, 520) or UDim2.new(0, 520, 0, 310)
		storageTitle.Text = storageSnapshot.DisplayName or (isBank and "Player Bank" or "Treasure Chest")
		renderTabs()
		local maxSlots = storageSnapshot.MaxSlots or 0
		for i = 1, maxSlots do
			local view = ensureStorageSlot(i)
			renderSlotFrame(view, storageSnapshot.Slots and storageSnapshot.Slots[tostring(i)] or nil)
		end
		for i, view in pairs(storageViews) do
			view.Frame.Visible = i <= maxSlots
		end
	end

	requestStorage = function(tab)
		if not currentStorage then return end
		local result = invoke("GetStorageSnapshot", { StorageType = currentStorage.StorageType, StorageId = currentStorage.StorageId, Tab = tab or currentStorage.Tab or 1 })
		if type(result) == "table" and result.Ok and type(result.Storage) == "table" then
			storageSnapshot = result.Storage
			currentStorage.Tab = storageSnapshot.Tab
			renderStorage()
		end
	end

	local function ensureMarketWindow()
		if marketWindow then return end
		marketWindow = mk("Frame", { Name = "CharredTokenMarket", BackgroundColor3 = THEME.panel2, BackgroundTransparency = 0.03, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(620, 430), Visible = false, ZIndex = 420 }, gui)
		corner(marketWindow, 8)
		stroke(marketWindow, 1.5, THEME.gold, 0.08)
		mk("TextLabel", { Name = "Title", BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, Text = "Charred Token Exchange", TextColor3 = THEME.text, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 18, 0, 12), Size = UDim2.new(1, -72, 0, 34), ZIndex = 421 }, marketWindow)
		local close = mk("TextButton", { Text = "X", Position = UDim2.new(1, -44, 0, 12), Size = UDim2.fromOffset(30, 30), ZIndex = 422 }, marketWindow)
		styleButton(close, THEME.inner)
		close.Activated:Connect(function() marketWindow.Visible = false end)
		local price = mk("TextBox", { Name = "PriceBox", PlaceholderText = "Coin each", Text = "100", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextColor3 = THEME.text, PlaceholderColor3 = THEME.subtle, TextSize = 14, BackgroundColor3 = THEME.inner, BorderSizePixel = 0, Position = UDim2.new(0, 18, 0, 62), Size = UDim2.fromOffset(132, 34), ZIndex = 421 }, marketWindow)
		corner(price, 7); stroke(price, 1, THEME.goldDim, 0.35)
		local amount = mk("TextBox", { Name = "AmountBox", PlaceholderText = "Amount", Text = "1", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextColor3 = THEME.text, PlaceholderColor3 = THEME.subtle, TextSize = 14, BackgroundColor3 = THEME.inner, BorderSizePixel = 0, Position = UDim2.new(0, 158, 0, 62), Size = UDim2.fromOffset(110, 34), ZIndex = 421 }, marketWindow)
		corner(amount, 7); stroke(amount, 1, THEME.goldDim, 0.35)
		local buy = mk("TextButton", { Text = "Buy Order", Position = UDim2.new(0, 278, 0, 62), Size = UDim2.fromOffset(112, 34), ZIndex = 421 }, marketWindow)
		local sell = mk("TextButton", { Text = "Sell Order", Position = UDim2.new(0, 398, 0, 62), Size = UDim2.fromOffset(112, 34), ZIndex = 421 }, marketWindow)
		styleButton(buy, THEME.green); styleButton(sell, THEME.red)
		local lists = mk("Frame", { Name = "Lists", BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 112), Size = UDim2.new(1, -36, 1, -130), ZIndex = 421 }, marketWindow)
		local function makeList(name, xScale, title)
			local frame = mk("Frame", { Name = name, BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.12, BorderSizePixel = 0, Position = UDim2.new(xScale, xScale == 0 and 0 or 8, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), ZIndex = 421 }, lists)
			corner(frame, 8); stroke(frame, 1, THEME.goldDim, 0.4)
			mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = title, TextColor3 = THEME.text, TextSize = 15, Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(1, -20, 0, 24), ZIndex = 422 }, frame)
			local scroll = mk("ScrollingFrame", { Name = "Scroll", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 10, 0, 36), Size = UDim2.new(1, -20, 1, -46), ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 422 }, frame)
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, 6)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = scroll
			return scroll
		end
		makeList("BuyList", 0, "Buy Orders")
		makeList("SellList", 0.5, "Sell Orders")
		local function place(side)
			local result = invoke("PlaceMarketOrder", { Side = side, Price = tonumber(price.Text), Amount = tonumber(amount.Text) })
			applyMoveResult(result)
			if type(result) == "table" and result.Market then
				snapshot = snapshot or {}
				snapshot.Market = result.Market
			end
			Controller.RenderMarket()
		end
		buy.Activated:Connect(function() place("Buy") end)
		sell.Activated:Connect(function() place("Sell") end)
	end

	function Controller.RenderMarket()
		ensureMarketWindow()
		local result = invoke("GetMarket")
		if type(result) == "table" and result.Ok then
			snapshot = snapshot or {}
			snapshot.Market = result.Market
			if result.Economy then snapshot.Economy = result.Economy; applyEconomy() end
		end
		local market = snapshot and snapshot.Market or { Buys = {}, Sells = {} }
		local function fill(scroll, rows)
			for _, child in ipairs(scroll:GetChildren()) do
				if child:IsA("GuiObject") then child:Destroy() end
			end
			for i, row in ipairs(rows or {}) do
				local r = mk("Frame", { BackgroundColor3 = THEME.inner, BackgroundTransparency = 0.12, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = i, ZIndex = 423 }, scroll)
				corner(r, 6)
				mk("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = string.format("%s @ %s", comma(row.Amount or 0), formatCurrency(row.Price or 0)), TextColor3 = THEME.text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, row.Mine and -78 or -16, 1, 0), ZIndex = 424 }, r)
				if row.Mine then
					local cancel = mk("TextButton", { Text = "Cancel", Position = UDim2.new(1, -68, 0.5, -13), Size = UDim2.fromOffset(58, 26), ZIndex = 424 }, r)
					styleButton(cancel, THEME.red)
					cancel.TextSize = 11
					cancel.Activated:Connect(function()
						local res = invoke("CancelMarketOrder", { OrderId = row.Id })
						applyMoveResult(res)
						Controller.RenderMarket()
					end)
				end
			end
		end
		fill(marketWindow.Lists.BuyList.Scroll, market.Buys)
		fill(marketWindow.Lists.SellList.Scroll, market.Sells)
	end

	local function openMarket()
		ensureMarketWindow()
		marketWindow.Visible = true
		Controller.RenderMarket()
	end

	if tokenFrame and not tokenFrame:FindFirstChild("TokenMarketHit") then
		local hit = mk("TextButton", { Name = "TokenMarketHit", Text = "", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = tokenFrame.ZIndex + 4 }, tokenFrame)
		hit.Activated:Connect(openMarket)
	end

	UserInputService.InputChanged:Connect(function(input)
		if not drag then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local point = pointerPosition(input)
		drag.Last = point
		if not drag.Moved and (point - drag.Start).Magnitude >= DRAG_THRESHOLD then drag.Moved = true end
		if drag.Moved then
			local itemGhost = ensureGhost(drag)
			itemGhost.Position = UDim2.fromOffset(point.X, point.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not drag or not primaryInput(input) then return end
		local finished = drag
		drag = nil
		local point = pointerPosition(input)
		destroyGhost()
		setInventoryDragActive(false)
		if finished.Moved then
			local target = slotAt(point)
			if target then
				moveSourceToTarget(finished.Source, target)
			elseif finished.Source.Type == "Inventory" and not inventorySurfaceAt(point) then
				showDeletePrompt(finished.Source.Slot, point)
			end
		else
			openDetail(finished.Source)
		end
	end)

	inventoryUpdated.OnClientEvent:Connect(function(serverSnapshot)
		if type(serverSnapshot) == "table" and serverSnapshot.Ok then
			snapshot = serverSnapshot
			render()
		end
	end)

	openStorage.OnClientEvent:Connect(function(info)
		if type(info) ~= "table" then return end
		setInventoryVisible(true)
		currentStorage = { StorageType = info.StorageType, StorageId = info.StorageId, DisplayName = info.DisplayName, Tab = info.Tab or 1 }
		requestStorage(currentStorage.Tab)
	end)

	requestSnapshot()
	render()
end

return Controller
