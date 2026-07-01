--[[
Name: WorldBus
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.WorldBus
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players
Functions: bucket, Bus.FX, Bus.FXInRange, Bus.Rel, Bus.Drain
Clean source lines: 44
]]
local Players = game:GetService("Players")

local Bus = {}
local perPlr = {}

local function bucket(plr)
	local b = perPlr[plr]
	if not b then b = { fx = {}, rel = {} }; perPlr[plr] = b end
	return b
end


function Bus.FX(plr, name, data)
	local b = bucket(plr)
	b.fx[#b.fx+1] = { name, data }
end


function Bus.FXInRange(pos, radius, name, data)
	radius = radius or 128
	for _, plr in ipairs(Players:GetPlayers()) do
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - pos).Magnitude <= radius then
			Bus.FX(plr, name, data)
		end
	end
end


function Bus.Rel(plr, rec)
	local b = bucket(plr)
	b.rel[#b.rel+1] = rec
end


function Bus.Drain(plr)
	local b = perPlr[plr]
	if not b then return { fx = {}, rel = {} } end
	perPlr[plr] = nil
	return b
end

return Bus
