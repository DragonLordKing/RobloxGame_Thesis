--[[
Name: Bootstrap
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.PlayerCoreLean.Bootstrap
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Requires:
  - local C         = require(script.Parent.Core)
  - local Stats     = require(script.Parent.Stats)
  - local Combat    = require(script.Parent.Combat)
  - local Heartbeat = require(script.Parent.Heartbeat)
Functions: C.GetPlayerMountBF.OnInvoke
Clean source lines: 59
]]
local C         = require(script.Parent.Core)
local Stats     = require(script.Parent.Stats)
local Combat    = require(script.Parent.Combat)
local Heartbeat = require(script.Parent.Heartbeat)

C.SetupCollisionGroups()
C.InitNPCIndex()
C.BuildEquipmentIndex()
C.BuildLootIndex()
Stats.LoadEquipmentModules()


for _, d in ipairs(C.Workspace:GetDescendants()) do
	if d:IsA("Model") then
		local hum = d:FindFirstChildOfClass("Humanoid")
		if hum then Stats.initializeHumanoidStats(hum) end
	end
end


C.Workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Humanoid") and desc.Parent:IsA("Model") then
		Stats.initializeHumanoidStats(desc)
		Stats.bindDeathCleanup(desc)
	end
end)

for model, s in pairs(C.humanoidStats) do
	if s.Humanoid then Stats.bindDeathCleanup(s.Humanoid) end
end

C.Players.PlayerRemoving:Connect(function(player)
	local model = player.Character
	if model and C.humanoidStats[model] then
		local stats = C.humanoidStats[model]
		Stats.persistPlayerStats(player, stats)
		Stats.cleanupStats(model)
	end
end)

Heartbeat.Bind()
Combat.Bind()


C.GetPlayerMountBF.OnInvoke = function(player)
	if not player then return nil end
	local section = C.ProfileService.GetSection(player, "Equipment", function()
		return { Equipment = {}, Mount = nil }
	end)
	local equipment = type(section.Equipment) == "table" and section.Equipment or {}
	local mountId = equipment.Mount or section.Mount
	if mountId == nil or tostring(mountId) == "" then
		return nil
	end
	return tostring(mountId)
end

return C.humanoidStats
