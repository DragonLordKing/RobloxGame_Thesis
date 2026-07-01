--[[
Name: GenerationStudioPlugin
Class: Script
Original path: game.ServerScriptService.GenerationStudioPlugin
Exported from: Generation
Original comments: removed
Children: 2
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ReplicatedStorage, ServerScriptService, RunService, TextService
Requires:
  - HybridWorldGen = require(worldFolder:WaitForChild("HybridWorldGen")),
  - WorldGenConfig = require(worldFolder:WaitForChild("WorldGenConfig")),
  - WorldState = require(roadFolder:WaitForChild("WorldState")),
  - RoadService = require(roadFolder:WaitForChild("RoadService")),
  - RoadDefaults = require(shared:WaitForChild("RoadDefaults")),
Functions: corner, stroke, pad, scaledText, label, button, textBox, refreshModalCanvas, setZIndex, closeModal, showInfoModal, confirmAsync, showReadme, setStatus, getRuntimeFolders, requireSystems, getTemplateRoadDefaults, getDefaultOptions, makeSection, makeInputRow, setInput, setProfileButtons, applyTerrainDefaults, d, numberOrNil, textOrNil, readTerrainRequest, ensureRoadPlan, buildSlotLookup, getEdgeKey, isBlockedKey, applyCellVisual, rebuildRoadGrid, makeRoadSettingRow, refreshRoadInputs, rebuildPlanFromRoadUi, repaintGrid, refreshRoadMask, hasStructureAssets, folderHasTemplates, hasDecorationAssets, confirmGenerationAssets, toCellFloor, toCellCeil, getUndoBounds, captureGenerationUndo, restoreGenerationUndo, undoLastGeneration, generateTerrain, generateRoads, switchTab, initializeRoadUi, modalResolver
Signal classes referenced: BindableEvent
Clean source lines: 1528
]]
if type(plugin) ~= "userdata" then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Terrain = workspace.Terrain

local pluginScript = script
local runtimeTemplate = pluginScript:FindFirstChild("GenerationRuntimeTemplate")

local PLUGIN_WIDGET_ID = "GenerationUnifiedMapTools_v1"
local toolbar = plugin:CreateToolbar("Generation")
local toolbarButton = toolbar:CreateButton("Map Tools", "Open the Generation terrain and road tools", "")
toolbarButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left,
	false,
	false,
	430,
	650,
	360,
	430
)
local widget = plugin:CreateDockWidgetPluginGuiAsync(PLUGIN_WIDGET_ID, widgetInfo)
widget.Title = "Generation Map Tools"

local THEME = {
	bg = Color3.fromRGB(22, 25, 30),
	panel = Color3.fromRGB(29, 34, 41),
	panel2 = Color3.fromRGB(35, 41, 50),
	field = Color3.fromRGB(25, 29, 35),
	line = Color3.fromRGB(75, 86, 100),
	text = Color3.fromRGB(236, 240, 246),
	subtle = Color3.fromRGB(166, 176, 189),
	blue = Color3.fromRGB(71, 126, 184),
	green = Color3.fromRGB(67, 158, 91),
	orange = Color3.fromRGB(222, 139, 43),
	red = Color3.fromRGB(132, 54, 54),
	purple = Color3.fromRGB(88, 86, 145),
}

local systems = nil
local busy = false
local selectedProfile = "City"
local decorationsEnabled = true
local activeTab = "Terrain"

local terrainInputs = {}
local roadInputs = {}
local exitStates = {}
local anchorStates = {}
local blockedCells = {}
local cellHints = {}
local cellButtons = {}
local roadPlan = nil
local roadDefaultsModule = nil
local sideSlotLookup = {}
local lastGenerationUndo = nil

local function corner(parent, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px or 6)
	c.Parent = parent
	return c
end

local function stroke(parent, color)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME.line
	s.Thickness = 1
	s.Parent = parent
	return s
end

local function pad(parent, all)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all)
	p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	p.Parent = parent
	return p
end

local function scaledText(obj, minSize, maxSize)
	obj.TextScaled = true
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = minSize or 10
	c.MaxTextSize = maxSize or 18
	c.Parent = obj
end

local function label(text, sizeY, textColor)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, sizeY or 24)
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = textColor or THEME.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Text = text
	scaledText(l, 10, 16)
	return l
end

local function button(text)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = THEME.panel2
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamMedium
	b.TextColor3 = THEME.text
	b.Text = text
	scaledText(b, 10, 16)
	corner(b, 6)
	return b
end

local function textBox(text)
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = THEME.field
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Gotham
	box.TextColor3 = THEME.text
	box.PlaceholderColor3 = Color3.fromRGB(130, 140, 154)
	box.Text = tostring(text or "")
	scaledText(box, 10, 15)
	corner(box, 5)
	return box
end

local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundColor3 = THEME.bg
root.BorderSizePixel = 0
root.Size = UDim2.fromScale(1, 1)
root.Parent = widget

pad(root, 10)

local rootLayout = Instance.new("UIListLayout")
rootLayout.FillDirection = Enum.FillDirection.Vertical
rootLayout.SortOrder = Enum.SortOrder.LayoutOrder
rootLayout.Padding = UDim.new(0, 8)
rootLayout.Parent = root

local header = Instance.new("Frame")
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 34)
header.LayoutOrder = 1
header.Parent = root

local title = label("Generation Tools", 34)
title.Size = UDim2.new(0.38, 0, 1, 0)
title.Parent = header

local readmeButton = button("Read Me")
readmeButton.Position = UDim2.new(0.40, 0, 0, 0)
readmeButton.Size = UDim2.new(0.22, 0, 1, 0)
readmeButton.Parent = header

local undoButton = button("Undo")
undoButton.Position = UDim2.new(0.64, 0, 0, 0)
undoButton.Size = UDim2.new(0.14, 0, 1, 0)
undoButton.Parent = header

local statusLight = label("Idle", 34, THEME.subtle)
statusLight.AnchorPoint = Vector2.new(1, 0)
statusLight.Position = UDim2.new(1, 0, 0, 0)
statusLight.Size = UDim2.new(0.20, 0, 1, 0)
statusLight.TextXAlignment = Enum.TextXAlignment.Right
statusLight.Parent = header

local tabBar = Instance.new("Frame")
tabBar.BackgroundTransparency = 1
tabBar.Size = UDim2.new(1, 0, 0, 36)
tabBar.LayoutOrder = 2
tabBar.Parent = root

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 8)
tabLayout.Parent = tabBar

local terrainTab = button("Terrain")
terrainTab.Size = UDim2.new(0.5, -4, 1, 0)
terrainTab.LayoutOrder = 1
terrainTab.Parent = tabBar

local roadTab = button("Roads")
roadTab.Size = UDim2.new(0.5, -4, 1, 0)
roadTab.LayoutOrder = 2
roadTab.Parent = tabBar

local pages = Instance.new("Frame")
pages.BackgroundTransparency = 1
pages.Size = UDim2.new(1, 0, 1, -86)
pages.LayoutOrder = 3
pages.Parent = root

local terrainPage = Instance.new("Frame")
terrainPage.BackgroundTransparency = 1
terrainPage.Size = UDim2.fromScale(1, 1)
terrainPage.Parent = pages

local roadPage = Instance.new("Frame")
roadPage.BackgroundTransparency = 1
roadPage.Size = UDim2.fromScale(1, 1)
roadPage.Visible = false
roadPage.Parent = pages

local modalShade = Instance.new("Frame")
modalShade.Name = "ModalShade"
modalShade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
modalShade.BackgroundTransparency = 0.28
modalShade.BorderSizePixel = 0
modalShade.Size = UDim2.fromScale(1, 1)
modalShade.Visible = false
modalShade.ZIndex = 50
modalShade.Parent = widget

local modalPanel = Instance.new("Frame")
modalPanel.BackgroundColor3 = THEME.panel
modalPanel.BorderSizePixel = 0
modalPanel.AnchorPoint = Vector2.new(0.5, 0.5)
modalPanel.Position = UDim2.fromScale(0.5, 0.5)
modalPanel.Size = UDim2.new(0.88, 0, 0.78, 0)
modalPanel.ZIndex = 51
modalPanel.Parent = modalShade
corner(modalPanel, 8)
stroke(modalPanel)
pad(modalPanel, 10)

local modalLayout = Instance.new("UIListLayout")
modalLayout.FillDirection = Enum.FillDirection.Vertical
modalLayout.SortOrder = Enum.SortOrder.LayoutOrder
modalLayout.Padding = UDim.new(0, 8)
modalLayout.Parent = modalPanel

local modalTitle = label("", 32)
modalTitle.LayoutOrder = 1
modalTitle.Parent = modalPanel

local modalScroll = Instance.new("ScrollingFrame")
modalScroll.BackgroundColor3 = THEME.field
modalScroll.BorderSizePixel = 0
modalScroll.ScrollBarThickness = 8
modalScroll.ScrollingDirection = Enum.ScrollingDirection.Y
modalScroll.Active = true
modalScroll.Size = UDim2.new(1, 0, 1, -86)
modalScroll.CanvasSize = UDim2.fromOffset(0, 0)
modalScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
modalScroll.LayoutOrder = 2
modalScroll.Parent = modalPanel
corner(modalScroll, 6)
pad(modalScroll, 8)

local modalBody = Instance.new("TextLabel")
modalBody.BackgroundTransparency = 1
modalBody.Size = UDim2.new(1, -18, 0, 0)
modalBody.AutomaticSize = Enum.AutomaticSize.None
modalBody.Font = Enum.Font.Gotham
modalBody.TextColor3 = THEME.text
modalBody.TextSize = 13
modalBody.TextWrapped = true
modalBody.TextXAlignment = Enum.TextXAlignment.Left
modalBody.TextYAlignment = Enum.TextYAlignment.Top
modalBody.Parent = modalScroll

local function refreshModalCanvas(resetPosition)
	local width = math.max(120, modalScroll.AbsoluteSize.X - 28)
	local textBounds = TextService:GetTextSize(
		modalBody.Text,
		modalBody.TextSize,
		modalBody.Font,
		Vector2.new(width, 100000)
	)
	local height = math.max(math.ceil(textBounds.Y) + 24, modalScroll.AbsoluteSize.Y)
	modalBody.Size = UDim2.new(1, -18, 0, height)
	modalScroll.CanvasSize = UDim2.fromOffset(0, height + 16)
	if resetPosition then
		modalScroll.CanvasPosition = Vector2.new(0, 0)
	end
end

modalScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if modalShade.Visible then
		refreshModalCanvas(false)
	end
end)

local modalButtons = Instance.new("Frame")
modalButtons.BackgroundTransparency = 1
modalButtons.Size = UDim2.new(1, 0, 0, 38)
modalButtons.LayoutOrder = 3
modalButtons.Parent = modalPanel

local modalPrimary = button("Continue")
modalPrimary.BackgroundColor3 = THEME.blue
modalPrimary.AnchorPoint = Vector2.new(1, 0)
modalPrimary.Position = UDim2.new(1, 0, 0, 0)
modalPrimary.Size = UDim2.new(0.34, 0, 1, 0)
modalPrimary.Parent = modalButtons

local modalSecondary = button("Cancel")
modalSecondary.AnchorPoint = Vector2.new(1, 0)
modalSecondary.Position = UDim2.new(0.64, -8, 0, 0)
modalSecondary.Size = UDim2.new(0.30, 0, 1, 0)
modalSecondary.Parent = modalButtons

local function setZIndex(rootObject, zIndex)
	if rootObject:IsA("GuiObject") then
		rootObject.ZIndex = zIndex
	end
	for _, descendant in ipairs(rootObject:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = zIndex
		end
	end
end
setZIndex(modalShade, 50)
setZIndex(modalPanel, 51)

local modalResolver = nil
local function closeModal(result)
	local resolver = modalResolver
	modalResolver = nil
	modalShade.Visible = false
	if resolver then
		resolver(result)
	end
end

modalPrimary.MouseButton1Click:Connect(function()
	closeModal(true)
end)

modalSecondary.MouseButton1Click:Connect(function()
	closeModal(false)
end)

local function showInfoModal(titleText, bodyText)
	modalTitle.Text = titleText
	modalBody.Text = bodyText
	modalPrimary.Text = "Close"
	modalPrimary.BackgroundColor3 = THEME.blue
	modalPrimary.Visible = true
	modalSecondary.Visible = false
	modalResolver = function() end
	modalShade.Visible = true
	refreshModalCanvas(true)
	task.defer(function()
		refreshModalCanvas(false)
	end)
end

local function confirmAsync(titleText, bodyText)
	local event = Instance.new("BindableEvent")
	modalTitle.Text = titleText
	modalBody.Text = bodyText
	modalPrimary.Text = "Continue"
	modalPrimary.BackgroundColor3 = THEME.orange
	modalPrimary.Visible = true
	modalSecondary.Text = "Cancel"
	modalSecondary.Visible = true
	modalResolver = function(result)
		event:Fire(result == true)
	end
	modalShade.Visible = true
	refreshModalCanvas(true)
	task.defer(function()
		refreshModalCanvas(false)
	end)
	local result = event.Event:Wait()
	event:Destroy()
	return result == true
end

local function showReadme()
	local readmeText = "README module missing from the plugin package."
	local readmeModule = pluginScript:FindFirstChild("README")
	if readmeModule and readmeModule:IsA("ModuleScript") then
		local sourceOk, source = pcall(function()
			return readmeModule.Source
		end)
		if sourceOk and type(source) == "string" then
			readmeText = source:match("^return%s*%[%[%s*(.-)%s*%]%]%s*$") or source
		else
			local ok, result = pcall(require, readmeModule)
			readmeText = ok and tostring(result) or tostring(result)
		end
	end
	showInfoModal("Generation Plugin Read Me", readmeText)
end

local terrainScroll = Instance.new("ScrollingFrame")
terrainScroll.BackgroundColor3 = THEME.panel
terrainScroll.BorderSizePixel = 0
terrainScroll.ScrollBarThickness = 6
terrainScroll.Size = UDim2.new(1, 0, 1, -108)
terrainScroll.CanvasSize = UDim2.fromOffset(0, 0)
terrainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
terrainScroll.Parent = terrainPage
corner(terrainScroll, 7)
stroke(terrainScroll)
pad(terrainScroll, 8)

local terrainLayout = Instance.new("UIListLayout")
terrainLayout.FillDirection = Enum.FillDirection.Vertical
terrainLayout.SortOrder = Enum.SortOrder.LayoutOrder
terrainLayout.Padding = UDim.new(0, 7)
terrainLayout.Parent = terrainScroll

local terrainStatus = label("Choose settings, then generate.", 42, THEME.subtle)
terrainStatus.Position = UDim2.new(0, 0, 1, -100)
terrainStatus.Size = UDim2.new(1, 0, 0, 42)
terrainStatus.TextWrapped = true
terrainStatus.Parent = terrainPage

local terrainButtons = Instance.new("Frame")
terrainButtons.BackgroundTransparency = 1
terrainButtons.Position = UDim2.new(0, 0, 1, -50)
terrainButtons.Size = UDim2.new(1, 0, 0, 44)
terrainButtons.Parent = terrainPage

local terrainButtonLayout = Instance.new("UIListLayout")
terrainButtonLayout.FillDirection = Enum.FillDirection.Horizontal
terrainButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder
terrainButtonLayout.Padding = UDim.new(0, 8)
terrainButtonLayout.Parent = terrainButtons

local profileCity = button("City")
profileCity.Size = UDim2.new(0.22, 0, 1, 0)
profileCity.LayoutOrder = 1
profileCity.Parent = terrainButtons

local profileMain = button("Main")
profileMain.Size = UDim2.new(0.22, 0, 1, 0)
profileMain.LayoutOrder = 2
profileMain.Parent = terrainButtons

local decorateToggle = button("Decor: On")
decorateToggle.Size = UDim2.new(0.25, 0, 1, 0)
decorateToggle.LayoutOrder = 3
decorateToggle.Parent = terrainButtons

local generateTerrainButton = button("Generate")
generateTerrainButton.BackgroundColor3 = THEME.blue
generateTerrainButton.Size = UDim2.new(0.31, -24, 1, 0)
generateTerrainButton.LayoutOrder = 4
generateTerrainButton.Parent = terrainButtons

local function setStatus(target, text, color)
	target.Text = text
	target.TextColor3 = color or THEME.subtle
	statusLight.Text = text
	statusLight.TextColor3 = color or THEME.subtle
end

local function getRuntimeFolders()
	if not runtimeTemplate then
		error("GenerationRuntimeTemplate is missing. Re-save the plugin from the prepared GenerationStudioPlugin script.")
	end
	local serverTemplate = runtimeTemplate:WaitForChild("ServerScriptService")
	local replicatedTemplate = runtimeTemplate:WaitForChild("ReplicatedStorage")
	local worldFolder = serverTemplate:WaitForChild("WorldGen")
	local roadFolder = serverTemplate:WaitForChild("RoadSystem")
	local roadRoot = replicatedTemplate:WaitForChild("RoadSystem")
	local shared = roadRoot:WaitForChild("Shared")
	return worldFolder, roadFolder, shared
end

local function requireSystems()
	if systems then
		return systems
	end
	local worldFolder, roadFolder, shared = getRuntimeFolders()
	systems = {
		HybridWorldGen = require(worldFolder:WaitForChild("HybridWorldGen")),
		WorldGenConfig = require(worldFolder:WaitForChild("WorldGenConfig")),
		WorldState = require(roadFolder:WaitForChild("WorldState")),
		RoadService = require(roadFolder:WaitForChild("RoadService")),
		RoadDefaults = require(shared:WaitForChild("RoadDefaults")),
	}
	roadDefaultsModule = systems.RoadDefaults
	if not roadPlan then
		roadPlan = roadDefaultsModule.DeepCopy(roadDefaultsModule.DefaultPlan)
	end
	return systems
end

local function getTemplateRoadDefaults()
	if roadDefaultsModule then
		return roadDefaultsModule
	end
	if not runtimeTemplate then
		return nil
	end
	local replicatedTemplate = runtimeTemplate:FindFirstChild("ReplicatedStorage")
	local roadRoot = replicatedTemplate and replicatedTemplate:FindFirstChild("RoadSystem")
	local shared = roadRoot and roadRoot:FindFirstChild("Shared")
	local defaultsModule = shared and shared:FindFirstChild("RoadDefaults")
	if defaultsModule and defaultsModule:IsA("ModuleScript") then
		local ok, defaults = pcall(require, defaultsModule)
		if ok then
			roadDefaultsModule = defaults
			return defaults
		end
	end
	return nil
end

local fallbackDefaults = {
	seed = "",
	biome = "grass",
	mapScale = 0.643,
	baseHeight = 220,
	waterLevel = 22,
	plainsBaseRelief = 0,
	plainsRelief = 0,
	lakeCount = 0,
	lakeRadiusMin = 45,
	lakeRadiusMax = 95,
	lakeDepth = 20,
	lakeWaterDepth = 7,
	lakeShapeNoise = 0.34,
	riverCount = 0,
	riverWidth = 110,
	riverDepth = 10,
	riverWaterDepth = 7,
	riverWobble = 70,
	canyonCount = 0,
	canyonWidth = 260,
	canyonDepth = 700,
	mesaCount = 0,
	mesaRadiusMin = 95,
	mesaRadiusMax = 190,
	mesaRise = 95,
	structureCount = 0,
	rockCount = 55,
	treeCount = 70,
	bushCount = 105,
	miniRockCount = 280,
	featureMix = "both",
	northSide = "ocean",
	southSide = "mountains",
	eastSide = "mountains",
	westSide = "desert_abandoned",
	edgeDecorationWidth = 340,
	cityMonolithHeight = 96,
	cityMonolithRadius = 18,
}

local function getDefaultOptions()
	local configModule = nil
	if runtimeTemplate then
		local serverTemplate = runtimeTemplate:FindFirstChild("ServerScriptService")
		local templateWorld = serverTemplate and serverTemplate:FindFirstChild("WorldGen")
		configModule = templateWorld and templateWorld:FindFirstChild("WorldGenConfig")
	end
	if configModule and configModule:IsA("ModuleScript") then
		local ok, config = pcall(require, configModule)
		if ok and type(config) == "table" and type(config.GetDefaultOptions) == "function" then
			local defaultsOk, defaults = pcall(config.GetDefaultOptions)
			if defaultsOk and type(defaults) == "table" then
				return defaults
			end
		end
	end
	return fallbackDefaults
end

local terrainFieldSpecs = {
	{ label = "Seed", key = "seed" },
	{ label = "Biome", key = "biome", options = { "grass", "desert", "snow" } },
	{ label = "Scale", key = "mapScale" },
	{ label = "Base Height", key = "baseHeight" },
	{ label = "Water Level", key = "waterLevel" },
	{ label = "Main Relief", key = "plainsBaseRelief" },
	{ label = "Small Relief", key = "plainsRelief" },
	{ section = "Water" },
	{ label = "Lakes", key = "lakeCount" },
	{ label = "Lake Min", key = "lakeRadiusMin" },
	{ label = "Lake Max", key = "lakeRadiusMax" },
	{ label = "Lake Depth", key = "lakeDepth" },
	{ label = "Lake Water", key = "lakeWaterDepth" },
	{ label = "Lake Shape", key = "lakeShapeNoise" },
	{ label = "Rivers", key = "riverCount" },
	{ label = "River Width", key = "riverWidth" },
	{ label = "River Depth", key = "riverDepth" },
	{ label = "River Water", key = "riverWaterDepth" },
	{ label = "River Wobble", key = "riverWobble" },
	{ section = "Large Features" },
	{ label = "Canyons", key = "canyonCount" },
	{ label = "Canyon Width", key = "canyonWidth" },
	{ label = "Canyon Depth", key = "canyonDepth" },
	{ label = "Mesas", key = "mesaCount" },
	{ label = "Mesa Min", key = "mesaRadiusMin" },
	{ label = "Mesa Max", key = "mesaRadiusMax" },
	{ label = "Mesa Rise", key = "mesaRise" },
	{ section = "Structures And Decoration" },
	{ label = "Random Structures", key = "structureCount" },
	{ label = "Rocks", key = "rockCount" },
	{ label = "Trees", key = "treeCount" },
	{ label = "Bushes", key = "bushCount" },
	{ label = "Mini Rocks", key = "miniRockCount" },
	{ label = "Feature Mix", key = "featureMix", options = { "both", "exclusive" } },
	{ section = "Borders And City" },
	{ label = "North Side", key = "northSide", options = { "ocean", "mountains", "mountains_heavy", "cliff_grasslands", "desert_abandoned", "none" } },
	{ label = "South Side", key = "southSide", options = { "ocean", "mountains", "mountains_heavy", "cliff_grasslands", "desert_abandoned", "none" } },
	{ label = "East Side", key = "eastSide", options = { "ocean", "mountains", "mountains_heavy", "cliff_grasslands", "desert_abandoned", "none" } },
	{ label = "West Side", key = "westSide", options = { "ocean", "mountains", "mountains_heavy", "cliff_grasslands", "desert_abandoned", "none" } },
	{ label = "Edge Ring", key = "edgeDecorationWidth" },
	{ label = "Monolith H", key = "cityMonolithHeight" },
	{ label = "Monolith R", key = "cityMonolithRadius" },
}

local function makeSection(text, parent)
	local s = label(text, 24, Color3.fromRGB(151, 197, 255))
	s.Parent = parent
	return s
end

local function makeInputRow(spec, parent)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -4, 0, 34)
	row.Parent = parent

	local name = label(spec.label, 34, THEME.text)
	name.Size = UDim2.new(0.48, 0, 1, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = row

	if spec.options then
		local b = button("")
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, 0, 0, 0)
		b.Size = UDim2.new(0.5, 0, 1, 0)
		b.Parent = row
		b.MouseButton1Click:Connect(function()
			local current = b.Text
			local nextIndex = 1
			for i, option in ipairs(spec.options) do
				if option == current then
					nextIndex = (i % #spec.options) + 1
					break
				end
			end
			b.Text = spec.options[nextIndex]
		end)
		terrainInputs[spec.key] = b
		return b
	end

	local box = textBox("")
	box.AnchorPoint = Vector2.new(1, 0)
	box.Position = UDim2.new(1, 0, 0, 0)
	box.Size = UDim2.new(0.5, 0, 1, 0)
	box.Parent = row
	terrainInputs[spec.key] = box
	return box
end

for _, spec in ipairs(terrainFieldSpecs) do
	if spec.section then
		makeSection(spec.section, terrainScroll)
	else
		makeInputRow(spec, terrainScroll)
	end
end

local function setInput(key, value)
	local input = terrainInputs[key]
	if input then
		input.Text = tostring(value == nil and "" or value)
	end
end

local function setProfileButtons()
	profileCity.BackgroundColor3 = selectedProfile == "City" and THEME.blue or THEME.panel2
	profileMain.BackgroundColor3 = selectedProfile == "Main" and THEME.blue or THEME.panel2
	decorateToggle.Text = decorationsEnabled and "Decor: On" or "Decor: Off"
	decorateToggle.BackgroundColor3 = decorationsEnabled and THEME.green or THEME.panel2
end

local function applyTerrainDefaults(profile)
	selectedProfile = profile
	local defaults = getDefaultOptions()
	local function d(key)
		local v = defaults[key]
		if v == nil then
			v = fallbackDefaults[key]
		end
		return v
	end
	setInput("seed", d("seed"))
	setInput("biome", "grass")
	setInput("baseHeight", 220)
	setInput("waterLevel", 22)
	setInput("riverWidth", 110)
	setInput("riverDepth", 10)
	setInput("riverWaterDepth", 7)
	setInput("riverWobble", 70)
	setInput("canyonWidth", 260)
	setInput("canyonDepth", 700)
	setInput("mesaRadiusMin", 95)
	setInput("mesaRadiusMax", 190)
	setInput("mesaRise", 95)
	setInput("featureMix", "both")
	setInput("northSide", "ocean")
	setInput("southSide", "mountains")
	setInput("eastSide", "mountains")
	setInput("westSide", "desert_abandoned")
	if profile == "City" then
		setInput("mapScale", string.format("%.3f", d("mapScale") or 0.643))
		setInput("plainsBaseRelief", 0)
		setInput("plainsRelief", 0)
		setInput("lakeCount", 0)
		setInput("lakeRadiusMin", 45)
		setInput("lakeRadiusMax", 95)
		setInput("lakeDepth", 20)
		setInput("lakeWaterDepth", 7)
		setInput("lakeShapeNoise", 0.34)
		setInput("riverCount", 0)
		setInput("canyonCount", 0)
		setInput("mesaCount", 0)
		setInput("structureCount", 0)
		setInput("rockCount", 55)
		setInput("treeCount", 70)
		setInput("bushCount", 105)
		setInput("miniRockCount", 280)
		setInput("edgeDecorationWidth", d("edgeDecorationWidth") or 340)
		setInput("cityMonolithHeight", 96)
		setInput("cityMonolithRadius", 18)
	else
		setInput("mapScale", "2.250")
		setInput("plainsBaseRelief", 7)
		setInput("plainsRelief", 2.5)
		setInput("lakeCount", 4)
		setInput("lakeRadiusMin", 100)
		setInput("lakeRadiusMax", 330)
		setInput("lakeDepth", 34)
		setInput("lakeWaterDepth", 10)
		setInput("lakeShapeNoise", 0.26)
		setInput("riverCount", 1)
		setInput("canyonCount", 1)
		setInput("mesaCount", "")
		setInput("structureCount", 6)
		setInput("rockCount", 170)
		setInput("treeCount", 230)
		setInput("bushCount", 360)
		setInput("miniRockCount", 1800)
		setInput("edgeDecorationWidth", "")
		setInput("cityMonolithHeight", "")
		setInput("cityMonolithRadius", "")
	end
	setProfileButtons()
end

local function numberOrNil(value)
	local n = tonumber(value)
	return n
end

local function textOrNil(value)
	if value == nil or value == "" then
		return nil
	end
	return tostring(value)
end

local function readTerrainRequest()
	local request = {
		profile = selectedProfile,
		seed = numberOrNil(terrainInputs.seed.Text),
		biome = textOrNil(terrainInputs.biome.Text),
		mapScale = numberOrNil(terrainInputs.mapScale.Text),
		baseHeight = numberOrNil(terrainInputs.baseHeight.Text),
		waterLevel = numberOrNil(terrainInputs.waterLevel.Text),
		plainsBaseRelief = numberOrNil(terrainInputs.plainsBaseRelief.Text),
		plainsRelief = numberOrNil(terrainInputs.plainsRelief.Text),
		lakeCount = numberOrNil(terrainInputs.lakeCount.Text),
		lakeRadiusMin = numberOrNil(terrainInputs.lakeRadiusMin.Text),
		lakeRadiusMax = numberOrNil(terrainInputs.lakeRadiusMax.Text),
		lakeDepth = numberOrNil(terrainInputs.lakeDepth.Text),
		lakeWaterDepth = numberOrNil(terrainInputs.lakeWaterDepth.Text),
		lakeShapeNoise = numberOrNil(terrainInputs.lakeShapeNoise.Text),
		riverCount = numberOrNil(terrainInputs.riverCount.Text),
		riverWidth = numberOrNil(terrainInputs.riverWidth.Text),
		riverDepth = numberOrNil(terrainInputs.riverDepth.Text),
		riverWaterDepth = numberOrNil(terrainInputs.riverWaterDepth.Text),
		riverWobble = numberOrNil(terrainInputs.riverWobble.Text),
		canyonCount = numberOrNil(terrainInputs.canyonCount.Text),
		canyonWidth = numberOrNil(terrainInputs.canyonWidth.Text),
		canyonDepth = numberOrNil(terrainInputs.canyonDepth.Text),
		mesaCount = numberOrNil(terrainInputs.mesaCount.Text),
		mesaRadiusMin = numberOrNil(terrainInputs.mesaRadiusMin.Text),
		mesaRadiusMax = numberOrNil(terrainInputs.mesaRadiusMax.Text),
		mesaRise = numberOrNil(terrainInputs.mesaRise.Text),
		structureCount = numberOrNil(terrainInputs.structureCount.Text),
		structureCounts = {},
		rockCount = numberOrNil(terrainInputs.rockCount.Text),
		treeCount = numberOrNil(terrainInputs.treeCount.Text),
		bushCount = numberOrNil(terrainInputs.bushCount.Text),
		miniRockCount = numberOrNil(terrainInputs.miniRockCount.Text),
		featureMix = textOrNil(terrainInputs.featureMix.Text),
		northSide = textOrNil(terrainInputs.northSide.Text),
		southSide = textOrNil(terrainInputs.southSide.Text),
		eastSide = textOrNil(terrainInputs.eastSide.Text),
		westSide = textOrNil(terrainInputs.westSide.Text),
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
		request.edgeDecorationWidth = numberOrNil(terrainInputs.edgeDecorationWidth.Text)
		request.cityMonolithHeight = numberOrNil(terrainInputs.cityMonolithHeight.Text)
		request.cityMonolithRadius = numberOrNil(terrainInputs.cityMonolithRadius.Text)
	end
	return request
end

local roadContent = Instance.new("Frame")
roadContent.BackgroundTransparency = 1
roadContent.Size = UDim2.new(1, 0, 1, -100)
roadContent.Parent = roadPage

local gridFrame = Instance.new("Frame")
gridFrame.BackgroundColor3 = THEME.panel
gridFrame.BorderSizePixel = 0
gridFrame.Size = UDim2.new(0.60, -4, 0.68, 0)
gridFrame.Position = UDim2.new(0, 0, 0, 0)
gridFrame.Parent = roadContent
corner(gridFrame, 7)
stroke(gridFrame)
pad(gridFrame, 8)

local gridAspect = Instance.new("UIAspectRatioConstraint")
gridAspect.AspectRatio = 1
gridAspect.Parent = gridFrame

local roadSettings = Instance.new("ScrollingFrame")
roadSettings.BackgroundColor3 = THEME.panel
roadSettings.BorderSizePixel = 0
roadSettings.ScrollBarThickness = 6
roadSettings.Size = UDim2.new(0.40, -4, 0.76, 0)
roadSettings.Position = UDim2.new(0.60, 8, 0, 0)
roadSettings.CanvasSize = UDim2.fromOffset(0, 0)
roadSettings.AutomaticCanvasSize = Enum.AutomaticSize.Y
roadSettings.Parent = roadContent
corner(roadSettings, 7)
stroke(roadSettings)
pad(roadSettings, 8)

local roadLayout = Instance.new("UIListLayout")
roadLayout.FillDirection = Enum.FillDirection.Vertical
roadLayout.SortOrder = Enum.SortOrder.LayoutOrder
roadLayout.Padding = UDim.new(0, 7)
roadLayout.Parent = roadSettings

local roadStatus = label("Generate terrain first, then configure roads.", 46, THEME.subtle)
roadStatus.Position = UDim2.new(0, 0, 1, -96)
roadStatus.Size = UDim2.new(1, 0, 0, 46)
roadStatus.TextWrapped = true
roadStatus.Parent = roadPage

local roadButtons = Instance.new("Frame")
roadButtons.BackgroundTransparency = 1
roadButtons.Position = UDim2.new(0, 0, 1, -44)
roadButtons.Size = UDim2.new(1, 0, 0, 42)
roadButtons.Parent = roadPage

local roadButtonLayout = Instance.new("UIListLayout")
roadButtonLayout.FillDirection = Enum.FillDirection.Horizontal
roadButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder
roadButtonLayout.Padding = UDim.new(0, 8)
roadButtonLayout.Parent = roadButtons

local clearRoadButton = button("Clear")
clearRoadButton.Size = UDim2.new(0.2, 0, 1, 0)
clearRoadButton.Parent = roadButtons

local refreshRoadButton = button("Refresh")
refreshRoadButton.Size = UDim2.new(0.24, 0, 1, 0)
refreshRoadButton.Parent = roadButtons

local generateRoadButton = button("Generate Roads")
generateRoadButton.BackgroundColor3 = THEME.blue
generateRoadButton.Size = UDim2.new(0.56, -16, 1, 0)
generateRoadButton.Parent = roadButtons

local editableRoadSettings = {
	"pathCellSize",
	"roadWidth",
	"roadThickness",
	"roadLift",
	"roadShoulder",
	"exitStraightLength",
	"outOfMapDistance",
	"wiggleAmplitude",
	"wiggleScale",
	"maxSlope",
	"reuseBonus",
	"bridgeDeckLift",
	"bridgeExtraWidth",
	"bridgePostGap",
	"portLength",
	"portWidth",
	"portDeckLift",
	"tunnelRadius",
	"tunnelDepth",
	"tunnelLip",
}

local function ensureRoadPlan()
	if roadPlan then
		return roadPlan
	end
	local defaults = (systems and systems.RoadDefaults) or getTemplateRoadDefaults()
	if defaults then
		local ok = pcall(function()
			roadPlan = defaults.DeepCopy(defaults.DefaultPlan)
		end)
		if ok and roadPlan then
			return roadPlan
		end
	end
	roadPlan = { mapGridSize = 9, edgeSlotsPerSide = 4, exits = {}, anchors = {}, settings = {} }
	return roadPlan
end

local function buildSlotLookup(gridSize, slotCount)
	local lookup = {}
	for i = 1, slotCount do
		local pos = math.floor(((i - 0.5) / slotCount) * (gridSize - 1) + 1.5)
		lookup[pos] = i
	end
	return lookup
end

local function getEdgeKey(gx, gz)
	local plan = ensureRoadPlan()
	if gz == 1 and sideSlotLookup[gx] then
		return "N:" .. tostring(sideSlotLookup[gx]), "N", sideSlotLookup[gx]
	end
	if gz == plan.mapGridSize and sideSlotLookup[gx] then
		return "S:" .. tostring(sideSlotLookup[gx]), "S", sideSlotLookup[gx]
	end
	if gx == 1 and sideSlotLookup[gz] then
		return "W:" .. tostring(sideSlotLookup[gz]), "W", sideSlotLookup[gz]
	end
	if gx == plan.mapGridSize and sideSlotLookup[gz] then
		return "E:" .. tostring(sideSlotLookup[gz]), "E", sideSlotLookup[gz]
	end
	return nil
end

local gridLayout = Instance.new("UIGridLayout")
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local function isBlockedKey(key)
	return blockedCells[key] == true
end

local function applyCellVisual(cell, gx, gz)
	local edgeKey = getEdgeKey(gx, gz)
	local key = edgeKey or (tostring(gx) .. ":" .. tostring(gz))
	local blocked = isBlockedKey(key)
	cell.Active = not blocked
	cell.AutoButtonColor = not blocked
	if blocked then
		cell.BackgroundColor3 = THEME.red
		cell.TextColor3 = Color3.fromRGB(210, 150, 150)
		cell.Text = "X"
		return
	end
	cell.TextColor3 = THEME.text
	if edgeKey then
		local state = exitStates[edgeKey]
		if state == "road" then
			cell.BackgroundColor3 = THEME.green
			cell.Text = edgeKey
		elseif state == "tunnel" then
			cell.BackgroundColor3 = THEME.orange
			cell.Text = edgeKey
		elseif cellHints[edgeKey] then
			cell.BackgroundColor3 = THEME.purple
			cell.Text = edgeKey
		else
			cell.BackgroundColor3 = Color3.fromRGB(76, 82, 91)
			cell.Text = edgeKey
		end
	else
		if anchorStates[key] then
			cell.BackgroundColor3 = THEME.blue
		elseif cellHints[key] then
			cell.BackgroundColor3 = THEME.purple
		else
			cell.BackgroundColor3 = Color3.fromRGB(48, 54, 62)
		end
		cell.Text = tostring(gx) .. "," .. tostring(gz)
	end
end

local function rebuildRoadGrid()
	local plan = ensureRoadPlan()
	sideSlotLookup = buildSlotLookup(plan.mapGridSize, plan.edgeSlotsPerSide)
	for _, child in ipairs(gridFrame:GetChildren()) do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	table.clear(cellButtons)
	local gap = 0.006
	local cellScale = (1 - gap * (plan.mapGridSize - 1)) / plan.mapGridSize
	gridLayout.CellSize = UDim2.new(cellScale, 0, cellScale, 0)
	gridLayout.CellPadding = UDim2.new(gap, 0, gap, 0)
	gridLayout.FillDirectionMaxCells = plan.mapGridSize
	for gz = 1, plan.mapGridSize do
		for gx = 1, plan.mapGridSize do
			local cell = button("")
			cell.Name = "Cell_" .. tostring(gx) .. "_" .. tostring(gz)
			cell.LayoutOrder = (gz - 1) * plan.mapGridSize + gx
			cell.Parent = gridFrame
			scaledText(cell, 7, 14)
			cellButtons[gx .. ":" .. gz] = cell
			cell.MouseButton1Click:Connect(function()
				local edgeKey = getEdgeKey(gx, gz)
				local blockedKey = edgeKey or (tostring(gx) .. ":" .. tostring(gz))
				if isBlockedKey(blockedKey) then
					setStatus(roadStatus, "That slot is obstructed.", THEME.red)
					return
				end
				if edgeKey then
					local current = exitStates[edgeKey]
					if current == nil then
						exitStates[edgeKey] = "road"
					elseif current == "road" then
						exitStates[edgeKey] = "tunnel"
					else
						exitStates[edgeKey] = nil
					end
				else
					local key = tostring(gx) .. ":" .. tostring(gz)
					anchorStates[key] = not anchorStates[key] or nil
				end
				applyCellVisual(cell, gx, gz)
			end)
			applyCellVisual(cell, gx, gz)
		end
	end
end

local function makeRoadSettingRow(key)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -4, 0, 32)
	row.Parent = roadSettings

	local l = label(key, 32)
	l.Size = UDim2.new(0.56, 0, 1, 0)
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = row

	local input = textBox("")
	input.AnchorPoint = Vector2.new(1, 0)
	input.Position = UDim2.new(1, 0, 0, 0)
	input.Size = UDim2.new(0.42, 0, 1, 0)
	input.Parent = row
	roadInputs[key] = input
	return input
end

for _, key in ipairs(editableRoadSettings) do
	makeRoadSettingRow(key)
end

local function refreshRoadInputs()
	local plan = ensureRoadPlan()
	for _, key in ipairs(editableRoadSettings) do
		if roadInputs[key] then
			roadInputs[key].Text = tostring(plan.settings[key] or "")
		end
	end
end

local function rebuildPlanFromRoadUi()
	local plan = ensureRoadPlan()
	plan.exits = {}
	plan.anchors = {}
	for key, mode in pairs(exitStates) do
		if mode and not blockedCells[key] then
			local side, slot = string.match(key, "^(%u):(%d+)$")
			plan.exits[#plan.exits + 1] = { side = side, slot = tonumber(slot), mode = mode }
		end
	end
	for key, state in pairs(anchorStates) do
		if state and not blockedCells[key] then
			local gx, gz = string.match(key, "^(%d+):(%d+)$")
			plan.anchors[#plan.anchors + 1] = { gx = tonumber(gx), gz = tonumber(gz) }
		end
	end
	for key, input in pairs(roadInputs) do
		local n = tonumber(input.Text)
		if n ~= nil then
			plan.settings[key] = n
		end
	end
	return plan
end

local function repaintGrid()
	local plan = ensureRoadPlan()
	for gz = 1, plan.mapGridSize do
		for gx = 1, plan.mapGridSize do
			local cell = cellButtons[gx .. ":" .. gz]
			if cell then
				applyCellVisual(cell, gx, gz)
			end
		end
	end
end

local function refreshRoadMask()
	if busy then
		return
	end
	local ok, serviceOk, mask = pcall(function()
		return requireSystems().RoadService.GetEditorMask(rebuildPlanFromRoadUi())
	end)
	if not ok then
		setStatus(roadStatus, tostring(serviceOk), THEME.red)
		return
	end
	if not serviceOk then
		setStatus(roadStatus, tostring(mask), THEME.red)
		return
	end
	table.clear(blockedCells)
	table.clear(cellHints)
	for key, value in pairs(mask.blocked or {}) do
		if value then
			blockedCells[key] = true
			exitStates[key] = nil
			anchorStates[key] = nil
		end
	end
	for key in pairs(mask.resolved or {}) do
		cellHints[key] = true
	end
	repaintGrid()
	local blockedCount = 0
	for _ in pairs(blockedCells) do
		blockedCount += 1
	end
	setStatus(roadStatus, "Grid ready. Blocked: " .. tostring(blockedCount), THEME.subtle)
end

local function hasStructureAssets()
	local folder = ReplicatedStorage:FindFirstChild("Structures")
	if not folder then
		return false
	end
	for _, inst in ipairs(folder:GetChildren()) do
		if inst.Name ~= "Monolith" and inst:IsA("Model") then
			local base = inst:FindFirstChild("Base", true)
			if base and base:IsA("BasePart") then
				return true
			end
		end
	end
	if selectedProfile == "City" then
		local monolith = folder:FindFirstChild("Monolith")
		if monolith then
			for _, inst in ipairs(monolith:GetChildren()) do
				if inst:IsA("Model") or inst:IsA("BasePart") then
					return true
				end
			end
		end
	end
	return false
end

local function folderHasTemplates(folder)
	if not folder then
		return false
	end
	for _, inst in ipairs(folder:GetDescendants()) do
		if inst:IsA("Model") or inst:IsA("BasePart") then
			return true
		end
	end
	return false
end

local function hasDecorationAssets()
	if not decorationsEnabled then
		return true
	end
	local rootFolder = ReplicatedStorage:FindFirstChild("Decoration")
	if not rootFolder then
		return false
	end
	local biomeName = string.lower(tostring(terrainInputs.biome and terrainInputs.biome.Text or "grass"))
	local biomeFolderNames = { grass = "Grass", desert = "Desert", snow = "Snow" }
	local searchRoot = rootFolder:FindFirstChild(biomeFolderNames[biomeName] or "Grass") or rootFolder
	for _, category in ipairs({ "Rocks", "Trees", "Bushes", "MiniRocks" }) do
		if folderHasTemplates(searchRoot:FindFirstChild(category)) then
			return true
		end
	end
	return false
end

local function confirmGenerationAssets()
	if not hasStructureAssets() then
		local keepGoing = confirmAsync(
			"No Structures Found",
			"ReplicatedStorage.Structures has no usable structure templates. Random structures need Models with a Base part, and city maps can optionally use ReplicatedStorage.Structures.Monolith for the custom monolith. Continue without structure assets?"
		)
		if not keepGoing then
			return false
		end
	end
	if decorationsEnabled and not hasDecorationAssets() then
		local keepGoing = confirmAsync(
			"No Decorations Found",
			"Decoration is enabled, but the plugin found no usable templates in ReplicatedStorage.Decoration for the selected biome. Continue without decorations?"
		)
		if not keepGoing then
			return false
		end
	end
	return true
end

local VOXEL_STUDS = 4
local SNAPSHOT_CHUNK_CELLS_XZ = 256
local SNAPSHOT_CHUNK_CELLS_Y = 256

local function toCellFloor(studs)
	return math.floor(studs / VOXEL_STUDS)
end

local function toCellCeil(studs)
	return math.ceil(studs / VOXEL_STUDS)
end

local function getUndoBounds(config)
	local radius = config.radius or 1024
	if type(config.border) == "table" then
		radius = config.border.decoRadius or config.border.playableRadius or radius
	end
	local padStuds = 64
	local bottomY = config.bottomY or -80
	local topY = config.topY or 320
	return
		toCellFloor(-radius - padStuds * 0.5),
		toCellCeil(radius + padStuds * 0.5),
		toCellFloor(bottomY),
		toCellCeil(topY),
		toCellFloor(-radius - padStuds * 0.5),
		toCellCeil(radius + padStuds * 0.5)
end

local function captureGenerationUndo(config)
	local snapshot = {
		previousGeneratedWorld = nil,
		terrainChunks = {},
		runId = tostring(os.clock()),
	}
	local existingRoot = workspace:FindFirstChild("GeneratedWorld")
	if existingRoot then
		snapshot.previousGeneratedWorld = existingRoot:Clone()
	end
	local minX, maxX, minY, maxY, minZ, maxZ = getUndoBounds(config)
	local chunkIndex = 0
	for y = minY, maxY - 1, SNAPSHOT_CHUNK_CELLS_Y do
		local y1 = math.min(maxY, y + SNAPSHOT_CHUNK_CELLS_Y)
		for x = minX, maxX - 1, SNAPSHOT_CHUNK_CELLS_XZ do
			local x1 = math.min(maxX, x + SNAPSHOT_CHUNK_CELLS_XZ)
			for z = minZ, maxZ - 1, SNAPSHOT_CHUNK_CELLS_XZ do
				local z1 = math.min(maxZ, z + SNAPSHOT_CHUNK_CELLS_XZ)
				local cornerCell = Vector3int16.new(x, y, z)
				local region = Region3int16.new(cornerCell, Vector3int16.new(x1, y1, z1))
				snapshot.terrainChunks[#snapshot.terrainChunks + 1] = {
					corner = cornerCell,
					region = Terrain:CopyRegion(region),
				}
				chunkIndex += 1
				if chunkIndex % 12 == 0 then
					RunService.Heartbeat:Wait()
				end
			end
		end
	end
	return snapshot
end

local function restoreGenerationUndo(snapshot)
	local currentRoot = workspace:FindFirstChild("GeneratedWorld")
	if currentRoot then
		currentRoot:Destroy()
	end
	for index, chunk in ipairs(snapshot.terrainChunks or {}) do
		Terrain:PasteRegion(chunk.region, chunk.corner, true)
		if index % 12 == 0 then
			RunService.Heartbeat:Wait()
		end
	end
	if snapshot.previousGeneratedWorld then
		snapshot.previousGeneratedWorld.Parent = workspace
	end
end

local function undoLastGeneration()
	if busy then
		return
	end
	if RunService:IsRunning() then
		setStatus(activeTab == "Roads" and roadStatus or terrainStatus, "Stop Play mode before undoing plugin generation.", THEME.red)
		return
	end
	if not lastGenerationUndo then
		setStatus(activeTab == "Roads" and roadStatus or terrainStatus, "Nothing to undo from this plugin session.", THEME.subtle)
		return
	end
	busy = true
	undoButton.Text = "Undoing..."
	setStatus(activeTab == "Roads" and roadStatus or terrainStatus, "Restoring the previous generated terrain state...", THEME.subtle)
	task.spawn(function()
		local snapshot = lastGenerationUndo
		lastGenerationUndo = nil
		local ok, err = pcall(function()
			restoreGenerationUndo(snapshot)
		end)
		busy = false
		undoButton.Text = "Undo"
		undoButton.BackgroundColor3 = THEME.panel2
		if ok then
			table.clear(blockedCells)
			table.clear(cellHints)
			repaintGrid()
			setStatus(activeTab == "Roads" and roadStatus or terrainStatus, "Undid the last plugin generation.", THEME.green)
		else
			setStatus(activeTab == "Roads" and roadStatus or terrainStatus, tostring(err), THEME.red)
		end
	end)
end

local function generateTerrain()
	if busy then
		return
	end
	if RunService:IsRunning() then
		setStatus(terrainStatus, "Stop Play mode before generating from the plugin.", THEME.red)
		return
	end
	busy = true
	if not confirmGenerationAssets() then
		busy = false
		setStatus(terrainStatus, "Generation cancelled.", THEME.subtle)
		return
	end
	generateTerrainButton.Text = "Generating..."
	setStatus(terrainStatus, "Preparing terrain undo snapshot...", THEME.subtle)
	task.spawn(function()
		local pendingUndo = nil
		local ok, result = pcall(function()
			local sys = requireSystems()
			sys.WorldState.Set(nil)
			local startedAt = os.clock()
			local config = sys.WorldGenConfig.Build(readTerrainRequest())
			pendingUndo = captureGenerationUndo(config)
			setStatus(terrainStatus, "Generating terrain...", THEME.subtle)
			local world = sys.HybridWorldGen.Generate(config)
			local rootFolder = workspace:FindFirstChild("GeneratedWorld")
			if rootFolder then
				rootFolder:SetAttribute("GeneratedByGenerationPlugin", true)
				rootFolder:SetAttribute("GenerationPluginRunId", pendingUndo.runId)
			end
			sys.WorldState.Set(world)
			return {
				profile = config.mapProfile or config.profile or selectedProfile,
				playableRadius = config.border and config.border.playableRadius or config.radius,
				lakeCount = world.lakeCount or 0,
				duration = os.clock() - startedAt,
			}
		end)
		busy = false
		generateTerrainButton.Text = "Generate"
		if ok then
			lastGenerationUndo = pendingUndo
			undoButton.BackgroundColor3 = THEME.orange
			setStatus(terrainStatus, string.format("Generated %s in %.1fs. Lakes: %d", tostring(result.profile), result.duration, result.lakeCount), THEME.green)
			activeTab = "Roads"
			terrainPage.Visible = false
			roadPage.Visible = true
			terrainTab.BackgroundColor3 = THEME.panel2
			roadTab.BackgroundColor3 = THEME.blue
			refreshRoadMask()
		else
			if pendingUndo then
				local restored, restoreErr = pcall(function()
					restoreGenerationUndo(pendingUndo)
				end)
				if restored then
					result = tostring(result) .. " Previous terrain state restored."
				else
					result = tostring(result) .. " Restore failed: " .. tostring(restoreErr)
				end
			end
			setStatus(terrainStatus, tostring(result), THEME.red)
		end
	end)
end

local function generateRoads()
	if busy then
		return
	end
	if RunService:IsRunning() then
		setStatus(roadStatus, "Stop Play mode before generating roads from the plugin.", THEME.red)
		return
	end
	busy = true
	generateRoadButton.Text = "Generating..."
	setStatus(roadStatus, "Generating roads...", THEME.subtle)
	task.spawn(function()
		local ok, resultA, resultB = pcall(function()
			local serviceOk, serviceResult = requireSystems().RoadService.Generate(rebuildPlanFromRoadUi())
			return serviceOk, serviceResult
		end)
		busy = false
		generateRoadButton.Text = "Generate Roads"
		if not ok then
			setStatus(roadStatus, tostring(resultA), THEME.red)
			return
		end
		if resultA then
			local planned = resultB
			local roadCount = type(planned) == "table" and #(planned.connections or {}) or 0
			local tunnelCount = type(planned) == "table" and #(planned.tunnelTerminals or {}) or 0
			setStatus(roadStatus, "Generated roads: " .. tostring(roadCount) .. " | tunnels: " .. tostring(tunnelCount), THEME.green)
			refreshRoadMask()
		else
			setStatus(roadStatus, tostring(resultB), THEME.red)
		end
	end)
end

local function switchTab(tab)
	activeTab = tab
	terrainPage.Visible = tab == "Terrain"
	roadPage.Visible = tab == "Roads"
	terrainTab.BackgroundColor3 = tab == "Terrain" and THEME.blue or THEME.panel2
	roadTab.BackgroundColor3 = tab == "Roads" and THEME.blue or THEME.panel2
end

terrainTab.MouseButton1Click:Connect(function()
	switchTab("Terrain")
end)

roadTab.MouseButton1Click:Connect(function()
	switchTab("Roads")
end)

profileCity.MouseButton1Click:Connect(function()
	applyTerrainDefaults("City")
end)

profileMain.MouseButton1Click:Connect(function()
	applyTerrainDefaults("Main")
end)

decorateToggle.MouseButton1Click:Connect(function()
	decorationsEnabled = not decorationsEnabled
	setProfileButtons()
end)

readmeButton.MouseButton1Click:Connect(showReadme)
undoButton.MouseButton1Click:Connect(undoLastGeneration)

generateTerrainButton.MouseButton1Click:Connect(generateTerrain)

clearRoadButton.MouseButton1Click:Connect(function()
	table.clear(exitStates)
	table.clear(anchorStates)
	repaintGrid()
	setStatus(roadStatus, "Selection cleared.", THEME.subtle)
end)

refreshRoadButton.MouseButton1Click:Connect(refreshRoadMask)
generateRoadButton.MouseButton1Click:Connect(generateRoads)

local function initializeRoadUi()
	ensureRoadPlan()
	rebuildRoadGrid()
	refreshRoadInputs()
end

applyTerrainDefaults("City")
initializeRoadUi()
switchTab("Terrain")

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toolbarButton:SetActive(widget.Enabled)
end)

toolbarButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	toolbarButton:SetActive(widget.Enabled)
end)
