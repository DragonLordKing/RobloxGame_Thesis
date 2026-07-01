--[[
Name: WorldMapController
Class: LocalScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.StarterGuiTemplates.WorldMapUI.WorldMapController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage, RunService, StarterGui, UserInputService, GuiService
Requires:
  - local WorldConfig = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("WorldRuntime"):WaitForChild("WorldPlaceConfig"))
Functions: setTopbarEnabled, hideCoreGui, restoreCoreGui, hideOtherGuis, restoreOtherGuis, applySafeTopOffset, fitSizeForAspect, resizeCanvas, clearContent, colorForMaterial, newLabel, formatPercent, setPurityInfo, normalizedPlayerPosition, updatePlayerMarker, updatePartyMarkers, renderPartyMarkers, renderExit, mapIconText, renderStructure, renderStructures, normalizedCellMaterial, cellKey, colorForCell, makeMapRect, renderEdgeBands, renderRegions, renderLocal, mapGridBounds, mapPos, drawLine, sideStripe, renderGlobal, currentMapCacheKey, request, open, closeMap, bindCameraResize
Clean source lines: 881
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("WorldRuntime"):WaitForChild("WorldPlaceConfig"))
local remoteEvents = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")
local MapRequest = remoteEvents:WaitForChild("WorldMapRequest")
local PartySnapshotRemote = remoteEvents:WaitForChild("PartySnapshot")

local player = Players.LocalPlayer
local gui = script.Parent

gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local theme = {
	bg = Color3.fromRGB(12, 14, 16),
	panel = Color3.fromRGB(24, 27, 29),
	panel2 = Color3.fromRGB(31, 35, 36),
	stroke = Color3.fromRGB(176, 135, 65),
	text = Color3.fromRGB(241, 233, 214),
	subtle = Color3.fromRGB(186, 178, 158),
	road = Color3.fromRGB(196, 168, 112),
	water = Color3.fromRGB(43, 112, 156),
	blocked = Color3.fromRGB(124, 54, 50),
	exit = Color3.fromRGB(234, 195, 82),
	player = Color3.fromRGB(92, 190, 255),
	mountain = Color3.fromRGB(78, 80, 79),
	desert = Color3.fromRGB(185, 166, 103),
}

local root = Instance.new("Frame")
root.Name = "WorldMapRoot"
root.Visible = false
root.BackgroundColor3 = theme.bg
root.BackgroundTransparency = 0.02
root.BorderSizePixel = 0
root.Size = UDim2.fromScale(1, 1)
root.Active = true
root.ZIndex = 1000
root.Parent = gui

local top = Instance.new("Frame")
top.Name = "TopBar"
top.BackgroundColor3 = Color3.fromRGB(18, 20, 21)
top.BorderSizePixel = 0
top.Position = UDim2.fromOffset(0, 28)
top.Size = UDim2.new(1, 0, 0, 58)
top.ZIndex = 1100
top.Parent = root

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = theme.text
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.new(0, 24, 0, 6)
title.Size = UDim2.new(0, 280, 0, 26)
title.Text = "World Map"
title.ZIndex = 1101
title.Parent = top

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.TextWrapped = false
subtitle.TextColor3 = theme.subtle
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Position = UDim2.new(0, 24, 0, 32)
subtitle.Size = UDim2.new(0, 420, 0, 18)
subtitle.Text = ""
subtitle.ZIndex = 1101
subtitle.Parent = top

local close = Instance.new("TextButton")
close.Name = "CloseButton"
close.BackgroundColor3 = Color3.fromRGB(44, 29, 25)
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.Text = "X"
close.TextColor3 = theme.text
close.TextSize = 18
close.Position = UDim2.new(1, -58, 0, 10)
close.Size = UDim2.fromOffset(38, 38)
close.ZIndex = 1102
close.Parent = top
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = theme.stroke
closeStroke.Transparency = 0.15
closeStroke.Parent = close

local purityButton = Instance.new("TextButton")
purityButton.Name = "PurityButton"
purityButton.AutoButtonColor = true
purityButton.BackgroundColor3 = Color3.fromRGB(35, 37, 36)
purityButton.BorderSizePixel = 0
purityButton.Font = Enum.Font.GothamBold
purityButton.Text = "Purity: none"
purityButton.TextColor3 = theme.text
purityButton.TextSize = 13
purityButton.TextXAlignment = Enum.TextXAlignment.Left
purityButton.Position = UDim2.new(0, 324, 0, 10)
purityButton.Size = UDim2.fromOffset(230, 38)
purityButton.ZIndex = 1102
purityButton.Parent = top
Instance.new("UICorner", purityButton).CornerRadius = UDim.new(0, 6)
local purityPadding = Instance.new("UIPadding")
purityPadding.PaddingLeft = UDim.new(0, 12)
purityPadding.PaddingRight = UDim.new(0, 10)
purityPadding.Parent = purityButton
local purityStroke = Instance.new("UIStroke")
purityStroke.Color = theme.stroke
purityStroke.Transparency = 0.28
purityStroke.Parent = purityButton

local purityTooltip = Instance.new("Frame")
purityTooltip.Name = "PurityTooltip"
purityTooltip.Visible = false
purityTooltip.BackgroundColor3 = Color3.fromRGB(16, 18, 18)
purityTooltip.BorderSizePixel = 0
purityTooltip.Position = UDim2.new(0, 324, 0, 54)
purityTooltip.Size = UDim2.fromOffset(430, 78)
purityTooltip.ZIndex = 1120
purityTooltip.Parent = top
Instance.new("UICorner", purityTooltip).CornerRadius = UDim.new(0, 6)
local tooltipStroke = Instance.new("UIStroke")
tooltipStroke.Color = theme.stroke
tooltipStroke.Transparency = 0.15
tooltipStroke.Parent = purityTooltip
local purityTooltipText = Instance.new("TextLabel")
purityTooltipText.BackgroundTransparency = 1
purityTooltipText.Font = Enum.Font.GothamMedium
purityTooltipText.TextColor3 = theme.text
purityTooltipText.TextSize = 12
purityTooltipText.TextXAlignment = Enum.TextXAlignment.Left
purityTooltipText.TextYAlignment = Enum.TextYAlignment.Top
purityTooltipText.TextWrapped = true
purityTooltipText.Position = UDim2.fromOffset(12, 10)
purityTooltipText.Size = UDim2.new(1, -24, 1, -20)
purityTooltipText.ZIndex = 1121
purityTooltipText.Parent = purityTooltip
purityButton.MouseEnter:Connect(function() purityTooltip.Visible = true end)
purityButton.MouseLeave:Connect(function() purityTooltip.Visible = false end)
purityTooltip.MouseEnter:Connect(function() purityTooltip.Visible = true end)
purityTooltip.MouseLeave:Connect(function() purityTooltip.Visible = false end)

local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.Position = UDim2.new(0, 0, 0, 86)
body.Size = UDim2.new(1, 0, 1, -86)
body.ZIndex = 1000
body.Parent = root

local canvas = Instance.new("Frame")
canvas.Name = "Canvas"
canvas.AnchorPoint = Vector2.new(0.5, 0.5)
canvas.BackgroundColor3 = theme.panel
canvas.BorderSizePixel = 0
canvas.Position = UDim2.fromScale(0.5, 0.5)
canvas.Size = UDim2.fromOffset(720, 720)
canvas.ZIndex = 1002
canvas.Parent = body
Instance.new("UICorner", canvas).CornerRadius = UDim.new(0, 8)
local canvasStroke = Instance.new("UIStroke")
canvasStroke.Color = theme.stroke
canvasStroke.Thickness = 1
canvasStroke.Transparency = 0.12
canvasStroke.Parent = canvas

local canvasAspect = Instance.new("UIAspectRatioConstraint")
canvasAspect.AspectRatio = 1
canvasAspect.AspectType = Enum.AspectType.FitWithinMaxSize
canvasAspect.DominantAxis = Enum.DominantAxis.Width
canvasAspect.Parent = canvas

local canvasSizeConstraint = Instance.new("UISizeConstraint")
canvasSizeConstraint.MinSize = Vector2.new(300, 300)
canvasSizeConstraint.MaxSize = Vector2.new(860, 860)
canvasSizeConstraint.Parent = canvas

local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundColor3 = theme.panel2
content.BackgroundTransparency = 0
content.ClipsDescendants = true
content.Position = UDim2.fromScale(0, 0)
content.Size = UDim2.fromScale(1, 1)
content.ZIndex = 1003
content.Parent = canvas
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 7)

local playerMarker = Instance.new("Frame")
playerMarker.Name = "PlayerMarker"
playerMarker.Visible = false
playerMarker.AnchorPoint = Vector2.new(0.5, 0.5)
playerMarker.BackgroundColor3 = theme.player
playerMarker.BorderSizePixel = 0
playerMarker.Size = UDim2.fromOffset(16, 16)
playerMarker.ZIndex = 1060
playerMarker.Parent = content
Instance.new("UICorner", playerMarker).CornerRadius = UDim.new(1, 0)
local playerStroke = Instance.new("UIStroke")
playerStroke.Color = Color3.new(1, 1, 1)
playerStroke.Thickness = 2
playerStroke.Parent = playerMarker

local activeMode = nil
local activeLocalSnapshot = nil
local renderToken = 0
local activePartySnapshot = { Members = {} }
local partyMarkers = {}
local cachedLocalSnapshots = {}
local renderedLocalCacheKey = nil
local hiddenGuis = {}
local coreGuiStates = {}
local topbarWasEnabled = nil

local function setTopbarEnabled(enabled)
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCore("TopbarEnabled", enabled)
		end)
		if ok then
			return true
		end
		task.wait(0.1)
	end
	return false
end

local function hideCoreGui()
	table.clear(coreGuiStates)
	local okTopbar, topbarEnabled = pcall(function()
		return StarterGui:GetCore("TopbarEnabled")
	end)
	topbarWasEnabled = okTopbar and topbarEnabled or true
	task.spawn(setTopbarEnabled, false)
	for _, coreType in ipairs(Enum.CoreGuiType:GetEnumItems()) do
		if coreType.Name ~= "All" and coreType.Name ~= "ExperienceShop" then
			local ok, enabled = pcall(function()
				return StarterGui:GetCoreGuiEnabled(coreType)
			end)
			if ok then
				coreGuiStates[coreType] = enabled
				pcall(function()
					StarterGui:SetCoreGuiEnabled(coreType, false)
				end)
			end
		end
	end
end

local function restoreCoreGui()
	for coreType, enabled in pairs(coreGuiStates) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreType, enabled)
		end)
	end
	table.clear(coreGuiStates)
	if topbarWasEnabled ~= nil then
		local restoreTopbar = topbarWasEnabled
		topbarWasEnabled = nil
		task.spawn(setTopbarEnabled, restoreTopbar)
	end
end

local function hideOtherGuis()
	table.clear(hiddenGuis)
	hideCoreGui()
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child ~= gui and child.Enabled then
			hiddenGuis[child] = true
			child.Enabled = false
		end
	end
end

local function restoreOtherGuis()
	for screenGui in pairs(hiddenGuis) do
		if screenGui and screenGui.Parent then
			screenGui.Enabled = true
		end
	end
	table.clear(hiddenGuis)
	restoreCoreGui()
end

local function applySafeTopOffset()
	local insetTop = 0
	pcall(function()
		local topInset = GuiService:GetGuiInset()
		insetTop = math.max(28, topInset.Y)
	end)
	top.Position = UDim2.fromOffset(0, insetTop)
	body.Position = UDim2.new(0, 0, 0, insetTop + 58)
	body.Size = UDim2.new(1, 0, 1, -(insetTop + 58))
end

local function fitSizeForAspect(maxW, maxH, aspect)
	aspect = math.max(0.05, tonumber(aspect) or 1)
	local width = maxW
	local height = width / aspect
	if height > maxH then
		height = maxH
		width = height * aspect
	end
	return math.max(1, math.floor(width + 0.5)), math.max(1, math.floor(height + 0.5))
end

local function resizeCanvas(mode, snapshot)
	applySafeTopOffset()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local availableW = math.max(300, viewport.X - 72)
	local availableH = math.max(300, viewport.Y - 146)
	local aspect = 1
	local desiredW = math.min(availableW, 860)
	local desiredH = math.min(availableH, 860)
	if mode == "Global" then
		aspect = 1080 / 650
		desiredW = math.min(availableW, 1080)
		desiredH = math.min(availableH, 650)
	else
		local bounds = snapshot and snapshot.Bounds or {}
		local mapW = math.max(1, tonumber(bounds.Width) or 2048)
		local mapH = math.max(1, tonumber(bounds.Depth) or 2048)
		aspect = math.clamp(mapW / mapH, 0.35, 2.85)
		local longStuds = math.max(mapW, mapH)
		local desiredLong = math.clamp(longStuds * 0.42, 620, 1280)
		local naturalW, naturalH = fitSizeForAspect(desiredLong, desiredLong, aspect)
		desiredW = math.min(availableW, naturalW)
		desiredH = math.min(availableH, naturalH)
	end
	local targetW, targetH = fitSizeForAspect(desiredW, desiredH, aspect)
	canvasAspect.AspectRatio = aspect
	canvasSizeConstraint.MaxSize = Vector2.new(targetW, targetH)
	canvasSizeConstraint.MinSize = Vector2.new(math.min(300, targetW), math.min(300, targetH))
	canvas.Size = UDim2.fromOffset(targetW, targetH)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
end

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if child ~= playerMarker then
			child:Destroy()
		end
	end
	playerMarker.Visible = false
	table.clear(partyMarkers)
	renderedLocalCacheKey = nil
end

local function colorForMaterial(material)
	if material == "Water" then return theme.water end
	return WorldConfig.GetMaterialColor(material)
end

local function newLabel(parent, text, pos, size, textSize, color, z)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = color or theme.text
	label.TextSize = textSize or 12
	label.TextWrapped = true
	label.Position = pos
	label.Size = size
	label.ZIndex = z or 5
	label.Parent = parent
	return label
end

local function formatPercent(value)
	local n = tonumber(value) or 0
	if math.abs(n - math.floor(n)) < 0.05 then
		return string.format("%d%%", math.floor(n + 0.5))
	end
	return string.format("%.1f%%", n)
end

local function setPurityInfo(info)
	if type(info) ~= "table" then
		purityButton.Text = "Purity: none"
		purityTooltipText.Text = "Tier 1-3 maps do not roll purity."
		purityTooltip.Size = UDim2.fromOffset(360, 54)
		return
	end
	purityButton.Text = tostring(info.Summary or "Purity")
	local lines = {}
	for _, tierInfo in ipairs(info.Tiers or {}) do
		local parts = {}
		for _, entry in ipairs(tierInfo.Entries or {}) do
			table.insert(parts, string.format("%s %s", tostring(entry.Name or "None"), formatPercent(entry.Percent)))
		end
		if #parts > 0 then
			table.insert(lines, string.format("Tier %s: %s", tostring(tierInfo.Tier or "?"), table.concat(parts, " | ")))
		end
	end
	if #lines == 0 then
		purityTooltipText.Text = "Tier 1-3 maps do not roll purity."
		purityTooltip.Size = UDim2.fromOffset(360, 54)
	else
		purityTooltipText.Text = table.concat(lines, "\n")
		purityTooltip.Size = UDim2.fromOffset(430, math.max(58, 28 + #lines * 20))
	end
end

local function normalizedPlayerPosition(userId, bounds)
	local targetPlayer = nil
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.UserId == userId then
			targetPlayer = candidate
			break
		end
	end
	local character = targetPlayer and targetPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (bounds and hrp) then return nil end
	return math.clamp((hrp.Position.X - bounds.MinX) / math.max(1, bounds.Width), 0, 1), math.clamp((hrp.Position.Z - bounds.MinZ) / math.max(1, bounds.Depth), 0, 1)
end

local function updatePlayerMarker()
	if activeMode ~= "Local" or not activeLocalSnapshot or not root.Visible then return end
	local x, y = normalizedPlayerPosition(player.UserId, activeLocalSnapshot.Bounds)
	if not (x and y) then
		playerMarker.Visible = false
		return
	end
	playerMarker.Position = UDim2.fromScale(x, y)
	playerMarker.Visible = true
end

local function updatePartyMarkers()
	if activeMode ~= "Local" or not activeLocalSnapshot or not root.Visible then return end
	for userId, marker in pairs(partyMarkers) do
		local x, y = normalizedPlayerPosition(userId, activeLocalSnapshot.Bounds)
		marker.Visible = x ~= nil and y ~= nil
		if x and y then marker.Position = UDim2.fromScale(x, y) end
	end
end

local function renderPartyMarkers()
	for _, old in pairs(partyMarkers) do
		if old and old.Parent then old:Destroy() end
	end
	table.clear(partyMarkers)
	if activeMode ~= "Local" then return end
	for _, member in ipairs(activePartySnapshot.Members or {}) do
		local userId = tonumber(member.UserId)
		if userId and userId ~= player.UserId then
			local marker = Instance.new("Frame")
			marker.Name = "PartyMarker_" .. tostring(userId)
			marker.AnchorPoint = Vector2.new(0.5, 0.5)
			marker.BackgroundColor3 = Color3.fromRGB(61, 218, 232)
			marker.BorderSizePixel = 0
			marker.Size = UDim2.fromOffset(12, 12)
			marker.ZIndex = 1058
			marker.Parent = content
			Instance.new("UICorner", marker).CornerRadius = UDim.new(1, 0)
			local markerStroke = Instance.new("UIStroke")
			markerStroke.Color = Color3.fromRGB(8, 34, 38)
			markerStroke.Thickness = 2
			markerStroke.Parent = marker
			partyMarkers[userId] = marker
		end
	end
	updatePartyMarkers()
end

local function renderExit(exit)
	local dot = Instance.new("Frame")
	dot.Name = "Exit_" .. tostring(exit.Name)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = theme.exit
	dot.BorderSizePixel = 0
	dot.Position = UDim2.fromScale(exit.Position.X, exit.Position.Y)
	dot.Size = UDim2.fromOffset(13, 13)
	dot.ZIndex = 1040
	dot.Parent = content
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 30, 14)
	stroke.Thickness = 2
	stroke.Parent = dot
	local target = exit.TargetMapKey or (exit.TargetPlaceId and ("Place " .. tostring(exit.TargetPlaceId))) or "unassigned"
	local xOffset = exit.Position.X > 0.72 and -154 or 10
	newLabel(content, string.format("%s -> %s", exit.Direction or exit.Name, target), UDim2.new(exit.Position.X, xOffset, exit.Position.Y, -16), UDim2.fromOffset(144, 34), 11, theme.text, 1041)
end

local function mapIconText(icon)
	local text = tostring(icon or "Sword")
	if text == "Sword" then return "⚔" end
	return text
end

local function renderStructure(structure)
	local pos = type(structure) == "table" and structure.Position or nil
	if type(pos) ~= "table" then return end
	local name = tostring(structure.Name or structure.RawName or "Structure")
	local marker = Instance.new("Frame")
	marker.Name = "Structure_" .. name
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.BackgroundColor3 = Color3.fromRGB(42, 32, 24)
	marker.BorderSizePixel = 0
	marker.Position = UDim2.fromScale(math.clamp(tonumber(pos.X) or 0.5, 0, 1), math.clamp(tonumber(pos.Y) or 0.5, 0, 1))
	marker.Size = UDim2.fromOffset(24, 24)
	marker.ZIndex = 1050
	marker.Parent = content
	Instance.new("UICorner", marker).CornerRadius = UDim.new(1, 0)
	local markerStroke = Instance.new("UIStroke")
	markerStroke.Color = Color3.fromRGB(250, 210, 115)
	markerStroke.Thickness = 2
	markerStroke.Transparency = 0.05
	markerStroke.Parent = marker
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBold
	icon.Text = mapIconText(structure.Icon)
	icon.TextColor3 = theme.text
	icon.TextSize = 15
	icon.Size = UDim2.fromScale(1, 1)
	icon.ZIndex = 1051
	icon.Parent = marker
	local labelOffset = (tonumber(pos.X) or 0.5) > 0.76 and -88 or 14
	newLabel(content, name, UDim2.new(marker.Position.X.Scale, labelOffset, marker.Position.Y.Scale, -12), UDim2.fromOffset(78, 28), 10, theme.text, 1051)
end

local function renderStructures(snapshot)
	for _, structure in ipairs(snapshot.Structures or {}) do
		renderStructure(structure)
	end
end

local MOUNTAIN_MATERIALS = {
	Rock = true,
	Slate = true,
	Basalt = true,
	Granite = true,
	Limestone = true,
	Cobblestone = true,
	Concrete = true,
	Pavement = true,
	Asphalt = true,
	CrackedLava = true,
	Snow = true,
}

local DESERT_MATERIALS = {
	Sand = true,
	Sandstone = true,
	Ground = true,
	Mud = true,
	Salt = true,
}

local function normalizedCellMaterial(cell)
	if type(cell) ~= "table" or cell.Void == true or cell.Material == "Void" then return nil end
	local material = tostring(cell.Material or "Grass")
	if cell.Water == true or material == "Water" then return "Water" end
	if cell.Blocked == true or MOUNTAIN_MATERIALS[material] then return "Mountain" end
	if DESERT_MATERIALS[material] then return "Sand" end
	return "Grass"
end

local function cellKey(cell)
	return normalizedCellMaterial(cell)
end

local function colorForCell(cell)
	local material = normalizedCellMaterial(cell)
	if not material then return nil, 1 end
	if material == "Water" then return theme.water, 0 end
	if material == "Sand" then return theme.desert, 0 end
	if material == "Mountain" then return theme.mountain, 0 end
	return colorForMaterial("Grass"), 0
end

local function makeMapRect(name, color, pos, size, z, transparency)
	local rect = Instance.new("Frame")
	rect.Name = name
	rect.BackgroundColor3 = color
	rect.BackgroundTransparency = transparency or 0
	rect.BorderSizePixel = 0
	rect.Position = pos
	rect.Size = size
	rect.ZIndex = z or 1004
	rect.Parent = content
	return rect
end

local function renderEdgeBands(snapshot)
	for _, band in ipairs(snapshot.EdgeBands or {}) do
		local side = tostring(band.Side or "")
		local kind = tostring(band.Kind or "")
		local t = math.clamp(tonumber(band.Thickness) or 0.075, 0.025, 0.25)
		local color = theme.water
		if kind == "Mountain" then
			color = theme.mountain
		elseif kind == "Desert" then
			color = theme.desert
		end
		local transparency = kind == "Mountain" and 0.02 or 0
		if side == "North" then makeMapRect("EdgeNorth", color, UDim2.fromScale(0, 0), UDim2.fromScale(1, t), 1010, transparency) end
		if side == "South" then makeMapRect("EdgeSouth", color, UDim2.fromScale(0, 1 - t), UDim2.fromScale(1, t), 1010, transparency) end
		if side == "West" then makeMapRect("EdgeWest", color, UDim2.fromScale(0, 0), UDim2.fromScale(t, 1), 1010, transparency) end
		if side == "East" then makeMapRect("EdgeEast", color, UDim2.fromScale(1 - t, 0), UDim2.fromScale(t, 1), 1010, transparency) end
	end
end

local function renderRegions(snapshot)
	for _, region in ipairs(snapshot.Regions or {}) do
		local rect = region.Rect
		if type(rect) == "table" then
			local material = region.Material or "Grass"
			local color = material == "Sand" and theme.desert or colorForMaterial(material)
			makeMapRect("Region_" .. tostring(region.Name or material), color, UDim2.fromScale(rect.X or 0, rect.Y or 0), UDim2.fromScale(math.max(0.004, rect.W or 0), math.max(0.004, rect.H or 0)), 1009, 0.04)
		end
	end
end

local function renderLocal(snapshot)
	activeMode = "Local"
	activeLocalSnapshot = snapshot
	resizeCanvas("Local", snapshot)
	title.Text = snapshot.DisplayName or "Local Map"
	local bounds = snapshot.Bounds or {}
	subtitle.Text = string.format("%s | %.1f studs/sample | %dx%d studs", tostring(snapshot.RegionKey or "Region"), tonumber(snapshot.StudsPerSample) or 0, math.floor(tonumber(bounds.Width) or 0), math.floor(tonumber(bounds.Depth) or 0))
	setPurityInfo(snapshot.PurityInfo)
	local cacheKey = tostring(snapshot.CacheKey or snapshot.MapKey or "Local")
	if renderedLocalCacheKey == cacheKey then
		renderPartyMarkers()
		updatePlayerMarker()
		return
	end
	clearContent()
	local samples = snapshot.Samples or {}
	local rows = math.max(1, tonumber(snapshot.SampleRows) or #samples or 1)
	local cols = math.max(1, tonumber(snapshot.SampleCols) or tonumber(snapshot.SampleSize) or 1)
	local token = renderToken + 1
	renderToken = token
	for rowIndex, row in ipairs(samples) do
		local startCol = 1
		while startCol <= #row do
			if renderToken ~= token then return end
			local startCell = row[startCol]
			local key = cellKey(startCell)
			local endCol = startCol
			while endCol + 1 <= #row and cellKey(row[endCol + 1]) == key do
				endCol += 1
			end
			local color, transparency = colorForCell(startCell)
			if color then
				makeMapRect("TileRun", color, UDim2.fromScale((startCol - 1) / cols, (rowIndex - 1) / rows), UDim2.fromScale((endCol - startCol + 1) / cols + 0.001, 1 / rows + 0.001), 1004, transparency)
			end
			startCol = endCol + 1
		end
		if rowIndex % 12 == 0 then task.wait() end
	end
	renderedLocalCacheKey = cacheKey
	renderStructures(snapshot)
	for _, exit in ipairs(snapshot.Exits or {}) do
		renderExit(exit)
	end
	renderPartyMarkers()
	updatePlayerMarker()
end

local function mapGridBounds(maps)
	local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
	for _, map in pairs(maps or {}) do
		local x = tonumber(map.WorldX) or 0
		local y = tonumber(map.WorldY) or 0
		minX = math.min(minX, x); maxX = math.max(maxX, x)
		minY = math.min(minY, y); maxY = math.max(maxY, y)
	end
	if minX == math.huge then minX, maxX, minY, maxY = 0, 0, 0, 0 end
	return minX, maxX, minY, maxY
end

local function mapPos(map, minX, maxX, minY, maxY)
	local rawX = tonumber(map.WorldX) or 0
	local rawY = tonumber(map.WorldY) or 0
	local x = 0.5
	local y = 0.5
	if maxX > minX then
		x = 0.24 + ((rawX - minX) / math.max(1, maxX - minX)) * 0.52
	end
	if maxY > minY then
		y = 0.24 + ((rawY - minY) / math.max(1, maxY - minY)) * 0.52
	end
	return x, y
end

local function drawLine(a, b)
	local ax, ay = a[1], a[2]
	local bx, by = b[1], b[2]
	local dx, dy = bx - ax, by - ay
	local lengthScale = math.sqrt(dx * dx + dy * dy)
	local line = Instance.new("Frame")
	line.Name = "RoadLine"
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = theme.road
	line.BorderSizePixel = 0
	line.Position = UDim2.fromScale((ax + bx) * 0.5, (ay + by) * 0.5)
	line.Size = UDim2.new(lengthScale, 0, 0, 4)
	line.Rotation = math.deg(math.atan2(dy, dx))
	line.ZIndex = 1005
	line.Parent = content
end

local function sideStripe(card, side, color)
	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = color
	stripe.BorderSizePixel = 0
	stripe.ZIndex = 1012
	if side == "North" then stripe.Size = UDim2.new(1, 0, 0, 4); stripe.Position = UDim2.new(0, 0, 0, 0) end
	if side == "South" then stripe.Size = UDim2.new(1, 0, 0, 4); stripe.Position = UDim2.new(0, 0, 1, -4) end
	if side == "West" then stripe.Size = UDim2.new(0, 4, 1, 0); stripe.Position = UDim2.new(0, 0, 0, 0) end
	if side == "East" then stripe.Size = UDim2.new(0, 4, 1, 0); stripe.Position = UDim2.new(1, -4, 0, 0) end
	stripe.Parent = card
end

local function renderGlobal(snapshot)
	clearContent()
	activeMode = "Global"
	activeLocalSnapshot = nil
	title.Text = "Global World Map"
	subtitle.Text = "Places, roads, terrain, coastlines, and regions"
	setPurityInfo(nil)
	local maps = snapshot.Maps or {}
	local minX, maxX, minY, maxY = mapGridBounds(maps)
	local positions = {}
	for key, map in pairs(maps) do
		local x, y = mapPos(map, minX, maxX, minY, maxY)
		positions[key] = { x, y }
	end
	for key, map in pairs(maps) do
		local from = positions[key]
		for _, targetKey in pairs(map.Roads or {}) do
			local to = positions[targetKey]
			if from and to then drawLine(from, to) end
		end
	end
	for key, map in pairs(maps) do
		local pos = positions[key]
		local card = Instance.new("Frame")
		card.Name = "Map_" .. tostring(key)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.BackgroundColor3 = colorForMaterial(map.DominantMaterial or map.Biome)
		card.BorderSizePixel = 0
		card.Position = UDim2.fromScale(pos[1], pos[2])
		card.Size = UDim2.fromOffset(156, 88)
		card.ZIndex = 1010
		card.Parent = content
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
		local stroke = Instance.new("UIStroke")
		stroke.Color = key == snapshot.CurrentMapKey and theme.player or theme.stroke
		stroke.Thickness = key == snapshot.CurrentMapKey and 3 or 1
		stroke.Transparency = 0.05
		stroke.Parent = card
		for side, enabled in pairs(map.Ocean or {}) do if enabled then sideStripe(card, side, theme.water) end end
		for side, enabled in pairs(map.Desert or {}) do if enabled then sideStripe(card, side, theme.desert) end end
		for side, enabled in pairs(map.Mountains or {}) do if enabled then sideStripe(card, side, Color3.fromRGB(86, 86, 88)) end end
		newLabel(card, map.DisplayName or key, UDim2.new(0, 10, 0, 10), UDim2.new(1, -20, 0, 32), 13, theme.text, 1013)
		newLabel(card, string.format("%s | %s", tostring(map.RegionKey or "EU"), tostring(map.Biome or map.DominantMaterial or "Land")), UDim2.new(0, 10, 1, -32), UDim2.new(1, -20, 0, 24), 11, theme.text, 1013)
	end
end

local function currentMapCacheKey()
	local ok, key = pcall(function()
		return WorldConfig.GetCurrentMapKey()
	end)
	if ok and key and tostring(key) ~= "" then
		return tostring(key)
	end
	return tostring(game.PlaceId)
end

local function request(mode)
	if mode ~= "Global" then
		local cached = cachedLocalSnapshots[currentMapCacheKey()]
		if cached then
			renderLocal(cached)
			return
		end
	end
	local ok, snapshot = pcall(function()
		return MapRequest:InvokeServer(mode)
	end)
	if not ok or type(snapshot) ~= "table" then
		clearContent()
		title.Text = "Map unavailable"
		subtitle.Text = tostring(snapshot)
		return
	end
	if mode == "Global" then
		renderGlobal(snapshot)
	else
		cachedLocalSnapshots[currentMapCacheKey()] = snapshot
		if snapshot.MapKey then
			cachedLocalSnapshots[tostring(snapshot.MapKey)] = snapshot
		end
		renderLocal(snapshot)
	end
end

local function open(mode)
	if not root.Visible then
		hideOtherGuis()
	end
	resizeCanvas(mode, activeLocalSnapshot)
	root.Visible = true
	request(mode)
end

local function closeMap()
	root.Visible = false
	activeMode = nil
	activeLocalSnapshot = nil
	playerMarker.Visible = false
	restoreOtherGuis()
end

close.MouseButton1Click:Connect(closeMap)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.N then
		if root.Visible and activeMode == "Local" then closeMap() else open("Local") end
	elseif input.KeyCode == Enum.KeyCode.M then
		if root.Visible and activeMode == "Global" then closeMap() else open("Global") end
	elseif input.KeyCode == Enum.KeyCode.Escape and root.Visible then
		closeMap()
	end
end)

PartySnapshotRemote.OnClientEvent:Connect(function(snapshot)
	activePartySnapshot = type(snapshot) == "table" and snapshot or { Members = {} }
	if root.Visible and activeMode == "Local" then
		renderPartyMarkers()
	end
end)

local cameraResizeConnection = nil
local function bindCameraResize(camera)
	if cameraResizeConnection then
		cameraResizeConnection:Disconnect()
		cameraResizeConnection = nil
	end
	if not camera then return end
	cameraResizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if root.Visible then
			resizeCanvas(activeMode, activeLocalSnapshot)
			updatePlayerMarker()
			updatePartyMarkers()
		end
	end)
end
bindCameraResize(workspace.CurrentCamera)
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCameraResize(workspace.CurrentCamera)
end)

RunService.RenderStepped:Connect(function()
	updatePlayerMarker()
	updatePartyMarkers()
end)
