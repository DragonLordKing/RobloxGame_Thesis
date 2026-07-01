--[[
Name: MountHelper
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.MountHelper
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, ServerScriptService
Requires:
  - local MountInfo = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("MountInfo"))
Functions: updateMountHealthBar, forceDismount, abortMounting
Clean source lines: 93
]]
local Players = game:GetService("Players")
local RemoteEvents = game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")

local MountInfo = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("MountInfo"))

local UpdateHorseStatus = RemoteEvents:WaitForChild("UpdateHorseStatus")

local mountingPlayers = MountInfo.mountingPlayers
local mountDebounce = MountInfo.mountDebounce

local function updateMountHealthBar(horse)

	local riderName = horse.Name:split("+")[1]
	local rider     = Players:FindFirstChild(riderName)
	if not (rider and rider.Character) then return end

	local head   = rider.Character:FindFirstChild("Head")
	local barGui = head
		and head:FindFirstChild("TopBar")
		and head.TopBar:FindFirstChild("MountHealthBar")

	if not barGui then return end
	local fill = barGui:FindFirstChild("Health")
	if not fill then return end

	if horse:GetAttribute("Mounted") ~= true then
		barGui.Visible = false
		fill.Visible = false
		return
	end

	local hp  = horse:GetAttribute("Health") or 0
	local max = horse:GetAttribute("MaxHealth") or 1
	fill.Size   = UDim2.new(hp / max, 0, 1, 0)
	barGui.Visible = true
	fill.Visible = true
end

local function forceDismount(player, horse)
	if not (player and player.Character and horse) then return end
	local char = player.Character
	local hrp  = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end


	local seat = horse:FindFirstChild("VehicleSeat", true)
	if seat then
		for _, w in ipairs(seat:GetChildren()) do
			if w:IsA("WeldConstraint") and w.Name == "SeatWeldConstraint" then
				w:Destroy()
			end
		end
	end

	for _, w in ipairs(hrp:GetChildren()) do
		if w:IsA("WeldConstraint") and w.Name == "SeatWeldConstraint" then
			w:Destroy()
		end
	end


	hrp.Anchored = false
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if hum then
		hum.Sit = false
		hum.PlatformStand = false

		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end


	horse:SetAttribute("Mounted", false)
	updateMountHealthBar(horse)
end

local function abortMounting(player)
	if not mountingPlayers[player.UserId] then return end

	local char = player.Character
	if char and char.PrimaryPart then
		char.PrimaryPart.Anchored = false
	end
	print("Mount/remount cancelled because the player acted.")
	mountingPlayers[player.UserId] = nil
	mountDebounce[player.UserId]  = false
	UpdateHorseStatus:FireClient(player, false)
end

return {
	updateMountHealthBar = updateMountHealthBar,
	forceDismount = forceDismount,
	abortMounting = abortMounting,
}