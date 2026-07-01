--[[
Name: RelationClient
Class: ModuleScript
Original path: game.ReplicatedStorage.MMO_ReplicatedPackage.Client.RelationClient
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage, Players
Requires:
  - local colors  = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").RelationColors)
Functions: idOf, M:Get, M:GetColor, M:Apply, M:ApplyMany
Clean source lines: 55
]]
local RSnap   = game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents").RelationSnapshot
local RDel    = game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents").RelationDelta
local colors  = require(game:GetService("ReplicatedStorage"):WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared").RelationColors)
local Players = game:GetService("Players")


local relOf = {}

RSnap.OnClientEvent:Connect(function(snap)
	for _, rec in ipairs(snap) do
		relOf[rec.Id] = rec.Relation
	end
end)

RDel.OnClientEvent:Connect(function(delta)
	if delta.Remove then
		relOf[delta.Id] = nil
	else
		relOf[delta.Id] = delta.Relation
	end
end)

local function idOf(unit)
	local p = Players:GetPlayerFromCharacter(unit)
	if p then
		return p.UserId
	end

	return unit:GetAttribute("RelationId")
end

local M = {}

function M:Get(unit)
	return relOf[idOf(unit)] or "Neutral"
end

function M:GetColor(unit)
	return colors[self:Get(unit)]
end

function M:Apply(rec)
	if rec.Remove then
		relOf[rec.Id] = nil
	else
		relOf[rec.Id] = rec.Relation
	end
end

function M:ApplyMany(list)
	for _, r in ipairs(list) do self:Apply(r) end
end

return M
