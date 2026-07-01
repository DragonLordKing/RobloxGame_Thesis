--[[
Name: WorldGenMenu
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.WorldGenMenu
Exported from: Generation
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage
Functions: openRoadEditorAfterGenerate, addStructureName, textLabel, makeButton, makeRow, makeSectionHeader, makeDropdown, close, setButtonState, refreshProfileButtons, setText, setStructureDefaults, setCityDefaults, setMainDefaults, numberOrNil, textOrNil, readStructureCounts, readRequest
Signal classes referenced: BindableEvent
Clean source lines: 601
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("WorldGenSystem")
local generateRemote = remotes:WaitForChild("GenerateWorld")
local defaultsRemote = remotes:WaitForChild("GetWorldGenDefaults")

local function openRoadEditorAfterGenerate()
	local roadRoot = ReplicatedStorage:FindFirstChild("RoadSystem") or ReplicatedStorage:WaitForChild("RoadSystem", 2)
	local openEvent = roadRoot and (roadRoot:FindFirstChild("OpenRoadEditorRequested") or roadRoot:WaitForChild("OpenRoadEditorRequested", 2))
	if openEvent and openEvent:IsA("BindableEvent") then
		openEvent:Fire()
	end
end

local defaults = {}
pcall(function()
	defaults = defaultsRemote:InvokeServer() or {}
end)

local selectedProfile = defaults.profile or "City"
local decorationsEnabled = defaults.decorationEnabled ~= false
local busy = false

local structureNames = {}
local structureNameSeen = {}
local function addStructureName(name)
	name = tostring(name or "")
	if name == "" or structureNameSeen[name] then
		return
	end
	structureNameSeen[name] = true
	structureNames[#structureNames + 1] = name
end

if type(defaults.structureTemplates) == "table" then
	for _, name in ipairs(defaults.structureTemplates) do
		addStructureName(name)
	end
end

local structureFolder = ReplicatedStorage:FindFirstChild("Structures")
if structureFolder then
	for _, inst in ipairs(structureFolder:GetChildren()) do
		if inst:IsA("Model") then
			local base = inst:FindFirstChild("Base", true)
			if base and base:IsA("BasePart") then
				addStructureName(inst.Name)
			end
		end
	end
end

table.sort(structureNames)

local gui = Instance.new("ScreenGui")
gui.Name = "WorldGenMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromScale(0.015, 0.105)
panel.Size = UDim2.fromScale(0.245, 0.78)
panel.BackgroundColor3 = Color3.fromRGB(24, 27, 32)
panel.BorderSizePixel = 0
panel.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(78, 86, 96)
stroke.Thickness = 1
stroke.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = panel

local function textLabel(text, height, size)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(235, 239, 245)
	label.TextSize = size or 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	return label
end

local title = textLabel("World Generation", 24, 17)
title.LayoutOrder = 1
title.Parent = panel

local profileRow = Instance.new("Frame")
profileRow.BackgroundTransparency = 1
profileRow.Size = UDim2.new(1, 0, 0, 34)
profileRow.LayoutOrder = 2
profileRow.Parent = panel

local profileLayout = Instance.new("UIListLayout")
profileLayout.FillDirection = Enum.FillDirection.Horizontal
profileLayout.SortOrder = Enum.SortOrder.LayoutOrder
profileLayout.Padding = UDim.new(0, 8)
profileLayout.Parent = profileRow

local function makeButton(text)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.5, -4, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(42, 47, 55)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextColor3 = Color3.fromRGB(238, 241, 246)
	button.TextSize = 13
	button.Text = text
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = button
	return button
end

local cityButton = makeButton("City")
cityButton.LayoutOrder = 1
cityButton.Parent = profileRow

local mainButton = makeButton("Main")
mainButton.LayoutOrder = 2
mainButton.Parent = profileRow

local fieldScroll = Instance.new("ScrollingFrame")
fieldScroll.Name = "Fields"
fieldScroll.LayoutOrder = 3
fieldScroll.Size = UDim2.fromScale(1, 0.58)
fieldScroll.BackgroundColor3 = Color3.fromRGB(20, 23, 28)
fieldScroll.BorderSizePixel = 0
fieldScroll.ScrollBarThickness = 6
fieldScroll.CanvasSize = UDim2.fromOffset(0, 0)
fieldScroll.Parent = panel

local fieldCorner = Instance.new("UICorner")
fieldCorner.CornerRadius = UDim.new(0, 6)
fieldCorner.Parent = fieldScroll

local fieldPadding = Instance.new("UIPadding")
fieldPadding.PaddingTop = UDim.new(0, 8)
fieldPadding.PaddingBottom = UDim.new(0, 8)
fieldPadding.PaddingLeft = UDim.new(0, 8)
fieldPadding.PaddingRight = UDim.new(0, 8)
fieldPadding.Parent = fieldScroll

local fieldLayout = Instance.new("UIListLayout")
fieldLayout.FillDirection = Enum.FillDirection.Vertical
fieldLayout.SortOrder = Enum.SortOrder.LayoutOrder
fieldLayout.Padding = UDim.new(0, 7)
fieldLayout.Parent = fieldScroll

fieldLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	fieldScroll.CanvasSize = UDim2.fromOffset(0, fieldLayout.AbsoluteContentSize.Y + 18)
end)

local inputBoxes = {}
local rowOrder = 0

local function makeRow(labelText, key, value)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -4, 0, 32)
	rowOrder += 1
	row.LayoutOrder = rowOrder
	row.Parent = fieldScroll

	local label = textLabel(labelText, 32, 13)
	label.Size = UDim2.new(0.52, 0, 1, 0)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = row

	local box = Instance.new("TextBox")
	box.AnchorPoint = Vector2.new(1, 0)
	box.Position = UDim2.new(1, 0, 0, 0)
	box.Size = UDim2.new(0.44, 0, 1, 0)
	box.BackgroundColor3 = Color3.fromRGB(33, 38, 45)
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Gotham
	box.TextColor3 = Color3.fromRGB(245, 247, 250)
	box.PlaceholderColor3 = Color3.fromRGB(140, 148, 158)
	box.TextSize = 13
	box.Text = tostring(value or "")
	box.Parent = row

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = box

	inputBoxes[key] = box
	return box
end

local function makeSectionHeader(text)
	local label = textLabel(text, 24, 13)
	label.Size = UDim2.new(1, -4, 0, 24)
	label.TextColor3 = Color3.fromRGB(149, 196, 255)
	rowOrder += 1
	label.LayoutOrder = rowOrder
	label.Parent = fieldScroll
	return label
end

local function makeDropdown(labelText, key, value, options)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.ClipsDescendants = true
	row.Size = UDim2.new(1, -4, 0, 32)
	rowOrder += 1
	row.LayoutOrder = rowOrder
	row.Parent = fieldScroll

	local label = textLabel(labelText, 32, 13)
	label.Size = UDim2.new(0.52, 0, 0, 32)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = row

	local button = makeButton(tostring(value or options[1] or ""))
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, 0, 0, 0)
	button.Size = UDim2.new(0.44, 0, 0, 32)
	button.TextXAlignment = Enum.TextXAlignment.Center
	button.Parent = row

	local menu = Instance.new("Frame")
	menu.BackgroundColor3 = Color3.fromRGB(30, 35, 42)
	menu.BorderSizePixel = 0
	menu.Position = UDim2.new(0.56, 0, 0, 36)
	menu.Size = UDim2.new(0.44, 0, 0, #options * 28)
	menu.Visible = false
	menu.Parent = row

	local menuCorner = Instance.new("UICorner")
	menuCorner.CornerRadius = UDim.new(0, 5)
	menuCorner.Parent = menu

	local menuLayout = Instance.new("UIListLayout")
	menuLayout.FillDirection = Enum.FillDirection.Vertical
	menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
	menuLayout.Parent = menu

	local function close()
		menu.Visible = false
		row.Size = UDim2.new(1, -4, 0, 32)
	end

	for index, option in ipairs(options) do
		local optionButton = makeButton(option)
		optionButton.Size = UDim2.new(1, 0, 0, 28)
		optionButton.LayoutOrder = index
		optionButton.Parent = menu
		optionButton.MouseButton1Click:Connect(function()
			button.Text = option
			close()
		end)
	end

	button.MouseButton1Click:Connect(function()
		menu.Visible = not menu.Visible
		row.Size = menu.Visible and UDim2.new(1, -4, 0, 38 + #options * 28) or UDim2.new(1, -4, 0, 32)
	end)

	inputBoxes[key] = button
	return button
end

local seedBox = makeRow("Seed", "seed", defaults.seed or "")
local biomeBox = makeDropdown("Biome", "biome", defaults.biome or "grass", { "grass", "desert", "snow" })
local scaleBox = makeRow("Scale", "mapScale", string.format("%.3f", defaults.mapScale or 0.643))
local baseHeightBox = makeRow("Base Height", "baseHeight", defaults.baseHeight or 220)
local waterLevelBox = makeRow("Water Level", "waterLevel", defaults.waterLevel or 22)
local plainsBaseReliefBox = makeRow("Main Relief", "plainsBaseRelief", defaults.plainsBaseRelief or 0)
local plainsReliefBox = makeRow("Small Relief", "plainsRelief", defaults.plainsRelief or 0)
local lakeBox = makeRow("Lakes", "lakeCount", defaults.lakeCount or 0)
local lakeMinBox = makeRow("Lake Min", "lakeRadiusMin", defaults.lakeRadiusMin or 45)
local lakeMaxBox = makeRow("Lake Max", "lakeRadiusMax", defaults.lakeRadiusMax or 95)
local lakeDepthBox = makeRow("Lake Depth", "lakeDepth", defaults.lakeDepth or 20)
local lakeWaterDepthBox = makeRow("Lake Water", "lakeWaterDepth", defaults.lakeWaterDepth or 7)
local lakeShapeBox = makeRow("Lake Shape", "lakeShapeNoise", defaults.lakeShapeNoise or 0.34)
local riverBox = makeRow("Rivers", "riverCount", defaults.riverCount or 0)
local riverWidthBox = makeRow("River Width", "riverWidth", defaults.riverWidth or 110)
local riverDepthBox = makeRow("River Depth", "riverDepth", defaults.riverDepth or 10)
local riverWaterBox = makeRow("River Water", "riverWaterDepth", defaults.riverWaterDepth or 7)
local riverWobbleBox = makeRow("River Wobble", "riverWobble", defaults.riverWobble or 70)
local canyonBox = makeRow("Canyons", "canyonCount", defaults.canyonCount or 0)
local canyonWidthBox = makeRow("Canyon Width", "canyonWidth", defaults.canyonWidth or 260)
local canyonDepthBox = makeRow("Canyon Depth", "canyonDepth", defaults.canyonDepth or 700)
local mesaBox = makeRow("Mesas", "mesaCount", defaults.mesaCount or 0)
local mesaMinBox = makeRow("Mesa Min", "mesaRadiusMin", defaults.mesaRadiusMin or 95)
local mesaMaxBox = makeRow("Mesa Max", "mesaRadiusMax", defaults.mesaRadiusMax or 190)
local mesaRiseBox = makeRow("Mesa Rise", "mesaRise", defaults.mesaRise or 95)
makeSectionHeader("Structures")
local structureBox = makeRow("Any Random", "structureCount", defaults.structureCount or 0)
local structureBoxes = {}
for _, structureName in ipairs(structureNames) do
	local defaultCount = 0
	if type(defaults.structureCounts) == "table" then
		defaultCount = defaults.structureCounts[structureName] or 0
	end
	structureBoxes[structureName] = makeRow(structureName, "structure_" .. structureName, defaultCount)
end
makeSectionHeader("Decorations")
local rockBox = makeRow("Rocks", "rockCount", defaults.rockCount or 55)
local treeBox = makeRow("Trees", "treeCount", defaults.treeCount or 70)
local bushBox = makeRow("Bushes", "bushCount", defaults.bushCount or 105)
local miniRockBox = makeRow("Mini Rocks", "miniRockCount", defaults.miniRockCount or 280)
local featureMixBox = makeDropdown("Feature Mix", "featureMix", defaults.featureMix or "both", { "both", "exclusive" })
makeSectionHeader("Borders")
local sideOptions = { "ocean", "mountains", "mountains_heavy", "cliff_grasslands", "desert_abandoned", "none" }
local northSideBox = makeDropdown("North Side", "northSide", defaults.northSide or "ocean", sideOptions)
local southSideBox = makeDropdown("South Side", "southSide", defaults.southSide or "mountains", sideOptions)
local eastSideBox = makeDropdown("East Side", "eastSide", defaults.eastSide or "mountains", sideOptions)
local westSideBox = makeDropdown("West Side", "westSide", defaults.westSide or "desert_abandoned", sideOptions)
local edgeBox = makeRow("Edge Ring", "edgeDecorationWidth", defaults.edgeDecorationWidth or 300)
local monolithHeightBox = makeRow("Monolith H", "cityMonolithHeight", defaults.cityMonolithHeight or 96)
local monolithRadiusBox = makeRow("Monolith R", "cityMonolithRadius", defaults.cityMonolithRadius or 18)

local decorateRow = Instance.new("Frame")
decorateRow.BackgroundTransparency = 1
decorateRow.Size = UDim2.new(1, 0, 0, 34)
decorateRow.LayoutOrder = 30
decorateRow.Parent = panel

local decorateLabel = textLabel("Decorations", 34, 13)
decorateLabel.Size = UDim2.new(0.52, 0, 1, 0)
decorateLabel.Parent = decorateRow

local decorateButton = makeButton("On")
decorateButton.AnchorPoint = Vector2.new(1, 0)
decorateButton.Position = UDim2.new(1, 0, 0, 0)
decorateButton.Size = UDim2.new(0.44, 0, 1, 0)
decorateButton.Parent = decorateRow

local status = textLabel("Choose settings, then generate.", 44, 12)
status.Name = "Status"
status.TextColor3 = Color3.fromRGB(175, 184, 196)
status.TextWrapped = true
status.LayoutOrder = 40
status.Parent = panel

local generateButton = makeButton("Generate")
generateButton.Name = "GenerateButton"
generateButton.Size = UDim2.new(1, 0, 0, 40)
generateButton.LayoutOrder = 50
generateButton.Parent = panel

local function setButtonState(button, active)
	button.BackgroundColor3 = active and Color3.fromRGB(67, 121, 170) or Color3.fromRGB(42, 47, 55)
end

local function refreshProfileButtons()
	setButtonState(cityButton, selectedProfile == "City")
	setButtonState(mainButton, selectedProfile == "Main")
	decorateButton.Text = decorationsEnabled and "On" or "Off"
	setButtonState(decorateButton, decorationsEnabled)
end

local function setText(box, value)
	box.Text = tostring(value or "")
end

local function setStructureDefaults(randomCount, counts)
	setText(structureBox, randomCount or 0)
	counts = counts or {}
	for _, structureName in ipairs(structureNames) do
		local box = structureBoxes[structureName]
		if box then
			setText(box, counts[structureName] or 0)
		end
	end
end

local function setCityDefaults()
	selectedProfile = "City"
	setText(seedBox, defaults.seed or "")
	setText(biomeBox, "grass")
	setText(scaleBox, string.format("%.3f", defaults.mapScale or 0.643))
	setText(baseHeightBox, 220)
	setText(waterLevelBox, 22)
	setText(plainsBaseReliefBox, 0)
	setText(plainsReliefBox, 0)
	setText(lakeBox, 0)
	setText(lakeMinBox, 45)
	setText(lakeMaxBox, 95)
	setText(lakeDepthBox, 20)
	setText(lakeWaterDepthBox, 7)
	setText(lakeShapeBox, 0.34)
	setText(riverBox, 0)
	setText(riverWidthBox, 110)
	setText(riverDepthBox, 10)
	setText(riverWaterBox, 7)
	setText(riverWobbleBox, 70)
	setText(canyonBox, 0)
	setText(canyonWidthBox, 260)
	setText(canyonDepthBox, 700)
	setText(mesaBox, 0)
	setText(mesaMinBox, 95)
	setText(mesaMaxBox, 190)
	setText(mesaRiseBox, 95)
	setStructureDefaults(0)
	setText(rockBox, 55)
	setText(treeBox, 70)
	setText(bushBox, 105)
	setText(miniRockBox, 280)
	setText(featureMixBox, "both")
	setText(northSideBox, "ocean")
	setText(southSideBox, "mountains")
	setText(eastSideBox, "mountains")
	setText(westSideBox, "desert_abandoned")
	setText(edgeBox, defaults.edgeDecorationWidth or 300)
	setText(monolithHeightBox, 96)
	setText(monolithRadiusBox, 18)
	refreshProfileButtons()
end

local function setMainDefaults()
	selectedProfile = "Main"
	setText(seedBox, defaults.seed or "")
	setText(biomeBox, "grass")
	setText(scaleBox, "2.250")
	setText(baseHeightBox, 220)
	setText(waterLevelBox, 22)
	setText(plainsBaseReliefBox, 7)
	setText(plainsReliefBox, 2.5)
	setText(lakeBox, 4)
	setText(lakeMinBox, 100)
	setText(lakeMaxBox, 330)
	setText(lakeDepthBox, 34)
	setText(lakeWaterDepthBox, 10)
	setText(lakeShapeBox, 0.26)
	setText(riverBox, 1)
	setText(riverWidthBox, 110)
	setText(riverDepthBox, 10)
	setText(riverWaterBox, 7)
	setText(riverWobbleBox, 70)
	setText(canyonBox, 1)
	setText(canyonWidthBox, 260)
	setText(canyonDepthBox, 700)
	setText(mesaBox, "")
	setText(mesaMinBox, 95)
	setText(mesaMaxBox, 190)
	setText(mesaRiseBox, 95)
	setStructureDefaults(6)
	setText(rockBox, 170)
	setText(treeBox, 230)
	setText(bushBox, 360)
	setText(miniRockBox, 1800)
	setText(featureMixBox, "both")
	setText(northSideBox, "ocean")
	setText(southSideBox, "mountains")
	setText(eastSideBox, "mountains")
	setText(westSideBox, "desert_abandoned")
	setText(edgeBox, "")
	setText(monolithHeightBox, "")
	setText(monolithRadiusBox, "")
	refreshProfileButtons()
end

cityButton.MouseButton1Click:Connect(setCityDefaults)
mainButton.MouseButton1Click:Connect(setMainDefaults)

decorateButton.MouseButton1Click:Connect(function()
	decorationsEnabled = not decorationsEnabled
	refreshProfileButtons()
end)

local function numberOrNil(text)
	local n = tonumber(text)
	if n == nil then
		return nil
	end
	return n
end

local function textOrNil(text)
	if text == nil or text == "" then
		return nil
	end
	return text
end

local function readStructureCounts()
	local counts = {}
	for _, structureName in ipairs(structureNames) do
		local box = structureBoxes[structureName]
		local count = box and numberOrNil(box.Text) or nil
		if count and count > 0 then
			counts[structureName] = math.floor(count + 0.5)
		end
	end
	return counts
end

local function readRequest()
	local request = {
		profile = selectedProfile,
		seed = numberOrNil(seedBox.Text),
		biome = textOrNil(biomeBox.Text),
		mapScale = numberOrNil(scaleBox.Text),
		baseHeight = numberOrNil(baseHeightBox.Text),
		waterLevel = numberOrNil(waterLevelBox.Text),
		plainsBaseRelief = numberOrNil(plainsBaseReliefBox.Text),
		plainsRelief = numberOrNil(plainsReliefBox.Text),
		lakeCount = numberOrNil(lakeBox.Text),
		lakeRadiusMin = numberOrNil(lakeMinBox.Text),
		lakeRadiusMax = numberOrNil(lakeMaxBox.Text),
		lakeDepth = numberOrNil(lakeDepthBox.Text),
		lakeWaterDepth = numberOrNil(lakeWaterDepthBox.Text),
		lakeShapeNoise = numberOrNil(lakeShapeBox.Text),
		riverCount = numberOrNil(riverBox.Text),
		riverWidth = numberOrNil(riverWidthBox.Text),
		riverDepth = numberOrNil(riverDepthBox.Text),
		riverWaterDepth = numberOrNil(riverWaterBox.Text),
		riverWobble = numberOrNil(riverWobbleBox.Text),
		canyonCount = numberOrNil(canyonBox.Text),
		canyonWidth = numberOrNil(canyonWidthBox.Text),
		canyonDepth = numberOrNil(canyonDepthBox.Text),
		mesaCount = numberOrNil(mesaBox.Text),
		mesaRadiusMin = numberOrNil(mesaMinBox.Text),
		mesaRadiusMax = numberOrNil(mesaMaxBox.Text),
		mesaRise = numberOrNil(mesaRiseBox.Text),
		structureCount = numberOrNil(structureBox.Text),
		structureCounts = readStructureCounts(),
		rockCount = numberOrNil(rockBox.Text),
		treeCount = numberOrNil(treeBox.Text),
		bushCount = numberOrNil(bushBox.Text),
		miniRockCount = numberOrNil(miniRockBox.Text),
		featureMix = textOrNil(featureMixBox.Text),
		northSide = textOrNil(northSideBox.Text),
		southSide = textOrNil(southSideBox.Text),
		eastSide = textOrNil(eastSideBox.Text),
		westSide = textOrNil(westSideBox.Text),
		decorationEnabled = decorationsEnabled,
		resourceSpawnEnabled = false,
	}
	if selectedProfile == "City" then
		request.lakeCount = 0
		request.riverCount = 0
		request.canyonCount = 0
		request.mesaCount = 0
		request.structureCount = 0
		request.structureCounts = {}
		request.edgeDecorationWidth = numberOrNil(edgeBox.Text)
		request.cityMonolithHeight = numberOrNil(monolithHeightBox.Text)
		request.cityMonolithRadius = numberOrNil(monolithRadiusBox.Text)
	end
	return request
end

generateButton.MouseButton1Click:Connect(function()
	if busy then
		return
	end
	busy = true
	generateButton.Text = "Generating..."
	generateButton.AutoButtonColor = false
	status.Text = "Generating terrain. This can take a bit."

	task.spawn(function()
		local ok, response = pcall(function()
			return generateRemote:InvokeServer(readRequest())
		end)

		if ok and response and response.ok then
			status.Text = response.message or "Generated."
			panel.Visible = false
			gui.Enabled = false
			openRoadEditorAfterGenerate()
		elseif ok and response then
			status.Text = response.message or "Generation failed."
		else
			status.Text = tostring(response)
		end

		busy = false
		generateButton.Text = "Generate"
		generateButton.AutoButtonColor = true
	end)
end)

refreshProfileButtons()