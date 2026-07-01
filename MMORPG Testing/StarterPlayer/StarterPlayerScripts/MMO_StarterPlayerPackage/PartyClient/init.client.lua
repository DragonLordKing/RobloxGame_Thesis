--[[
Name: PartyClient
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.PartyClient
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage, RunService
Requires:
  - local Selection = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util"):WaitFor...
Functions: corner, stroke, promptButton, getPlayerByUserId, thumbnail, showNotice, invokeParty, clearList, makeHealthBar, setHealthFill, makeMemberCard, renderParty, _G.PartySnapshot
Clean source lines: 331
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remoteEvents = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")
local PartyRequest = remoteEvents:WaitForChild("PartyRequest")
local PartyInvite = remoteEvents:WaitForChild("PartyInvite")
local PartySnapshot = remoteEvents:WaitForChild("PartySnapshot")
local PartyNotice = remoteEvents:WaitForChild("PartyNotice")
local Selection = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client"):WaitForChild("Modules"):WaitForChild("Util"):WaitForChild("Selection"))

local THEME = {
	panel = Color3.fromRGB(24, 18, 14),
	panel2 = Color3.fromRGB(38, 28, 20),
	line = Color3.fromRGB(232, 176, 64),
	text = Color3.fromRGB(242, 228, 198),
	subtle = Color3.fromRGB(202, 188, 158),
	health = Color3.fromRGB(192, 44, 34),
	cyan = Color3.fromRGB(61, 218, 232),
}

local gui = Instance.new("ScreenGui")
gui.Name = "PartyHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local function stroke(parent, thickness, color, transparency)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 1
	s.Color = color or THEME.line
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local notice = Instance.new("TextLabel")
notice.Name = "PartyNotice"
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.BackgroundColor3 = Color3.fromRGB(20, 15, 13)
notice.BackgroundTransparency = 0.04
notice.BorderSizePixel = 0
notice.Font = Enum.Font.GothamBold
notice.TextColor3 = THEME.text
notice.TextSize = 15
notice.TextWrapped = true
notice.Position = UDim2.new(0.5, 0, 0, 86)
notice.Size = UDim2.fromOffset(420, 42)
notice.Visible = false
notice.ZIndex = 200
notice.Parent = gui
corner(notice, 8)
stroke(notice, 1, THEME.line, 0.16)

local inviteFrame = Instance.new("Frame")
inviteFrame.Name = "PartyInvitePrompt"
inviteFrame.AnchorPoint = Vector2.new(0.5, 0.5)
inviteFrame.BackgroundColor3 = THEME.panel
inviteFrame.BackgroundTransparency = 0.03
inviteFrame.BorderSizePixel = 0
inviteFrame.Position = UDim2.fromScale(0.5, 0.46)
inviteFrame.Size = UDim2.fromOffset(430, 154)
inviteFrame.Visible = false
inviteFrame.ZIndex = 210
inviteFrame.Parent = gui
corner(inviteFrame, 8)
stroke(inviteFrame, 1, THEME.line, 0.08)

local inviteText = Instance.new("TextLabel")
inviteText.BackgroundTransparency = 1
inviteText.Font = Enum.Font.GothamBold
inviteText.TextColor3 = THEME.text
inviteText.TextSize = 18
inviteText.TextWrapped = true
inviteText.Position = UDim2.fromOffset(24, 22)
inviteText.Size = UDim2.new(1, -48, 0, 58)
inviteText.ZIndex = 211
inviteText.Parent = inviteFrame

local function promptButton(name, text, x, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 247, 224)
	b.TextSize = 15
	b.Position = UDim2.fromOffset(x, 96)
	b.Size = UDim2.fromOffset(170, 38)
	b.ZIndex = 211
	b.Parent = inviteFrame
	corner(b, 7)
	return b
end

local joinButton = promptButton("Join", "Join", 42, Color3.fromRGB(51, 130, 78))
local declineButton = promptButton("Decline", "Decline", 218, Color3.fromRGB(116, 44, 38))

local partyList = Instance.new("Frame")
partyList.Name = "PartyList"
partyList.BackgroundTransparency = 1
partyList.Position = UDim2.fromOffset(12, 126)
partyList.Size = UDim2.fromOffset(380, 420)
partyList.Visible = false
partyList.ZIndex = 70
partyList.Parent = gui

local thumbnailCache = {}
local currentInvite
local currentSnapshot = { Members = {}, Size = 0 }
local memberCards = {}

local function getPlayerByUserId(userId)
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.UserId == userId then return candidate end
	end
	return nil
end

local function thumbnail(userId)
	userId = tonumber(userId) or 0
	if thumbnailCache[userId] then return thumbnailCache[userId] end
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	thumbnailCache[userId] = ok and image or ""
	return thumbnailCache[userId]
end

local function showNotice(text)
	notice.Text = tostring(text or "")
	notice.Visible = notice.Text ~= ""
	if notice.Visible then
		local token = os.clock()
		notice:SetAttribute("Token", token)
		task.delay(3, function()
			if notice:GetAttribute("Token") == token then
				notice.Visible = false
			end
		end)
	end
end

local function invokeParty(action, payload)
	local ok, result = pcall(function()
		return PartyRequest:InvokeServer(action, payload or {})
	end)
	if not ok then
		showNotice(tostring(result))
		return nil
	end
	if type(result) == "table" and result.Ok == false and result.Error then
		showNotice(result.Error)
	end
	return result
end

_G.PartyRequest = invokeParty
_G.PartySnapshot = function()
	return currentSnapshot
end

local function clearList()
	for _, child in ipairs(partyList:GetChildren()) do
		child:Destroy()
	end
	table.clear(memberCards)
end

local function makeHealthBar(parent, y, width, height)
	local back = Instance.new("Frame")
	back.Name = "HealthBack"
	back.BackgroundColor3 = Color3.fromRGB(13, 10, 9)
	back.BorderSizePixel = 0
	back.Position = UDim2.fromOffset(46, y)
	back.Size = UDim2.fromOffset(width, height)
	back.ZIndex = parent.ZIndex + 1
	back.Parent = parent
	corner(back, math.max(2, math.floor(height * 0.5)))
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = THEME.health
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	corner(fill, math.max(2, math.floor(height * 0.5)))
	return fill
end

local function setHealthFill(fill, health, maxHealth)
	if fill then
		fill.Size = UDim2.fromScale(math.clamp((tonumber(health) or 0) / math.max(1, tonumber(maxHealth) or 1), 0, 1), 1)
	end
end

local function makeMemberCard(member, index, compact)
	local card = Instance.new("TextButton")
	card.Name = "Member_" .. tostring(member.UserId)
	card.AutoButtonColor = true
	card.BackgroundColor3 = THEME.panel
	card.BackgroundTransparency = 0.06
	card.BorderSizePixel = 0
	card.Text = ""
	card.ZIndex = 72
	card.Parent = partyList
	corner(card, 7)
	stroke(card, 1, member.IsLeader and THEME.line or Color3.fromRGB(82, 62, 38), member.IsLeader and 0.1 or 0.36)
	local width = compact and 178 or 268
	local height = compact and 36 or 62
	local col = compact and math.floor((index - 1) / 10) or 0
	local row = compact and ((index - 1) % 10) or (index - 1)
	card.Size = UDim2.fromOffset(width, height)
	card.Position = UDim2.fromOffset(col * (width + 10), row * (height + 6))

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundTransparency = 1
	avatar.Image = thumbnail(member.UserId)
	avatar.Position = UDim2.fromOffset(6, 6)
	avatar.Size = UDim2.fromOffset(compact and 24 or 42, compact and 24 or 42)
	avatar.ZIndex = 73
	avatar.Parent = card
	corner(avatar, compact and 12 or 21)

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Text = (member.IsLeader and "* " or "") .. tostring(member.DisplayName or member.Name or "Member")
	name.TextColor3 = THEME.text
	name.TextSize = compact and 11 or 13
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Position = UDim2.fromOffset(compact and 36 or 56, compact and 3 or 8)
	name.Size = UDim2.new(1, compact and -42 or -66, 0, compact and 14 or 18)
	name.ZIndex = 73
	name.Parent = card

	local fill = makeHealthBar(card, compact and 21 or 36, compact and 120 or 198, compact and 8 or 12)
	setHealthFill(fill, member.Health, member.MaxHealth)
	memberCards[member.UserId] = { Card = card, Fill = fill }
	card.Activated:Connect(function()
		local target = getPlayerByUserId(member.UserId)
		if target and target.Character then
			Selection.setPersistent(target.Character)
		end
	end)
end

local function renderParty(snapshot)
	currentSnapshot = type(snapshot) == "table" and snapshot or { Members = {}, Size = 0 }
	clearList()
	local visibleMembers = {}
	for _, member in ipairs(currentSnapshot.Members or {}) do
		if not member.IsSelf then
			table.insert(visibleMembers, member)
		end
	end
	partyList.Visible = #visibleMembers > 0
	local compact = (tonumber(currentSnapshot.Size) or #visibleMembers) > 5
	for index, member in ipairs(visibleMembers) do
		makeMemberCard(member, index, compact)
	end
	partyList.Size = compact and UDim2.fromOffset(366, 396) or UDim2.fromOffset(280, math.max(1, #visibleMembers) * 68)
end

joinButton.Activated:Connect(function()
	if currentInvite then
		invokeParty("RespondInvite", { Accept = true, FromUserId = currentInvite.FromUserId })
	end
	inviteFrame.Visible = false
	currentInvite = nil
end)

declineButton.Activated:Connect(function()
	if currentInvite then
		invokeParty("RespondInvite", { Accept = false, FromUserId = currentInvite.FromUserId })
	end
	inviteFrame.Visible = false
	currentInvite = nil
end)

PartyInvite.OnClientEvent:Connect(function(data)
	currentInvite = type(data) == "table" and data or nil
	if not currentInvite then return end
	inviteText.Text = tostring(currentInvite.FromName or "Someone") .. " has invited you to their party."
	inviteFrame.Visible = true
	task.delay(tonumber(currentInvite.Expires) or 30, function()
		if currentInvite == data then
			currentInvite = nil
			inviteFrame.Visible = false
		end
	end)
end)

PartySnapshot.OnClientEvent:Connect(renderParty)
PartyNotice.OnClientEvent:Connect(function(data)
	showNotice(type(data) == "table" and data.Text or data)
end)

task.defer(function()
	local result = invokeParty("Snapshot")
	if type(result) == "table" and type(result.Snapshot) == "table" then
		renderParty(result.Snapshot)
	end
end)

local healthTimer = 0
RunService.RenderStepped:Connect(function(dt)
	healthTimer += dt
	if healthTimer < 0.15 then return end
	healthTimer = 0
	for userId, refs in pairs(memberCards) do
		local target = getPlayerByUserId(userId)
		local character = target and target.Character
		local health = tonumber(character and character:GetAttribute("Health")) or 0
		local maxHealth = tonumber(character and character:GetAttribute("MaxHealth")) or 1
		setHealthFill(refs.Fill, health, maxHealth)
	end
end)
