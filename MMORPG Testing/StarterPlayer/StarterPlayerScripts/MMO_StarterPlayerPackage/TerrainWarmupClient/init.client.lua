--[[
Name: TerrainWarmupClient
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.TerrainWarmupClient
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players
Functions: requestStreamAround, startBackgroundWarmup
Clean source lines: 50
]]
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local STREAM_TIMEOUT_SECONDS = 8
local REREQUEST_DISTANCE = 192
local REREQUEST_COOLDOWN = 2.5

local streamBusy = false
local lastStreamPosition = nil
local lastStreamRequestTime = 0

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

local function startBackgroundWarmup(character)
	task.spawn(function()
		local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		requestStreamAround(root.Position, STREAM_TIMEOUT_SECONDS)
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

player.CharacterAdded:Connect(startBackgroundWarmup)

if player.Character then
	task.defer(startBackgroundWarmup, player.Character)
end
