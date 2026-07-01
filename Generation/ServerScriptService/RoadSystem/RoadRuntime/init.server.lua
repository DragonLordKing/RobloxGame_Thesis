--[[
Name: RoadRuntime
Class: Script
Original path: game.ServerScriptService.RoadSystem.RoadRuntime
Exported from: Generation
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ReplicatedStorage
Requires:
  - local RoadService = require(script.Parent:WaitForChild("RoadService"))
Functions: generateFn.OnServerInvoke, editorMaskFn.OnServerInvoke
Signal classes referenced: RemoteFunction
Clean source lines: 42
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoadService = require(script.Parent:WaitForChild("RoadService"))

local root = ReplicatedStorage:FindFirstChild("RoadSystem")
if not root then
	root = Instance.new("Folder")
	root.Name = "RoadSystem"
	root.Parent = ReplicatedStorage
end

local remotes = root:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = root
end

local generateFn = remotes:FindFirstChild("GenerateRoads")
if not generateFn then
	generateFn = Instance.new("RemoteFunction")
	generateFn.Name = "GenerateRoads"
	generateFn.Parent = remotes
end

local editorMaskFn = remotes:FindFirstChild("GetRoadEditorMask")
if not editorMaskFn then
	editorMaskFn = Instance.new("RemoteFunction")
	editorMaskFn.Name = "GetRoadEditorMask"
	editorMaskFn.Parent = remotes
end

generateFn.OnServerInvoke = function(_, plan)
	local ok, result = RoadService.Generate(plan)
	return ok, result
end

editorMaskFn.OnServerInvoke = function(_, plan)
	local ok, result = RoadService.GetEditorMask(plan)
	return ok, result
end
