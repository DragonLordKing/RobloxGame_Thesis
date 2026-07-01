--[[
Name: GatheringController
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.Modules.Controllers.GatheringController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, RunService
Requires:
  - local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("GatheringConfig"))
  - local Effects = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Effects)
  - local GameState = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.GameState)
Functions: getNodeRoot, getNodePart, getNodePosition, gatherVerb, gatherLabel, clearCurrentGather, GatheringController.cancel, GatheringController.isGatheringNode, GatheringController.getGatheringNode, GatheringController.startGathering
Clean source lines: 203
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remoteEvents = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")
local gatherRequest = remoteEvents:WaitForChild("GatherRequest")
local gatherResult = remoteEvents:WaitForChild("GatherResult")

local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("GatheringConfig"))
local Effects = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.Effects)
local GameState = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").Modules.Util.GameState)

local GatheringController = {}

local activeNode = nil
local activeBar = nil
local activeConn = nil
local activeToken = 0
local chainNode = nil
local pendingContinueNode = nil

local function getNodeRoot(instance)
	if not instance then
		return nil
	end

	local current = instance
	while current and current ~= workspace do
		if current:GetAttribute("GatheringNode") then
			local model = current:IsA("Model") and current or current:FindFirstAncestorOfClass("Model")
			return model or current
		end
		current = current.Parent
	end

	return nil
end

local function getNodePart(node)
	if not node then
		return nil
	end
	if node:IsA("BasePart") then
		return node
	end
	if node:IsA("Model") then
		return node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true)
	end
	return node:FindFirstChildWhichIsA("BasePart", true)
end

local function getNodePosition(node)
	local part = getNodePart(node)
	return part and part.Position or nil
end

local function gatherVerb(node)
	local kind = tostring(node and node:GetAttribute("GatherKind") or "")
	local lower = kind:lower()
	if lower:find("wood", 1, true) then return "Chopping" end
	if lower:find("fiber", 1, true) then return "Harvesting" end
	if lower:find("hide", 1, true) then return "Skinning" end
	return "Mining"
end

local function gatherLabel(node)
	local itemName = tostring(node and node:GetAttribute("GatherItem") or "resource")
	local ticks = math.max(0, math.floor(tonumber(node and node:GetAttribute("GatherTicks")) or 0))
	local maxTicks = math.max(1, math.floor(tonumber(node and node:GetAttribute("GatherMaxTicks")) or math.max(1, ticks)))
	return string.format("%s %s  %d / %d", gatherVerb(node), itemName, ticks, maxTicks)
end

local function clearCurrentGather(keepChain)
	activeToken += 1
	activeNode = nil
	if keepChain ~= true then
		chainNode = nil
		pendingContinueNode = nil
	end
	GameState.gathering = false
	GameState.disableMovement = false

	if activeConn then
		activeConn:Disconnect()
		activeConn = nil
	end

	if activeBar then
		activeBar.destroy()
		activeBar = nil
	end
end

function GatheringController.cancel()
	clearCurrentGather(false)
end

function GatheringController.isGatheringNode(instance)
	return getNodeRoot(instance) ~= nil
end

function GatheringController.getGatheringNode(instance)
	return getNodeRoot(instance)
end

function GatheringController.startGathering(node, keepChain)
	node = getNodeRoot(node)
	if not node or node:GetAttribute("Depleted") or activeNode == node then
		return
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local nodePosition = getNodePosition(node)
	if not hrp or not nodePosition then
		return
	end

	local range = tonumber(Config.InteractDistance) or 8
	if (hrp.Position - nodePosition).Magnitude > range + 0.5 then
		return
	end

	clearCurrentGather(keepChain == true)
	activeToken += 1
	local token = activeToken
	activeNode = node
	chainNode = node
	GameState.gathering = true
	GameState.disableMovement = true

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid:MoveTo(hrp.Position)
	end

	local duration = tonumber(node:GetAttribute("GatherDuration")) or Config.DurationFromSpecialization(0)
	activeBar = Effects.createProgressBar(duration, gatherLabel(node))
	local startPosition = hrp.Position
	local startTime = time()

	activeConn = RunService.RenderStepped:Connect(function()
		if token ~= activeToken then
			return
		end

		local currentCharacter = player.Character
		local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
		local currentNodePosition = getNodePosition(node)
		if not currentRoot or not currentNodePosition or not node.Parent or node:GetAttribute("Depleted") then
			GatheringController.cancel()
			return
		end

		if (currentRoot.Position - startPosition).Magnitude > 0.75 or (currentRoot.Position - currentNodePosition).Magnitude > range + 1 then
			GatheringController.cancel()
			return
		end

		if activeBar and activeBar.setLabel then
			activeBar.setLabel(gatherLabel(node))
		end
		local progress = activeBar and activeBar.update() or 0
		if progress >= 1 or (time() - startTime) >= duration then
			local finishedNode = activeNode
			pendingContinueNode = finishedNode
			clearCurrentGather(true)
			gatherRequest:FireServer(finishedNode)
		end
	end)
end

gatherResult.OnClientEvent:Connect(function(success, itemName, amount, total, valorSkillKey, valorAmount, valorTier, remainingTicks)
	local continueNode = pendingContinueNode
	pendingContinueNode = nil

	if success then
		local totalCount = tonumber(total) or 0
		local text = string.format("+%d %s  (Total: %d)", tonumber(amount) or 1, tostring(itemName), totalCount)
		if _G.SetStat then
			_G.SetStat(tostring(itemName), totalCount)
		end
		Effects.showBillboardPopup(player.Character and player.Character:FindFirstChild("HumanoidRootPart"), text)

		local ticksLeft = tonumber(remainingTicks)
		if ticksLeft == nil and continueNode then
			ticksLeft = tonumber(continueNode:GetAttribute("GatherTicks")) or 0
		end
		if continueNode and chainNode == continueNode and (ticksLeft or 0) > 0 and continueNode.Parent and not continueNode:GetAttribute("Depleted") then
			task.defer(function()
				if chainNode == continueNode and continueNode.Parent and not continueNode:GetAttribute("Depleted") then
					GatheringController.startGathering(continueNode, true)
				end
			end)
		end
	else
		chainNode = nil
		Effects.showBillboardPopup(player.Character and player.Character:FindFirstChild("HumanoidRootPart"), tostring(itemName or "Unable to gather"))
	end
end)

return GatheringController