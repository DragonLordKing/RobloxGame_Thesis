--[[
Name: ItemDetail2
Class: ModuleScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.ItemDetail2
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, UserInputService, StarterGui
Functions: mk, uiStroke, uiCorner, addGradient, build, section, layoutLeft, beginDrag, onDrag, pct, comma, clearSection, addRow, M.Install, M.Rollback, _G.OpenItemDetail, _G.CloseItemDetail
Clean source lines: 378
]]
local M = {}


local function mk(t, props, kids)
	local o = Instance.new(t)
	for k,v in pairs(props or {}) do o[k] = v end
	for _,c in ipairs(kids or {}) do c.Parent = o end
	return o
end
local function uiStroke(parent, thickness, color, trans)
	return mk("UIStroke", { Parent = parent, Thickness = thickness or 1.5,
		Color = color or Color3.fromRGB(232,176,64), Transparency = trans or 0.18 })
end
local function uiCorner(parent, r) return mk("UICorner", { Parent = parent, CornerRadius = UDim.new(0, r or 12) }) end
local function addGradient(parent, seq, rotation)
	local g = Instance.new("UIGradient"); local ks = {}
	for _,k in ipairs(seq) do table.insert(ks, ColorSequenceKeypoint.new(k.p, k.c)) end
	g.Color = ColorSequence.new(ks); g.Rotation = rotation or 0; g.Parent = parent; return g
end


local Theme = {
	panelBg=Color3.fromRGB(14,10,10), panelBgTop=Color3.fromRGB(28,20,18),
	slotOuter=Color3.fromRGB(26,18,16), slotInner=Color3.fromRGB(38,26,22),
	gilt=Color3.fromRGB(232,176,64), giltDim=Color3.fromRGB(156,116,48),
	text=Color3.fromRGB(242,228,198), subtleText=Color3.fromRGB(210,196,166), textShadow=Color3.fromRGB(8,6,4),
}


local function build(starterGui, opts)
	opts = opts or {}

	local gui = mk("ScreenGui", {
		Name="ItemDetailUI", ResetOnSpawn=false, IgnoreGuiInset=true,
		ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=9999,
	}, {}); gui.Parent = starterGui

	local dim = mk("Frame", { Name="Backdrop", BackgroundColor3=Color3.new(0,0,0),
		BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=0 }, {}); dim.Parent = gui

	local card = mk("Frame", {
		Name="ItemCard", AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.fromScale(0.5,0.5),
		Size=UDim2.new(0.62,0, 0.68,0), BackgroundColor3=Theme.panelBg, BackgroundTransparency=0.15,
		BorderSizePixel=0, ZIndex=10, Visible=false,
	}, {}); card.Parent = gui
	uiCorner(card,14); uiStroke(card,1.6,Theme.gilt,0.18)
	addGradient(card, {{p=0,c=Theme.panelBgTop},{p=1,c=Theme.panelBg}}, 0)

	local header = mk("Frame", {
		Name="Header", BackgroundColor3=Theme.panelBgTop, BackgroundTransparency=0.05,
		Size=UDim2.new(1,0, 0.12,0), ZIndex=12
	}, {}); header.Parent = card
	uiCorner(header,12); uiStroke(header,1.1,Theme.gilt,0.22)
	mk("UIPadding", {PaddingLeft=UDim.new(0.02,0),PaddingRight=UDim.new(0.02,0),PaddingTop=UDim.new(0.25,0)}, {}).Parent = header


	local amt = mk("TextLabel", {
		Name="AmountBadge", BackgroundTransparency=0.1, BackgroundColor3=Theme.slotOuter,
		Text="x0", Font=Enum.Font.GothamBold, TextScaled=true, TextColor3=Theme.text,
		AnchorPoint=Vector2.new(1,0), Position=UDim2.new(0.94,0, 0.02,0), Size=UDim2.new(0.12,0,0.08,0), ZIndex=14
	}, {}); amt.Parent = card
	uiCorner(amt,10); uiStroke(amt,1.2,Theme.gilt,0.18)


	local closeX = mk("TextButton", {
		Name="CloseX", Text="X", Font=Enum.Font.GothamBold, TextScaled=true, TextColor3=Theme.text,
		BackgroundColor3=Theme.slotOuter, BackgroundTransparency=0.05,
		AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1, 12, 0.01, -2), Size=UDim2.new(0.06,0, 0.06,0),
		ZIndex=15
	}, {}); closeX.Parent = card
	uiCorner(closeX,999); uiStroke(closeX,1.2,Theme.gilt,0.18)


	local hdrRow = mk("Frame", {Name="HeaderRow", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0)}, {}); hdrRow.Parent = header
	local quality = mk("TextLabel", {
		Name="QualityLabel", BackgroundTransparency=1, Text="Quality: —", Font=Enum.Font.GothamBold, TextScaled=true,
		TextColor3=Theme.text, TextXAlignment=Enum.TextXAlignment.Left,
		AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0.02,0, 0.40,0), Size=UDim2.new(0.40,0, 0.5,0),
		TextStrokeColor3=Theme.textShadow, TextStrokeTransparency=0.9
	}, {}); quality.Parent = hdrRow
	local enhWrap = mk("Frame", {Name="EnhancementWrap", BackgroundTransparency=1,
		AnchorPoint=Vector2.new(0,0.5), Position=UDim2.new(0.44,0, 0.40,0), Size=UDim2.new(0.22,0, 0.5,0)}, {}); enhWrap.Parent = hdrRow
	mk("TextLabel", {Name="EnhLabel", BackgroundTransparency=1, Text="Enhancement:", Font=Enum.Font.Gotham, TextScaled=true,
		TextColor3=Theme.subtleText, TextXAlignment=Enum.TextXAlignment.Left, AnchorPoint=Vector2.new(0,0.5),
		Position=UDim2.new(0,0,0.5,0), Size=UDim2.new(0.66,0,1,0)}, {}).Parent = enhWrap
	local enhIcon = mk("ImageLabel", {Name="EnhIcon", BackgroundTransparency=1, Image="rbxassetid://0",
		AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.new(0.30,0,0.9,0)}, {}); enhIcon.Parent = enhWrap


	local subHdr = mk("Frame", {
		Name="SubHeader", BackgroundTransparency=1, AnchorPoint=Vector2.new(0.5,0),
		Position=UDim2.new(0.5,0, 0.12,0), Size=UDim2.new(0.96,0, 0.06,0), ZIndex=11
	}, {}); subHdr.Parent = card

	local byLbl = mk("TextLabel", {
		Name="ByLabel", BackgroundTransparency=1, Text="Crafted by: —", Font=Enum.Font.Gotham, TextScaled=true,
		TextColor3=Theme.subtleText, TextXAlignment=Enum.TextXAlignment.Right,
		AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.new(0.48,0,1,0)
	}, {}); byLbl.Parent = subHdr

	local weightLbl = mk("TextLabel", {
		Name="WeightLabel", BackgroundTransparency=1, Text="Weight: 0 (0%)", Font=Enum.Font.Gotham, TextScaled=true,
		TextColor3=Theme.subtleText, TextXAlignment=Enum.TextXAlignment.Right,
		AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(0.50,0,0.5,0), Size=UDim2.new(0.46,0,1,0)
	}, {}); weightLbl.Parent = subHdr


	local body = mk("Frame", {
		Name="Body", BackgroundTransparency=1, AnchorPoint=Vector2.new(0.5,1),
		Position=UDim2.new(0.5,0, 0.90,0), Size=UDim2.new(0.96,0, 0.66,0)
	}, {}); body.Parent = card
	local left  = mk("Frame", {Name="LeftCol",  BackgroundTransparency=1, Size=UDim2.new(0.34,0,1,0)}, {}); left.Parent  = body
	local right = mk("Frame", {Name="RightCol", BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,0,0,0), Size=UDim2.new(0.64,0,1,0)}, {}); right.Parent = body


	local previewWrap = mk("Frame", {
		Name="PreviewWrap", BackgroundColor3=Theme.slotOuter, BackgroundTransparency=0.05, BorderSizePixel=0,
		AnchorPoint=Vector2.new(0,0), Position=UDim2.new(0,0, 0,0), Size=UDim2.new(1,0, 0.30,0), ZIndex=13
	}, {}); previewWrap.Parent = left
	uiCorner(previewWrap,10); uiStroke(previewWrap,1.2,Theme.gilt,0.22)
	local preview = mk("ImageLabel", {Name="ItemImage", BackgroundTransparency=1, Image="rbxassetid://0", Size=UDim2.fromScale(1,1)}, {}); preview.Parent = previewWrap


	local namePower = mk("TextLabel", {
		Name="NamePower", BackgroundTransparency=1, Text="Item Name  |  0", Font=Enum.Font.GothamBold, TextScaled=true,
		TextColor3=Theme.text, TextXAlignment=Enum.TextXAlignment.Left, AnchorPoint=Vector2.new(0,0),
		Position=UDim2.new(0,0, 0.32,0), Size=UDim2.new(1,0, 0.10,0), TextStrokeColor3=Theme.textShadow, TextStrokeTransparency=0.9
	}, {}); namePower.Parent = left


	local descBox = mk("Frame", {
		Name="DescriptionBox", BackgroundColor3=Theme.slotOuter, BackgroundTransparency=0.05, BorderSizePixel=0,
		Size=UDim2.new(1,0, 0.38,0), Position=UDim2.new(0,0, 0.44,0)
	}, {}); descBox.Parent = left
	uiCorner(descBox,10); uiStroke(descBox,1.1,Theme.gilt,0.22)
	local descScroll = mk("ScrollingFrame", {
		Name="DescriptionScroll", BackgroundTransparency=1, CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
		ScrollBarThickness=0, Size=UDim2.fromScale(1,1)
	}, {}); descScroll.Parent = descBox
	local descText = mk("TextLabel", {
		Name="DescriptionText", BackgroundTransparency=1, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left,
		TextYAlignment=Enum.TextYAlignment.Top, Text="—", Font=Enum.Font.Gotham, TextScaled=true, TextColor3=Theme.subtleText,
		Size=UDim2.new(0.96,0, 0,0), AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0, 0,0)
	}, {}); descText.Parent = descScroll


	local slotBox = mk("Frame", {
		Name="SlotValueBox", BackgroundColor3=Theme.slotOuter, BackgroundTransparency=0.05, BorderSizePixel=0,
		Size=UDim2.new(1,0, 0.16,0), Position=UDim2.new(0,0, 0.82,0)
	}, {}); slotBox.Parent = left
	uiCorner(slotBox,10); uiStroke(slotBox,1.1,Theme.gilt,0.22)
	local slotLbl = mk("TextLabel", {Name="SlotLabel", BackgroundTransparency=1, Text="Slot: —", Font=Enum.Font.Gotham, TextScaled=true,
		TextColor3=Theme.text, TextXAlignment=Enum.TextXAlignment.Left, AnchorPoint=Vector2.new(0,0.5),
		Position=UDim2.new(0.04,0, 0.35,0), Size=UDim2.new(0.92,0, 0.4,0)}, {}); slotLbl.Parent = slotBox
	local valLbl  = mk("TextLabel", {Name="ValueLabel", BackgroundTransparency=1, Text="Value: —", Font=Enum.Font.Gotham, TextScaled=true,
		TextColor3=Theme.text, TextXAlignment=Enum.TextXAlignment.Left, AnchorPoint=Vector2.new(0,0.5),
		Position=UDim2.new(0.04,0, 0.75,0), Size=UDim2.new(0.92,0, 0.4,0)}, {}); valLbl.Parent = slotBox


	local rightBox = mk("Frame", {Name="RightSections", BackgroundColor3=Theme.slotOuter, BackgroundTransparency=0.05, BorderSizePixel=0, Size=UDim2.new(1,0,1,0)}, {}); rightBox.Parent = right
	uiCorner(rightBox,10); uiStroke(rightBox,1.1,Theme.gilt,0.22)
	local rPad = mk("UIPadding", {PaddingTop=UDim.new(0.02,0),PaddingBottom=UDim.new(0.02,0),PaddingLeft=UDim.new(0.02,0),PaddingRight=UDim.new(0.02,0)}, {}); rPad.Parent = rightBox
	local rScroll = mk("ScrollingFrame", {Name="SectionScroll", BackgroundTransparency=1, AutomaticCanvasSize=Enum.AutomaticSize.Y,
		CanvasSize=UDim2.new(), ScrollBarThickness=0, Size=UDim2.fromScale(1,1)}, {}); rScroll.Parent = rightBox
	local rList = mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, Padding=UDim.new(0.012,0), SortOrder=Enum.SortOrder.LayoutOrder}, {}); rList.Parent = rScroll

	local function section(name)
		local box = mk("Frame", {Name=name.."Section", BackgroundColor3=Theme.slotInner, BackgroundTransparency=0.05,
			BorderSizePixel=0, Size=UDim2.new(1,0, 0,120), AutomaticSize=Enum.AutomaticSize.Y}, {})
		uiCorner(box,10); uiStroke(box,1,Theme.gilt,0.25)
		mk("TextLabel", {Name="Title", BackgroundTransparency=1, Text=string.upper(name), Font=Enum.Font.GothamBold, TextScaled=true,
			TextColor3=Theme.text, TextXAlignment=Enum.TextXAlignment.Left, AnchorPoint=Vector2.new(0,0),
			Position=UDim2.new(0.02,0,0.02,0), Size=UDim2.new(0.96,0,0.14,0)}, {}).Parent = box
		mk("Frame", {Name="Sep", BackgroundColor3=Theme.giltDim, BackgroundTransparency=0.35, BorderSizePixel=0,
			AnchorPoint=Vector2.new(0.5,0), Position=UDim2.new(0.5,0,0.18,0), Size=UDim2.new(0.96,0,0,1)}, {}).Parent = box
		local listWrap = mk("ScrollingFrame", {Name="List", BackgroundTransparency=1, AutomaticCanvasSize=Enum.AutomaticSize.Y,
			CanvasSize=UDim2.new(), ScrollBarThickness=0, AnchorPoint=Vector2.new(0.5,0),
			Position=UDim2.new(0.5,0,0.20,0), Size=UDim2.new(0.96,0,0.80,0)}, {}); listWrap.Parent = box
		local ul = mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, Padding=UDim.new(0.006,0), SortOrder=Enum.SortOrder.LayoutOrder}, {}); ul.Parent = listWrap
		local row = mk("Frame", {Name="RowTemplate", Visible=false, BackgroundTransparency=1, Size=UDim2.new(1,0,0.10,0), AutomaticSize=Enum.AutomaticSize.Y}, {})
		mk("TextLabel", {Name="Text", BackgroundTransparency=1, Text="—", TextWrapped=true, Font=Enum.Font.Gotham, TextScaled=true,
			TextColor3=Theme.text, TextXAlignment=Enum.TextXAlignment.Left, AnchorPoint=Vector2.new(0,0), Position=UDim2.new(0,0,0,0), Size=UDim2.new(1,0,0,24)}, {}).Parent = row
		mk("Frame", {BackgroundColor3=Theme.giltDim, BackgroundTransparency=0.55, BorderSizePixel=0, AnchorPoint=Vector2.new(0.5,1),
			Position=UDim2.new(0.5,0,1,0), Size=UDim2.new(1,0,0,1)}, {}).Parent = row
		row.Parent = box
		return box
	end

	local statsSec  = section("Stats");     statsSec.Parent  = rScroll
	local abilSec   = section("Abilities"); abilSec.Parent   = rScroll
	local recipeSec = section("Recipe");    recipeSec.Parent = rScroll


	local footer = mk("Frame", {Name="Footer", BackgroundTransparency=1, AnchorPoint=Vector2.new(1,1),
		Position=UDim2.new(0.98,0,0.98,0), Size=UDim2.new(0.30,0,0.06,0), ZIndex=12}, {}); footer.Parent = card
	local equipBtn = mk("TextButton", {Name="EquipButton", Text="EQUIP", Font=Enum.Font.GothamBold, TextScaled=true, TextColor3=Theme.text,
		BackgroundColor3=Theme.slotOuter, BackgroundTransparency=0.05, Size=UDim2.fromScale(1,1)}, {}); equipBtn.Parent = footer
	uiCorner(equipBtn,10); uiStroke(equipBtn,1.2,Theme.gilt,0.18)


	local ctrl = Instance.new("LocalScript")
	ctrl.Name = "ItemDetailController"
	ctrl.Parent = gui
	ctrl.Source = [[
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local gui = script.Parent
local card = gui:WaitForChild("ItemCard")
local dim  = gui:WaitForChild("Backdrop")


local header = card:WaitForChild("Header")
local body = card:WaitForChild("Body")
local left = body:WaitForChild("LeftCol")
local right = body:WaitForChild("RightCol")

local previewWrap = left:WaitForChild("PreviewWrap")
local preview = previewWrap:WaitForChild("ItemImage")
local amt = card:WaitForChild("AmountBadge")
local closeX = card:WaitForChild("CloseX")

local hdrRow = header:WaitForChild("HeaderRow")
local quality = hdrRow:WaitForChild("QualityLabel")
local enhWrap = hdrRow:WaitForChild("EnhancementWrap")
local enhIcon = enhWrap:WaitForChild("EnhIcon")

local subHdr = card:WaitForChild("SubHeader")
local weightLbl = subHdr:WaitForChild("WeightLabel")
local byLbl = subHdr:WaitForChild("ByLabel")

local namePower = left:WaitForChild("NamePower")
local descText = left:WaitForChild("DescriptionBox"):WaitForChild("DescriptionScroll"):WaitForChild("DescriptionText")
local slotLbl = left:WaitForChild("SlotValueBox"):WaitForChild("SlotLabel")
local valLbl  = left:WaitForChild("SlotValueBox"):WaitForChild("ValueLabel")

local rScroll = right:WaitForChild("RightSections"):WaitForChild("SectionScroll")
local statsSec  = rScroll:WaitForChild("StatsSection")
local abilSec   = rScroll:WaitForChild("AbilitiesSection")
local recipeSec = rScroll:WaitForChild("RecipeSection")


local function layoutLeft()
	local ny = namePower.Position.Y.Scale
	local pad = 0.00
	previewWrap.Position = UDim2.new(0,0, 0,0)
	previewWrap.Size = UDim2.new(1,0, math.max(0, ny - pad), 0)
end
layoutLeft()
left:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutLeft)
namePower:GetPropertyChangedSignal("Position"):Connect(layoutLeft)


local dragging=false; local dragStart; local startPos
local function beginDrag(input)
	dragging=true; dragStart=input.Position; startPos=card.Position
	input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
end
local function onDrag(input)
	if not dragging then return end
	local d = input.Position - dragStart
	card.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
end
header.InputBegan:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then beginDrag(input) end
end)
UIS.InputChanged:Connect(function(input)
	if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then onDrag(input) end
end)


closeX.Activated:Connect(function() if _G.CloseItemDetail then _G.CloseItemDetail() end end)
card:WaitForChild("Footer"):WaitForChild("EquipButton").Activated:Connect(function()
	print("[ItemDetail] Equip pressed for:", namePower.Text)
end)


local function pct(n) return math.floor((tonumber(n) or 0)+0.5) end
local function comma(n)
	n = tostring(n)
	local left, num, right = n:match('^([^%d]*%d)(%d*)(.-)$')
	if not num then return n end
	return left .. num:reverse():gsub('(%d%d%d)','%1,'):reverse() .. right
end


_G.OpenItemDetail = function(data)
	card.Visible = true
	dim.BackgroundTransparency = 0.25

	preview.Image = data.imageId and ("rbxassetid://"..tostring(data.imageId)) or "rbxassetid://0"
	amt.Text = "x"..tostring(data.amount or 0)

	quality.Text = "Quality: "..tostring(data.qualityName or "—")
	enhIcon.Image = data.enhancementImageId and ("rbxassetid://"..tostring(data.enhancementImageId)) or "rbxassetid://0"

	weightLbl.Text = string.format("Weight: %s (%d%%)", comma(data.weightTotal or 0), pct(data.weightPercent or 0))
	local byType = data.byType or "Crafted"
	local byName = data.byName or "—"
	byLbl.Text = (byType .. " by: " .. tostring(byName))

	namePower.Text = string.format("%s  |  %s", tostring(data.itemName or "Item"), comma(data.power or 0))
	descText.Text  = tostring(data.description or "—")
	slotLbl.Text   = "Slot: " .. tostring(data.slot or "—")
	valLbl.Text    = "Value: " .. tostring(data.value or "—")

	local function clearSection(sec)
		local list = sec:FindFirstChild("List"); if not list then return end
		for _,child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "RowTemplate" then child:Destroy() end
		end
	end
	local function addRow(sec, txt)
		local list = sec:FindFirstChild("List"); local t = sec:FindFirstChild("RowTemplate"); if not list or not t then return end
		local r = t:Clone(); r.Visible=true; r.Text.Text=tostring(txt); r.Parent=list
	end

	clearSection(statsSec); clearSection(abilSec); clearSection(recipeSec)
	if data.stats and #data.stats>0 then statsSec.Visible=true for _,s in ipairs(data.stats) do addRow(statsSec,s) end else statsSec.Visible=false end
	if data.abilities and #data.abilities>0 then abilSec.Visible=true for _,a in ipairs(data.abilities) do addRow(abilSec,a) end else abilSec.Visible=false end
	if data.recipe and #data.recipe>0 then recipeSec.Visible=true for _,r in ipairs(data.recipe) do addRow(recipeSec,r) end else recipeSec.Visible=false end

	layoutLeft()
end

_G.CloseItemDetail = function()
	card.Visible = false
	dim.BackgroundTransparency = 1
end


task.delay(0.1,function()
	if not card.Visible then
		_G.OpenItemDetail({
			imageId=0, amount=3, qualityName="Pristine", enhancementImageId=0,
			weightTotal=560, weightPercent=79, byType="Crafted", byName=Players.LocalPlayer and Players.LocalPlayer.Name or "—",
			itemName="Sunforged Blade", power=2140,
			description="A blade tempered in phoenix flame. Warm to the touch; thrums with latent power.",
			slot="Weapon / Main Hand", value="—",
			stats={"Damage +120","Crit Rate +8%","Lifesteal +2%"},
			abilities={"Ignite (on hit)","Flare Slash (Q)"},
			recipe={"Phoenix Ember x2","Steel Ingot x8","Leather Wrap x1"},
		})
	end
end)
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
