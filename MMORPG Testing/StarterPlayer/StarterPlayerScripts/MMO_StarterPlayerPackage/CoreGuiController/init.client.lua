--[[
Name: CoreGuiController
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.CoreGuiController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: StarterGui, ContextActionService
Functions: disableRobloxCoreUi
Clean source lines: 33
]]
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")

local CORE_TYPES_TO_DISABLE = {
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Backpack,
}

local function disableRobloxCoreUi()
	for _, coreType in ipairs(CORE_TYPES_TO_DISABLE) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreType, false)
		end)
	end
end

disableRobloxCoreUi()
task.spawn(function()
	for _ = 1, 30 do
		disableRobloxCoreUi()
		task.wait(0.25)
	end
	while true do
		disableRobloxCoreUi()
		task.wait(5)
	end
end)

ContextActionService:BindActionAtPriority("SinkRobloxBackpackShortcut", function()
	disableRobloxCoreUi()
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 500, Enum.KeyCode.Backquote)
