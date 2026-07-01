--[[
Name: TerrainWarmupClient_Archived_20260611
Class: LocalScript
Original path: game.ServerStorage.MMO_Archive.TerrainWarmupClient_Archived_20260611
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, RunService, Workspace, ContentProvider, TweenService
Functions: makeLoadingGui, setProgress, hideLoadingGui, requestStreamAround, shouldSkipGroundProbe, raycastGround, waitForTerrainReady, startBackgroundWarmup, warmupCharacter
Clean source lines: 280
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local MIN_SHOW_SECONDS = 1.4
local MAX_WAIT_SECONDS = 10
local STREAM_TIMEOUT_SECONDS = 8
local REREQUEST_DISTANCE = 192
local REREQUEST_COOLDOWN = 2.5

local activeGui = nil
local streamBusy = false
local lastStreamPosition = nil
local lastStreamRequestTime = 0

local function makeLoadingGui()
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("TerrainLoadingUI")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TerrainLoadingUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12000
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundColor3 = Color3.fromRGB(9, 7, 7)
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 116)
	panel.BackgroundColor3 = Color3.fromRGB(18, 13, 12)
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(232, 176, 64)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.12
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(18, 14)
	title.Size = UDim2.new(1, -36, 0, 30)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(242, 228, 198)
	title.TextScaled = true
	title.Text = "Loading terrain"
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(18, 48)
	status.Size = UDim2.new(1, -36, 0, 24)
	status.Font = Enum.Font.Gotham
	status.TextColor3 = Color3.fromRGB(210, 196, 166)
	status.TextScaled = true
	status.Text = "Preparing the world around you..."
	status.Parent = panel

	local barBack = Instance.new("Frame")
	barBack.Name = "BarBack"
	barBack.BackgroundColor3 = Color3.fromRGB(38, 26, 22)
	barBack.BorderSizePixel = 0
	barBack.Position = UDim2.fromOffset(18, 84)
	barBack.Size = UDim2.new(1, -36, 0, 10)
	barBack.Parent = panel

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 5)
	barCorner.Parent = barBack

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(232, 176, 64)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0.08, 1)
	fill.Parent = barBack

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fill

	return gui, status, fill
end

local function setProgress(fill, amount)
	if fill then
		fill.Size = UDim2.fromScale(math.clamp(amount, 0.08, 1), 1)
	end
end

local function hideLoadingGui(gui)
	if not gui then
		return
	end
	local root = gui:FindFirstChild("Root")
	if root then
		local tween = TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
	end
	if gui.Parent then
		gui:Destroy()
	end
end

local function requestStreamAround(position, timeout)
	if typeof(position) ~= "Vector3" or streamBusy then
		return
	end
	streamBusy = true
	lastStreamPosition = position
	lastStreamRequestTime = os.clock()
	pcall(function()
		player:RequestStreamAroundAsync(position, timeout or STREAM_TIMEOUT_SECONDS)
	end)
	streamBusy = false
end

local function shouldSkipGroundProbe(inst)
	if not inst then
		return true
	end
	if inst == Workspace.Terrain then
		return false
	end
	if inst:IsA("BasePart") then
		if inst.CanCollide == false then
			return true
		end
		if inst.Transparency >= 0.95 then
			return true
		end
		local current = inst
		while current and current ~= Workspace do
			if current:GetAttribute("NonCollidable") == true or current:GetAttribute("Non-Collidable") == true then
				return true
			end
			current = current.Parent
		end
	end
	return false
end

local function raycastGround(position, character)
	local excludes = {}
	if character then
		table.insert(excludes, character)
	end
	local origin = position + Vector3.new(0, 256, 0)
	local direction = Vector3.new(0, -1, 0)
	local remaining = 1024
	for _ = 1, 12 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excludes
		params.IgnoreWater = false
		local result = Workspace:Raycast(origin, direction * remaining, params)
		if not result then
			return nil
		end
		if not shouldSkipGroundProbe(result.Instance) then
			return result
		end
		table.insert(excludes, result.Instance)
		local travelled = result.Distance + 0.05
		origin += direction * travelled
		remaining -= travelled
		if remaining <= 0 then
			return nil
		end
	end
	return nil
end

local function waitForTerrainReady(character, status, fill)
	if not game:IsLoaded() then
		if status then status.Text = "Loading assets..." end
		game.Loaded:Wait()
	end

	pcall(function()
		ContentProvider:PreloadAsync({ Workspace.Terrain })
	end)

	local root = character:WaitForChild("HumanoidRootPart", MAX_WAIT_SECONDS)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", MAX_WAIT_SECONDS)
	if not root then
		return
	end

	if status then status.Text = "Loading nearby terrain..." end
	setProgress(fill, 0.28)
	requestStreamAround(root.Position, STREAM_TIMEOUT_SECONDS)

	local started = os.clock()
	local stableFrames = 0
	while os.clock() - started < MAX_WAIT_SECONDS do
		RunService.RenderStepped:Wait()
		local elapsed = os.clock() - started
		local ground = raycastGround(root.Position, character)
		local floorReady = not humanoid or humanoid.FloorMaterial ~= Enum.Material.Air
		if ground and floorReady then
			stableFrames += 1
		else
			stableFrames = 0
		end
		setProgress(fill, 0.35 + math.clamp(elapsed / MAX_WAIT_SECONDS, 0, 1) * 0.55)
		if elapsed >= MIN_SHOW_SECONDS and stableFrames >= 8 then
			break
		end
	end
	setProgress(fill, 1)
	if status then status.Text = "Ready" end
	task.wait(0.12)
end

local function startBackgroundWarmup(character)
	task.spawn(function()
		local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		lastStreamPosition = root.Position
		while character.Parent do
			local now = os.clock()
			local pos = root.Position
			if (not lastStreamPosition or (pos - lastStreamPosition).Magnitude >= REREQUEST_DISTANCE)
				and now - lastStreamRequestTime >= REREQUEST_COOLDOWN then
				task.spawn(requestStreamAround, pos, 3)
			end
			task.wait(1)
		end
	end)
end

local function warmupCharacter(character)
	local gui, status, fill = makeLoadingGui()
	activeGui = gui
	waitForTerrainReady(character, status, fill)
	if activeGui == gui then
		activeGui = nil
	end
	hideLoadingGui(gui)
	startBackgroundWarmup(character)
end

player.CharacterAdded:Connect(function(character)
	task.defer(warmupCharacter, character)
end)

if player.Character then
	task.defer(warmupCharacter, player.Character)
end
