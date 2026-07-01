--[[
Name: ItemDetailUIInstaller
Class: ModuleScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.ItemDetailUIInstaller
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage, StarterGui
Requires:
  - ctrl.Source = [[local Controller = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Mo...
Functions: mk, uiStroke, uiCorner, addGradient, build, section, M.Install, M.Rollback
Clean source lines: 531
]]
local M = {}


local function mk(t, props, kids)
	local o = Instance.new(t)
	for k,v in pairs(props or {}) do o[k] = v end
	for _,c in ipairs(kids or {}) do c.Parent = o end
	return o
end

local function uiStroke(parent, thickness, color, trans)
	return mk("UIStroke", {
		Parent = parent,
		Thickness = thickness or 1.5,
		Color = color or Color3.fromRGB(232,176,64),
		Transparency = trans or 0.18,
	})
end

local function uiCorner(parent, r)
	return mk("UICorner", { Parent = parent, CornerRadius = UDim.new(0, r or 12) })
end

local function addGradient(parent, seq, rotation)
	local g = Instance.new("UIGradient")
	local ks = {}
	for _,k in ipairs(seq) do table.insert(ks, ColorSequenceKeypoint.new(k.p, k.c)) end
	g.Color = ColorSequence.new(ks)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end


local Theme = {
	panelBg      = Color3.fromRGB(14, 10, 10),
	panelBgTop   = Color3.fromRGB(28, 20, 18),
	slotOuter    = Color3.fromRGB(26, 18, 16),
	slotInner    = Color3.fromRGB(38, 26, 22),

	gilt         = Color3.fromRGB(232, 176, 64),
	giltDim      = Color3.fromRGB(156, 116, 48),

	text         = Color3.fromRGB(242, 228, 198),
	subtleText   = Color3.fromRGB(210, 196, 166),
	textShadow   = Color3.fromRGB(8, 6, 4),
}


local function build(starterGui, opts)
	opts = opts or {}

	local gui = mk("ScreenGui", {
		Name = "ItemDetailUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 9999,
	}, {})
	gui.Parent = starterGui


	local dim = mk("Frame", {
		Name="Backdrop",
		BackgroundColor3 = Color3.new(0,0,0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1,1),
		ZIndex = 0,
	}, {})
	dim.Parent = gui


	local card = mk("Frame", {
		Name="ItemCard",
		AnchorPoint = Vector2.new(0.5,0.5),
		Position = UDim2.fromScale(0.5,0.5),
		Size = UDim2.new(0.62,0, 0.68,0),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 10,
		Visible = false,
	}, {})
	card.Parent = gui
	uiCorner(card, 14)
	uiStroke(card, 1.6, Theme.gilt, 0.18)
	addGradient(card, {
		{p=0.00, c=Theme.panelBgTop},
		{p=1.00, c=Theme.panelBg},
	}, 0)


	local header = mk("Frame", {
		Name="Header",
		BackgroundColor3 = Theme.panelBgTop,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(1,0, 0.12,0),
		ZIndex = 12,
	}, {})
	header.Parent = card
	uiCorner(header, 12)
	uiStroke(header, 1.1, Theme.gilt, 0.22)

	local headerPad = mk("UIPadding", {
		PaddingLeft = UDim.new(0.02,0),
		PaddingRight= UDim.new(0.02,0),
		PaddingTop  = UDim.new(0.25,0),
	}, {}); headerPad.Parent = header


	local previewWrap = mk("Frame", {
		Name="PreviewWrap",
		AnchorPoint=Vector2.new(0,0),
		Position = UDim2.new(0.02,0, 0.02,0),
		Size     = UDim2.new(0.18,0, 0.26,0),
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		ZIndex=13,
	}, {})
	previewWrap.Parent = card
	uiCorner(previewWrap, 10)
	uiStroke(previewWrap, 1.2, Theme.gilt, 0.22)
	local preview = mk("ImageLabel", {
		Name="ItemImage",
		BackgroundTransparency=1,
		Image = "rbxassetid://0",
		Size = UDim2.fromScale(1,1),
	}, {}); preview.Parent = previewWrap


	local amt = mk("TextLabel", {
		Name="AmountBadge",
		BackgroundTransparency=0.1,
		BackgroundColor3 = Theme.slotOuter,
		Text = "x0",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Theme.text,
		AnchorPoint = Vector2.new(1,0),
		Position = UDim2.new(0.98,0, 0.02,0),
		Size = UDim2.new(0.12,0, 0.08,0),
		ZIndex=14,
	}, {})
	amt.Parent = card
	uiCorner(amt, 10)
	uiStroke(amt, 1.2, Theme.gilt, 0.18)


	local hdrRow = mk("Frame", {
		Name="HeaderRow",
		BackgroundTransparency=1,
		Size = UDim2.new(1,0,1,0),
	}, {}); hdrRow.Parent = header

	local quality = mk("TextLabel", {
		Name="QualityLabel",
		BackgroundTransparency=1,
		Text = "Quality: —",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0,0.5),
		Position = UDim2.new(0.22,0, 0.40,0),
		Size = UDim2.new(0.36,0, 0.5,0),
		TextStrokeColor3=Theme.textShadow,
		TextStrokeTransparency=0.9,
	}, {}); quality.Parent = hdrRow

	local enhWrap = mk("Frame", {
		Name="EnhancementWrap",
		BackgroundTransparency=1,
		AnchorPoint=Vector2.new(0,0.5),
		Position = UDim2.new(0.60,0, 0.40,0),
		Size = UDim2.new(0.34,0, 0.5,0),
	}, {}); enhWrap.Parent = hdrRow

	local enhLbl = mk("TextLabel", {
		Name="EnhLabel",
		BackgroundTransparency=1,
		Text = "Enhancement:",
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextColor3 = Theme.subtleText,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0,0.5),
		Position = UDim2.new(0,0,0.5,0),
		Size = UDim2.new(0.70,0,1,0),
	}, {}); enhLbl.Parent = enhWrap

	local enhIcon = mk("ImageLabel", {
		Name="EnhIcon",
		BackgroundTransparency=1,
		Image = "rbxassetid://0",
		AnchorPoint = Vector2.new(1,0.5),
		Position = UDim2.new(1,0,0.5,0),
		Size = UDim2.new(0.26,0,0.9,0),
	}, {}); enhIcon.Parent = enhWrap


	local subHdr = mk("Frame", {
		Name="SubHeader",
		BackgroundTransparency=1,
		AnchorPoint=Vector2.new(0.5,0),
		Position = UDim2.new(0.5,0, 0.12,0),
		Size = UDim2.new(0.96,0, 0.06,0),
		ZIndex=11,
	}, {}); subHdr.Parent = card

	local weightLbl = mk("TextLabel", {
		Name="WeightLabel",
		BackgroundTransparency=1,
		Text = "Weight: 0 (0%)",
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextColor3 = Theme.subtleText,
		TextXAlignment=Enum.TextXAlignment.Left,
		AnchorPoint=Vector2.new(0,0.5),
		Position = UDim2.new(0,0,0.5,0),
		Size = UDim2.new(0.5,0,1,0),
	}, {}); weightLbl.Parent = subHdr

	local byLbl = mk("TextLabel", {
		Name="ByLabel",
		BackgroundTransparency=1,
		Text = "Crafted by: —",
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextColor3 = Theme.subtleText,
		TextXAlignment=Enum.TextXAlignment.Right,
		AnchorPoint=Vector2.new(1,0.5),
		Position = UDim2.new(1,0,0.5,0),
		Size = UDim2.new(0.48,0,1,0),
	}, {}); byLbl.Parent = subHdr


	local body = mk("Frame", {
		Name="Body",
		BackgroundTransparency=1,
		AnchorPoint=Vector2.new(0.5,1),
		Position = UDim2.new(0.5,0, 0.90,0),
		Size = UDim2.new(0.96,0, 0.66,0),
	}, {}); body.Parent = card

	local left = mk("Frame", {
		Name="LeftCol",
		BackgroundTransparency=1,
		Size = UDim2.new(0.34,0,1,0),
	}, {}); left.Parent = body

	local right = mk("Frame", {
		Name="RightCol",
		BackgroundTransparency=1,
		AnchorPoint=Vector2.new(1,0),
		Position = UDim2.new(1,0,0,0),
		Size = UDim2.new(0.64,0,1,0),
	}, {}); right.Parent = body


	local namePower = mk("TextLabel", {
		Name="NamePower",
		BackgroundTransparency=1,
		Text = "Item Name  |  0",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint=Vector2.new(0,0),
		Position = UDim2.new(0,0, 0.30,0),
		Size = UDim2.new(1,0, 0.10,0),
		TextStrokeColor3 = Theme.textShadow,
		TextStrokeTransparency = 0.9,
	}, {}); namePower.Parent = left


	local descBox = mk("Frame", {
		Name="DescriptionBox",
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(1,0, 0.38,0),
		Position = UDim2.new(0,0, 0.42,0),
		BorderSizePixel = 0,
	}, {}); descBox.Parent = left
	uiCorner(descBox, 10); uiStroke(descBox, 1.1, Theme.gilt, 0.22)

	local descScroll = mk("ScrollingFrame", {
		Name="DescriptionScroll",
		BackgroundTransparency=1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		Size = UDim2.fromScale(1,1),
	}, {}); descScroll.Parent = descBox

	local descText = mk("TextLabel", {
		Name="DescriptionText",
		BackgroundTransparency=1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "—",
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextColor3 = Theme.subtleText,
		Size = UDim2.new(0.96,0, 0,0),
		AnchorPoint = Vector2.new(0.5,0),
		Position = UDim2.new(0.5,0, 0,0),
	}, {}); descText.Parent = descScroll


	local slotBox = mk("Frame", {
		Name="SlotValueBox",
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(1,0, 0.16,0),
		Position = UDim2.new(0,0, 0.82,0),
		BorderSizePixel = 0,
	}, {}); slotBox.Parent = left
	uiCorner(slotBox, 10); uiStroke(slotBox, 1.1, Theme.gilt, 0.22)

	local slotLbl = mk("TextLabel", {
		Name="SlotLabel",
		BackgroundTransparency=1,
		Text = "Slot: —",
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint=Vector2.new(0,0.5),
		Position = UDim2.new(0.04,0, 0.35,0),
		Size = UDim2.new(0.92,0, 0.4,0),
	}, {}); slotLbl.Parent = slotBox

	local valLbl = mk("TextLabel", {
		Name="ValueLabel",
		BackgroundTransparency=1,
		Text = "Value: —",
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint=Vector2.new(0,0.5),
		Position = UDim2.new(0.04,0, 0.75,0),
		Size = UDim2.new(0.92,0, 0.4,0),
	}, {}); valLbl.Parent = slotBox


	local rightBox = mk("Frame", {
		Name="RightSections",
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Size = UDim2.new(1,0, 1,0),
	}, {}); rightBox.Parent = right
	uiCorner(rightBox, 10); uiStroke(rightBox, 1.1, Theme.gilt, 0.22)

	local rPad = mk("UIPadding", {
		PaddingTop=UDim.new(0.02,0),
		PaddingBottom=UDim.new(0.02,0),
		PaddingLeft=UDim.new(0.02,0),
		PaddingRight=UDim.new(0.02,0),
	}, {}); rPad.Parent = rightBox

	local rScroll = mk("ScrollingFrame", {
		Name="SectionScroll",
		BackgroundTransparency=1, AutomaticCanvasSize=Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), ScrollBarThickness=0, Size=UDim2.fromScale(1,1),
	}, {}); rScroll.Parent = rightBox

	local rList = mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0.012,0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, {}); rList.Parent = rScroll


	local function section(name)
		local box = mk("Frame", {
			Name = name.."Section",
			BackgroundColor3 = Theme.slotInner,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Size = UDim2.new(1,0, 0, 120),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {})
		uiCorner(box, 10); uiStroke(box, 1, Theme.gilt, 0.25)

		local ttl = mk("TextLabel", {
			Name="Title",
			BackgroundTransparency=1,
			Text = string.upper(name),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextColor3 = Theme.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			AnchorPoint = Vector2.new(0,0),
			Position = UDim2.new(0.02,0, 0.02,0),
			Size = UDim2.new(0.96,0, 0.14,0),
		}, {}); ttl.Parent = box

		local sep = mk("Frame", {
			Name="Sep",
			BackgroundColor3 = Theme.giltDim,
			BackgroundTransparency = 0.35,
			BorderSizePixel=0,
			AnchorPoint=Vector2.new(0.5,0),
			Position = UDim2.new(0.5,0, 0.18,0),
			Size = UDim2.new(0.96,0, 0,1),
		}, {}); sep.Parent = box

		local listWrap = mk("ScrollingFrame", {
			Name="List",
			BackgroundTransparency=1,
			AutomaticCanvasSize=Enum.AutomaticSize.Y,
			CanvasSize=UDim2.new(),
			ScrollBarThickness=0,
			AnchorPoint=Vector2.new(0.5,0),
			Position=UDim2.new(0.5,0, 0.20,0),
			Size = UDim2.new(0.96,0, 0, 10),
		}, {}); listWrap.Parent = box

		local ul = mk("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0.006,0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, {}); ul.Parent = listWrap


		local row = mk("Frame", {
			Name="RowTemplate",
			Visible=false,
			BackgroundTransparency=1,
			Size = UDim2.new(1,0, 0.10,0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {})
		local text = mk("TextLabel", {
			Name="Text",
			BackgroundTransparency=1,
			Text = "—",
			TextWrapped = true,
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextColor3 = Theme.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			AnchorPoint=Vector2.new(0,0),
			Position = UDim2.new(0,0,0,0),
			Size = UDim2.new(1,0, 0, 24),
		}, {}); text.Parent = row
		local line = mk("Frame", {
			BackgroundColor3 = Theme.giltDim,
			BackgroundTransparency=0.55,
			BorderSizePixel=0,
			AnchorPoint=Vector2.new(0.5,1),
			Position=UDim2.new(0.5,0, 1,0),
			Size=UDim2.new(1,0, 0,1),
		}, {}); line.Parent = row
		row.Parent = box

		return box
	end

	local statsSec    = section("Stats");    statsSec.Parent = rScroll
	local abilSec     = section("Abilities"); abilSec.Parent = rScroll
	local recipeSec   = section("Recipe");   recipeSec.Parent = rScroll


	local footer = mk("Frame", {
		Name="Footer",
		BackgroundTransparency=1,
		AnchorPoint=Vector2.new(1,1),
		Position = UDim2.new(0.98,0, 0.98,0),
		Size = UDim2.new(0.30,0, 0.06,0),
		ZIndex=12,
	}, {}); footer.Parent = card

	local equipBtn = mk("TextButton", {
		Name="EquipButton",
		Text = "EQUIP",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = Theme.text,
		BackgroundColor3 = Theme.slotOuter,
		BackgroundTransparency = 0.05,
		Size = UDim2.fromScale(1,1),
	}, {}); equipBtn.Parent = footer
	uiCorner(equipBtn, 10); uiStroke(equipBtn, 1.2, Theme.gilt, 0.18)


	local ctrl = Instance.new("LocalScript")
	ctrl.Name = "ItemDetailController"
	ctrl.Parent = gui
	ctrl.Source = [[local Controller = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Controllers"):WaitForChild("ItemDetailController"))

Controller.Start(script.Parent)
]]


	return gui
end


function M.Install(opts)
	local starterGui = game:GetService("StarterGui")
	local existing = starterGui:FindFirstChild("ItemDetailUI")
	if existing then
		if not (opts and opts.force) then
			warn("[ItemDetailUIInstaller] ItemDetailUI already exists. Pass {force=true} to overwrite.")
			return existing
		end
		existing:Destroy()
	end
	local gui = build(starterGui, opts)
	print("[ItemDetailUIInstaller] Installed ItemDetailUI (center modal)")
	return gui
end

function M.Rollback()
	local starterGui = game:GetService("StarterGui")
	local existing = starterGui:FindFirstChild("ItemDetailUI")
	if existing then
		existing:Destroy()
		print("[ItemDetailUIInstaller] Rolled back ItemDetailUI")
		return true
	end
	warn("[ItemDetailUIInstaller] Nothing to remove.")
	return false
end

return M
