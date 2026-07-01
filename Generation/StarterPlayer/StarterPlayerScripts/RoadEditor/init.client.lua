--[[
Name: RoadEditor
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.RoadEditor
Exported from: Generation
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage
Requires:
  - local RoadDefaults = require(Shared:WaitForChild("RoadDefaults"))
Functions: applyScaledText, buildSlotLookup, getEdgeKey, makeBottomButton, isBlockedKey, applyVisual, rebuildPlanFromUi, refreshMask, setEditorOpen
Signal classes referenced: BindableEvent
Clean source lines: 462
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local roadRoot = ReplicatedStorage:WaitForChild("RoadSystem")
local openEditorEvent = roadRoot:FindFirstChild("OpenRoadEditorRequested")
if not openEditorEvent then
	openEditorEvent = Instance.new("BindableEvent")
	openEditorEvent.Name = "OpenRoadEditorRequested"
	openEditorEvent.Parent = roadRoot
end
local remotes = roadRoot:WaitForChild("Remotes")
local generateRoads = remotes:WaitForChild("GenerateRoads")
local getRoadEditorMask = remotes:WaitForChild("GetRoadEditorMask")
local Shared = roadRoot:WaitForChild("Shared")
local RoadDefaults = require(Shared:WaitForChild("RoadDefaults"))

local plan = RoadDefaults.DeepCopy(RoadDefaults.DefaultPlan)
local exitStates = {}
local anchorStates = {}
local blockedCells = {}
local cellHints = {}

local function applyScaledText(guiObject, minSize, maxSize)
	guiObject.TextScaled = true
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize or 10
	constraint.MaxTextSize = maxSize or 20
	constraint.Parent = guiObject
end

local function buildSlotLookup(gridSize, slotCount)
	local lookup = {}
	for i = 1, slotCount do
		local pos = math.floor(((i - 0.5) / slotCount) * (gridSize - 1) + 1.5)
		lookup[pos] = i
	end
	return lookup
end

local sideSlotLookup = buildSlotLookup(plan.mapGridSize, plan.edgeSlotsPerSide)

local function getEdgeKey(gx, gz)
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

local gui = Instance.new("ScreenGui")
gui.Name = "RoadEditorGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local openButton = Instance.new("TextButton")
openButton.Name = "OpenRoadEditor"
openButton.AnchorPoint = Vector2.new(0, 0)
openButton.Size = UDim2.new(0.11, 0, 0.05, 0)
openButton.Position = UDim2.new(0.015, 0, 0.02, 0)
openButton.Text = "Road Editor"
openButton.Parent = gui
applyScaledText(openButton, 10, 20)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0.74, 0, 0.82, 0)
panel.Position = UDim2.new(0.5, 0, 0.53, 0)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0.015, 0)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.96, 0, 0.045, 0)
title.Position = UDim2.new(0.02, 0, 0.01, 0)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Road System Editor"
title.Parent = panel
applyScaledText(title, 12, 24)

local legend = Instance.new("TextLabel")
legend.Size = UDim2.new(0.96, 0, 0.09, 0)
legend.Position = UDim2.new(0.02, 0, 0.055, 0)
legend.BackgroundTransparency = 1
legend.TextWrapped = true
legend.TextXAlignment = Enum.TextXAlignment.Left
legend.TextYAlignment = Enum.TextYAlignment.Top
legend.Text = "Blocked slots are auto-detected from the world and cannot be selected. Purple means the slot is usable but will be snapped inward away from an obstruction. Edge click: none -> road exit -> tunnel exit -> none. Interior click: anchor on/off."
legend.Parent = panel
applyScaledText(legend, 10, 18)

local gridFrame = Instance.new("Frame")
gridFrame.AnchorPoint = Vector2.new(0, 0)
gridFrame.Size = UDim2.new(0.56, 0, 0.60, 0)
gridFrame.Position = UDim2.new(0.02, 0, 0.15, 0)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = panel

local gridAspect = Instance.new("UIAspectRatioConstraint")
gridAspect.AspectRatio = 1
gridAspect.Parent = gridFrame

local gridPaddingScale = 0.004
local gridCellScale = (1 - (gridPaddingScale * (plan.mapGridSize - 1))) / plan.mapGridSize

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(gridCellScale, 0, gridCellScale, 0)
gridLayout.CellPadding = UDim2.new(gridPaddingScale, 0, gridPaddingScale, 0)
gridLayout.FillDirectionMaxCells = plan.mapGridSize
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local settingsFrame = Instance.new("ScrollingFrame")
settingsFrame.Size = UDim2.new(0.37, 0, 0.60, 0)
settingsFrame.Position = UDim2.new(0.61, 0, 0.15, 0)
settingsFrame.BackgroundTransparency = 0
settingsFrame.BorderSizePixel = 0
settingsFrame.CanvasSize = UDim2.new()
settingsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
settingsFrame.ScrollBarThickness = 8
settingsFrame.Parent = panel

local settingsCorner = Instance.new("UICorner")
settingsCorner.CornerRadius = UDim.new(0.02, 0)
settingsCorner.Parent = settingsFrame

local settingsPadding = Instance.new("UIPadding")
settingsPadding.PaddingTop = UDim.new(0.015, 0)
settingsPadding.PaddingBottom = UDim.new(0.015, 0)
settingsPadding.PaddingLeft = UDim.new(0.02, 0)
settingsPadding.PaddingRight = UDim.new(0.02, 0)
settingsPadding.Parent = settingsFrame

local settingsLayout = Instance.new("UIListLayout")
settingsLayout.Padding = UDim.new(0.012, 0)
settingsLayout.Parent = settingsFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.96, 0, 0.045, 0)
statusLabel.Position = UDim2.new(0.02, 0, 0.79, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Idle"
statusLabel.Parent = panel
applyScaledText(statusLabel, 10, 18)

local buttonsFrame = Instance.new("Frame")
buttonsFrame.Size = UDim2.new(0.96, 0, 0.07, 0)
buttonsFrame.Position = UDim2.new(0.02, 0, 0.87, 0)
buttonsFrame.BackgroundTransparency = 1
buttonsFrame.Parent = panel

local buttonsLayout = Instance.new("UIListLayout")
buttonsLayout.FillDirection = Enum.FillDirection.Horizontal
buttonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
buttonsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
buttonsLayout.Padding = UDim.new(0.015, 0)
buttonsLayout.Parent = buttonsFrame

local function makeBottomButton(text)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.23, 0, 0.9, 0)
	button.Text = text
	button.Parent = buttonsFrame
	applyScaledText(button, 10, 18)
	return button
end

local generateButton = makeBottomButton("Generate")
local clearButton = makeBottomButton("Clear Selection")
local refreshButton = makeBottomButton("Refresh Grid")
local closeButton = makeBottomButton("Close")

local settingInputs = {}

local editableSettings = {
	"pathCellSize",
	"roadWidth",
	"roadThickness",
	"roadLift",
	"roadShoulder",
	"exitStraightLength",
	"outOfMapDistance",
	"wiggleAmplitude",
	"wiggleScale",
	"mesaPenalty",
	"riverPenalty",
	"canyonPenalty",
	"slopePenalty",
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

for _, key in ipairs(editableSettings) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0.07, 0)
	row.BackgroundTransparency = 1
	row.Parent = settingsFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.58, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = key
	label.Parent = row
	applyScaledText(label, 10, 16)

	local input = Instance.new("TextBox")
	input.Size = UDim2.new(0.4, 0, 0.82, 0)
	input.Position = UDim2.new(0.6, 0, 0.09, 0)
	input.Text = tostring(plan.settings[key])
	input.ClearTextOnFocus = false
	input.Parent = row
	applyScaledText(input, 10, 16)

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0.15, 0)
	inputCorner.Parent = input

	settingInputs[key] = input
end

local cellButtons = {}

local function isBlockedKey(key)
	return blockedCells[key] == true
end

local function applyVisual(button, gx, gz)
	local edgeKey = getEdgeKey(gx, gz)
	local key = edgeKey or (tostring(gx) .. ":" .. tostring(gz))
	local blocked = isBlockedKey(key)
	button.AutoButtonColor = not blocked
	button.Active = not blocked
	button.Selectable = not blocked
	if blocked then
		button.BackgroundColor3 = Color3.fromRGB(28, 18, 18)
		button.TextColor3 = Color3.fromRGB(160, 110, 110)
		button.Text = "X"
		return
	end
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	if edgeKey then
		local state = exitStates[edgeKey]
		if state == "road" then
			button.BackgroundColor3 = Color3.fromRGB(60, 180, 75)
			button.Text = edgeKey
		elseif state == "tunnel" then
			button.BackgroundColor3 = Color3.fromRGB(230, 140, 35)
			button.Text = edgeKey
		elseif cellHints[edgeKey] then
			button.BackgroundColor3 = Color3.fromRGB(75, 75, 110)
			button.Text = edgeKey
		else
			button.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
			button.Text = edgeKey
		end
	else
		if anchorStates[key] then
			button.BackgroundColor3 = Color3.fromRGB(65, 105, 225)
			button.Text = tostring(gx) .. "," .. tostring(gz)
		elseif cellHints[key] then
			button.BackgroundColor3 = Color3.fromRGB(60, 60, 95)
			button.Text = tostring(gx) .. "," .. tostring(gz)
		else
			button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			button.Text = tostring(gx) .. "," .. tostring(gz)
		end
	end
end

for gz = 1, plan.mapGridSize do
	for gx = 1, plan.mapGridSize do
		local button = Instance.new("TextButton")
		button.Name = "Cell_" .. gx .. "_" .. gz
		button.Parent = gridFrame
		cellButtons[gx .. ":" .. gz] = button
		applyScaledText(button, 8, 18)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.12, 0)
		corner.Parent = button

		applyVisual(button, gx, gz)

		button.MouseButton1Click:Connect(function()
			local edgeKey = getEdgeKey(gx, gz)
			local blockedKey = edgeKey or (tostring(gx) .. ":" .. tostring(gz))
			if isBlockedKey(blockedKey) then
				statusLabel.Text = "That slot is obstructed by terrain and cannot be used."
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
				if anchorStates[key] then
					anchorStates[key] = nil
				else
					anchorStates[key] = true
				end
			end
			applyVisual(button, gx, gz)
		end)
	end
end

local function rebuildPlanFromUi()
	plan.exits = {}
	plan.anchors = {}
	for key, mode in pairs(exitStates) do
		if mode and not blockedCells[key] then
			local side, slot = string.match(key, "^(%u):(%d+)$")
			plan.exits[#plan.exits + 1] = {
				side = side,
				slot = tonumber(slot),
				mode = mode,
			}
		end
	end
	for key, state in pairs(anchorStates) do
		if state and not blockedCells[key] then
			local gx, gz = string.match(key, "^(%d+):(%d+)$")
			plan.anchors[#plan.anchors + 1] = {
				gx = tonumber(gx),
				gz = tonumber(gz),
			}
		end
	end
	for key, input in pairs(settingInputs) do
		local n = tonumber(input.Text)
		if n ~= nil then
			plan.settings[key] = n
		end
	end
end

local function refreshMask()
	rebuildPlanFromUi()
	statusLabel.Text = "Checking world obstruction grid..."
	local ok, result = getRoadEditorMask:InvokeServer(plan)
	if not ok then
		statusLabel.Text = tostring(result)
		return
	end
	table.clear(blockedCells)
	table.clear(cellHints)
	for key, value in pairs(result.blocked or {}) do
		if value then
			blockedCells[key] = true
			exitStates[key] = nil
			anchorStates[key] = nil
		end
	end
	for key in pairs(result.resolved or {}) do
		cellHints[key] = true
	end
	for gz = 1, plan.mapGridSize do
		for gx = 1, plan.mapGridSize do
			applyVisual(cellButtons[gx .. ":" .. gz], gx, gz)
		end
	end
	local blockedCount = 0
	for _ in pairs(blockedCells) do
		blockedCount += 1
	end
	statusLabel.Text = "Grid ready. Blocked slots: " .. tostring(blockedCount)
end

local function setEditorOpen(open)
	panel.Visible = open
	if panel.Visible then
		refreshMask()
	end
end

openButton.MouseButton1Click:Connect(function()
	setEditorOpen(not panel.Visible)
end)

openEditorEvent.Event:Connect(function()
	setEditorOpen(true)
end)

closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

clearButton.MouseButton1Click:Connect(function()
	table.clear(exitStates)
	table.clear(anchorStates)
	for gz = 1, plan.mapGridSize do
		for gx = 1, plan.mapGridSize do
			applyVisual(cellButtons[gx .. ":" .. gz], gx, gz)
		end
	end
	statusLabel.Text = "Selection cleared"
end)

refreshButton.MouseButton1Click:Connect(function()
	refreshMask()
end)

generateButton.MouseButton1Click:Connect(function()
	rebuildPlanFromUi()
	statusLabel.Text = "Generating..."
	local ok, result = generateRoads:InvokeServer(plan)
	if ok then
		local roadCount = 0
		local tunnelCount = 0
		local blockedCount = 0
		if type(result) == "table" then
			roadCount = #(result.connections or {})
			tunnelCount = #(result.tunnelTerminals or {})
			for _ in pairs((result.blockedSelections and result.blockedSelections.edges) or {}) do
				blockedCount += 1
			end
			for _ in pairs((result.blockedSelections and result.blockedSelections.anchors) or {}) do
				blockedCount += 1
			end
		end
		statusLabel.Text = "Generated roads: " .. tostring(roadCount) .. " | tunnels: " .. tostring(tunnelCount) .. " | skipped blocked: " .. tostring(blockedCount)
		refreshMask()
	else
		statusLabel.Text = tostring(result)
		refreshMask()
	end
end)

refreshMask()