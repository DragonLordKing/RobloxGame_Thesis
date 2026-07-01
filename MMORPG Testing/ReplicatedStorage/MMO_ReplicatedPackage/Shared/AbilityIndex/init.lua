--[[
Name: AbilityIndex
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Shared.AbilityIndex
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage
Functions: Index.GetTargetType
Clean source lines: 23
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local rf = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("GetAbilityMeta")


local ok, abilityMeta = pcall(function()
	return rf:InvokeServer()
end)
if not ok then
	warn("Ability meta request failed: ", abilityMeta)
	abilityMeta = {}
end

local Index = abilityMeta


function Index.GetTargetType(weaponType, slot, idx)
	local wt = Index[weaponType]
	local ability = wt and wt[slot] and wt[slot][idx]
	return ability and ability.TargetType
end

return Index
