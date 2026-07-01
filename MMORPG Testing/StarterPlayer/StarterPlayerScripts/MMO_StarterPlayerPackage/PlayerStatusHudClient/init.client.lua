--[[
Name: PlayerStatusHudClient
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.PlayerStatusHudClient
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage, GuiService, RunService, UserInputService
Requires:
  - local Selection = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util"):WaitFor...
  - local MouseUtil = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util"):WaitFor...
Functions: comma, mk, corner, stroke, layoutRoot, makeBar, setBar, localCharacter, updateHud, thumbnailFor, requestStatus, closeModal, makeCenterFrame, syncScale, clearGuiChildren, ensureStatsModal, openStatsPanel, openInspectItemDetail, ensureInspectModal, openInspectPanel, callParty, makeDropdown, addRow, makeStatusCard, makeCardBar, modelHealth, updateTargetHud, layoutTargetCard, makeOffscreenBar, makeOffscreenIndicator, clearOffscreenIndicator, viewportPointVisible, edgePositionFor, updateOffscreenIndicators, formatGuildLine, attachNameplate, makePlateBar, updatePlate, clearNameplate, watchPlayer, Callback
Clean source lines: 902
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remoteEvents = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")
local SetPvPFlag = remoteEvents:WaitForChild("SetPvPFlag")
local PlayerStatusRequest = remoteEvents:WaitForChild("PlayerStatusRequest")
local PartyRequest = remoteEvents:WaitForChild("PartyRequest")
local Selection = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util"):WaitForChild("Selection"))
local MouseUtil = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util"):WaitForChild("MouseUtil"))

local THEME = {
	panel = Color3.fromRGB(24, 18, 14),
	panel2 = Color3.fromRGB(38, 28, 20),
	line = Color3.fromRGB(232, 176, 64),
	text = Color3.fromRGB(242, 228, 198),
	subtle = Color3.fromRGB(202, 188, 158),
	health = Color3.fromRGB(192, 44, 34),
	mana = Color3.fromRGB(49, 118, 205),
	mount = Color3.fromRGB(220, 185, 65),
	red = Color3.fromRGB(178, 42, 36),
	green = Color3.fromRGB(58, 142, 82),
}

local HUD_SPEC = {
	width = 322,
	height = 108,
	avatar = 72,
	barHeight = 16,
	barGap = 5,
	nameHeight = 24,
}

local function comma(n)
	n = tostring(math.floor(tonumber(n) or 0))
	local left, num, right = n:match("^([^%d]*%d)(%d*)(.-)$")
	if not num then return n end
	return left .. num:reverse():gsub("(%d%d%d)", "%1,"):reverse() .. right
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
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local function stroke(parent, thickness, color, transparency)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 1
	s.Color = color or THEME.line
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local gui = mk("ScreenGui", {
	Name = "PlayerStatusHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 42,
}, player:WaitForChild("PlayerGui"))

local root = mk("Frame", {
	Name = "StatusRoot",
	BackgroundColor3 = THEME.panel,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(HUD_SPEC.width, HUD_SPEC.height),
}, gui)
corner(root, 7)
stroke(root, 1, THEME.line, 0.15)
mk("UIScale", { Scale = 1 }, root)

local function layoutRoot()
	local inset = GuiService:GetGuiInset()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local scale = math.clamp(viewport.X / 1400, 0.78, 1)
	root.UIScale.Scale = scale
	root.Position = UDim2.fromOffset(inset.X + 12, inset.Y + 8)
end
layoutRoot()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutRoot)
end

local avatarWrap = mk("Frame", {
	Name = "AvatarWrap",
	BackgroundColor3 = Color3.fromRGB(12, 10, 9),
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(10, 10),
	Size = UDim2.fromOffset(HUD_SPEC.avatar, HUD_SPEC.avatar),
}, root)
corner(avatarWrap, 36)
stroke(avatarWrap, 2, THEME.line, 0.05)

local avatar = mk("ImageLabel", {
	Name = "AvatarImage",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.fromOffset(HUD_SPEC.avatar - 8, HUD_SPEC.avatar - 8),
	ScaleType = Enum.ScaleType.Crop,
}, avatarWrap)
corner(avatar, 32)
local okThumb, thumb = pcall(function()
	return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
end)
avatar.Image = okThumb and thumb or ""

local avatarOverlay = mk("Frame", {
	Name = "AvatarOverlay",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
}, avatarWrap)
corner(avatarOverlay, 36)
stroke(avatarOverlay, 1, Color3.fromRGB(255, 235, 170), 0.25)

local nameLabel = mk("TextButton", {
	Name = "PlayerName",
	AutoButtonColor = false,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = player.DisplayName ~= "" and player.DisplayName or player.Name,
	TextColor3 = THEME.text,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(92, 9),
	Size = UDim2.fromOffset(162, HUD_SPEC.nameHeight),
}, root)

local leaderCrown = mk("TextLabel", {
	Name = "PartyLeaderCrown",
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Text = "*",
	TextColor3 = THEME.line,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(242, 6),
	Size = UDim2.fromOffset(18, 26),
	Visible = false,
}, root)

local pvpButton = mk("TextButton", {
	Name = "PvPFlagButton",
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(56, 46, 34),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "PVP",
	TextColor3 = THEME.text,
	TextSize = 12,
	Position = UDim2.fromOffset(260, 10),
	Size = UDim2.fromOffset(48, 23),
}, root)
corner(pvpButton, 5)
stroke(pvpButton, 1, THEME.line, 0.35)

local bars = {}
local function makeBar(name, y, color)
	local frame = mk("Frame", {
		Name = name,
		BackgroundColor3 = Color3.fromRGB(13, 10, 9),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(92, y),
		Size = UDim2.fromOffset(216, HUD_SPEC.barHeight),
	}, root)
	corner(frame, 4)
	stroke(frame, 1, Color3.fromRGB(82, 62, 38), 0.25)
	local fill = mk("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, frame)
	corner(fill, 4)
	local text = mk("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 246, 220),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, frame)
	bars[name] = { Frame = frame, Fill = fill, Text = text }
	return bars[name]
end

makeBar("HealthBar", 39, THEME.health)
makeBar("ManaBar", 60, THEME.mana)
makeBar("MountBar", 81, THEME.mount)

local function setBar(bar, current, maximum)
	current = math.max(0, math.floor(tonumber(current) or 0))
	maximum = math.max(1, math.floor(tonumber(maximum) or 1))
	bar.Fill.Size = UDim2.fromScale(math.clamp(current / maximum, 0, 1), 1)
	bar.Text.Text = string.format("%s/%s", comma(current), comma(maximum))
end

local function localCharacter()
	return player.Character
end

local function updateHud()
	local character = localCharacter()
	if not character then return end
	setBar(bars.HealthBar, character:GetAttribute("Health") or 0, character:GetAttribute("MaxHealth") or 1)
	setBar(bars.ManaBar, character:GetAttribute("Mana") or 0, character:GetAttribute("MaxMana") or 1)
	local mounted = character:GetAttribute("Mounted") == true
	bars.MountBar.Frame.Visible = mounted
	if mounted then
		setBar(bars.MountBar, character:GetAttribute("MountHealth") or 0, character:GetAttribute("MaxMountHealth") or 1)
	end
	local zone = tostring(character:GetAttribute("ZoneType") or "Safe")
	local flagged = character:GetAttribute("PvPFlagged") == true
	pvpButton.BackgroundColor3 = flagged and THEME.red or (zone == "Safe" and Color3.fromRGB(48, 48, 48) or Color3.fromRGB(56, 46, 34))
	pvpButton.Text = zone == "Death" and "RED" or "PVP"
	pvpButton.TextTransparency = zone == "Safe" and 0.35 or 0
	leaderCrown.Visible = player:GetAttribute("PartyLeader") == true
end

pvpButton.Activated:Connect(function()
	local character = localCharacter()
	local zone = character and tostring(character:GetAttribute("ZoneType") or "Safe") or "Safe"
	if zone == "Safe" or zone == "Death" then return end
	SetPvPFlag:FireServer({ Enabled = not (character:GetAttribute("PvPFlagged") == true) })
end)

local function thumbnailFor(userId)
	userId = tonumber(userId)
	if not userId then return "" end
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	return ok and image or ""
end

local function requestStatus(action, userId)
	local ok, result = pcall(function()
		return PlayerStatusRequest:InvokeServer(action, { UserId = userId })
	end)
	if ok and type(result) == "table" and result.Ok ~= false then
		return result
	end
	return nil
end

local statsModal = nil
local inspectModal = nil
local currentTargetModel = nil
local currentTargetUserId = nil

local function closeModal(modal)
	if modal then modal.Visible = false end
end

local function makeCenterFrame(name, size)
	local frame = mk("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = THEME.panel,
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		Visible = false,
		ZIndex = 120,
	}, gui)
	corner(frame, 8)
	stroke(frame, 1, THEME.line, 0.08)
	local scale = mk("UIScale", { Scale = 1 }, frame)
	local function syncScale()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(viewport.X / 1100, viewport.Y / 720), 0.78, 1)
	end
	syncScale()
	RunService.RenderStepped:Connect(syncScale)
	return frame
end

local function clearGuiChildren(container)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function ensureStatsModal()
	if statsModal then return statsModal end
	local frame = makeCenterFrame("StatsModal", UDim2.fromOffset(430, 390))
	local close = mk("TextButton", { Name = "Close", Text = "X", Font = Enum.Font.GothamBold, TextColor3 = THEME.text, TextSize = 16, BackgroundColor3 = Color3.fromRGB(36, 26, 20), BorderSizePixel = 0, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(32, 28), ZIndex = 125 }, frame)
	corner(close, 5)
	close.Activated:Connect(function() closeModal(frame) end)
	local avatarFrame = mk("Frame", { Name = "AvatarFrame", BackgroundColor3 = Color3.fromRGB(12, 10, 9), BorderSizePixel = 0, Position = UDim2.fromOffset(54, 28), Size = UDim2.fromOffset(84, 84), ZIndex = 121 }, frame)
	corner(avatarFrame, 42)
	stroke(avatarFrame, 2, THEME.line, 0.08)
	local avatarImage = mk("ImageLabel", { Name = "Avatar", BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(74, 74), ScaleType = Enum.ScaleType.Crop, ZIndex = 122 }, avatarFrame)
	corner(avatarImage, 37)
	mk("TextLabel", { Name = "Name", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "-", TextColor3 = THEME.text, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(154, 38), Size = UDim2.fromOffset(235, 30), ZIndex = 121 }, frame)
	mk("TextLabel", { Name = "Honor", BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "Honor: 0", TextColor3 = THEME.subtle, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(156, 70), Size = UDim2.fromOffset(230, 24), ZIndex = 121 }, frame)
	mk("TextLabel", { Name = "ValorTitle", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "Valor", TextColor3 = THEME.line, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(38, 135), Size = UDim2.fromOffset(250, 24), ZIndex = 121 }, frame)
	local rows = mk("Frame", { Name = "Rows", BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 170), Size = UDim2.fromOffset(354, 180), ZIndex = 121 }, frame)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows
	return frame
end

local function openStatsPanel(userId, model)
	local data = userId and requestStatus("Stats", userId) or nil
	local frame = ensureStatsModal()
	local nameText = frame:FindFirstChild("Name")
	local honorText = frame:FindFirstChild("Honor")
	local avatarFrame = frame:FindFirstChild("AvatarFrame")
	local avatarImage = avatarFrame and avatarFrame:FindFirstChild("Avatar")
	local rowsFrame = frame:FindFirstChild("Rows")
	local name = data and (data.DisplayName or data.Name) or (model and model.Name or "Creature")
	if nameText then nameText.Text = tostring(name) end
	if honorText then honorText.Text = "Honor: " .. tostring(data and data.Honor or (model and model:GetAttribute("Honor") or "-")) end
	if avatarImage then avatarImage.Image = data and thumbnailFor(data.UserId) or "" end
	clearGuiChildren(rowsFrame)
	local valor = data and data.Valor or { Total = 0, PvP = 0, PvE = 0, Gathering = 0, Crafting = 0 }
	local order = { "Total", "PvP", "PvE", "Gathering", "Crafting" }
	for index, key in ipairs(order) do
		local row = mk("Frame", { Name = key, BackgroundColor3 = index == 1 and Color3.fromRGB(44, 31, 21) or THEME.panel2, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, index == 1 and 38 or 30), ZIndex = 122 }, rowsFrame)
		corner(row, 6)
		stroke(row, 1, index == 1 and THEME.line or Color3.fromRGB(92, 68, 40), index == 1 and 0.12 or 0.45)
		mk("TextLabel", { Name = "Label", BackgroundTransparency = 1, Font = index == 1 and Enum.Font.GothamBold or Enum.Font.Gotham, Text = key .. " Valor", TextColor3 = THEME.text, TextSize = index == 1 and 15 or 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.55, 0, 1, 0), ZIndex = 123 }, row)
		mk("TextLabel", { Name = "Value", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = comma(valor[key] or 0), TextColor3 = index == 1 and THEME.line or THEME.subtle, TextSize = index == 1 and 15 or 13, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.55, 0, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), ZIndex = 123 }, row)
	end
	frame.Visible = true
end

local function openInspectItemDetail(detail)
	if type(detail) ~= "table" then return end
	detail.ReadOnlyAbilities = true
	detail.InspectReadOnly = true
	if type(_G.OpenItemDetail) == "function" then
		_G.OpenItemDetail(detail)
	end
end

local function ensureInspectModal()
	if inspectModal then return inspectModal end
	local frame = makeCenterFrame("InspectModal", UDim2.fromOffset(410, 420))
	local close = mk("TextButton", { Name = "Close", Text = "X", Font = Enum.Font.GothamBold, TextColor3 = THEME.text, TextSize = 16, BackgroundColor3 = Color3.fromRGB(36, 26, 20), BorderSizePixel = 0, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(32, 28), ZIndex = 125 }, frame)
	corner(close, 5)
	close.Activated:Connect(function() closeModal(frame) end)
	mk("TextLabel", { Name = "LayoutHint", BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = "", TextColor3 = THEME.subtle, TextSize = 12, Position = UDim2.fromOffset(34, 378), Size = UDim2.fromOffset(342, 20), ZIndex = 121 }, frame)
	local title = mk("TextButton", { Name = "Title", AutoButtonColor = false, BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = "Inspect", TextColor3 = THEME.text, TextSize = 23, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(56, 14), Size = UDim2.fromOffset(300, 30), ZIndex = 121 }, frame)
	local grid = mk("Frame", { Name = "EquipmentGrid", BackgroundTransparency = 1, Position = UDim2.fromOffset(66, 68), Size = UDim2.fromOffset(276, 304), ZIndex = 121 }, frame)
	return frame
end

local function openInspectPanel(userId, model)
	local data = userId and requestStatus("Inspect", userId) or nil
	local frame = ensureInspectModal()
	frame:SetAttribute("TargetUserId", tonumber(userId) or 0)
	frame.Title.Text = data and (data.DisplayName or data.Name) or (model and model.Name or "Creature")
	if not frame.Title:GetAttribute("StatsClickBound") then
		frame.Title:SetAttribute("StatsClickBound", true)
		frame.Title.Activated:Connect(function()
			local targetUserId = tonumber(frame:GetAttribute("TargetUserId"))
			openStatsPanel(targetUserId and targetUserId > 0 and targetUserId or nil, currentTargetModel)
		end)
	end
	clearGuiChildren(frame.EquipmentGrid)
	local slots = data and data.Slots or {}
	local bySlot = {}
	for _, slot in ipairs(slots) do
		bySlot[slot.Slot] = slot
	end
	local layout = {
		{ Slot = "Cape", X = 0, Y = 0 }, { Slot = "Helmet", X = 92, Y = 0 }, { Slot = "Bag", X = 184, Y = 0 },
		{ Slot = "Weapon", X = 0, Y = 76 }, { Slot = "Armor", X = 92, Y = 76 }, { Slot = "Offhand", X = 184, Y = 76 },
		{ Slot = "Food", X = 0, Y = 152 }, { Slot = "Boots", X = 92, Y = 152 }, { Slot = "Potion", X = 184, Y = 152 },
		{ Slot = "Mount", X = 92, Y = 232 },
	}
	for index, spec in ipairs(layout) do
		local slot = bySlot[spec.Slot] or { Slot = spec.Slot }
		local detail = slot.Detail
		local label = detail and (detail.itemName or detail.DisplayName or slot.ItemId) or spec.Slot
		local button = mk("TextButton", { Name = spec.Slot, AutoButtonColor = detail ~= nil, BackgroundColor3 = detail and Color3.fromRGB(43, 31, 23) or Color3.fromRGB(25, 20, 17), BorderSizePixel = 0, Font = Enum.Font.GothamBold, Text = tostring(label or spec.Slot), TextColor3 = detail and THEME.text or THEME.subtle, TextSize = 11, TextWrapped = true, Position = UDim2.fromOffset(spec.X, spec.Y), Size = UDim2.fromOffset(82, 66), LayoutOrder = index, ZIndex = 122 }, frame.EquipmentGrid)
		corner(button, 7)
		stroke(button, 1, detail and THEME.line or Color3.fromRGB(70, 58, 44), detail and 0.25 or 0.58)
		button.Activated:Connect(function()
			openInspectItemDetail(detail)
		end)
	end
	frame.Visible = true
end

local function callParty(actionName, payload)
	if _G.PartyRequest then
		return _G.PartyRequest(actionName, payload or {})
	end
	local ok, result = pcall(function()
		return PartyRequest:InvokeServer(actionName, payload or {})
	end)
	return ok and result or nil
end

local function makeDropdown(parent, y, includeInspect, statsCallback, inspectCallback, extraRows)
	extraRows = type(extraRows) == "table" and extraRows or {}
	local baseRows = includeInspect and 2 or 1
	local rowCount = baseRows + #extraRows
	local dropdown = mk("Frame", { Name = "NameDropdown", BackgroundColor3 = Color3.fromRGB(20, 15, 13), BorderSizePixel = 0, Position = UDim2.fromOffset(92, y), Size = UDim2.fromOffset(138, rowCount * 32 + 2), Visible = false, ZIndex = 80 }, parent)
	corner(dropdown, 6)
	stroke(dropdown, 1, THEME.line, 0.28)
	local function addRow(name, text, index, callback)
		local button = mk("TextButton", { Name = name, BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = text, TextColor3 = THEME.text, TextSize = 12, Position = UDim2.fromOffset(0, (index - 1) * 32), Size = UDim2.new(1, 0, 0, 32), ZIndex = 81 }, dropdown)
		button.Activated:Connect(function() dropdown.Visible = false; if callback then callback() end end)
		return button
	end
	addRow("Stats", "Stats", 1, statsCallback)
	local rowIndex = 2
	if includeInspect then
		addRow("Inspect", "Inspect", rowIndex, inspectCallback)
		rowIndex += 1
	end
	for _, row in ipairs(extraRows) do
		addRow(tostring(row.Name or row.Text or "Action"), tostring(row.Text or row.Name or "Action"), rowIndex, row.Callback)
		rowIndex += 1
	end
	return dropdown
end

local ownDropdown = makeDropdown(root, 34, false, function()
	openStatsPanel(player.UserId, player.Character)
end, nil, {
	{ Name = "LeaveParty", Text = "Leave party", Callback = function() callParty("Leave") end },
})
nameLabel.Activated:Connect(function()
	ownDropdown.Visible = not ownDropdown.Visible
end)

local function makeStatusCard(name, xOffset)
	local card = mk("Frame", { Name = name, BackgroundColor3 = THEME.panel, BackgroundTransparency = 0.08, BorderSizePixel = 0, Position = UDim2.fromOffset(xOffset, 0), Size = UDim2.fromOffset(HUD_SPEC.width, HUD_SPEC.height), Visible = false }, gui)
	corner(card, 7)
	stroke(card, 1, THEME.line, 0.15)
	mk("UIScale", { Scale = 1 }, card)
	local wrap = mk("Frame", { Name = "AvatarWrap", BackgroundColor3 = Color3.fromRGB(12, 10, 9), BorderSizePixel = 0, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(HUD_SPEC.avatar, HUD_SPEC.avatar) }, card)
	corner(wrap, 36)
	stroke(wrap, 2, THEME.line, 0.05)
	local image = mk("ImageLabel", { Name = "AvatarImage", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(HUD_SPEC.avatar - 8, HUD_SPEC.avatar - 8), ScaleType = Enum.ScaleType.Crop }, wrap)
	corner(image, 32)
	local nameButton = mk("TextButton", { Name = "NameButton", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.GothamBold, Text = "Target", TextColor3 = THEME.text, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(92, 9), Size = UDim2.fromOffset(180, HUD_SPEC.nameHeight) }, card)
	local cardBars = {}
	local function makeCardBar(barName, y, color)
		local frame = mk("Frame", { Name = barName, BackgroundColor3 = Color3.fromRGB(13, 10, 9), BorderSizePixel = 0, Position = UDim2.fromOffset(92, y), Size = UDim2.fromOffset(216, HUD_SPEC.barHeight) }, card)
		corner(frame, 4)
		stroke(frame, 1, Color3.fromRGB(82, 62, 38), 0.25)
		local fill = mk("Frame", { Name = "Fill", BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, frame)
		corner(fill, 4)
		local text = mk("TextLabel", { Name = "Value", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 246, 220), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, frame)
		cardBars[barName] = { Frame = frame, Fill = fill, Text = text }
	end
	makeCardBar("HealthBar", 39, THEME.health)
	makeCardBar("ManaBar", 60, THEME.mana)
	makeCardBar("MountBar", 81, THEME.mount)
	return { Root = card, Avatar = image, NameButton = nameButton, Bars = cardBars }
end

local targetCard = makeStatusCard("TargetStatusRoot", HUD_SPEC.width + 14)
local targetDropdown = makeDropdown(targetCard.Root, 34, true, function()
	openStatsPanel(currentTargetUserId, currentTargetModel)
end, function()
	openInspectPanel(currentTargetUserId, currentTargetModel)
end, {
	{ Name = "InviteParty", Text = "Invite to party", Callback = function()
		if currentTargetUserId then callParty("Invite", { TargetUserId = currentTargetUserId }) end
	end },
	{ Name = "KickParty", Text = "Kick from party", Callback = function()
		if currentTargetUserId then callParty("Kick", { TargetUserId = currentTargetUserId }) end
	end },
	{ Name = "PromoteParty", Text = "Make leader", Callback = function()
		if currentTargetUserId then callParty("Promote", { TargetUserId = currentTargetUserId }) end
	end },
})
targetCard.NameButton.Activated:Connect(function()
	targetDropdown.Visible = not targetDropdown.Visible
end)

local function modelHealth(model)
	local humanoid = model and model:FindFirstChildWhichIsA("Humanoid")
	local health = tonumber(model and model:GetAttribute("Health")) or (humanoid and humanoid.Health) or 0
	local maxHealth = tonumber(model and model:GetAttribute("MaxHealth")) or (humanoid and humanoid.MaxHealth) or math.max(1, health)
	return health, math.max(1, maxHealth)
end

local function updateTargetHud()
	local model = currentTargetModel
	if not (model and model.Parent) then
		targetCard.Root.Visible = false
		return
	end
	local targetPlayer = Players:GetPlayerFromCharacter(model)
	currentTargetUserId = targetPlayer and targetPlayer.UserId or nil
	targetCard.Root.Visible = true
	targetCard.NameButton.Text = targetPlayer and (targetPlayer.DisplayName ~= "" and targetPlayer.DisplayName or targetPlayer.Name) or model.Name
	targetCard.Avatar.Image = targetPlayer and thumbnailFor(targetPlayer.UserId) or ""
	local health, maxHealth = modelHealth(model)
	setBar(targetCard.Bars.HealthBar, health, maxHealth)
	local mana = tonumber(model:GetAttribute("Mana")) or 0
	local maxMana = tonumber(model:GetAttribute("MaxMana")) or 100
	setBar(targetCard.Bars.ManaBar, mana, maxMana)
	local mounted = model:GetAttribute("Mounted") == true
	targetCard.Bars.MountBar.Frame.Visible = mounted
	if mounted then
		setBar(targetCard.Bars.MountBar, model:GetAttribute("MountHealth") or 0, model:GetAttribute("MaxMountHealth") or 1)
	end
end

local function layoutTargetCard()
	local inset = GuiService:GetGuiInset()
	local scale = root.UIScale.Scale
	targetCard.Root.UIScale.Scale = scale
	targetCard.Root.Position = UDim2.fromOffset(inset.X + 12 + (HUD_SPEC.width * scale) + 14, inset.Y + 8)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Y then
		local targetPlayer = currentTargetModel and Players:GetPlayerFromCharacter(currentTargetModel)
		if not targetPlayer then return end
		local frame = ensureInspectModal()
		if frame.Visible then
			frame.Visible = false
		else
			openInspectPanel(targetPlayer.UserId, currentTargetModel)
		end
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local model = Selection.getTargetModel(MouseUtil.getMouseInteractionTarget())
	if Selection.isSelectableUnit(model) then
		Selection.setPersistent(model)
		currentTargetModel = model
		currentTargetUserId = nil
		updateTargetHud()
	end
end)

RunService.RenderStepped:Connect(function()
	local selected = Selection.getPersistent()
	if selected and selected ~= currentTargetModel then
		currentTargetModel = selected
		currentTargetUserId = nil
	end
	layoutTargetCard()
	updateTargetHud()
end)

local nameplates = {}
local offscreenIndicators = {}
local OFFSCREEN_MAX_DISTANCE = 60
local OFFSCREEN_CARD_WIDTH = 178
local OFFSCREEN_CARD_HEIGHT = 62

local offscreenRoot = mk("Frame", {
	Name = "OffscreenPlayerIndicators",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 35,
}, gui)

local function makeOffscreenBar(parent, name, y, color)
	local frame = mk("Frame", {
		Name = name,
		BackgroundColor3 = Color3.fromRGB(13, 10, 9),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(42, y),
		Size = UDim2.fromOffset(124, 9),
		ZIndex = 37,
	}, parent)
	corner(frame, 4)
	stroke(frame, 1, Color3.fromRGB(82, 62, 38), 0.32)
	local fill = mk("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 38,
	}, frame)
	corner(fill, 4)
	local text = mk("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 246, 220),
		TextSize = 8,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 39,
	}, frame)
	return { Frame = frame, Fill = fill, Text = text }
end

local function makeOffscreenIndicator(otherPlayer)
	local card = mk("Frame", {
		Name = otherPlayer.Name .. "OffscreenIndicator",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = THEME.panel,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(OFFSCREEN_CARD_WIDTH, OFFSCREEN_CARD_HEIGHT),
		Visible = false,
		ZIndex = 36,
	}, offscreenRoot)
	corner(card, 7)
	stroke(card, 1, THEME.line, 0.12)
	local scale = mk("UIScale", { Scale = 1 }, card)
	local pointer = mk("TextLabel", {
		Name = "Pointer",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = ">",
		TextColor3 = THEME.line,
		TextSize = 24,
		Position = UDim2.fromOffset(8, 18),
		Size = UDim2.fromOffset(22, 22),
		ZIndex = 38,
	}, card)
	local name = mk("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = otherPlayer.DisplayName ~= "" and otherPlayer.DisplayName or otherPlayer.Name,
		TextColor3 = THEME.text,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(42, 7),
		Size = UDim2.fromOffset(124, 16),
		ZIndex = 37,
	}, card)
	local bars = {
		HealthBar = makeOffscreenBar(card, "HealthBar", 27, THEME.health),
		ManaBar = makeOffscreenBar(card, "ManaBar", 42, THEME.mana),
	}
	offscreenIndicators[otherPlayer] = { Root = card, Scale = scale, Pointer = pointer, Name = name, Bars = bars }
	return offscreenIndicators[otherPlayer]
end

local function clearOffscreenIndicator(otherPlayer)
	local entry = offscreenIndicators[otherPlayer]
	if entry then
		if entry.Root then entry.Root:Destroy() end
		offscreenIndicators[otherPlayer] = nil
	end
end

local function viewportPointVisible(point, viewport)
	return point.Z > 0 and point.X >= 0 and point.X <= viewport.X and point.Y >= 0 and point.Y <= viewport.Y
end

local function edgePositionFor(camera, viewport, worldPosition, scaledSize)
	local point = camera:WorldToViewportPoint(worldPosition)
	local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
	local direction = Vector2.new(point.X - center.X, point.Y - center.Y)
	if point.Z <= 0 then
		local localPos = camera.CFrame:PointToObjectSpace(worldPosition)
		direction = Vector2.new(localPos.X, -localPos.Y)
	end
	if direction.Magnitude < 0.01 then
		direction = Vector2.new(0, 1)
	end
	local unit = direction.Unit
	local inset = GuiService:GetGuiInset()
	local halfW = scaledSize.X * 0.5 + 12
	local halfH = scaledSize.Y * 0.5 + 12
	local minX = halfW
	local maxX = math.max(minX, viewport.X - halfW)
	local minY = math.max(halfH, inset.Y + halfH)
	local maxY = math.max(minY, viewport.Y - halfH)
	local tx = math.huge
	if math.abs(unit.X) > 0.001 then
		tx = ((unit.X > 0 and maxX or minX) - center.X) / unit.X
	end
	local ty = math.huge
	if math.abs(unit.Y) > 0.001 then
		ty = ((unit.Y > 0 and maxY or minY) - center.Y) / unit.Y
	end
	local t = math.min(tx > 0 and tx or math.huge, ty > 0 and ty or math.huge)
	if t == math.huge then t = 0 end
	local pos = center + unit * t
	return Vector2.new(math.clamp(pos.X, minX, maxX), math.clamp(pos.Y, minY, maxY)), math.deg(math.atan2(unit.Y, unit.X))
end

local function updateOffscreenIndicators()
	local camera = workspace.CurrentCamera
	local localCharacterModel = player.Character
	local localRoot = localCharacterModel and localCharacterModel:FindFirstChild("HumanoidRootPart")
	if not (camera and localRoot) then
		for _, entry in pairs(offscreenIndicators) do
			entry.Root.Visible = false
		end
		return
	end
	local viewport = camera.ViewportSize
	local uiScale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.72, 1)
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local character = otherPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local head = character and character:FindFirstChild("Head")
			local entry = offscreenIndicators[otherPlayer] or makeOffscreenIndicator(otherPlayer)
			if character and rootPart and head and character:GetAttribute("Downed") ~= true then
				local distance = (rootPart.Position - localRoot.Position).Magnitude
				local aimPosition = head.Position + Vector3.new(0, 1.25, 0)
				local point, onScreen = camera:WorldToViewportPoint(aimPosition)
				local visibleInViewport = onScreen and viewportPointVisible(point, viewport)
				if distance <= OFFSCREEN_MAX_DISTANCE and not visibleInViewport then
					entry.Root.Visible = true
					entry.Scale.Scale = uiScale
					entry.Name.Text = otherPlayer.DisplayName ~= "" and otherPlayer.DisplayName or otherPlayer.Name
					local health, maxHealth = modelHealth(character)
					setBar(entry.Bars.HealthBar, health, maxHealth)
					setBar(entry.Bars.ManaBar, character:GetAttribute("Mana") or 0, character:GetAttribute("MaxMana") or 1)
					local position, angle = edgePositionFor(camera, viewport, aimPosition, Vector2.new(OFFSCREEN_CARD_WIDTH * uiScale, OFFSCREEN_CARD_HEIGHT * uiScale))
					entry.Root.Position = UDim2.fromOffset(position.X, position.Y)
					entry.Pointer.Rotation = angle
				else
					entry.Root.Visible = false
				end
			else
				entry.Root.Visible = false
			end
		end
	end
end
local function formatGuildLine(character)
	local alliance = tostring(character:GetAttribute("AllianceAlias") or "")
	local guild = tostring(character:GetAttribute("GuildName") or "")
	if alliance ~= "" and guild ~= "" then
		return string.format("[%s] \"%s\"", alliance, guild)
	elseif alliance ~= "" then
		return string.format("[%s]", alliance)
	elseif guild ~= "" then
		return string.format("\"%s\"", guild)
	end
	return ""
end

local function attachNameplate(otherPlayer, character)
	if not character then return end
	local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 5)
	if not head then return end
	local old = head:FindFirstChild("PlayerNameplate")
	if old then old:Destroy() end

	local billboard = mk("BillboardGui", {
		Name = "PlayerNameplate",
		Adornee = head,
		AlwaysOnTop = true,
		MaxDistance = 150,
		Size = UDim2.fromOffset(170, 62),
		StudsOffset = Vector3.new(0, 3.25, 0),
	}, head)

	local holder = mk("Frame", {
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, billboard)

	local n = mk("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = otherPlayer.DisplayName ~= "" and otherPlayer.DisplayName or otherPlayer.Name,
		TextColor3 = Color3.fromRGB(244, 234, 204),
		TextStrokeTransparency = 0.35,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 17),
	}, holder)

	local guild = mk("TextLabel", {
		Name = "GuildLine",
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(222, 204, 158),
		TextStrokeTransparency = 0.45,
		TextSize = 11,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 14),
	}, holder)

	local function makePlateBar(name, y, width, height, color)
		local back = mk("Frame", {
			Name = name,
			BackgroundColor3 = Color3.fromRGB(15, 11, 10),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset((170 - width) * 0.5, y),
			Size = UDim2.fromOffset(width, height),
		}, holder)
		corner(back, math.max(2, math.floor(height * 0.5)))
		stroke(back, 1, Color3.fromRGB(66, 48, 31), 0.35)
		local fill = mk("Frame", {
			Name = "Fill",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, back)
		corner(fill, math.max(2, math.floor(height * 0.5)))
		return back, fill
	end

	local hpBack, hpFill = makePlateBar("HealthBack", 33, 118, 7, THEME.health)
	local manaBack, manaFill = makePlateBar("ManaBack", 43, 102, 5, THEME.mana)
	local mountBack, mountFill = makePlateBar("MountBack", 51, 86, 4, THEME.mount)

	local function updatePlate()
		guild.Text = formatGuildLine(character)
		guild.Visible = guild.Text ~= ""
		local health = math.max(0, tonumber(character:GetAttribute("Health")) or 0)
		local maxHealth = math.max(1, tonumber(character:GetAttribute("MaxHealth")) or 1)
		local mana = math.max(0, tonumber(character:GetAttribute("Mana")) or 0)
		local maxMana = math.max(1, tonumber(character:GetAttribute("MaxMana")) or 1)
		local mounted = character:GetAttribute("Mounted") == true
		hpFill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
		manaFill.Size = UDim2.fromScale(math.clamp(mana / maxMana, 0, 1), 1)
		mountBack.Visible = mounted
		if mounted then
			local mountHealth = math.max(0, tonumber(character:GetAttribute("MountHealth")) or 0)
			local maxMountHealth = math.max(1, tonumber(character:GetAttribute("MaxMountHealth")) or 1)
			mountFill.Size = UDim2.fromScale(math.clamp(mountHealth / maxMountHealth, 0, 1), 1)
		end
		holder.Visible = character:GetAttribute("Downed") ~= true
	end

	local conns = {}
	for _, attr in ipairs({ "Health", "MaxHealth", "Mana", "MaxMana", "Mounted", "MountHealth", "MaxMountHealth", "GuildName", "AllianceAlias", "Downed" }) do
		table.insert(conns, character:GetAttributeChangedSignal(attr):Connect(updatePlate))
	end
	updatePlate()
	nameplates[character] = conns
end

local function clearNameplate(character)
	local conns = nameplates[character]
	if conns then
		for _, conn in ipairs(conns) do pcall(function() conn:Disconnect() end) end
		nameplates[character] = nil
	end
end

local function watchPlayer(otherPlayer)
	otherPlayer.CharacterAdded:Connect(function(character)
		clearNameplate(character)
		task.wait(0.2)
		attachNameplate(otherPlayer, character)
	end)
	otherPlayer.CharacterRemoving:Connect(clearNameplate)
	if otherPlayer.Character then
		attachNameplate(otherPlayer, otherPlayer.Character)
	end
end

for _, otherPlayer in ipairs(Players:GetPlayers()) do
	watchPlayer(otherPlayer)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(clearOffscreenIndicator)

player.CharacterAdded:Connect(function(character)
	for _, attr in ipairs({ "Health", "MaxHealth", "Mana", "MaxMana", "Mounted", "MountHealth", "MaxMountHealth", "PvPFlagged", "ZoneType" }) do
		character:GetAttributeChangedSignal(attr):Connect(updateHud)
	end
	task.wait(0.2)
	updateHud()
end)
if player.Character then
	for _, attr in ipairs({ "Health", "MaxHealth", "Mana", "MaxMana", "Mounted", "MountHealth", "MaxMountHealth", "PvPFlagged", "ZoneType" }) do
		player.Character:GetAttributeChangedSignal(attr):Connect(updateHud)
	end
	updateHud()
end

RunService.RenderStepped:Connect(function()
	layoutRoot()
	updateHud()
	updateOffscreenIndicators()
end)
