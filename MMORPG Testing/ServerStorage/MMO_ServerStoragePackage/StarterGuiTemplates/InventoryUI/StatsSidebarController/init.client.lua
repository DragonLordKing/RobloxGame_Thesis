--[[
Name: StatsSidebarController
Class: LocalScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.StarterGuiTemplates.InventoryUI.StatsSidebarController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Functions: layout, comma, ensureRow, setStat, _G.AddStat, _G.SetStat, _G.RemoveStat
Clean source lines: 99
]]
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
