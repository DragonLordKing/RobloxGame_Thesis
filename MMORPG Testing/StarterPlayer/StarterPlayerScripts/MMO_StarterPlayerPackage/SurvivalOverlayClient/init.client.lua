--[[
Name: SurvivalOverlayClient
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.SurvivalOverlayClient
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, RunService, TweenService
Functions: attr, setMode, refreshMode, hookCharacter
Clean source lines: 147
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "MMOSurvivalOverlay"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 95000
gui.Enabled = false
gui.Parent = playerGui

local red = Instance.new("Frame")
red.Name = "RedOverlay"
red.BackgroundColor3 = Color3.fromRGB(135, 18, 18)
red.BackgroundTransparency = 0.9
red.BorderSizePixel = 0
red.Size = UDim2.fromScale(1, 1)
red.Parent = gui

local black = Instance.new("Frame")
black.Name = "BlackFade"
black.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
black.BackgroundTransparency = 1
black.BorderSizePixel = 0
black.Size = UDim2.fromScale(1, 1)
black.Parent = gui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextColor3 = Color3.fromRGB(255, 236, 220)
title.TextSize = 34
title.TextWrapped = true
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.44)
title.Size = UDim2.new(0.86, 0, 0, 62)
title.Parent = gui

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextColor3 = Color3.fromRGB(232, 216, 196)
subtitle.TextSize = 17
subtitle.TextWrapped = true
subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
subtitle.Position = UDim2.fromScale(0.5, 0.52)
subtitle.Size = UDim2.new(0.86, 0, 0, 36)
subtitle.Parent = gui

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.BackgroundColor3 = Color3.fromRGB(30, 31, 31)
barBack.BorderSizePixel = 0
barBack.Position = UDim2.fromScale(0.5, 0.6)
barBack.Size = UDim2.new(0.42, 0, 0, 10)
barBack.Parent = gui
Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)

local bar = Instance.new("Frame")
bar.BackgroundColor3 = Color3.fromRGB(218, 171, 74)
bar.BorderSizePixel = 0
bar.Size = UDim2.fromScale(0, 1)
bar.Parent = barBack
Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

local mode = ""
local modeStartedAt = 0
local modeDuration = 0
local fadeTween

local function attr(name)
	local character = player.Character
	if character and character:GetAttribute(name) ~= nil then
		return character:GetAttribute(name)
	end
	return player:GetAttribute(name)
end

local function setMode(nextMode)
	if mode == nextMode then return end
	mode = nextMode
	modeStartedAt = os.clock()
	modeDuration = tonumber(attr("DownedDuration")) or (nextMode == "death" and 8 or 13)
	if fadeTween then fadeTween:Cancel() end
	black.BackgroundTransparency = 1
	bar.Size = UDim2.fromScale(0, 1)
	if nextMode == "death" then
		red.BackgroundTransparency = 0.35
		barBack.Visible = false
		fadeTween = TweenService:Create(black, TweenInfo.new(8, Enum.EasingStyle.Linear), { BackgroundTransparency = 0 })
		fadeTween:Play()
	elseif nextMode == "downed" then
		red.BackgroundTransparency = 0.9
		barBack.Visible = true
	else
		gui.Enabled = false
		return
	end
	gui.Enabled = true
end

local function refreshMode()
	local killedBy = tostring(attr("KilledBy") or "")
	if killedBy ~= "" then
		setMode("death")
		title.Text = "Killed by " .. killedBy
		subtitle.Text = "Respawn at city: " .. tostring(attr("DeathCityName") or "City")
		return
	end
	if attr("Downed") == true then
		setMode("downed")
		title.Text = "Downed by: " .. tostring(attr("DownedBy") or "Unknown")
		subtitle.Text = "Reviving"
		return
	end
	setMode("")
end

local function hookCharacter(character)
	if not character then return end
	for _, name in ipairs({ "Downed", "DownedBy", "KilledBy", "DeathCityName", "DownedDuration" }) do
		character:GetAttributeChangedSignal(name):Connect(refreshMode)
	end
	refreshMode()
end

for _, name in ipairs({ "Downed", "DownedBy", "KilledBy", "DeathCityName", "DownedDuration" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshMode)
end
player.CharacterAdded:Connect(hookCharacter)
if player.Character then hookCharacter(player.Character) end

RunService.RenderStepped:Connect(function()
	if not gui.Enabled or mode == "" then return end
	if mode == "downed" then
		local elapsed = os.clock() - modeStartedAt
		local progress = math.clamp(elapsed / math.max(0.1, modeDuration), 0, 1)
		bar.Size = UDim2.fromScale(progress, 1)
	elseif mode == "death" then
		bar.Size = UDim2.fromScale(1, 1)
	end
end)
