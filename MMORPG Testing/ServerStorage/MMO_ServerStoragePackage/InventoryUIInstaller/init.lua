--[[
Name: InventoryUIInstaller
Class: ModuleScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.InventoryUIInstaller
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage, StarterGui
Requires:
  - controller.Source = [[local Controller = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChi...
Functions: mk, uiStroke, uiCorner, addGradient, barScaleForPercent, buildUI, plume, rivet, makeSlot, makeChip, makeInvSlot, M.Install, M.Rollback
Clean source lines: 573
]]
local M = {}


local function mk(t, props, children)
	local inst = Instance.new(t)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	return inst
end

local function uiStroke(parent, thickness, color, trans)
	return mk("UIStroke", {
		Parent = parent,
		Thickness = thickness or 1.5,
		Color = color or Color3.fromRGB(42,42,48),
		Transparency = trans or 0,
	})
end

local function uiCorner(parent, r)
	return mk("UICorner", { Parent = parent, CornerRadius = UDim.new(0, r or 8) })
end


local Theme = {
	panelBg      = Color3.fromRGB(14, 10, 10),
	panelBgTop   = Color3.fromRGB(28, 20, 18),
	barOuter     = Color3.fromRGB(36, 24, 22),
	barOuterTop  = Color3.fromRGB(52, 36, 30),
	slotOuter    = Color3.fromRGB(26, 18, 16),
	slotInner    = Color3.fromRGB(38, 26, 22),

	gilt         = Color3.fromRGB(232, 176, 64),
	giltDim      = Color3.fromRGB(156, 116, 48),

	text         = Color3.fromRGB(242, 228, 198),
	subtleText   = Color3.fromRGB(210, 196, 166),
	textShadow   = Color3.fromRGB(8, 6, 4),

	emberA       = Color3.fromRGB(150, 36, 18),
	emberB       = Color3.fromRGB(240, 112, 28),
	emberC       = Color3.fromRGB(255, 196, 82),

	tick         = Color3.fromRGB(240, 210, 168),
}

local function addGradient(parent, seq, rotation)
	local g = Instance.new("UIGradient")
	local keys = {}
	for _, k in ipairs(seq) do
		table.insert(keys, ColorSequenceKeypoint.new(k.p, k.c))
	end
	g.Color = ColorSequence.new(keys)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end


local BAR_LABEL_Y    = 0.95
local BAR_LABEL_SIZE = UDim2.new(0.12,0,0.25,0)


local BAR_KP = {
	{p=  0, s=0.00},
	{p=100, s=0.50},
	{p=130, s=0.55},
	{p=170, s=0.65},
	{p=200, s=0.75},
	{p=600, s=0.87},
	{p=800, s=1.00},
}
local function barScaleForPercent(p)
	p = tonumber(p) or 0
	if p <= BAR_KP[1].p then return BAR_KP[1].s end
	for i=1, #BAR_KP-1 do
		local a, b = BAR_KP[i], BAR_KP[i+1]
		if p <= b.p then
			local t = (p - a.p) / (b.p - a.p)
			return a.s + t * (b.s - a.s)
		end
	end
	return BAR_KP[#BAR_KP].s
end


local function buildUI(starterGui, opts)
	opts = opts or {}
	local initialPercent = tonumber(opts.initialPercent) or 55


	local gui = mk("ScreenGui", {
		Name="InventoryUI",
		IgnoreGuiInset=true,
		ResetOnSpawn=false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {})
	gui.Parent = starterGui


	local panel = mk("Frame", {
		Name = "InventoryPanel",
		AnchorPoint = Vector2.new(1,0),
		Position = UDim2.new(1, 0, 0, 0),
		Size     = UDim2.new(0.25, 0, 1, 0),
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.20,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, {})
	uiCorner(panel, 12)
	uiStroke(panel, 1.5, Color3.fromRGB(58,58,66), 0.15)
	addGradient(panel, {
		{p=0.00, c=Theme.panelBgTop},
		{p=1.00, c=Theme.panelBg},
	}, 0)
	panel.Parent = gui


	local innerBorder = mk("Frame", {
		Name="InnerBronzeBorder",
		AnchorPoint=Vector2.new(0.5,0.5),
		Position=UDim2.fromScale(0.5,0.5),
		Size=UDim2.new(1,-10, 1,-10),
		BackgroundTransparency=1,
		ZIndex=-100,
	}, {})
	uiCorner(innerBorder, 12)
	uiStroke(innerBorder, 1.6, Theme.gilt, 0.18)
	innerBorder.Parent = panel

	local inset = mk("Frame", {
		Name="InsetLine",
		AnchorPoint=Vector2.new(0.5,0.5),
		Position=UDim2.fromScale(0.5,0.5),
		Size=UDim2.new(1,-22, 1,-22),
		BackgroundTransparency=1,
		ZIndex=-99,
	}, {})
	uiCorner(inset, 10)
	uiStroke(inset, 1, Theme.giltDim, 0.40)
	inset.Parent = panel


	local function plume(name, pos, size, rot)
		local f = mk("Frame", {
			Name=name, AnchorPoint=Vector2.new(0.5,0.5),
			Position=pos, Size=size, Rotation=rot or 0,
			BackgroundTransparency=1, ZIndex=-98,
		}, {})
		f.Parent = panel
		local mask = mk("Frame", {
			Name="Mask", AnchorPoint=Vector2.new(0.5,0.5),
			Position=UDim2.fromScale(0.5,0.5), Size=UDim2.fromScale(1,1),
			BackgroundTransparency=0.35, BackgroundColor3=Color3.fromRGB(0,0,0),
			BorderSizePixel=0, ZIndex=-98,
		}, {})
		uiCorner(mask, 200)
		addGradient(mask, {
			{p=0.00, c=Color3.fromRGB(0,0,0)},
			{p=0.25, c=Theme.emberA},
			{p=0.60, c=Theme.emberB},
			{p=1.00, c=Theme.emberC},
		}, 0)
		mask.Parent = f
	end
	plume("PhoenixPlumeTR", UDim2.fromScale(0.86, 0.12), UDim2.new(0.38,0, 0.18,0), 20)
	plume("PhoenixPlumeBL", UDim2.fromScale(0.18, 0.88), UDim2.new(0.32,0, 0.16,0), -18)


	local function rivet(x,y,name)
		local r = mk("Frame", {
			Name=name, AnchorPoint=Vector2.new(0.5,0.5),
			Position=UDim2.fromScale(x,y), Size=UDim2.fromOffset(8,8),
			BackgroundColor3=Theme.gilt, BorderSizePixel=0, ZIndex=1,
		},{})
		uiCorner(r, 8)
		uiStroke(r, 1, Theme.giltDim, 0.25)
		r.Parent = panel
	end
	rivet(0.02, 0.02, "Rivet_TL")
	rivet(0.98, 0.02, "Rivet_TR")
	rivet(0.02, 0.98, "Rivet_BL")
	rivet(0.98, 0.98, "Rivet_BR")


	local content = mk("Frame", {
		Name="Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1,1),
	}, {})
	content.Parent = panel

	local vstack = mk("UIListLayout", {
		Parent = content,
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment   = Enum.VerticalAlignment.Top,
		Padding   = UDim.new(0.01, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	mk("UIPadding", {
		Parent = content,
		PaddingTop    = UDim.new(0.015, 0),
		PaddingBottom = UDim.new(0.015, 0),
		PaddingLeft   = UDim.new(0.02,  0),
		PaddingRight  = UDim.new(0.02,  0),
	})


	local header = mk("Frame", {
		Name="Header", LayoutOrder=1,
		Size = UDim2.new(1, 0, 0.055, 0),
		BackgroundTransparency = 1, ZIndex=10,
	}, {})
	header.Parent = content

	local headerRow = mk("Frame", {
		Name="HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0.3, 0),
	}, {})
	headerRow.Parent = header

	local arrow = mk("ImageLabel", {
		Name="CloseArrow", BackgroundTransparency=1,
		AnchorPoint = Vector2.new(0,0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0.1, 0, 0.7, 0),
		Image = "rbxassetid://0",
		ImageColor3 = Theme.gilt,
		ZIndex=11,
	}, {})
	arrow.Parent = headerRow

	local nameWrap = mk("Frame", {
		Name="NameWrap",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0,0.5),
		Position = UDim2.new(0.06, 0, 0.5, 0),
		Size     = UDim2.new(0.94, 0, 1, 0),
	}, {})
	nameWrap.Parent = headerRow
	mk("UIPadding", { Parent = nameWrap, PaddingRight=UDim.new(0.01,0) })

	local nameLabel = mk("TextLabel", {
		Name="PlayerName",
		BackgroundTransparency = 1,
		Text = "Player",
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextScaled = true,
		TextColor3 = Theme.text,
		TextStrokeColor3 = Theme.textShadow,
		TextStrokeTransparency = 0.88,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0,0.5),
		Position = UDim2.new(0.05, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 11,
	}, {})
	nameLabel.Parent = nameWrap

	local etch = mk("Frame", {
		Name="HeaderEtch", AnchorPoint = Vector2.new(0.5,1),
		Position = UDim2.new(0.5,0,1,0), Size = UDim2.new(0.96,0,0,1),
		BackgroundColor3 = Theme.giltDim, BackgroundTransparency = 0.45, ZIndex = 5,
	}, {})
	etch.Parent = header


	local equipArea = mk("Frame", {
		Name="EquipArea", LayoutOrder=2,
		Size = UDim2.new(1, 0, 0.29, 0),
		BackgroundTransparency = 1,
	}, {})
	equipArea.Parent = content

	local equipCanvas = mk("Frame", {
		Name="EquipCanvas", Size = UDim2.new(1,0,1,0),
		BackgroundTransparency=1,
	}, {})
	equipCanvas.Parent = equipArea

	local function makeSlot(name, big)
		local f = mk("Frame", {
			Name = name,
			BackgroundColor3 = big and Theme.slotInner or Theme.slotOuter,
			BackgroundTransparency = 0.05, BorderSizePixel = 0,
		}, {})
		uiCorner(f, 10)
		uiStroke(f, 1.5, Theme.gilt, big and 0 or 0.15)
		local inner = mk("Frame", {
			Name="Inner", BackgroundColor3 = Theme.slotInner,
			BackgroundTransparency=0.05, BorderSizePixel=0,
			AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
			Size=UDim2.new(0.92,0,0.92,0),
		}, {})
		uiCorner(inner, 8)
		inner.Parent = f
		return f
	end

	local equipSlotLayout = {
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
	for r=1,3 do
		for c=1,3 do
			local key = ("r%dc%d"):format(r,c)
			local isCross = (r==2 or c==2)
			local s = makeSlot(key, isCross)
			s.Position = equipSlotLayout[key].Position
			s.Size = equipSlotLayout[key].Size
			s.Parent = equipCanvas
		end
	end
	local mountSlot = makeSlot("Mount", true)
	mountSlot.Position = equipSlotLayout.Mount.Position
	mountSlot.Size = equipSlotLayout.Mount.Size
	mountSlot.Parent = equipCanvas


	local function makeChip(name, text)
		local chip = mk("Frame", {
			Name=name, BackgroundTransparency=1, BorderSizePixel=0, ZIndex=8,
		}, {})
		uiCorner(chip, 10)
		mk("ImageLabel", {
			Name="Icon", BackgroundTransparency=1,
			Position = UDim2.new(-0.14, 0, 0.5, 0), Size = UDim2.new(0.3, 0, 0.8, 0),
			AnchorPoint = Vector2.new(0,0.5), Image = "rbxassetid://0",
			ImageColor3 = Theme.gilt, ZIndex=9,
		}, {}).Parent = chip
		mk("TextLabel", {
			Name="Text",
			BackgroundTransparency=1,
			Text=text or "Image Text",
			Font=Enum.Font.GothamMedium,
			TextSize=13,
			TextScaled = true,
			TextColor3=Theme.text,
			TextXAlignment=Enum.TextXAlignment.Left,
			AnchorPoint=Vector2.new(0,0.5),
			Position=UDim2.new(0.23, 0, 0.5, 0),
			Size=UDim2.new(0.72,0,0.8,0),
			ZIndex=9,
			TextStrokeColor3=Theme.textShadow,
			TextStrokeTransparency=0.9,
		}, {}).Parent = chip
		return chip
	end
	local chip1 = makeChip("Coin", "0"); chip1.Size = UDim2.new(0.33,0,0.16,0); chip1.Position = UDim2.new(0.66,0,0.22,0); chip1.Parent = equipCanvas
	local chip2 = makeChip("CharredToken", "0"); chip2.Size = UDim2.new(0.33,0,0.16,0); chip2.Position = UDim2.new(0.66,0,0.42,0); chip2.Parent = equipCanvas


	local barArea = mk("Frame", {
		Name="OvercapArea", LayoutOrder=3,
		Size = UDim2.new(1, 0, 0.09, 0),
		BackgroundTransparency = 1,
	}, {})
	barArea.Parent = content

	local percentLabel = mk("TextLabel", {
		Name="PercentLabel",
		BackgroundTransparency=1,
		Text = tostring(initialPercent) .. "%",
		Font=Enum.Font.GothamBold,
		TextSize=18,
		TextScaled = true,
		TextColor3=Theme.text,
		AnchorPoint=Vector2.new(0.5,1),
		Position = UDim2.new(0.5,0,0.35,0),
		Size=UDim2.new(0.2,0,0.4,0),
		TextStrokeColor3=Theme.textShadow,
		TextStrokeTransparency = 0.88,
	}, {})
	percentLabel.Parent = barArea

	local barOuter = mk("Frame", {
		Name="BarOuter", AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0.40,0),
		Size=UDim2.new(0.98,0,0.45,0), BackgroundColor3=Theme.barOuter,
		BackgroundTransparency=0, BorderSizePixel=0,
	}, {})
	uiCorner(barOuter, 10)
	uiStroke(barOuter, 1.5, Theme.gilt, 0.1)
	barOuter.ClipsDescendants = true
	barOuter.Parent = barArea
	addGradient(barOuter, {
		{p=0.00, c=Theme.barOuterTop},
		{p=1.00, c=Theme.barOuter},
	}, 0)

	local barFill = mk("Frame", {
		Name="Fill", AnchorPoint=Vector2.new(0,0.5),
		Position = UDim2.new(0,0,0.5,0),
		Size = UDim2.new(barScaleForPercent(initialPercent), 0, 1, 0),
		BackgroundColor3 = Theme.emberB, BorderSizePixel = 0,
	}, {})
	uiCorner(barFill, 10)
	barFill.Parent = barOuter
	addGradient(barFill, {
		{p=0.00, c=Theme.emberA},
		{p=0.45, c=Theme.emberB},
		{p=1.00, c=Theme.emberC},
	}, 90)


	for _, pc in ipairs({100,130,170,200,600}) do
		mk("Frame", {
			Name="Tick"..pc, BackgroundColor3=Theme.tick, BackgroundTransparency=0.12, BorderSizePixel=0,
			AnchorPoint=Vector2.new(0.5,0), Size=UDim2.new(0.003,0,1,0),
			Position=UDim2.new(barScaleForPercent(pc),0, 0,0), ZIndex=20,
		}, {}).Parent = barOuter
	end

	local lblSpecs = {
		{name="BarLbl0",   text="0%",   x=0.03, anchorX=0},
		{name="BarLbl100", text="100%", p=100, anchorX=1, dx=-0.010},
		{name="BarLbl130", text="130%", p=130, anchorX=0, dx= 0.010},
		{name="BarLbl170", text="170%", p=170, anchorX=1, dx=-0.010},
		{name="BarLbl200", text="200%", p=200, anchorX=0, dx= 0.010},
		{name="BarLbl600", text="600%", p=600, anchorX=0.5},
		{name="BarLbl800", text="800%", x=0.97, anchorX=1},
	}
	for _, spec in ipairs(lblSpecs) do
		local x = spec.x or barScaleForPercent(spec.p)
		mk("TextLabel", {
			Name = spec.name,
			BackgroundTransparency = 1,
			Text = spec.text,
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextSize = 12,
			TextColor3 = Theme.subtleText,
			AnchorPoint = Vector2.new(spec.anchorX or 0.5, 0),
			Position = UDim2.new(x + (spec.dx or 0), 0, BAR_LABEL_Y, 0),
			Size = BAR_LABEL_SIZE,
			ZIndex = 21,
		}, {}).Parent = barArea
	end


	local storageArea = mk("Frame", {
		Name="StorageArea", LayoutOrder=4,
		Size = UDim2.new(1, 0, 1 - (0.055 + 0.29 + 0.09) - (3*0.01), 0),
		BackgroundTransparency = 1,
	}, {})
	storageArea.Parent = content

	local scroll = mk("ScrollingFrame", {
		Name="StorageScroll",
		Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = true, BackgroundTransparency = 1, ClipsDescendants = true,
	}, {})
	scroll.Parent = storageArea

	local grid = mk("UIGridLayout", {
		Parent = scroll,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		CellPadding = UDim2.new(0.014, 0, 0.014, 0),
		CellSize    = UDim2.new(0.18, 0, 0.18, 0),
		FillDirectionMaxCells = 5,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local function makeInvSlot(i)
		local f = mk("Frame", {
			Name = ("Slot_%02d"):format(i),
			BackgroundColor3 = Theme.slotOuter,
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
		}, {})
		uiCorner(f, 10)
		uiStroke(f, 1.3, Theme.gilt, 0.20)
		local inner = mk("Frame", {
			Name="Inner",
			AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.5,0,0.5,0),
			Size=UDim2.new(0.96,0,0.96,0),
			BackgroundColor3 = Theme.slotInner, BackgroundTransparency = 0.05, BorderSizePixel=0,
		}, {})
		uiCorner(inner, 8)
		inner.Parent = f

		local countWrap = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0) }, {})
		countWrap.Parent = f
		mk("UIPadding", {Parent = countWrap, PaddingRight = UDim.new(0.04, 0), PaddingBottom= UDim.new(0.03, 0)})

		local count = mk("TextLabel", {
			Name="Count",
			BackgroundTransparency=1,
			Text = "",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextScaled = true,
			TextColor3 = Theme.text,
			AnchorPoint = Vector2.new(1,1),
			Position = UDim2.new(1,0, 1,0),
			Size = UDim2.new(0.5,0, 0.25,0),
			TextXAlignment = Enum.TextXAlignment.Right,
		}, {})
		count.Parent = countWrap
		return f
	end
	for i=1,40 do makeInvSlot(i).Parent = scroll end


	for _, d in ipairs(panel:GetDescendants()) do
		if d:IsA("UIStroke") then
			d.Color = Theme.gilt
			d.Transparency = math.min(d.Transparency or 0.2, 0.25)
		end
	end


	local controller = Instance.new("LocalScript")
	controller.Name = "InventoryUIController"
	controller.Parent = gui
	controller.Source = [[local Controller = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Controllers"):WaitForChild("InventoryController"))

Controller.Start(script.Parent)
]]

	return gui
end


function M.Install(opts)
	local starterGui = game:GetService("StarterGui")
	local existing = starterGui:FindFirstChild("InventoryUI")
	if existing then
		if not (opts and opts.force) then
			warn("[InventoryUIInstaller] StarterGui.InventoryUI already exists. Pass {force=true} to overwrite.")
			return existing
		end
		existing:Destroy()
	end
	local gui = buildUI(starterGui, opts)
	print("[InventoryUIInstaller] Installed StarterGui.InventoryUI")
	return gui
end

function M.Rollback()
	local starterGui = game:GetService("StarterGui")
	local existing = starterGui:FindFirstChild("InventoryUI")
	if existing then
		existing:Destroy()
		print("[InventoryUIInstaller] Rolled back (deleted) StarterGui.InventoryUI")
		return true
	end
	warn("[InventoryUIInstaller] Nothing to remove (StarterGui.InventoryUI not found).")
	return false
end

return M
