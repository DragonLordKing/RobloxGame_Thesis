--[[
Name: MapTeleportLoadingController
Class: LocalScript
Original path: game.ReplicatedFirst.MapTeleportLoadingController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedFirst, ReplicatedStorage, TeleportService, TweenService
Functions: buildLoadingGui, showNotice, showDangerPrompt, button
Clean source lines: 250
]]
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
local remoteFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents", 20)
local PrepareMapTeleport = remoteFolder and remoteFolder:WaitForChild("PrepareMapTeleport", 20)
local WorldExitPrompt = remoteFolder and remoteFolder:WaitForChild("WorldExitPrompt", 20)
local WorldExitResponse = remoteFolder and remoteFolder:WaitForChild("WorldExitResponse", 20)
local WorldTravelNotice = remoteFolder and remoteFolder:WaitForChild("WorldTravelNotice", 20)
local playerGui = player:WaitForChild("PlayerGui")

local function buildLoadingGui(payload)
	payload = type(payload) == "table" and payload or {}
	local gui = Instance.new("ScreenGui")
	gui.Name = "MMOMapTravelLoading"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100000

	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(56, 58, 58)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = gui

	local placeholder = Instance.new("ImageLabel")
	placeholder.Name = "PlaceholderImage"
	placeholder.BackgroundColor3 = Color3.fromRGB(83, 86, 84)
	placeholder.BorderSizePixel = 0
	placeholder.Image = ""
	placeholder.ImageTransparency = 1
	placeholder.Size = UDim2.fromScale(1, 1)
	placeholder.Parent = bg

	local shade = Instance.new("Frame")
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 0.28
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = bg

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Color3.fromRGB(244, 235, 214)
	title.TextSize = 32
	title.TextWrapped = true
	title.Text = "Travelling to " .. tostring(payload.DisplayName or payload.TargetMapKey or "the next region")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.42)
	title.Size = UDim2.new(0.86, 0, 0, 82)
	title.Parent = bg

	local phase = Instance.new("TextLabel")
	phase.Name = "PhaseLabel"
	phase.BackgroundTransparency = 1
	phase.Font = Enum.Font.GothamMedium
	phase.TextColor3 = Color3.fromRGB(218, 210, 189)
	phase.TextSize = 16
	phase.Text = "Preparing terrain"
	phase.AnchorPoint = Vector2.new(0.5, 0.5)
	phase.Position = UDim2.fromScale(0.5, 0.82)
	phase.Size = UDim2.new(0.82, 0, 0, 28)
	phase.Parent = bg

	local barBack = Instance.new("Frame")
	barBack.AnchorPoint = Vector2.new(0.5, 0.5)
	barBack.BackgroundColor3 = Color3.fromRGB(25, 27, 28)
	barBack.BorderSizePixel = 0
	barBack.Position = UDim2.fromScale(0.5, 0.87)
	barBack.Size = UDim2.new(0.58, 0, 0, 12)
	barBack.Parent = bg
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)

	local bar = Instance.new("Frame")
	bar.Name = "Fill"
	bar.BackgroundColor3 = Color3.fromRGB(218, 171, 74)
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(0.04, 1)
	bar.Parent = barBack
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	local phases = type(payload.LoadingPhases) == "table" and payload.LoadingPhases or { "Preparing terrain", "Warming NPC spawns", "Finding arrival spawn", "Opening the road" }
	task.spawn(function()
		local total = 3.4
		local stepTime = total / math.max(1, #phases)
		for i, text in ipairs(phases) do
			if not gui.Parent then return end
			phase.Text = tostring(text)
			TweenService:Create(bar, TweenInfo.new(stepTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(math.clamp(i / #phases, 0.08, 0.96), 1) }):Play()
			task.wait(stepTime)
		end
		if gui.Parent then
			phase.Text = "Entering " .. tostring(payload.DisplayName or "region")
			TweenService:Create(bar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
		end
	end)

	return gui
end

local function showNotice(text)
	local old = playerGui:FindFirstChild("MMOWorldTravelNotice")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MMOWorldTravelNotice"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100001
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.BackgroundColor3 = Color3.fromRGB(18, 19, 19)
	label.BackgroundTransparency = 0.05
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = tostring(text or "")
	label.TextColor3 = Color3.fromRGB(244, 235, 214)
	label.TextSize = 15
	label.TextWrapped = true
	label.Position = UDim2.new(0.5, 0, 0, 24)
	label.Size = UDim2.new(0, 420, 0, 42)
	label.Parent = gui
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)
	task.delay(3, function()
		if gui.Parent then gui:Destroy() end
	end)
end

local function showDangerPrompt(payload)
	if not WorldExitResponse or type(payload) ~= "table" then return end
	local old = playerGui:FindFirstChild("MMOWorldExitPrompt")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MMOWorldExitPrompt"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100002
	gui.Parent = playerGui

	local dim = Instance.new("TextButton")
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.42
	dim.BorderSizePixel = 0
	dim.Text = ""
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(18, 19, 19)
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(0, 460, 0, 220)
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(202, 157, 62)
	stroke.Thickness = 1
	stroke.Transparency = 0.15
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Color3.fromRGB(244, 235, 214)
	title.TextSize = 22
	title.Text = tostring(payload.TargetZoneType or "Danger") .. " Zone"
	title.Position = UDim2.new(0, 26, 0, 24)
	title.Size = UDim2.new(1, -52, 0, 30)
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.TextColor3 = Color3.fromRGB(211, 205, 188)
	body.TextSize = 15
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = "Travelling to " .. tostring(payload.DisplayName or "the next map") .. " can lead to gear loss and inventory loss. Are you sure?"
	body.Position = UDim2.new(0, 26, 0, 70)
	body.Size = UDim2.new(1, -52, 0, 76)
	body.Parent = frame

	local function button(name, text, x, color)
		local b = Instance.new("TextButton")
		b.Name = name
		b.BackgroundColor3 = color
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.Text = text
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.TextSize = 15
		b.Position = UDim2.new(x, 0, 1, -58)
		b.Size = UDim2.new(0.38, 0, 0, 36)
		b.Parent = frame
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		return b
	end

	button("Stay", "Stay", 0.08, Color3.fromRGB(66, 68, 68)).MouseButton1Click:Connect(function()
		WorldExitResponse:FireServer({ Id = payload.Id, Accepted = false })
		gui:Destroy()
	end)
	button("Travel", "Travel", 0.54, Color3.fromRGB(154, 70, 58)).MouseButton1Click:Connect(function()
		WorldExitResponse:FireServer({ Id = payload.Id, Accepted = true })
		gui:Destroy()
	end)
end

local arriving = TeleportService:GetArrivingTeleportGui()
if arriving then
	pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
	arriving.Parent = playerGui
	task.delay(3.65, function()
		if arriving and arriving.Parent then
			arriving:Destroy()
		end
	end)
end

if PrepareMapTeleport then
	PrepareMapTeleport.OnClientEvent:Connect(function(payload)
		pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
		local old = playerGui:FindFirstChild("MMOMapTravelLoading")
		if old then old:Destroy() end
		local gui = buildLoadingGui(payload)
		gui.Parent = playerGui
		TeleportService:SetTeleportGui(gui)
	end)
end

if WorldExitPrompt then
	WorldExitPrompt.OnClientEvent:Connect(showDangerPrompt)
end

if WorldTravelNotice then
	WorldTravelNotice.OnClientEvent:Connect(function(payload)
		local text = type(payload) == "table" and payload.Text or payload
		showNotice(text)
	end)
end
