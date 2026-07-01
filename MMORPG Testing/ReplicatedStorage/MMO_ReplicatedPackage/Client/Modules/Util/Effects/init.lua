--[[
Name: Effects
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Util.Effects
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: RunService, Players, Debris
Functions: update, setLabel, destroy, Effects.spawnExpandingCircle, Effects.showBillboardPopup, Effects.createProgressBar, Effects.clearMountGui
Clean source lines: 166
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Effects = {}

function Effects.spawnExpandingCircle(position)
	if not position then return end
	local circle = Instance.new("Part")
	circle.Shape = Enum.PartType.Cylinder
	circle.Anchored = true
	circle.CanCollide = false
	circle.CanQuery = false
	circle.CanTouch = false
	circle.CastShadow = false
	circle.Transparency = 0.5
	circle.Color = Color3.new(1, 0, 0)
	circle.Position = position
	circle.Size = Vector3.new(0.2, 1, 1)
	circle.Orientation = Vector3.new(0, 90, 90)
	circle.Parent = workspace

	local duration = 1.0
	local elapsed = 0
	local initialSize = circle.Size
	local targetSize = Vector3.new(0.1, 4, 4)

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local progress = math.clamp(elapsed / duration, 0, 1)
		circle.Size = initialSize:Lerp(targetSize, progress)
		circle.Transparency = 0.5 + progress * 0.5
		if progress >= 1 then
			conn:Disconnect()
			circle:Destroy()
		end
	end)
end

function Effects.showBillboardPopup(adornee, message)
	if not adornee then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "InteractionPopup"
	gui.Adornee = adornee
	gui.Size = UDim2.new(0, 200, 0, 50)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = message or "This object has been interacted with!"
	label.Parent = gui

	game:GetService("Debris"):AddItem(gui, 2)
end


function Effects.createProgressBar(duration : number?, labelText : string?)
	local screenGui = player:WaitForChild("PlayerGui"):FindFirstChild("MountProgressGui")
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "MountProgressGui"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.DisplayOrder = 220
		screenGui.Parent = player:WaitForChild("PlayerGui")
	end

	local d: number = (typeof(duration) == "number" and duration > 0) and duration or 1
	local label = tostring(labelText or "Channeling")

	local bar = Instance.new("Frame")
	bar.Name = "ActionProgressBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Size = UDim2.new(0.34, 0, 0, 42)
	bar.Position = UDim2.new(0.5, 0, 1, -72)
	bar.BackgroundColor3 = Color3.fromRGB(18, 14, 13)
	bar.BackgroundTransparency = 0.03
	bar.BorderSizePixel = 0
	bar.Parent = screenGui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(260, 42)
	sizeLimit.MaxSize = Vector2.new(520, 42)
	sizeLimit.Parent = bar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bar
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(188, 138, 54)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.12
	stroke.Parent = bar

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 8, 0, 8)
	track.Size = UDim2.new(1, -16, 1, -16)
	track.BackgroundColor3 = Color3.fromRGB(35, 28, 24)
	track.BackgroundTransparency = 0.05
	track.BorderSizePixel = 0
	track.Parent = bar
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 6)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(188, 138, 54)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.BackgroundTransparency = 1
	timerLabel.Font = Enum.Font.GothamBlack
	timerLabel.TextColor3 = Color3.fromRGB(242, 229, 202)
	timerLabel.TextStrokeTransparency = 0.55
	timerLabel.TextSize = 15
	timerLabel.Text = label
	timerLabel.Size = UDim2.fromScale(1, 1)
	timerLabel.Parent = track

	local startTime = time()
	local function update()
		local elapsed = time() - startTime
		local progress = math.clamp(elapsed / d, 0, 1)
		local remaining = math.max(0, d - elapsed)
		fill.Size = UDim2.new(progress, 0, 1, 0)
		timerLabel.Text = string.format("%s  %.1fs", label, remaining)
		return progress
	end

	local function setLabel(nextLabel)
		label = tostring(nextLabel or label)
	end

	local function destroy()
		if bar then bar:Destroy() end
	end

	update()
	return {
		update = update,
		setLabel = setLabel,
		destroy = destroy,
	}
end

function Effects.clearMountGui()
	local old = Players.LocalPlayer.PlayerGui:FindFirstChild("MountProgressGui")
	if old then old:Destroy() end
end

return Effects
