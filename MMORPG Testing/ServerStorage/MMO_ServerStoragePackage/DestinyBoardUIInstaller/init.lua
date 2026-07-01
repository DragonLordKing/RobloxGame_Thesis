--[[
Name: DestinyBoardUIInstaller
Class: ModuleScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.DestinyBoardUIInstaller
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ContextActionService, Players, ReplicatedStorage, TweenService, UserInputService, StarterGui
Requires:
  - local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("DestinyBoardConfig"))
Functions: mk, corner, stroke, label, button, build, comma, baseOrder, isDescendantOf, activeOrder, add, getDef, getState, updateZoomLabel, setControlSize, updateFocusControls, applyResponsiveLayout, setContentPosition, layoutBoundsKey, siblingIndex, displayPointForKey, resizeBoard, worldToCanvas, detailTier, currentVisibleRect, pointInRect, segmentOverlapsRect, scheduleViewportRender, centerOn, setZoom, nodeColor, nodeSize, isMajorNode, isMasteryNode, canFocusNode, applyFocusTarget, focusOnNode, resetToRoot, goBack, shouldRenderNodeAtZoom, shouldShowNodeName, isUnlocked, isLearned, clearBoard, lineThickness, makeLineBetween, makeLine, makeNode, canvasToViewportPoint, buildLandmarkSet, addDirectChildren, addContext, shouldRenderLandmark, makeLandmark, renderLandmarks, refreshFromServer, sinkMovement, bindMovementSink, setOpen, showToast
Clean source lines: 1449
]]
local M = {}

local Theme = {
	rootBg = Color3.new(0, 0, 0),
	panelBg = Color3.fromRGB(18, 15, 14),
	panelBgSoft = Color3.fromRGB(28, 22, 18),
	gilt = Color3.fromRGB(232, 178, 74),
	giltDim = Color3.fromRGB(145, 107, 48),
	text = Color3.fromRGB(244, 232, 204),
	subtleText = Color3.fromRGB(198, 185, 154),
}

local function mk(className, props, kids)
	local o = Instance.new(className)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	for _, child in ipairs(kids or {}) do
		child.Parent = o
	end
	return o
end

local function corner(parent, r)
	local c = mk("UICorner", { CornerRadius = UDim.new(0, r or 8) })
	c.Parent = parent
	return c
end

local function stroke(parent, thickness, color, transparency)
	local s = mk("UIStroke", {
		Thickness = thickness or 1,
		Color = color or Theme.gilt,
		Transparency = transparency or 0.25,
	})
	s.Parent = parent
	return s
end

local function label(props)
	local base = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.subtleText,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}
	for k, v in pairs(props or {}) do
		base[k] = v
	end
	return mk("TextLabel", base)
end

local function button(props)
	local base = {
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(31, 28, 23),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextColor3 = Theme.text,
		TextSize = 14,
		ZIndex = 22,
	}
	for k, v in pairs(props or {}) do
		base[k] = v
	end
	local b = mk("TextButton", base)
	corner(b, 8)
	stroke(b, 1, Theme.giltDim, 0.28)
	return b
end

local function build(starterGui)
	local gui = mk("ScreenGui", {
		Name = "DestinyBoardUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9998,
	})
	gui.Parent = starterGui

	local root = mk("Frame", {
		Name = "BoardRoot",
		Active = true,
		Visible = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, {})
	root.Parent = gui
	mk("UIGradient", {
		Parent = root,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 15, 18)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(10, 11, 16)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 14, 12)),
		}),
		Rotation = 90,
	})

	mk("Frame", {
		Name = "CoreTopCover",
		BackgroundColor3 = Color3.fromRGB(5, 5, 7),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 96),
		ZIndex = 30,
		Parent = root,
	})

	local topBar = mk("Frame", {
		Name = "TopBar",
		BackgroundColor3 = Color3.fromRGB(16, 13, 12),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 96),
		Size = UDim2.new(1, 0, 0, 72),
		ZIndex = 20,
	}, {})
	topBar.Parent = root
	stroke(topBar, 1, Theme.giltDim, 0.45)

	label({ Name = "Title", Parent = topBar, Text = "DESTINY BOARD", Font = Enum.Font.GothamBlack, TextColor3 = Theme.text, TextSize = 27, Position = UDim2.new(0, 28, 0, 9), Size = UDim2.new(0, 330, 0, 34) })
	label({ Name = "SubTitle", Parent = topBar, Text = "Combat left, crafting above, gathering below", TextColor3 = Theme.subtleText, TextSize = 13, Position = UDim2.new(0, 30, 0, 44), Size = UDim2.new(0, 440, 0, 18) })

	local controlTray = mk("Frame", {
		Name = "ControlTray",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 380, 0, 15),
		Size = UDim2.new(0, 440, 0, 42),
		ZIndex = 22,
	}, {})
	controlTray.Parent = topBar
	mk("UIListLayout", { Parent = controlTray, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	button({ Name = "ZoomOutButton", Parent = controlTray, Text = "-", Size = UDim2.new(0, 38, 0, 34), LayoutOrder = 1 })
	label({ Name = "ZoomLabel", Parent = controlTray, Text = "64%", Font = Enum.Font.GothamBold, TextColor3 = Theme.text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = Color3.fromRGB(31, 28, 23), BackgroundTransparency = 0.1, Size = UDim2.new(0, 68, 0, 34), ZIndex = 22, LayoutOrder = 2 })
	button({ Name = "ZoomInButton", Parent = controlTray, Text = "+", Size = UDim2.new(0, 38, 0, 34), LayoutOrder = 3 })
	button({ Name = "BackButton", Parent = controlTray, Text = "<", Size = UDim2.new(0, 38, 0, 34), LayoutOrder = 4 })
	button({ Name = "ResetViewButton", Parent = controlTray, Text = "Reset", Size = UDim2.new(0, 76, 0, 34), LayoutOrder = 5 })
	button({ Name = "DebugButton", Parent = controlTray, Text = "Debug Off", Visible = false, Size = UDim2.new(0, 96, 0, 34), LayoutOrder = 6 })

	corner(controlTray.ZoomLabel, 8)
	stroke(controlTray.ZoomLabel, 1, Theme.giltDim, 0.28)

	local currencyTray = mk("Frame", {
		Name = "CurrencyTray",
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -26, 0.5, 0),
		Size = UDim2.new(0, 520, 0, 42),
		ZIndex = 21,
	}, {})
	currencyTray.Parent = topBar
	mk("UIListLayout", { Parent = currencyTray, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })

	local insight = label({ Name = "InsightLabel", Text = "Insight 0", Font = Enum.Font.GothamBold, TextColor3 = Theme.text, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = Color3.fromRGB(31, 28, 23), BackgroundTransparency = 0.12, Size = UDim2.new(0, 150, 0, 34), ZIndex = 22, LayoutOrder = 1 })
	insight.Parent = currencyTray
	corner(insight, 8)
	stroke(insight, 1, Theme.giltDim, 0.28)
	local combatPoints = label({ Name = "CombatValorPointsLabel", Text = "Combat Valor Points 0", Font = Enum.Font.GothamBold, TextColor3 = Theme.text, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = Color3.fromRGB(31, 28, 23), BackgroundTransparency = 0.12, Size = UDim2.new(0, 245, 0, 34), ZIndex = 22, LayoutOrder = 2 })
	combatPoints.Parent = currencyTray
	corner(combatPoints, 8)
	stroke(combatPoints, 1, Theme.giltDim, 0.28)

	local viewport = mk("Frame", {
		Name = "Viewport",
		Active = true,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.new(0, 0, 0, 168),
		Size = UDim2.new(1, 0, 1, -168),
		ZIndex = 2,
	}, {})
	viewport.Parent = root

	local content = mk("Frame", { Name = "BoardContent", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(12000, 12000), ZIndex = 3 }, {})
	content.Parent = viewport
	mk("UIScale", { Name = "BoardScale", Scale = 0.64, Parent = content })
	local landmarkLayer = mk("Frame", { Name = "LandmarkLayer", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 18 }, {})
	landmarkLayer.Parent = viewport

	local detail = mk("Frame", {
		Name = "DetailPanel",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.new(1, -24, 0, 192),
		Size = UDim2.new(0, 356, 1, -220),
		ZIndex = 25,
	}, {})
	detail.Parent = root
	corner(detail, 8)
	stroke(detail, 1.4, Theme.gilt, 0.24)
	mk("UIPadding", { Parent = detail, PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 18), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) })
	label({ Name = "SkillName", Parent = detail, Text = "Novice Adventurer", Font = Enum.Font.GothamBlack, TextColor3 = Theme.text, TextSize = 22, TextWrapped = true, Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 58), ZIndex = 26 })
	label({ Name = "CategoryLabel", Parent = detail, Text = "Adventurer", Font = Enum.Font.GothamBold, TextColor3 = Theme.gilt, TextSize = 14, Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 22), ZIndex = 26 })
	label({ Name = "LevelLabel", Parent = detail, Text = "Level 0 / 3", Font = Enum.Font.GothamBold, TextColor3 = Theme.text, TextSize = 18, Position = UDim2.new(0, 0, 0, 98), Size = UDim2.new(1, 0, 0, 26), ZIndex = 26 })
	local progressBack = mk("Frame", { Name = "ProgressBack", BackgroundColor3 = Color3.fromRGB(8, 8, 10), BackgroundTransparency = 0.05, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 138), Size = UDim2.new(1, 0, 0, 18), ZIndex = 26 }, {})
	progressBack.Parent = detail
	corner(progressBack, 8)
	stroke(progressBack, 1, Theme.giltDim, 0.4)
	local progressFill = mk("Frame", { Name = "ProgressFill", BackgroundColor3 = Theme.gilt, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), ZIndex = 27 }, {})
	progressFill.Parent = progressBack
	corner(progressFill, 8)
	label({ Name = "ProgressText", Parent = detail, Text = "0 / 0 Valor", TextColor3 = Theme.subtleText, TextSize = 13, Position = UDim2.new(0, 0, 0, 164), Size = UDim2.new(1, 0, 0, 22), ZIndex = 26 })
	label({ Name = "Description", Parent = detail, Text = "Select a node to inspect progression.", TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Theme.subtleText, TextSize = 14, Position = UDim2.new(0, 0, 0, 204), Size = UDim2.new(1, 0, 0, 150), ZIndex = 26 })
	label({ Name = "PathLabel", Parent = detail, Text = "", TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Bottom, TextColor3 = Theme.giltDim, TextSize = 12, Position = UDim2.new(0, 0, 1, -64), Size = UDim2.new(1, 0, 0, 64), ZIndex = 26 })

	local toast = label({ Name = "Toast", AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Theme.panelBgSoft, BackgroundTransparency = 0.08, Font = Enum.Font.GothamBold, Text = "", TextColor3 = Theme.text, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.new(0, 450, 0, 36), Visible = false, ZIndex = 40 })
	toast.Parent = root
	corner(toast, 8)
	stroke(toast, 1, Theme.giltDim, 0.24)

	local ctrl = Instance.new("LocalScript")
	ctrl.Name = "DestinyBoardController"
	ctrl.Source = [=[
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("DestinyBoardConfig"))
local Remotes = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")
local GetDestinyBoard = Remotes:WaitForChild("GetDestinyBoard")
local ValorUpdated = Remotes:WaitForChild("ValorUpdated")

local gui = script.Parent
local root = gui:WaitForChild("BoardRoot")
local coreTopCover = root:WaitForChild("CoreTopCover")
local viewport = root:WaitForChild("Viewport")
local content = viewport:WaitForChild("BoardContent")
local boardScale = content:WaitForChild("BoardScale")
local landmarkLayer = viewport:WaitForChild("LandmarkLayer")
local topBar = root:WaitForChild("TopBar")
local titleLabel = topBar:WaitForChild("Title")
local subtitleLabel = topBar:WaitForChild("SubTitle")
local controls = topBar:WaitForChild("ControlTray")
local controlLayout = controls:FindFirstChildOfClass("UIListLayout")
local zoomOutButton = controls:WaitForChild("ZoomOutButton")
local zoomInButton = controls:WaitForChild("ZoomInButton")
local zoomLabel = controls:WaitForChild("ZoomLabel")
local backButton = controls:WaitForChild("BackButton")
local resetViewButton = controls:WaitForChild("ResetViewButton")
local debugButton = controls:WaitForChild("DebugButton")
local currencyTray = topBar:WaitForChild("CurrencyTray")
local currencyLayout = currencyTray:FindFirstChildOfClass("UIListLayout")
local insightLabel = currencyTray:WaitForChild("InsightLabel")
local combatValorPointsLabel = currencyTray:WaitForChild("CombatValorPointsLabel")
local detail = root:WaitForChild("DetailPanel")
local detailPadding = detail:FindFirstChildOfClass("UIPadding")
local toast = root:WaitForChild("Toast")

local skillName = detail:WaitForChild("SkillName")
local categoryLabel = detail:WaitForChild("CategoryLabel")
local levelLabel = detail:WaitForChild("LevelLabel")
local progressBack = detail:WaitForChild("ProgressBack")
local progressFill = progressBack:WaitForChild("ProgressFill")
local progressText = detail:WaitForChild("ProgressText")
local descText = detail:WaitForChild("Description")
local pathLabel = detail:WaitForChild("PathLabel")

local Theme = {
	gilt = Color3.fromRGB(232, 178, 74),
	giltDim = Color3.fromRGB(145, 107, 48),
	text = Color3.fromRGB(244, 232, 204),
	subtleText = Color3.fromRGB(198, 185, 154),
	locked = Color3.fromRGB(28, 27, 29),
	combat = Color3.fromRGB(159, 62, 49),
	gathering = Color3.fromRGB(64, 132, 86),
	crafting = Color3.fromRGB(70, 114, 176),
	adventurer = Color3.fromRGB(194, 139, 58),
	veterancy = Color3.fromRGB(117, 78, 164),
	selected = Color3.fromRGB(92, 154, 220),
}

local closeBoardButton = topBar:FindFirstChild("CloseBoardButton")
if not (closeBoardButton and closeBoardButton:IsA("TextButton")) then
	if closeBoardButton then closeBoardButton:Destroy() end
	closeBoardButton = Instance.new("TextButton")
	closeBoardButton.Name = "CloseBoardButton"
	closeBoardButton.Text = "X"
	closeBoardButton.Font = Enum.Font.GothamBlack
	closeBoardButton.TextColor3 = Theme.text
	closeBoardButton.BackgroundColor3 = Color3.fromRGB(46, 25, 20)
	closeBoardButton.BackgroundTransparency = 0.04
	closeBoardButton.BorderSizePixel = 0
	closeBoardButton.ZIndex = 42
	closeBoardButton.Parent = topBar
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBoardButton
	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Theme.gilt
	closeStroke.Thickness = 1
	closeStroke.Transparency = 0.12
	closeStroke.Parent = closeBoardButton
end

local selectedKey = Config.ActivityRootKey or "adventurer_t1_3"
local currentFocusKey = nil
local focusHistory = {}
local snapshot = { Skills = {}, Currencies = { Insight = 0, CombatValorPoints = 0 } }
local currentToastTween
local localPlayer = Players.LocalPlayer
local debugAllowed = localPlayer and localPlayer.UserId == 475178488
local debugEnabled = false
local nodeInputStarted = setmetatable({}, { __mode = "k" })
local dragging = false
local dragStartInput
local dragStartMouse
local dragStartPos
local movementBound = false
local centeredOnce = false
local zoom = Config.BoardDefaultZoom or 0.64
local boardOrigin = Vector2.new(0, 0)
local lastBoundsKey = ""
local renderQueued = false
local lastRenderAt = 0
local isPhoneLayout = false
local FULL_DETAIL_ZOOM = 0.35
local MID_DETAIL_ZOOM = 0.18

local function comma(n)
	n = tostring(math.floor(tonumber(n) or 0))
	local left, num, right = n:match("^([^%d]*%d)(%d*)(.-)$")
	if not num then return n end
	return left .. num:reverse():gsub("(%d%d%d)", "%1,"):reverse() .. right
end

local function baseOrder()
	if debugEnabled and debugAllowed then
		return Config.DebugNodeOrder or Config.NodeOrder
	end
	return Config.NormalNodeOrder or Config.NodeOrder
end

local function isDescendantOf(key, parentKey)
	if not parentKey or key == parentKey then return true end
	local def = Config.Skills[key]
	local guard = 0
	while def and def.Parent and guard < 48 do
		if def.Parent == parentKey then return true end
		def = Config.Skills[def.Parent]
		guard += 1
	end
	return false
end

local function activeOrder()
	local order = baseOrder()
	local include = {}
	local function add(key)
		if key and Config.Skills[key] then
			include[key] = true
		end
	end
	if not currentFocusKey then
		add(Config.ActivityRootKey)
		for _, key in ipairs(order) do
			local def = Config.Skills[key]
			if def and def.Parent == Config.ActivityRootKey then
				add(key)
			end
		end
	else
		local focusDef = Config.Skills[currentFocusKey]
		add(currentFocusKey)
		local showFullTrail = currentFocusKey == Config.GatheringRootKey or currentFocusKey == "craft_refining"
		for _, key in ipairs(order) do
			local def = Config.Skills[key]
			if def then
				if showFullTrail and isDescendantOf(key, currentFocusKey) then
					add(key)
				elseif def.Parent == currentFocusKey then
					add(key)
				elseif focusDef and focusDef.NodeType == "GatheringRoot" and def.Activity == "Gathering" and isDescendantOf(key, currentFocusKey) then
					add(key)
				end
			end
		end
	end
	local out = {}
	for _, key in ipairs(order) do
		if include[key] then
			table.insert(out, key)
		end
	end
	return out
end

local function getDef(key)
	return Config.Skills[key]
end

local function getState(key)
	local state = snapshot.Skills and snapshot.Skills[key]
	if state then return state end
	if getDef(key) then return Config.BuildSkillSnapshot(key, 0) end
	return nil
end

local function updateZoomLabel()
	zoomLabel.Text = tostring(math.floor((zoom * 100) + 0.5)) .. "%"
end

local function setControlSize(object, width, height, textSize)
	object.Size = UDim2.fromOffset(width, height)
	if object:IsA("TextButton") or object:IsA("TextLabel") then
		object.TextSize = textSize or object.TextSize
	end
end

local function updateFocusControls()
	resetViewButton.Text = "Reset"
	local canBack = currentFocusKey ~= nil or #focusHistory > 0
	backButton.TextTransparency = canBack and 0 or 0.55
	backButton.BackgroundTransparency = canBack and 0.1 or 0.35
end

local function applyResponsiveLayout()
	local width = root.AbsoluteSize.X
	local height = root.AbsoluteSize.Y
	local phone = width > 0 and width < 720
	local tablet = width >= 720 and width < 980
	isPhoneLayout = phone

	local coverHeight = phone and 40 or (tablet and 70 or 96)
	local topHeight = phone and 124 or (tablet and 88 or 72)
	local boardTop = coverHeight + topHeight

	coreTopCover.Size = UDim2.new(1, 0, 0, coverHeight)
	topBar.Position = UDim2.new(0, 0, 0, coverHeight)
	topBar.Size = UDim2.new(1, 0, 0, topHeight)
	viewport.Position = UDim2.new(0, 0, 0, boardTop)
	viewport.Size = UDim2.new(1, 0, 1, -boardTop)

	titleLabel.Position = UDim2.new(0, phone and 12 or 28, 0, phone and 5 or 9)
	titleLabel.Size = UDim2.new(0, phone and 260 or 330, 0, phone and 26 or 34)
	titleLabel.TextSize = phone and 20 or (tablet and 24 or 27)
	subtitleLabel.Visible = not phone
	subtitleLabel.Position = UDim2.new(0, 30, 0, tablet and 39 or 44)

	if controlLayout then
		controlLayout.Padding = UDim.new(0, phone and 6 or 8)
	end
	controls.Position = phone and UDim2.new(0, 12, 0, 80) or UDim2.new(0, tablet and 310 or 380, 0, tablet and 42 or 15)
	controls.Size = phone and UDim2.new(1, -24, 0, 34) or UDim2.new(0, tablet and 400 or 440, 0, 42)
	setControlSize(zoomOutButton, phone and 30 or 38, phone and 30 or 34, phone and 13 or 14)
	setControlSize(zoomLabel, phone and 50 or 68, phone and 30 or 34, phone and 12 or 14)
	setControlSize(zoomInButton, phone and 30 or 38, phone and 30 or 34, phone and 13 or 14)
	setControlSize(backButton, phone and 30 or 38, phone and 30 or 34, phone and 13 or 14)
	setControlSize(resetViewButton, phone and 58 or 76, phone and 30 or 34, phone and 12 or 14)
	setControlSize(debugButton, phone and 68 or 96, phone and 30 or 34, phone and 10 or 14)

	closeBoardButton.AnchorPoint = phone and Vector2.new(1, 0) or Vector2.new(1, 0.5)
	closeBoardButton.Position = phone and UDim2.new(1, -12, 0, 6) or UDim2.new(1, -16, 0.5, 0)
	closeBoardButton.Size = UDim2.fromOffset(phone and 32 or 38, phone and 32 or 38)
	closeBoardButton.TextSize = phone and 16 or 18
	currencyTray.AnchorPoint = phone and Vector2.new(0, 0) or Vector2.new(1, 0.5)
	currencyTray.Position = phone and UDim2.new(0, 12, 0, 38) or UDim2.new(1, -68, 0.5, 0)
	currencyTray.Size = phone and UDim2.new(1, -72, 0, 30) or UDim2.new(0, tablet and 390 or 470, 0, 42)
	if currencyLayout then
		currencyLayout.HorizontalAlignment = phone and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right
		currencyLayout.Padding = UDim.new(0, phone and 8 or 10)
	end
	setControlSize(insightLabel, phone and 104 or 150, phone and 28 or 34, phone and 12 or 16)
	setControlSize(combatValorPointsLabel, phone and 142 or 245, phone and 28 or 34, phone and 12 or 16)

	if detailPadding then
		detailPadding.PaddingTop = UDim.new(0, phone and 12 or 18)
		detailPadding.PaddingBottom = UDim.new(0, phone and 12 or 18)
		detailPadding.PaddingLeft = UDim.new(0, phone and 12 or 18)
		detailPadding.PaddingRight = UDim.new(0, phone and 12 or 18)
	end
	if phone then
		local detailHeight = math.clamp(math.floor(height * 0.32), 164, 204)
		detail.AnchorPoint = Vector2.new(0, 1)
		detail.Position = UDim2.new(0, 8, 1, -8)
		detail.Size = UDim2.new(1, -16, 0, detailHeight)
		skillName.TextSize = 17
		skillName.Position = UDim2.new(0, 0, 0, 0)
		skillName.Size = UDim2.new(1, 0, 0, 38)
		categoryLabel.TextSize = 12
		categoryLabel.Position = UDim2.new(0, 0, 0, 42)
		categoryLabel.Size = UDim2.new(1, 0, 0, 18)
		levelLabel.TextSize = 15
		levelLabel.Position = UDim2.new(0, 0, 0, 64)
		levelLabel.Size = UDim2.new(1, 0, 0, 22)
		progressBack.Position = UDim2.new(0, 0, 0, 94)
		progressBack.Size = UDim2.new(1, 0, 0, 14)
		progressText.TextSize = 11
		progressText.Position = UDim2.new(0, 0, 0, 112)
		progressText.Size = UDim2.new(1, 0, 0, 18)
		descText.TextSize = 12
		descText.Position = UDim2.new(0, 0, 0, 134)
		descText.Size = UDim2.new(1, 0, 0, 38)
		pathLabel.Visible = false
		toast.Size = UDim2.new(1, -28, 0, 34)
		toast.Position = UDim2.new(0.5, 0, 1, -(detailHeight + 16))
	else
		detail.AnchorPoint = Vector2.new(1, 0)
		detail.Position = UDim2.new(1, -24, 0, boardTop + 24)
		detail.Size = UDim2.new(0, tablet and 320 or 356, 1, -(boardTop + 52))
		skillName.TextSize = tablet and 19 or 22
		skillName.Position = UDim2.new(0, 0, 0, 0)
		skillName.Size = UDim2.new(1, 0, 0, 58)
		categoryLabel.TextSize = 14
		categoryLabel.Position = UDim2.new(0, 0, 0, 62)
		categoryLabel.Size = UDim2.new(1, 0, 0, 22)
		levelLabel.TextSize = 18
		levelLabel.Position = UDim2.new(0, 0, 0, 98)
		levelLabel.Size = UDim2.new(1, 0, 0, 26)
		progressBack.Position = UDim2.new(0, 0, 0, 138)
		progressBack.Size = UDim2.new(1, 0, 0, 18)
		progressText.TextSize = 13
		progressText.Position = UDim2.new(0, 0, 0, 164)
		progressText.Size = UDim2.new(1, 0, 0, 22)
		descText.TextSize = 14
		descText.Position = UDim2.new(0, 0, 0, 204)
		descText.Size = UDim2.new(1, 0, 0, 150)
		pathLabel.Visible = true
		pathLabel.Position = UDim2.new(0, 0, 1, -64)
		pathLabel.Size = UDim2.new(1, 0, 0, 64)
		toast.Size = UDim2.new(0, 450, 0, 36)
		toast.Position = UDim2.new(0.5, 0, 1, -26)
	end
	if updateCurrencies then
		updateCurrencies()
	end
end

local function setContentPosition(pos)
	content.Position = UDim2.fromOffset(pos.X, pos.Y)
end

local function layoutBoundsKey()
	return tostring(debugEnabled and debugAllowed) .. ":" .. tostring(currentFocusKey or "all") .. ":" .. tostring(#activeOrder())
end

local gatherColumnX = {
	ore = -900,
	stone = -450,
	wood = 0,
	fiber = 450,
	hide = 900,
}

local function siblingIndex(key, parentKey)
	local index = 1
	local count = 0
	for _, candidate in ipairs(baseOrder()) do
		local def = getDef(candidate)
		if def and def.Parent == parentKey then
			count += 1
			if candidate == key then
				index = count
			end
		end
	end
	return index, math.max(count, 1)
end

local function displayPointForKey(key, def)
	def = def or getDef(key)
	if not def then return Vector2.new(0, 0) end
	local raw = Vector2.new(tonumber(def.Layout and def.Layout.X) or 0, tonumber(def.Layout and def.Layout.Y) or 0)
	if not currentFocusKey then
		if key == Config.ActivityRootKey then
			return Vector2.new(0, 0)
		end
		if def.Parent == Config.ActivityRootKey then
			if def.NodeType == "CombatRoot" then
				return Vector2.new(-700, 0)
			elseif def.NodeType == "GatheringRoot" then
				return Vector2.new(0, 390)
			elseif def.NodeType == "CraftingRoot" then
				return Vector2.new(0, -250)
			end
		end
		return raw
	end
	local focusDef = getDef(currentFocusKey)
	if not focusDef then return raw end
	local focusRaw = Vector2.new(tonumber(focusDef.Layout and focusDef.Layout.X) or 0, tonumber(focusDef.Layout and focusDef.Layout.Y) or 0)
	if key == currentFocusKey then
		return Vector2.new(0, 0)
	end
	if currentFocusKey == Config.GatheringRootKey and def.Activity == "Gathering" and def.NodeType == "GatheringTier" then
		local gatherType = tostring(def.GatherType or "wood")
		local tier = math.max(4, math.floor(tonumber(def.TierSource) or 4))
		return Vector2.new(gatherColumnX[gatherType] or 0, 650 + ((tier - 4) * 220))
	end
	if def.Parent == currentFocusKey then
		local index, count = siblingIndex(key, currentFocusKey)
		local middle = (count + 1) * 0.5
		if focusDef.NodeType == "CombatRoot" or focusDef.NodeType == "CraftingRoot" then
			return Vector2.new(-900, (index - middle) * 300)
		elseif focusDef.NodeType == "CombatMastery" or focusDef.NodeType == "CraftingMastery" then
			local perCol = 5
			local col = math.floor((index - 1) / perCol)
			local row = (index - 1) % perCol
			local rows = math.min(count, perCol)
			local middleRow = (rows - 1) * 0.5
			return Vector2.new(-750 - (col * 700), (row - middleRow) * 230)
		else
			local perCol = 5
			local col = math.floor((index - 1) / perCol)
			local row = (index - 1) % perCol
			local rows = math.min(count, perCol)
			local middleRow = (rows - 1) * 0.5
			return Vector2.new(-900 - (col * 800), (row - middleRow) * 260)
		end
	end
	return raw - focusRaw
end

local function resizeBoard()
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	for _, key in ipairs(activeOrder()) do
		local def = getDef(key)
		if def and def.Layout then
			local point = displayPointForKey(key, def)
			minX = math.min(minX, point.X)
			minY = math.min(minY, point.Y)
			maxX = math.max(maxX, point.X)
			maxY = math.max(maxY, point.Y)
		end
	end
	if minX == math.huge then
		minX, minY, maxX, maxY = -1000, -1000, 1000, 1000
	end
	local pad = 2400
	boardOrigin = Vector2.new(pad - minX, pad - minY)
	content.Size = UDim2.fromOffset((maxX - minX) + (pad * 2), (maxY - minY) + (pad * 2))
	lastBoundsKey = layoutBoundsKey()
end

local function worldToCanvas(def, key)
	return boardOrigin + displayPointForKey(key, def)
end

local function detailTier()
	return 2
end

local function currentVisibleRect()
	local safeZoom = math.max(zoom, 0.04)
	local pos = Vector2.new(content.Position.X.Offset, content.Position.Y.Offset)
	local margin = 1100 / safeZoom
	local minPoint = ((Vector2.new(0, 0) - pos) / safeZoom) - Vector2.new(margin, margin)
	local maxPoint = ((viewport.AbsoluteSize - pos) / safeZoom) + Vector2.new(margin, margin)
	return minPoint.X, minPoint.Y, maxPoint.X, maxPoint.Y
end

local function pointInRect(point, minX, minY, maxX, maxY, radius)
	radius = radius or 0
	return point.X >= minX - radius and point.X <= maxX + radius and point.Y >= minY - radius and point.Y <= maxY + radius
end

local function segmentOverlapsRect(from, to, minX, minY, maxX, maxY, pad)
	pad = pad or 0
	local aX, bX = math.min(from.X, to.X), math.max(from.X, to.X)
	local aY, bY = math.min(from.Y, to.Y), math.max(from.Y, to.Y)
	return bX >= minX - pad and aX <= maxX + pad and bY >= minY - pad and aY <= maxY + pad
end

local function scheduleViewportRender(delayTime)
	if renderQueued or not root.Visible then return end
	renderQueued = true
	local tier = detailTier()
	local delay = delayTime or (tier >= 2 and 0.08 or 0.14)
	task.delay(delay, function()
		renderQueued = false
		if not root.Visible then return end
		local throttle = detailTier() >= 2 and 0.32 or 0.48
		if dragging and (os.clock() - lastRenderAt) < throttle then
			return
		end
		renderBoard()
	end)
end

local function centerOn(key)
	local def = getDef(key) or getDef(selectedKey) or getDef(Config.ActivityRootKey)
	if not def then return end
	local point = worldToCanvas(def, key)
	local focusX = viewport.AbsoluteSize.X * 0.5
	if not isPhoneLayout then
		local detailWidth = detail.AbsoluteSize.X > 0 and detail.AbsoluteSize.X or 356
		focusX = math.min(viewport.AbsoluteSize.X * 0.42, math.max(180, viewport.AbsoluteSize.X - detailWidth - 120))
	end
	local target = Vector2.new(focusX, viewport.AbsoluteSize.Y * 0.5) - (point * zoom)
	setContentPosition(target)
	scheduleViewportRender(0)
end

local function setZoom(newZoom, anchorScreenPoint)
	local oldZoom = zoom
	newZoom = math.clamp(newZoom, Config.BoardMinZoom or 0.2, Config.BoardMaxZoom or 1.7)
	if math.abs(newZoom - oldZoom) < 0.001 then return end

	local pos = Vector2.new(content.Position.X.Offset, content.Position.Y.Offset)
	local viewportPoint
	if anchorScreenPoint then
		viewportPoint = anchorScreenPoint - viewport.AbsolutePosition
	else
		viewportPoint = viewport.AbsoluteSize * 0.5
	end
	local boardPoint = (viewportPoint - pos) / oldZoom
	zoom = newZoom
	boardScale.Scale = zoom
	setContentPosition(viewportPoint - (boardPoint * zoom))
	updateZoomLabel()
	scheduleViewportRender(0)
end

local function nodeColor(def)
	if def.IsVeterancy then return Theme.veterancy end
	if def.Activity == "Combat" then return Theme.combat end
	if def.Activity == "Gathering" then return Theme.gathering end
	if def.Activity == "Crafting" then return Theme.crafting end
	return Theme.adventurer
end

local function nodeSize(def)
	if def.NodeType == "Root" then return 100 end
	if def.NodeType == "CombatBranch" or def.NodeType == "CraftingBranch" then return 84 end
	if def.NodeType == "CombatRoot" or def.NodeType == "GatheringRoot" or def.NodeType == "CraftingRoot" then return 82 end
	if def.NodeType == "GatheringTier" or def.IsVeterancy then return 54 end
	return 70
end

local function isMajorNode(def)
	return def.NodeType == "Root"
		or def.NodeType == "CombatRoot"
		or def.NodeType == "GatheringRoot"
		or def.NodeType == "CraftingRoot"
		or def.NodeType == "CombatBranch"
		or def.NodeType == "CraftingBranch"
end

local function isMasteryNode(def)
	return def.NodeType == "CombatMastery" or def.NodeType == "CraftingMastery"
end

local function canFocusNode(key, def)
	if not def then return false end
	if key == Config.ActivityRootKey then return true end
	return def.NodeType == "CombatRoot"
		or def.NodeType == "GatheringRoot"
		or def.NodeType == "CraftingRoot"
		or def.NodeType == "CombatBranch"
		or def.NodeType == "CraftingBranch"
		or isMasteryNode(def)
end

local function applyFocusTarget(targetKey)
	if targetKey == "__ROOT__" or targetKey == Config.ActivityRootKey then
		currentFocusKey = nil
	else
		currentFocusKey = targetKey
	end
	selectedKey = currentFocusKey or Config.ActivityRootKey
	updateFocusControls()
	resizeBoard()
	setZoom(Config.BoardDefaultZoom or 0.55, viewport.AbsolutePosition + (viewport.AbsoluteSize * 0.5))
	centerOn(selectedKey)
	renderBoard()
end

local function focusOnNode(key, remember)
	local def = getDef(key)
	if not canFocusNode(key, def) then
		selectedKey = key
		centerOn(key)
		updateDetail()
		return
	end
	local newFocusKey = nil
	if key ~= Config.ActivityRootKey then
		newFocusKey = key
	end
	if remember ~= false and newFocusKey ~= currentFocusKey then
		table.insert(focusHistory, currentFocusKey or "__ROOT__")
	end
	applyFocusTarget(newFocusKey or "__ROOT__")
end

local function resetToRoot()
	focusHistory = {}
	applyFocusTarget("__ROOT__")
end

local function goBack()
	local previous = table.remove(focusHistory)
	if previous then
		applyFocusTarget(previous)
	elseif currentFocusKey then
		applyFocusTarget("__ROOT__")
	else
		centerOn(Config.ActivityRootKey)
	end
end

local function shouldRenderNodeAtZoom(key, def)
	return true
end

local function shouldShowNodeName(def)
	return true
end

local function isUnlocked(key)
	if key == Config.ActivityRootKey then return true end
	local state = getState(key)
	return state and (state.Level or 0) >= 1 or false
end

local function isLearned(key)
	local state = getState(key)
	return state and (state.Level or 0) >= 1 or false
end

local function clearBoard()
	for _, child in ipairs(content:GetChildren()) do
		if child ~= boardScale then
			child:Destroy()
		end
	end
	for _, child in ipairs(landmarkLayer:GetChildren()) do
		child:Destroy()
	end
end

local function lineThickness(learned)
	local tier = detailTier()
	local screenTarget = learned and (tier >= 2 and 6 or 4) or (tier >= 2 and 2 or 1)
	return math.clamp(screenTarget / math.max(zoom, 0.08), screenTarget, learned and 80 or 20)
end

local function makeLineBetween(name, from, to, learned)
	local delta = to - from
	if delta.Magnitude < 2 then return end
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromOffset((from.X + to.X) * 0.5, (from.Y + to.Y) * 0.5)
	line.Size = UDim2.fromOffset(delta.Magnitude, lineThickness(learned))
	line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	line.BackgroundColor3 = learned and Theme.gilt or Theme.giltDim
	line.BackgroundTransparency = learned and 0.14 or 0.62
	line.BorderSizePixel = 0
	line.ZIndex = 4
	line.Parent = content
end

local function makeLine(parentKey, childKey, minX, minY, maxX, maxY)
	local fromDef = getDef(parentKey)
	local toDef = getDef(childKey)
	if not fromDef or not toDef then return end
	if detailTier() < 2 and not (shouldRenderNodeAtZoom(childKey, toDef) or selectedKey == parentKey) then return end
	local from = worldToCanvas(fromDef, parentKey)
	local to = worldToCanvas(toDef, childKey)
	makeLineBetween("Link_" .. childKey, from, to, isLearned(childKey))
end


local function makeNode(key, minX, minY, maxX, maxY)
	local def = getDef(key)
	if not def then return end
	if not shouldRenderNodeAtZoom(key, def) then return end
	local state = getState(key)
	if not state then return end
	local unlocked = isUnlocked(key)
	local selected = key == selectedKey
	local tier = detailTier()
	local fullDetail = tier >= 2
	local showName = shouldShowNodeName(def)
	local size = nodeSize(def)
	if tier < 2 and not isMajorNode(def) then
		size = math.max(42, math.floor(size * 0.78))
	end
	local center = worldToCanvas(def, key)
	local wrapWidth = showName and math.max(138, size + 46) or (size + 18)
	local wrapHeight = size + (showName and 62 or 18)
	local wrap = Instance.new("Frame")
	wrap.Name = "NodeWrap_" .. key
	wrap.AnchorPoint = Vector2.new(0.5, 0.5)
	wrap.BackgroundTransparency = 1
	wrap.Position = UDim2.fromOffset(center.X, center.Y)
	wrap.Size = UDim2.fromOffset(wrapWidth, wrapHeight)
	wrap.ZIndex = 8
	wrap.Parent = content

	local nodeButton = Instance.new("TextButton")
	nodeButton.Name = "Node_" .. key
	nodeButton.AnchorPoint = Vector2.new(0.5, 0)
	nodeButton.Position = UDim2.new(0.5, 0, 0, 0)
	nodeButton.Size = UDim2.fromOffset(size, size)
	nodeButton.BackgroundColor3 = unlocked and nodeColor(def) or Theme.locked
	nodeButton.BackgroundTransparency = unlocked and 0.03 or 0.2
	nodeButton.BorderSizePixel = 0
	nodeButton.AutoButtonColor = true
	nodeButton.Text = tostring(def.IconText or "?")
	nodeButton.TextColor3 = unlocked and Theme.text or Theme.subtleText
	nodeButton.TextSize = size >= 84 and 24 or (size >= 60 and 17 or 13)
	nodeButton.Font = Enum.Font.GothamBlack
	nodeButton.ZIndex = 9
	nodeButton.Parent = wrap
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(1, 0)
	buttonCorner.Parent = nodeButton
	local outline = Instance.new("UIStroke")
	outline.Thickness = selected and (fullDetail and 4 or 2.6) or (unlocked and (fullDetail and 2 or 1.4) or 1)
	outline.Color = selected and Theme.selected or (unlocked and Theme.gilt or Theme.giltDim)
	outline.Transparency = unlocked and 0.06 or 0.36
	outline.Parent = nodeButton

	if fullDetail then
		local levelBadge = Instance.new("TextLabel")
		levelBadge.Name = "LevelBadge"
		levelBadge.AnchorPoint = Vector2.new(1, 1)
		levelBadge.BackgroundColor3 = Color3.fromRGB(10, 9, 9)
		levelBadge.BackgroundTransparency = 0.06
		levelBadge.BorderSizePixel = 0
		levelBadge.Position = UDim2.new(1, 4, 1, 4)
		levelBadge.Size = UDim2.fromOffset(46, 22)
		levelBadge.Font = Enum.Font.GothamBold
		levelBadge.Text = tostring(state.Level or 0)
		levelBadge.TextColor3 = Theme.text
		levelBadge.TextSize = 12
		levelBadge.ZIndex = 10
		levelBadge.Parent = nodeButton
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 8)
		badgeCorner.Parent = levelBadge

		local barBack = Instance.new("Frame")
		barBack.Name = "NodeProgressBack"
		barBack.AnchorPoint = Vector2.new(0.5, 0)
		barBack.BackgroundColor3 = Color3.fromRGB(8, 8, 9)
		barBack.BackgroundTransparency = 0.08
		barBack.BorderSizePixel = 0
		barBack.Position = UDim2.new(0.5, 0, 0, size + 7)
		barBack.Size = UDim2.fromOffset(math.max(66, size), 5)
		barBack.ZIndex = 9
		barBack.Parent = wrap
		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(1, 0)
		barCorner.Parent = barBack
		local barFill = Instance.new("Frame")
		barFill.Name = "NodeProgressFill"
		barFill.BackgroundColor3 = Theme.gilt
		barFill.BorderSizePixel = 0
		barFill.Size = UDim2.new(math.clamp(state.Progress or 0, 0, 1), 0, 1, 0)
		barFill.ZIndex = 10
		barFill.Parent = barBack
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = barFill
	end

	if showName then
		local name = Instance.new("TextLabel")
		name.Name = "NodeName"
		name.BackgroundTransparency = 1
		name.Position = UDim2.new(0, 0, 0, size + (fullDetail and 15 or 7))
		name.Size = UDim2.new(1, 0, 0, fullDetail and 40 or 28)
		name.Font = Enum.Font.GothamBold
		name.Text = tostring(def.ShortName or def.DisplayName or key)
		name.TextColor3 = unlocked and Theme.text or Theme.subtleText
		name.TextSize = fullDetail and 11 or 10
		name.TextWrapped = true
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.ZIndex = 9
		name.Parent = wrap
	end

	nodeButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			nodeInputStarted[input] = true
		end
	end)
	nodeButton.Activated:Connect(function()
		if canFocusNode(key, def) and currentFocusKey ~= key then
			focusOnNode(key)
			return
		end
		selectedKey = key
		renderBoard()
		updateDetail()
	end)
end

local function canvasToViewportPoint(point)
	local pos = Vector2.new(content.Position.X.Offset, content.Position.Y.Offset)
	return pos + (point * zoom)
end

local function buildLandmarkSet()
	local include = {}
	local function add(key)
		if key == "__ROOT__" then key = Config.ActivityRootKey end
		if key and Config.Skills[key] then
			include[key] = true
		end
	end
	local function addDirectChildren(parentKey)
		if not parentKey then return end
		for _, childKey in ipairs(baseOrder()) do
			local childDef = Config.Skills[childKey]
			if childDef and childDef.Parent == parentKey then
				add(childKey)
			end
		end
	end
	local function addContext(key)
		if key == "__ROOT__" then key = Config.ActivityRootKey end
		if not key or not Config.Skills[key] then return end
		add(key)
		local def = Config.Skills[key]
		add(def and def.Parent)
		addDirectChildren(key)
	end
	add(Config.ActivityRootKey)
	addDirectChildren(Config.ActivityRootKey)
	addContext(currentFocusKey)
	addContext(selectedKey)
	return include
end

local function shouldRenderLandmark(key, def)
	if zoom > 0.16 then return false end
	return buildLandmarkSet()[key] == true
end

local function makeLandmark(key)
	local def = getDef(key)
	if not def or not shouldRenderLandmark(key, def) then return end
	local state = getState(key)
	local point = canvasToViewportPoint(worldToCanvas(def, key))
	local diameter = isPhoneLayout and 44 or 54
	local size = Vector2.new(diameter, diameter)
	local padX = math.max(8, size.X * 0.5 + 8)
	local padY = math.max(8, size.Y * 0.5 + 8)
	local screen = Vector2.new(
		math.clamp(point.X, padX, math.max(padX, viewport.AbsoluteSize.X - padX)),
		math.clamp(point.Y, padY, math.max(padY, viewport.AbsoluteSize.Y - padY))
	)
	local button = Instance.new("TextButton")
	button.Name = "Landmark_" .. key
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromOffset(screen.X, screen.Y)
	button.Size = UDim2.fromOffset(size.X, size.Y)
	button.BackgroundColor3 = nodeColor(def)
	button.BackgroundTransparency = key == selectedKey and 0.02 or 0.1
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.Text = tostring(def.IconText or def.ShortName or def.DisplayName or key)
	button.TextColor3 = Theme.text
	button.TextSize = isPhoneLayout and 15 or 18
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.ZIndex = 19
	button.Parent = landmarkLayer
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button
	local outline = Instance.new("UIStroke")
	outline.Color = key == selectedKey and Theme.selected or Theme.gilt
	outline.Thickness = key == selectedKey and 2.2 or 1.2
	outline.Transparency = key == selectedKey and 0.05 or 0.28
	outline.Parent = button
	if state and (state.Level or 0) >= 1 then
		local level = Instance.new("TextLabel")
		level.Name = "Level"
		level.AnchorPoint = Vector2.new(1, 1)
		level.BackgroundColor3 = Color3.fromRGB(8, 8, 9)
		level.BackgroundTransparency = 0.08
		level.BorderSizePixel = 0
		level.Position = UDim2.new(1, 4, 1, 3)
		level.Size = UDim2.fromOffset(isPhoneLayout and 22 or 26, isPhoneLayout and 16 or 18)
		level.Font = Enum.Font.GothamBlack
		level.Text = tostring(state.Level or 0)
		level.TextColor3 = Theme.text
		level.TextSize = isPhoneLayout and 9 or 10
		level.ZIndex = 20
		level.Parent = button
		local levelCorner = Instance.new("UICorner")
		levelCorner.CornerRadius = UDim.new(1, 0)
		levelCorner.Parent = level
	end
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			nodeInputStarted[input] = true
		end
	end)
	button.Activated:Connect(function()
		if canFocusNode(key, def) and currentFocusKey ~= key then
			focusOnNode(key)
		else
			selectedKey = key
			centerOn(key)
			renderBoard()
			updateDetail()
		end
	end)
end

local function renderLandmarks(order)
	if zoom > 0.16 then return end
	local include = buildLandmarkSet()
	local rendered = {}
	for _, key in ipairs(baseOrder()) do
		if include[key] and not rendered[key] then
			rendered[key] = true
			makeLandmark(key)
		end
	end
end

function renderBoard()
	if viewport.AbsoluteSize.X < 20 or viewport.AbsoluteSize.Y < 20 then return end
	resizeBoard()
	clearBoard()
	local minX, minY, maxX, maxY = currentVisibleRect()
	local order = activeOrder()
	local activeKeys = {}
	for _, key in ipairs(order) do
		activeKeys[key] = true
	end
	for _, key in ipairs(order) do
		local def = getDef(key)
		if def and def.Parent and activeKeys[def.Parent] then
			makeLine(def.Parent, key, minX, minY, maxX, maxY)
		end
	end
	for _, key in ipairs(order) do
		makeNode(key, minX, minY, maxX, maxY)
	end
	renderLandmarks(order)
	lastRenderAt = os.clock()
	updateFocusControls()
	updateCurrencies()
	updateDetail()
end

function updateCurrencies()
	local currencies = snapshot.Currencies or {}
	insightLabel.Text = "Insight " .. comma(currencies.Insight or 0)
	if isPhoneLayout then
		combatValorPointsLabel.Text = "CVP " .. comma(currencies.CombatValorPoints or 0)
	else
		combatValorPointsLabel.Text = "Combat Valor Points " .. comma(currencies.CombatValorPoints or 0)
	end
end

function updateDetail()
	local state = selectedKey and getState(selectedKey)
	local def = selectedKey and getDef(selectedKey)
	if not state or not def then
		detail.Visible = false
		return
	end
	detail.Visible = true
	skillName.Text = state.DisplayName or selectedKey
	categoryLabel.Text = tostring(state.Category or "Unknown")
	local extra = ""
	if state.Activity == "Combat" and not state.IsVeterancy then
		extra = "  |  Unlocks T" .. tostring(state.UnlockTier or 3)
	end
	levelLabel.Text = string.format("Level %d / %d%s", state.Level or 0, state.MaxLevel or 1, extra)
	descText.Text = state.Description or "No description yet."
	local total = state.TotalValor or 0
	local cur = state.CurrentLevelValor or 0
	local nextValue = state.NextLevelValor or cur
	local into = math.max(0, total - cur)
	local needed = math.max(0, nextValue - cur)
	local progress = math.clamp(state.Progress or 0, 0, 1)
	progressFill:TweenSize(UDim2.new(progress, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
	if (state.Level or 0) >= (state.MaxLevel or 1) then
		progressText.Text = comma(total) .. " Valor - max level"
	else
		progressText.Text = comma(into) .. " / " .. comma(needed) .. " Valor to next level"
	end
	local parent = def and def.Parent and getDef(def.Parent)
	pathLabel.Text = parent and ("Path from " .. tostring(parent.DisplayName or parent.ShortName or def.Parent)) or "Main board foundation"
end

local function refreshFromServer()
	local ok, result = pcall(function()
		return GetDestinyBoard:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		snapshot = result
		snapshot.Currencies = snapshot.Currencies or { Insight = 0, CombatValorPoints = 0 }
		renderBoard()
	else
		warn("[DestinyBoard] Snapshot request failed", result)
	end
end

local function sinkMovement()
	return Enum.ContextActionResult.Sink
end

local function bindMovementSink(open)
	if open and not movementBound then
		movementBound = true
		ContextActionService:BindActionAtPriority("DestinyBoardMovementSink", sinkMovement, false, 3000,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
			Enum.KeyCode.Space, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right)
	elseif not open and movementBound then
		movementBound = false
		ContextActionService:UnbindAction("DestinyBoardMovementSink")
	end
end

local function setOpen(open)
	root.Visible = open
	bindMovementSink(open)
	if open then
		task.defer(function()
			applyResponsiveLayout()
			refreshFromServer()
			if not centeredOnce then
				centeredOnce = true
				centerOn(Config.ActivityRootKey)
			end
		end)
	end
end

closeBoardButton.Activated:Connect(function()
	setOpen(false)
end)

local function showToast(text)
	toast.Text = tostring(text)
	toast.Visible = true
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.08
	if currentToastTween then currentToastTween:Cancel() end
	currentToastTween = TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 2.0), { TextTransparency = 1, BackgroundTransparency = 1 })
	currentToastTween.Completed:Once(function()
		toast.Visible = false
	end)
	currentToastTween:Play()
end

local function inputHitNode(input)
	return nodeInputStarted[input] == true
end

viewport.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStartInput = input
		dragStartMouse = input.Position
		dragStartPos = Vector2.new(content.Position.X.Offset, content.Position.Y.Offset)
		task.defer(function()
			if dragStartInput == input and not inputHitNode(input) then
				selectedKey = nil
				renderBoard()
			end
		end)
	end
end)

viewport.InputEnded:Connect(function(input)
	if input == dragStartInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		dragStartInput = nil
		scheduleViewportRender(0)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel and root.Visible then
		local mousePoint = Vector2.new(input.Position.X, input.Position.Y)
		local direction = input.Position.Z > 0 and 1 or -1
		setZoom(zoom * (direction > 0 and 1.12 or 0.89), mousePoint)
		return
	end
	if not dragging then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local delta = Vector2.new(input.Position.X - dragStartMouse.X, input.Position.Y - dragStartMouse.Y)
	setContentPosition(dragStartPos + delta)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.V then
		if gameProcessed or UserInputService:GetFocusedTextBox() then return end
		setOpen(not root.Visible)
	elseif root.Visible and input.KeyCode == Enum.KeyCode.Backspace then
		goBack()
	elseif root.Visible and input.KeyCode == Enum.KeyCode.Home then
		resetToRoot()
	elseif root.Visible and input.KeyCode == Enum.KeyCode.Equals then
		setZoom(zoom * 1.12)
	elseif root.Visible and input.KeyCode == Enum.KeyCode.Minus then
		setZoom(zoom * 0.89)
	end
end)

zoomOutButton.Activated:Connect(function()
	setZoom(zoom * 0.84)
end)
zoomInButton.Activated:Connect(function()
	setZoom(zoom * 1.18)
end)
local lastBackClickAt = 0
local function handleBackButton()
	local now = os.clock()
	if now - lastBackClickAt < 0.12 then return end
	lastBackClickAt = now
	goBack()
end
backButton.Activated:Connect(handleBackButton)
backButton.MouseButton1Click:Connect(handleBackButton)

local lastResetClickAt = 0
local function handleResetButton()
	local now = os.clock()
	if now - lastResetClickAt < 0.12 then return end
	lastResetClickAt = now
	resetToRoot()
end
resetViewButton.Activated:Connect(handleResetButton)
resetViewButton.MouseButton1Click:Connect(handleResetButton)

local function pointInGuiObject(object, point)
	if not (object and object.Visible) then return false end
	local pos = object.AbsolutePosition
	local size = object.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

UserInputService.InputBegan:Connect(function(input)
	if not root.Visible then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local point = Vector2.new(input.Position.X, input.Position.Y)
	if pointInGuiObject(resetViewButton, point) then
		handleResetButton()
	elseif pointInGuiObject(backButton, point) then
		handleBackButton()
	end
end)

debugButton.Visible = debugAllowed == true
debugButton.Activated:Connect(function()
	if not debugAllowed then return end
	debugEnabled = not debugEnabled
	debugButton.Text = debugEnabled and "Debug On" or "Debug Off"
	if currentFocusKey and not table.find(baseOrder(), currentFocusKey) then
		currentFocusKey = nil
		focusHistory = {}
	end
	if selectedKey and not table.find(activeOrder(), selectedKey) then
		selectedKey = currentFocusKey
	end
	updateFocusControls()
	resizeBoard()
	renderBoard()
	centerOn(selectedKey or Config.ActivityRootKey)
end)
ValorUpdated.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	snapshot.Currencies = snapshot.Currencies or { Insight = 0, CombatValorPoints = 0 }
	if payload.Currency then
		snapshot.Currencies[payload.Currency] = payload.Total or snapshot.Currencies[payload.Currency] or 0
		updateCurrencies()
		if payload.Currency == "CombatValorPoints" then
			showToast("+" .. comma(payload.Amount or 0) .. " Combat Valor Points")
		end
		return
	end
	if typeof(payload.Skill) ~= "table" then return end
	local skill = payload.Skill
	snapshot.Skills = snapshot.Skills or {}
	snapshot.Skills[skill.Key] = skill
	if root.Visible then
		renderBoard()
	end
	showToast("+" .. comma(payload.Amount or 0) .. " Valor - " .. tostring(skill.DisplayName or skill.Key))
end)

local function handleViewportSizeChanged()
	applyResponsiveLayout()
	if root.Visible then
		resizeBoard()
		setContentPosition(Vector2.new(content.Position.X.Offset, content.Position.Y.Offset))
		renderBoard()
	end
end

viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(handleViewportSizeChanged)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(handleViewportSizeChanged)

boardScale.Scale = zoom
updateZoomLabel()
updateFocusControls()
applyResponsiveLayout()
resizeBoard()
task.defer(refreshFromServer)
]=]
	ctrl.Parent = gui

	return gui
end

function M.Install(opts)
	opts = opts or {}
	local starterGui = game:GetService("StarterGui")
	local existing = starterGui:FindFirstChild("DestinyBoardUI")
	if existing then
		if opts.force == false then
			return existing
		end
		existing:Destroy()
	end
	local gui = build(starterGui)
	print("[DestinyBoardUIInstaller] Installed zoomable DestinyBoardUI")
	return gui
end

function M.Rollback()
	local starterGui = game:GetService("StarterGui")
	local existing = starterGui:FindFirstChild("DestinyBoardUI")
	if existing then
		existing:Destroy()
		return true
	end
	return false
end

return M
