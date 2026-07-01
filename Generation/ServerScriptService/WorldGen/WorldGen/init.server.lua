--[[
Name: WorldGen
Class: Script
Original path: game.ServerScriptService.WorldGen.WorldGen
Exported from: Generation
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ReplicatedStorage
Requires:
  - local HybridWorldGen = require(script.Parent:WaitForChild("HybridWorldGen"))
  - local WorldGenConfig = require(script.Parent:WaitForChild("WorldGenConfig"))
  - local WorldState = require(script.Parent.Parent:WaitForChild("RoadSystem"):WaitForChild("WorldState"))
Functions: getOrCreateFolder, getOrCreateRemoteFunction, defaultsRemote.OnServerInvoke, generateRemote.OnServerInvoke
Signal classes referenced: RemoteFunction
Clean source lines: 86
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HybridWorldGen = require(script.Parent:WaitForChild("HybridWorldGen"))
local WorldGenConfig = require(script.Parent:WaitForChild("WorldGenConfig"))
local WorldState = require(script.Parent.Parent:WaitForChild("RoadSystem"):WaitForChild("WorldState"))

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function getOrCreateRemoteFunction(parent, name)
	local remote = parent:FindFirstChild(name)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end
	if remote then
		remote:Destroy()
	end
	remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local remotes = getOrCreateFolder(ReplicatedStorage, "WorldGenSystem")
local generateRemote = getOrCreateRemoteFunction(remotes, "GenerateWorld")
local defaultsRemote = getOrCreateRemoteFunction(remotes, "GetWorldGenDefaults")

local generating = false

defaultsRemote.OnServerInvoke = function()
	return WorldGenConfig.GetDefaultOptions()
end

generateRemote.OnServerInvoke = function(player, request)
	if generating then
		return { ok = false, message = "World generation is already running." }
	end

	generating = true
	WorldState.Set(nil)
	local startedAt = os.clock()

	local ok, result = pcall(function()
		local config = WorldGenConfig.Build(request)
		local worldResult = HybridWorldGen.Generate(config)
		WorldState.Set(worldResult)

		return {
			profile = config.mapProfile or config.profile or "Main",
			playableRadius = config.border and config.border.playableRadius or config.radius,
			decoRadius = config.border and config.border.decoRadius or config.radius,
			lakeCount = worldResult.lakeCount or 0,
			duration = os.clock() - startedAt,
		}
	end)

	generating = false

	if not ok then
		warn("[WorldGen] Generation failed: " .. tostring(result))
		return { ok = false, message = tostring(result) }
	end

	local message = string.format(
		"Generated %s map in %.1fs (playable %.0f, lakes %d).",
		result.profile,
		result.duration,
		result.playableRadius or 0,
		result.lakeCount or 0
	)
	print("[WorldGen] " .. message)
	return { ok = true, message = message, summary = result }
end

print("[WorldGen] Waiting for the generation menu before building terrain.")