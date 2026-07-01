--[[
Name: StatsSidebarInstaller
Class: ModuleScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.StatsSidebarInstaller
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: StarterGui
Functions: mk, addGradient, build, layout, comma, ensureRow, setStat, M.Install, M.Rollback, _G.AddStat, _G.SetStat, _G.RemoveStat
Clean source lines: 333
]]
local M = {}


local function mk(t, props, children)
	local inst = Instance.new(t)
	for k, v in pairs(props or {}) do inst[k] = v end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	return inst
end

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


local Theme = {
	panelBg      = Color3.fromRGB(14, 10, 10),
	panelBgTop   = Color3.fromRGB(28, 20, 18),
	text         = Color3.fromRGB(242, 228, 198),
	textShadow   = Color3.fromRGB(8, 6, 4),
	subtleText   = Color3.fromRGB(210, 196, 166),
	gilt         = Color3.fromRGB(232, 176, 64),
	giltDim      = Color3.fromRGB(156, 116, 48),
}


local function build(starterGui, opts)
	opts = opts or {}


	local w = math.clamp(tonumber(opts.statsWidthScale) or 0.07, 0.05, 0.09)
	local overlap = tonumber(opts.overlapScale)
	if overlap == nil then overlap = 0.01 end
	overlap = math.clamp(overlap, -0.05, 0.05)


	local gui = starterGui:FindFirstChild("InventoryUI")
	if not gui or not gui:IsA("ScreenGui") then
		warn("[StatsSidebarInstaller] StarterGui.InventoryUI not found. Install InventoryUI first.")
		return nil
	end

	local invPanel = gui:FindFirstChild("InventoryPanel")
	if not invPanel or not invPanel:IsA("Frame") then
		warn("[StatsSidebarInstaller] InventoryPanel not found under InventoryUI.")
		return nil
	end


	local stats = mk("Frame", {
		Name = "StatsPanel",
		AnchorPoint = Vector2.new(1,0),

		Position = UDim2.new(0, 0, 0, 0),
		Size     = UDim2.new(w, 0, 1, 0),
		Visible  = false,
		BackgroundColor3 = Theme.panelBg,
		BackgroundTransparency = 0.20,
		BorderSizePixel = 0,
		ZIndex = math.max(0, (invPanel.ZIndex or 1) - 1),
	}, {})
	stats.Parent = gui
	stats:SetAttribute("WidthScale", w)
	stats:SetAttribute("OverlapScale", overlap)


	addGradient(stats, {
		{p=0.00, c=Theme.panelBgTop},
		{p=1.00, c=Theme.panelBg},
	}, 0)


	do
		local st = Instance.new("UIStroke")
		st.Thickness = 1.3
		st.Transparency = 0.25
		st.Color = Theme.gilt
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = stats
	end


	local scroll = mk("ScrollingFrame", {
		Name="StatsScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Size = UDim2.fromScale(1,1),
	}, {})
	scroll.Parent = stats

	mk("UIPadding", {
		Parent = scroll,
		PaddingTop    = UDim.new(0.022, 0),
		PaddingBottom = UDim.new(0.022, 0),
		PaddingLeft   = UDim.new(0.038, 0),
		PaddingRight  = UDim.new(0.038, 0),
	})

	local list = mk("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment   = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0.004, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, {})
	list.Parent = scroll


	local template = mk("Frame", {
		Name = "StatTemplate",
		Visible = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.045, 0),
	}, {})


	local nameLbl = mk("TextLabel", {
		Name="NameLabel",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "Stat:",
		TextScaled = true,
		TextColor3 = Theme.subtleText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Theme.textShadow,
		TextStrokeTransparency = 0.9,
		AnchorPoint = Vector2.new(0,0.5),
		Position = UDim2.new(0.00, 0, 0.5, 0),
		Size = UDim2.new(0.62, 0, 1, 0),
	}, {})
	nameLbl.Parent = template


	local valueLbl = mk("TextLabel", {
		Name="ValueLabel",
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "0",
		TextScaled = true,
		TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextStrokeColor3 = Theme.textShadow,
		TextStrokeTransparency = 0.85,
		AnchorPoint = Vector2.new(1,0.5),
		Position = UDim2.new(1.00, 0, 0.5, 0),
		Size = UDim2.new(0.35, 0, 1, 0),
	}, {})
	valueLbl.Parent = template


	local sep = mk("Frame", {
		Name = "Separator",
		BackgroundColor3 = Theme.giltDim,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5,1),
		Position = UDim2.new(0.5,0, 1,0),
		Size = UDim2.new(1, 0, 0, 1),
	}, {})
	sep.Parent = template

	template.Parent = stats


	local ctrl = Instance.new("LocalScript")
	ctrl.Name = "StatsSidebarController"
	ctrl.Parent = gui
	ctrl.Source = [[
local gui = script.Parent
local stats = gui:WaitForChild("StatsPanel")
local inv   = gui:WaitForChild("InventoryPanel")
local scroll= stats:WaitForChild("StatsScroll")
local template = stats:WaitForChild("StatTemplate")


local header    = inv:WaitForChild("Content"):WaitForChild("Header")
local headerRow = header:WaitForChild("HeaderRow")
local arrow     = headerRow:WaitForChild("CloseArrow")
local btn       = arrow:FindFirstChild("ImageButton")
if not btn then
	btn = Instance.new("ImageButton")
	btn.Name = "ImageButton"
	btn.BackgroundTransparency = 1
	btn.Size = UDim2.fromScale(1,1)
	btn.Position = UDim2.fromScale(0,0)
	btn.ZIndex = (arrow.ZIndex or 1) + 1
	btn.Parent = arrow
end

local OPEN_IMG  = "rbxassetid://120091236830415"
local CLOSE_IMG = "rbxassetid://125141241573251"
local showing = false


local function layout()
	local invScale = inv.Size.X.Scale
	local w = stats:GetAttribute("WidthScale") or 0.07
	local overlap = stats:GetAttribute("OverlapScale") or 0.01

	stats.Position = UDim2.new(1 - invScale + overlap, 0, 0, 0)
	stats.Size     = UDim2.new(w, 0, 1, 0)
end
layout()
inv:GetPropertyChangedSignal("Size"):Connect(layout)


arrow.Image = CLOSE_IMG

btn.Activated:Connect(function()
	showing = not showing
	stats.Visible = showing
	arrow.Image = showing and OPEN_IMG or CLOSE_IMG
end)


local function comma(n)
	n = tostring(n)
	local left, num, right = n:match('^([^%d]*%d)(%d*)(.-)$')
	if not num then return n end
	return left .. num:reverse():gsub('(%d%d%d)','%1,'):reverse() .. right
end


local rows = {}

local function ensureRow(name)
	local key = tostring(name)
	if rows[key] and rows[key].Parent then return rows[key] end
	local row = template:Clone()
	row.Name = "Stat_"..key
	row.Visible = true
	row.Parent = scroll
	rows[key] = row
	return row
end

local function setStat(name, value)
	local row = ensureRow(name)
	local nameLbl = row:FindFirstChild("NameLabel")
	local valLbl  = row:FindFirstChild("ValueLabel")
	if nameLbl then
		local labelText = tostring(name)
		if not labelText:match(':$') then labelText = labelText .. ':' end
		nameLbl.Text = labelText
	end
	if valLbl  then
		if tonumber(value) then
			valLbl.Text = comma(value)
		else
			valLbl.Text = tostring(value)
		end
	end
end


_G.AddStat = function(name, value) setStat(name, value) end
_G.SetStat  = function(name, value) setStat(name, value) end
_G.RemoveStat = function(name)
	local key = tostring(name)
	local row = rows[key]
	if row then row:Destroy() rows[key] = nil end
end


if not rows["Health"] then setStat("Health", 1500) end
if not rows["Speed"]  then setStat("Speed", 700)  end
]]

	return stats
end


function M.Install(opts)
	local starterGui = game:GetService("StarterGui")
	local gui = starterGui:FindFirstChild("InventoryUI")
	if not gui then
		warn("[StatsSidebarInstaller] InventoryUI not found. Install your InventoryUI first.")
		return nil
	end


	local prev = gui:FindFirstChild("StatsPanel")
	if prev then
		if not (opts and opts.force) then
			warn("[StatsSidebarInstaller] StatsPanel already exists. Pass {force=true} to overwrite.")
			return prev
		end
		prev:Destroy()
		local oldCtrl = gui:FindFirstChild("StatsSidebarController")
		if oldCtrl then oldCtrl:Destroy() end
	end

	local stats = build(starterGui, opts)
	if stats then
		print("[StatsSidebarInstaller] Installed StatsPanel beside InventoryPanel")
	end
	return stats
end

function M.Rollback()
	local starterGui = game:GetService("StarterGui")
	local gui = starterGui:FindFirstChild("InventoryUI")
	if not gui then
		warn("[StatsSidebarInstaller] Nothing to remove (InventoryUI not found).")
		return false
	end
	local stats = gui:FindFirstChild("StatsPanel")
	local ctrl  = gui:FindFirstChild("StatsSidebarController")
	if stats then stats:Destroy() end
	if ctrl  then ctrl:Destroy()  end
	if stats or ctrl then
		print("[StatsSidebarInstaller] Rolled back StatsPanel")
		return true
	end
	warn("[StatsSidebarInstaller] Nothing to remove (StatsPanel not found).")
	return false
end

return M
