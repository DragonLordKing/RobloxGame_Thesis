--[[
Name: Heartbeat
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.PlayerCoreLean.Heartbeat
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Requires:
  - local C = require(script.Parent.Core)
  - local CombatState = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
Functions: Heart.Bind
Clean source lines: 28
]]
local C = require(script.Parent.Core)
local CombatState = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
local Heart = {}

function Heart.Bind()
	local last = os.clock()
	C.RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - last
		last = now
		for _, plr in ipairs(C.Players:GetPlayers()) do
			local ch = plr.Character
			if ch and C.humanoidStats[ch] then
				C.SpatialGrid.Update(ch)
				CombatState.RegeneratePlayer(plr, dt)
			end
		end
		for uid, horse in pairs(C.MountInfo.mountedHorses) do
			if horse and horse.Parent then
				if not horse:GetAttribute("__CG_HorseSet") then C.SetModelGroup(horse, "Horse"); horse:SetAttribute("__CG_HorseSet", true) end
				C.SpatialGrid.Update(horse)
			end
		end
	end)
end

return Heart
