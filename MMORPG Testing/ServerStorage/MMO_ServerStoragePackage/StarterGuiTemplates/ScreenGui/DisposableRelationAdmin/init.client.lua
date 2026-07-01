--[[
Name: DisposableRelationAdmin
Class: LocalScript
Original path: game.ServerStorage.MMO_ServerStoragePackage.StarterGuiTemplates.ScreenGui.DisposableRelationAdmin
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, UserInputService, ReplicatedStorage
Functions: makeButton, refreshPlayerList, makeTextRow, commitChange, makeFriendlyRow, refreshDetails
Clean source lines: 272
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DisposableFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Disposable")
local RequestRelationUpdate = DisposableFolder:WaitForChild("RequestRelationUpdate")
local RequestMapTypeChange = DisposableFolder:WaitForChild("RequestMapTypeChange")
local RelationAdminSnapshot = DisposableFolder:WaitForChild("RelationAdminSnapshot")

local player = Players.LocalPlayer

local gui = script.Parent
gui.Enabled = false


gui:ClearAllChildren()

local TOGGLE_KEY = Enum.KeyCode.RightBracket

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == TOGGLE_KEY then
		gui.Enabled = not gui.Enabled
	end
end)


local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0.5, 0, 0.7, 0)
mainFrame.Position = UDim2.new(0.25, 0, 0.15, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
mainFrame.BorderSizePixel = 2
mainFrame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Relation Admin"
title.TextColor3 = Color3.new(1,1,1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Size = UDim2.new(0.35, 0, 0.85, 0)
playerListFrame.Position = UDim2.new(0.02, 0, 0.11, 0)
playerListFrame.BackgroundColor3 = Color3.fromRGB(35,35,35)
playerListFrame.CanvasSize = UDim2.new(0,0,0,0)
playerListFrame.ScrollBarThickness = 8
playerListFrame.BorderSizePixel = 1
playerListFrame.Parent = mainFrame

local playerDetails = Instance.new("Frame")
playerDetails.Size = UDim2.new(0.6, 0, 0.67, 0)
playerDetails.Position = UDim2.new(0.38, 0, 0.11, 0)
playerDetails.BackgroundColor3 = Color3.fromRGB(35,35,35)
playerDetails.BorderSizePixel = 1
playerDetails.Parent = mainFrame

local mapTypeFrame = Instance.new("Frame")
mapTypeFrame.Size = UDim2.new(0.59, 0, 0.12, 0)
mapTypeFrame.Position = UDim2.new(0.38, 0, 0.8, 0)
mapTypeFrame.BackgroundColor3 = Color3.fromRGB(40,40,50)
mapTypeFrame.BorderSizePixel = 1
mapTypeFrame.Parent = mainFrame

local mapTypeLabel = Instance.new("TextLabel")
mapTypeLabel.Size = UDim2.new(0.38, 0, 1, 0)
mapTypeLabel.BackgroundTransparency = 1
mapTypeLabel.Text = "Map Type:"
mapTypeLabel.TextColor3 = Color3.new(1,1,1)
mapTypeLabel.TextScaled = true
mapTypeLabel.Parent = mapTypeFrame

local mapTypeDropdown = Instance.new("TextButton")
mapTypeDropdown.Size = UDim2.new(0.62, -6, 0.9, 0)
mapTypeDropdown.Position = UDim2.new(0.38, 6, 0.05, 0)
mapTypeDropdown.BackgroundColor3 = Color3.fromRGB(60,60,85)
mapTypeDropdown.TextColor3 = Color3.new(1,1,1)
mapTypeDropdown.TextScaled = true
mapTypeDropdown.Font = Enum.Font.Gotham
mapTypeDropdown.Text = "..."
mapTypeDropdown.Parent = mapTypeFrame


local function makeButton(parent, text, ypos, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 30)
	btn.Position = UDim2.new(0, 0, 0, ypos)
	btn.BackgroundColor3 = Color3.fromRGB(60,60,60)
	btn.TextColor3 = Color3.new(1,1,1)
	btn.Text = text
	btn.Font = Enum.Font.Gotham
	btn.TextScaled = true
	btn.Parent = parent
	btn.MouseButton1Click:Connect(callback)
	return btn
end

local selectedPlayer = nil
local allPlayerData = {}

local function refreshPlayerList()
	playerListFrame:ClearAllChildren()


	local layout = Instance.new("UIListLayout")
	layout.Parent = playerListFrame
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)

	for i, data in ipairs(allPlayerData) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 28)
		btn.BackgroundColor3 = Color3.fromRGB(70,80,100)
		btn.TextColor3 = Color3.new(1,1,1)
		btn.Font = Enum.Font.Gotham
		btn.TextScaled = true
		btn.Text = data.Name
		btn.Parent = playerListFrame
		btn.MouseButton1Click:Connect(function()
			selectedPlayer = data
			refreshDetails()
		end)
	end
end

function refreshDetails()
	playerDetails:ClearAllChildren()


	local layout = Instance.new("UIListLayout")
	layout.Parent = playerDetails
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)

	if not selectedPlayer then return end


	local function makeTextRow(label, value, updateKey)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundTransparency = 1
		row.Parent = playerDetails

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.5, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.Font = Enum.Font.Gotham
		lbl.TextColor3 = Color3.new(1,1,1)
		lbl.TextScaled = true
		lbl.Parent = row

		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0.5, -6, 0.9, 0)
		box.Position = UDim2.new(0.5, 6, 0.05, 0)
		box.BackgroundColor3 = Color3.fromRGB(100,100,120)
		box.TextColor3 = Color3.new(1,1,1)
		box.TextScaled = true
		box.Font = Enum.Font.Gotham
		box.Text = tostring(value or "")
		box.ClearTextOnFocus = false
		box.Parent = row


		local function commitChange()
			local newValue = box.Text
			if newValue == "" then newValue = nil end
			RequestRelationUpdate:FireServer({
				UserId = selectedPlayer.UserId,
				Party = updateKey == "Party" and newValue or selectedPlayer.Party,
				Guild = updateKey == "Guild" and newValue or selectedPlayer.Guild,
				Alliance = updateKey == "Alliance" and newValue or selectedPlayer.Alliance,
				Friendly = selectedPlayer.Friendly
			})
		end

		box.FocusLost:Connect(function(enterPressed)
			if enterPressed or box.Text ~= tostring(value or "") then
				commitChange()
			end
		end)
	end


	makeTextRow("Party", selectedPlayer.Party, "Party")
	makeTextRow("Guild", selectedPlayer.Guild, "Guild")
	makeTextRow("Alliance", selectedPlayer.Alliance, "Alliance")


	local function makeFriendlyRow()
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundTransparency = 1
		row.Parent = playerDetails

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.5, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "FriendlyFlagged"
		lbl.Font = Enum.Font.Gotham
		lbl.TextColor3 = Color3.new(1,1,1)
		lbl.TextScaled = true
		lbl.Parent = row

		local box = Instance.new("TextButton")
		box.Size = UDim2.new(0.5, -6, 0.9, 0)
		box.Position = UDim2.new(0.5, 6, 0.05, 0)
		box.BackgroundColor3 = Color3.fromRGB(100,100,120)
		box.TextColor3 = Color3.new(1,1,1)
		box.TextScaled = true
		box.Font = Enum.Font.Gotham
		box.Text = tostring(selectedPlayer.Friendly)
		box.Parent = row
		box.MouseButton1Click:Connect(function()
			RequestRelationUpdate:FireServer({
				UserId = selectedPlayer.UserId,
				Party = selectedPlayer.Party,
				Guild = selectedPlayer.Guild,
				Alliance = selectedPlayer.Alliance,
				Friendly = not selectedPlayer.Friendly
			})
		end)
	end

	makeFriendlyRow()
end


local mapTypes = {"Safe", "Warn", "Danger", "Death"}
mapTypeDropdown.MouseButton1Click:Connect(function()
	local idx = table.find(mapTypes, mapTypeDropdown.Text) or 1
	local nextIdx = idx % #mapTypes + 1
	mapTypeDropdown.Text = mapTypes[nextIdx]
	RequestMapTypeChange:FireServer(mapTypes[nextIdx])
end)


RelationAdminSnapshot.OnClientEvent:Connect(function(data)
	allPlayerData = data.Players
	refreshPlayerList()
	if selectedPlayer then

		for _, d in ipairs(allPlayerData) do
			if d.UserId == selectedPlayer.UserId then
				selectedPlayer = d
			end
		end
		refreshDetails()
	end
	mapTypeDropdown.Text = data.MapType or "..."
end)


RequestMapTypeChange:FireServer("Safe")


local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,36,0,36)
closeBtn.Position = UDim2.new(1,-40,0,4)
closeBtn.AnchorPoint = Vector2.new(0,0)
closeBtn.Text = "X"
closeBtn.BackgroundColor3 = Color3.fromRGB(150,30,30)
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextScaled = true
closeBtn.Parent = mainFrame
closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)
