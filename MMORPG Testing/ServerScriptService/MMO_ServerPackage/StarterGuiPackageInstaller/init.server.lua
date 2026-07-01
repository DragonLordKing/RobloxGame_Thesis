--[[
Name: StarterGuiPackageInstaller
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.StarterGuiPackageInstaller
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ServerStorage
Functions: cloneTemplate, installForPlayer
Clean source lines: 42
]]
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local serverStoragePackage = ServerStorage:WaitForChild("MMO_ServerStoragePackage")
local templates = serverStoragePackage:WaitForChild("StarterGuiTemplates")

local function cloneTemplate(template, playerGui)
	local existing = playerGui:FindFirstChild(template.Name)
	if existing then
		return existing
	end

	local clone = template:Clone()
	clone:SetAttribute("PackagedStarterGuiClone", true)
	clone.Parent = playerGui
	return clone
end

local function installForPlayer(player)
	local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 15)
	if not playerGui then
		return
	end

	for _, template in ipairs(templates:GetChildren()) do
		if template:IsA("ScreenGui") then
			cloneTemplate(template, playerGui)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.defer(installForPlayer, player)
	player.CharacterAdded:Connect(function()
		task.defer(installForPlayer, player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(installForPlayer, player)
end
