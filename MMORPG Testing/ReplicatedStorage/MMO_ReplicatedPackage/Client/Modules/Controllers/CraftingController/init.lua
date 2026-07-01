--[[
Name: CraftingController
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Controllers.CraftingController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, UserInputService
Requires:
  - local ImageCatalog = require(sharedFolder:WaitForChild("ImageCatalog"))
  - local ItemCatalog = require(sharedFolder:WaitForChild("ItemCatalog"))
Functions: mk, addCorner, addStroke, clearGuiList, invoke, setStatus, costText, matchesSearch, currentPurity, currentRecipeRows, currentMaxCraftable, setCraftTooltip, updateCraftSliderVisual, setCraftAmount, renderCraftPopup, setSliderFromX, closeCraftPopup, openCraftPopup, ensureGui, makeTabButton, renderTabs, itemRow, renderItems, Controller.render, Controller.close, Controller.openFromDetector, _G.CloseCraftingStationPanel
Clean source lines: 870
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local sharedFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared")
local ImageCatalog = require(sharedFolder:WaitForChild("ImageCatalog"))
local ItemCatalog = require(sharedFolder:WaitForChild("ItemCatalog"))

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("CraftingStationRemotes")
local requestRemote = remotesFolder:WaitForChild("Request")

local Controller = {}

local Theme = {
	panelBg = Color3.fromRGB(14, 10, 10),
	panelTop = Color3.fromRGB(28, 20, 18),
	slotOuter = Color3.fromRGB(26, 18, 16),
	slotInner = Color3.fromRGB(38, 26, 22),
	gilt = Color3.fromRGB(232, 176, 64),
	text = Color3.fromRGB(242, 228, 198),
	subtleText = Color3.fromRGB(210, 196, 166),
	success = Color3.fromRGB(88, 188, 116),
	danger = Color3.fromRGB(190, 72, 68),
	blue = Color3.fromRGB(60, 150, 255),
}

local gui
local panel
local titleLabel
local statusLabel
local manageButton
local searchBox
local craftableButton
local tabList
local inspectTabButton
local itemList
local craftPopup
local craftPopupTitle
local craftPopupIcon
local craftPopupPurityLabel
local craftAmountBox
local craftSliderTrack
local craftSliderFill
local craftSliderKnob
local craftRecipeList
local craftConfirmButton
local craftPopupStatus
local craftTooltip
local craftPurityPrev
local craftPurityNext
local activeCraftItem
local activeCraftPurityIndex = 1
local activeCraftAmount = 1
local sliderDragging = false
local state = {
	buildingKey = nil,
	buildingInstanceId = nil,
	snapshot = nil,
	activeCategory = nil,
	craftableOnly = false,
	search = "",
}

local function mk(className, props, children)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do
		obj[key] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	return obj
end

local function addCorner(parent, radius)
	mk("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function addStroke(parent, color, thickness, transparency)
	mk("UIStroke", { Color = color or Theme.gilt, Thickness = thickness or 1, Transparency = transparency or 0.16, Parent = parent })
end

local function clearGuiList(container)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function invoke(actionName, payload)
	local ok, result = pcall(function()
		return requestRemote:InvokeServer(actionName, payload or {})
	end)
	if not ok then
		return { Ok = false, Error = tostring(result) }
	end
	return type(result) == "table" and result or { Ok = false, Error = "Crafting request failed." }
end

local function setStatus(text, danger)
	if statusLabel then
		statusLabel.Text = tostring(text or "")
		statusLabel.TextColor3 = danger and Theme.danger or Theme.subtleText
	end
end

local function costText(recipe)
	local parts = {}
	for _, req in ipairs(recipe or {}) do
		table.insert(parts, tostring(req.DisplayName or req.ItemId) .. " x" .. tostring(req.Amount or 1))
	end
	return (#parts > 0) and table.concat(parts, "  ") or "Free"
end

local function matchesSearch(item)
	local search = tostring(state.search or ""):lower()
	if search == "" then return true end
	return tostring(item.DisplayName or item.ItemId or ""):lower():find(search, 1, true) ~= nil
end

local function currentPurity()
	local options = (activeCraftItem and activeCraftItem.PurityOptions) or { "None" }
	activeCraftPurityIndex = math.clamp(activeCraftPurityIndex, 1, math.max(1, #options))
	return options[activeCraftPurityIndex] or "None"
end

local function currentRecipeRows()
	if not activeCraftItem then return {} end
	local variants = activeCraftItem.RecipeVariants or {}
	return variants[currentPurity()] or variants.None or activeCraftItem.Recipe or {}
end

local function currentMaxCraftable()
	if not activeCraftItem then return 0 end
	local maxes = activeCraftItem.MaxCraftableByPurity or {}
	return math.max(0, math.floor(tonumber(maxes[currentPurity()] or activeCraftItem.MaxCraftable) or 0))
end

local function setCraftTooltip(text)
	if craftTooltip then
		craftTooltip.Text = tostring(text or "")
		craftTooltip.Visible = text ~= nil and text ~= ""
	end
end

local function updateCraftSliderVisual()
	if not craftSliderFill or not craftSliderKnob then return end
	local maxAmount = math.max(1, currentMaxCraftable())
	local alpha = maxAmount <= 1 and 1 or math.clamp((activeCraftAmount - 1) / (maxAmount - 1), 0, 1)
	craftSliderFill.Size = UDim2.new(alpha, 0, 1, 0)
	craftSliderKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
end

local function setCraftAmount(value)
	local maxAmount = currentMaxCraftable()
	local upper = math.max(1, maxAmount)
	activeCraftAmount = math.clamp(math.floor(tonumber(value) or 1), 1, upper)
	if craftAmountBox and not craftAmountBox:IsFocused() then
		craftAmountBox.Text = tostring(activeCraftAmount)
	end
	updateCraftSliderVisual()
end

local function renderCraftPopup()
	if not craftPopup or not activeCraftItem then return end
	local purity = currentPurity()
	local purityOptions = activeCraftItem.PurityOptions or { "None" }
	local maxAmount = currentMaxCraftable()
	setCraftAmount(activeCraftAmount)
	craftPopupTitle.Text = tostring(activeCraftItem.DisplayName or activeCraftItem.ItemId or "Craft")
	craftPopupPurityLabel.Text = (#purityOptions > 1) and ("Purity: " .. purity) or "Purity: None"
	craftPurityPrev.Visible = #purityOptions > 1
	craftPurityNext.Visible = #purityOptions > 1
	ImageCatalog.SetImage(craftPopupIcon, activeCraftItem.Icon or "Default")
	craftConfirmButton.Text = maxAmount > 0 and "Craft" or "Missing"
	craftConfirmButton.AutoButtonColor = maxAmount > 0
	craftConfirmButton.BackgroundColor3 = maxAmount > 0 and Theme.success or Theme.slotOuter
	clearGuiList(craftRecipeList)
	for _, req in ipairs(currentRecipeRows()) do
		local needed = math.max(1, math.floor(tonumber(req.Amount) or 1)) * activeCraftAmount
		local owned = math.max(0, math.floor(tonumber(req.Owned) or 0))
		local card = mk("Frame", {
			Size = UDim2.fromOffset(82, 98),
			BackgroundColor3 = Theme.slotInner,
			BackgroundTransparency = 0.05,
			Parent = craftRecipeList,
		})
		addCorner(card, 8)
		addStroke(card, owned >= needed and Theme.gilt or Theme.danger, 1, 0.2)
		local icon = mk("ImageButton", {
			Position = UDim2.fromOffset(13, 8),
			Size = UDim2.fromOffset(56, 56),
			BackgroundColor3 = Theme.slotOuter,
			BackgroundTransparency = 0.08,
			AutoButtonColor = true,
			Image = "",
			Parent = card,
		})
		addCorner(icon, 7)
		ImageCatalog.SetImage(icon, req.Icon or "Default")
		icon.MouseEnter:Connect(function()
			setCraftTooltip(req.DisplayName or req.ItemId)
		end)
		icon.MouseLeave:Connect(function()
			setCraftTooltip(nil)
		end)
		icon.Activated:Connect(function()
			if type(_G.OpenItemDetail) == "function" then
				local detail = ItemCatalog.BuildDetail({ Id = req.ItemId, Amount = 1 })
				if detail then _G.OpenItemDetail(detail) end
			end
		end)
		mk("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(6, 66),
			Size = UDim2.new(1, -12, 0, 24),
			Font = Enum.Font.GothamBold,
			TextColor3 = owned >= needed and Theme.text or Theme.danger,
			TextScaled = true,
			TextWrapped = true,
			Text = tostring(owned) .. "/" .. tostring(needed),
			Parent = card,
		})
	end
	craftPopupStatus.TextColor3 = maxAmount > 0 and Theme.subtleText or Theme.danger
	craftPopupStatus.Text = maxAmount > 0 and ("Max: " .. tostring(maxAmount)) or "Not enough resources"
end

local function setSliderFromX(x)
	local maxAmount = currentMaxCraftable()
	if maxAmount <= 1 then
		setCraftAmount(1)
		return
	end
	local left = craftSliderTrack.AbsolutePosition.X
	local width = math.max(1, craftSliderTrack.AbsoluteSize.X)
	local alpha = math.clamp((x - left) / width, 0, 1)
	setCraftAmount(1 + math.floor(alpha * (maxAmount - 1) + 0.5))
	renderCraftPopup()
end

local function closeCraftPopup()
	if craftPopup then
		craftPopup.Visible = false
	end
	activeCraftItem = nil
	setCraftTooltip(nil)
end

local function openCraftPopup(item)
	if not craftPopup then return end
	activeCraftItem = item
	activeCraftPurityIndex = 1
	activeCraftAmount = 1
	craftAmountBox.Text = "1"
	craftPopup.Visible = true
	renderCraftPopup()
end

local function ensureGui()
	if gui and gui.Parent then return end
	gui = mk("ScreenGui", {
		Name = "CraftingStationUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 8200,
		Parent = player:WaitForChild("PlayerGui"),
	})
	panel = mk("Frame", {
		Visible = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 24, 0.5, 0),
		Size = UDim2.new(0, 430, 0, 560),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.05,
		Parent = gui,
	})
	addCorner(panel, 12)
	addStroke(panel, Theme.gilt, 1.5, 0.12)
	mk("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.panelTop), ColorSequenceKeypoint.new(1, Theme.panelBg) }),
		Parent = panel,
	})
	titleLabel = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -58, 0, 34),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Crafting",
		Parent = panel,
	})
	local close = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "X",
		Parent = panel,
	})
	addCorner(close, 7)
	addStroke(close, Theme.gilt, 1, 0.2)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	manageButton = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -48, 0, 12),
		Size = UDim2.fromOffset(74, 30),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "Manage",
		Parent = panel,
	})
	addCorner(manageButton, 7)
	addStroke(manageButton, Theme.gilt, 1, 0.2)
	manageButton.Activated:Connect(function()
		if type(_G.OpenBuildingManagePanel) == "function" then
			_G.OpenBuildingManagePanel(state.buildingInstanceId or state.buildingKey)
			panel.Visible = false
		end
	end)
	statusLabel = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 48),
		Size = UDim2.new(1, -32, 0, 24),
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.subtleText,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = panel,
	})
	searchBox = mk("TextBox", {
		Position = UDim2.fromOffset(16, 82),
		Size = UDim2.new(1, -152, 0, 36),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.text,
		PlaceholderColor3 = Theme.subtleText,
		TextScaled = true,
		Text = "",
		PlaceholderText = "Search",
		Parent = panel,
	})
	addCorner(searchBox, 8)
	addStroke(searchBox, Theme.gilt, 1, 0.25)
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		state.search = searchBox.Text
		Controller.render()
	end)
	craftableButton = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -88, 0, 82),
		Size = UDim2.fromOffset(72, 36),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "All",
		Parent = panel,
	})
	addCorner(craftableButton, 8)
	addStroke(craftableButton, Theme.gilt, 1, 0.22)
	craftableButton.Activated:Connect(function()
		state.craftableOnly = not state.craftableOnly
		Controller.render()
	end)
	itemList = mk("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 134),
		Size = UDim2.new(1, -110, 1, -150),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 5,
		Parent = panel,
	})
	mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = itemList })
	tabList = mk("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 134),
		Size = UDim2.new(0, 78, 1, -204),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })
	inspectTabButton = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(78, 42),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextWrapped = true,
		Text = "Inspect",
		Parent = panel,
	})
	addCorner(inspectTabButton, 8)
	addStroke(inspectTabButton, Theme.gilt, 1, 0.2)
	inspectTabButton.Activated:Connect(function()
		state.activeCategory = "__Inspect"
		Controller.render()
	end)

	craftPopup = mk("Frame", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.9, 0, 0, 430),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.03,
		Parent = gui,
	})
	addCorner(craftPopup, 12)
	addStroke(craftPopup, Theme.gilt, 1.5, 0.1)
	mk("UISizeConstraint", { MaxSize = Vector2.new(660, 430), MinSize = Vector2.new(310, 380), Parent = craftPopup })
	mk("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.panelTop), ColorSequenceKeypoint.new(1, Theme.panelBg) }),
		Parent = craftPopup,
	})
	craftPopupTitle = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -58, 0, 34),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Craft",
		Parent = craftPopup,
	})
	local closePopup = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "X",
		Parent = craftPopup,
	})
	addCorner(closePopup, 7)
	addStroke(closePopup, Theme.gilt, 1, 0.2)
	closePopup.Activated:Connect(closeCraftPopup)
	craftPopupIcon = mk("ImageLabel", {
		Position = UDim2.fromOffset(18, 58),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Image = "",
		Parent = craftPopup,
	})
	addCorner(craftPopupIcon, 8)
	addStroke(craftPopupIcon, Theme.gilt, 1, 0.2)
	craftPurityPrev = mk("TextButton", {
		Position = UDim2.fromOffset(104, 58),
		Size = UDim2.fromOffset(32, 30),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "<",
		Parent = craftPopup,
	})
	addCorner(craftPurityPrev, 7)
	addStroke(craftPurityPrev, Theme.gilt, 1, 0.25)
	craftPopupPurityLabel = mk("TextLabel", {
		Position = UDim2.fromOffset(142, 58),
		Size = UDim2.new(1, -220, 0, 30),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.16,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextWrapped = true,
		Text = "Purity: None",
		Parent = craftPopup,
	})
	addCorner(craftPopupPurityLabel, 7)
	craftPurityNext = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 58),
		Size = UDim2.fromOffset(32, 30),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = ">",
		Parent = craftPopup,
	})
	addCorner(craftPurityNext, 7)
	addStroke(craftPurityNext, Theme.gilt, 1, 0.25)
	craftPurityPrev.Activated:Connect(function()
		local options = (activeCraftItem and activeCraftItem.PurityOptions) or { "None" }
		activeCraftPurityIndex = activeCraftPurityIndex - 1
		if activeCraftPurityIndex < 1 then activeCraftPurityIndex = #options end
		activeCraftAmount = 1
		renderCraftPopup()
	end)
	craftPurityNext.Activated:Connect(function()
		local options = (activeCraftItem and activeCraftItem.PurityOptions) or { "None" }
		activeCraftPurityIndex = activeCraftPurityIndex + 1
		if activeCraftPurityIndex > #options then activeCraftPurityIndex = 1 end
		activeCraftAmount = 1
		renderCraftPopup()
	end)
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(104, 98),
		Size = UDim2.fromOffset(72, 24),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.subtleText,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Amount",
		Parent = craftPopup,
	})
	craftAmountBox = mk("TextBox", {
		Position = UDim2.fromOffset(104, 126),
		Size = UDim2.fromOffset(72, 34),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "1",
		Parent = craftPopup,
	})
	addCorner(craftAmountBox, 7)
	addStroke(craftAmountBox, Theme.gilt, 1, 0.25)
	craftAmountBox.FocusLost:Connect(function()
		setCraftAmount(craftAmountBox.Text)
		renderCraftPopup()
	end)
	craftSliderTrack = mk("Frame", {
		Position = UDim2.fromOffset(188, 138),
		Size = UDim2.new(1, -216, 0, 10),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Parent = craftPopup,
	})
	addCorner(craftSliderTrack, 5)
	craftSliderFill = mk("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.gilt,
		BackgroundTransparency = 0.08,
		Parent = craftSliderTrack,
	})
	addCorner(craftSliderFill, 5)
	craftSliderKnob = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Theme.text,
		Parent = craftSliderTrack,
	})
	addCorner(craftSliderKnob, 9)
	craftSliderTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliderDragging = true
			setSliderFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setSliderFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliderDragging = false
		end
	end)
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 180),
		Size = UDim2.new(1, -36, 0, 24),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Total Resources",
		Parent = craftPopup,
	})
	craftRecipeList = mk("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 210),
		Size = UDim2.new(1, -36, 0, 112),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		Parent = craftPopup,
	})
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = craftRecipeList })
	craftPopupStatus = mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 332),
		Size = UDim2.new(1, -160, 0, 28),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.subtleText,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = craftPopup,
	})
	craftConfirmButton = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(124, 42),
		BackgroundColor3 = Theme.success,
		BackgroundTransparency = 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "Craft",
		Parent = craftPopup,
	})
	addCorner(craftConfirmButton, 8)
	addStroke(craftConfirmButton, Theme.gilt, 1, 0.18)
	craftConfirmButton.Activated:Connect(function()
		if not activeCraftItem or currentMaxCraftable() <= 0 then return end
		local result = invoke("CraftItem", {
			BuildingKey = state.buildingKey,
			BuildingInstanceId = state.buildingInstanceId,
			ItemId = activeCraftItem.ItemId,
			Amount = activeCraftAmount,
			Purity = currentPurity(),
		})
		if result.Ok then
			state.snapshot = result
			setStatus(result.Message or "Item crafted.")
			closeCraftPopup()
			Controller.render()
		else
			craftPopupStatus.Text = result.Error or "Could not craft item."
			craftPopupStatus.TextColor3 = Theme.danger
		end
	end)
	craftTooltip = mk("TextLabel", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, -230),
		Size = UDim2.fromOffset(300, 30),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.05,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = "",
		Parent = gui,
	})
	addCorner(craftTooltip, 7)
	addStroke(craftTooltip, Theme.gilt, 1, 0.18)
end

local function makeTabButton(key, text, order)
	local active = state.activeCategory == key
	local button = mk("TextButton", {
		LayoutOrder = order or 1,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = active and Theme.blue or Theme.slotOuter,
		BackgroundTransparency = active and 0.02 or 0.08,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextWrapped = true,
		Text = tostring(text or key),
		Parent = tabList,
	})
	addCorner(button, 8)
	addStroke(button, active and Theme.text or Theme.gilt, 1, active and 0 or 0.2)
	button.Activated:Connect(function()
		state.activeCategory = key
		Controller.render()
	end)
end

local function renderTabs()
	clearGuiList(tabList)
	local snapshot = state.snapshot
	for index, category in ipairs((snapshot and snapshot.Categories) or {}) do
		makeTabButton(category.Key, category.DisplayName, index)
	end
	if inspectTabButton then
		local active = state.activeCategory == "__Inspect"
		inspectTabButton.BackgroundColor3 = active and Theme.blue or Theme.slotOuter
		inspectTabButton.BackgroundTransparency = active and 0.02 or 0.08
		local stroke = inspectTabButton:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = active and Theme.text or Theme.gilt
			stroke.Transparency = active and 0 or 0.2
		end
	end
end

local function itemRow(item, actionText, callback, disabled)
	local row = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 86),
		BackgroundColor3 = Theme.slotInner,
		BackgroundTransparency = 0.05,
		Parent = itemList,
	})
	addCorner(row, 8)
	addStroke(row, Theme.gilt, 1, 0.22)
	local icon = mk("ImageLabel", {
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.08,
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.fromOffset(54, 54),
		Parent = row,
	})
	addCorner(icon, 7)
	ImageCatalog.SetImage(icon, item.Icon or "Default")
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(74, 8),
		Size = UDim2.new(1, -154, 0, 26),
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(item.DisplayName or item.ItemId),
		Parent = row,
	})
	mk("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(74, 34),
		Size = UDim2.new(1, -154, 0, 42),
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.subtleText,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = actionText == "Study" and ("Owned: " .. tostring(item.Owned or 0) .. "  |  " .. tostring(item.CraftingSkillKey or "Crafting")) or (item.LockedReason or costText(item.Recipe)),
		Parent = row,
	})
	local action = mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(68, 34),
		BackgroundColor3 = disabled and Theme.slotOuter or Theme.success,
		BackgroundTransparency = disabled and 0.35 or 0.08,
		AutoButtonColor = not disabled,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextScaled = true,
		Text = actionText,
		Parent = row,
	})
	addCorner(action, 8)
	if not disabled then
		action.Activated:Connect(callback)
	end
end

local function renderItems()
	clearGuiList(itemList)
	local snapshot = state.snapshot
	if not snapshot then return end
	if state.activeCategory == "__Inspect" then
		for _, item in ipairs(snapshot.InspectItems or {}) do
			if matchesSearch(item) then
				itemRow(item, "Study", function()
					local result = invoke("StudyItem", { BuildingKey = state.buildingKey, BuildingInstanceId = state.buildingInstanceId, ItemId = item.ItemId })
					if result.Ok then
						state.snapshot = result
						setStatus(result.Message or "Item studied.")
						Controller.render()
					else
						setStatus(result.Error or "Could not study item.", true)
					end
				end, (item.Owned or 0) <= 0)
			end
		end
		return
	end
	for _, category in ipairs(snapshot.Categories or {}) do
		if category.Key == state.activeCategory then
			for _, item in ipairs(category.Items or {}) do
				local canCraftAny = item.AnyCraftable == true or item.Craftable == true
				if matchesSearch(item) and (not state.craftableOnly or canCraftAny) then
					itemRow(item, "Craft", function()
						openCraftPopup(item)
					end, not canCraftAny)
				end
			end
			return
		end
	end
end

function Controller.render()
	ensureGui()
	local snapshot = state.snapshot
	if not snapshot then return end
	titleLabel.Text = tostring(snapshot.DisplayName or "Crafting")
	craftableButton.Text = state.craftableOnly and "Have" or "All"
	if not state.activeCategory then
		local first = snapshot.Categories and snapshot.Categories[1]
		state.activeCategory = first and first.Key or "__Inspect"
	end
	renderTabs()
	renderItems()
end

function Controller.close()
	if panel then
		panel.Visible = false
	end
end

_G.CloseCraftingStationPanel = function()
	Controller.close()
end

function Controller.openFromDetector(detector)
	ensureGui()
	if type(_G.CloseBuildManagePanel) == "function" then
		_G.CloseBuildManagePanel()
	end
	local buildingKey = detector and detector:GetAttribute("BuildingKey")
	local buildingInstanceId = detector and detector:GetAttribute("BuildingInstanceId")
	if not buildingKey or buildingKey == "" then
		return false
	end
	local result = invoke("GetStation", { BuildingKey = buildingKey, BuildingInstanceId = buildingInstanceId })
	if result.Ok then
		state.buildingKey = buildingKey
		state.buildingInstanceId = buildingInstanceId
		state.snapshot = result
		state.activeCategory = result.Categories and result.Categories[1] and result.Categories[1].Key or "__Inspect"
		panel.Visible = true
		setStatus(result.Message or "")
		Controller.render()
	else
		panel.Visible = true
		titleLabel.Text = "Crafting"
		setStatus(result.Error or "Crafting station unavailable.", true)
	end
	return true
end

return Controller
