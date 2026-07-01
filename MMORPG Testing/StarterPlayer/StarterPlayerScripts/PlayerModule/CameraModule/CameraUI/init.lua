--[[
Name: CameraUI
Class: ModuleScript
Original path: game.StarterPlayer.StarterPlayerScripts.PlayerModule.CameraModule.CameraUI
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=false, LinkedSource=""
Services: StarterGui
Functions: CameraUI.setCameraModeToastEnabled, CameraUI.setCameraModeToastOpen
Clean source lines: 37
]]
local StarterGui = game:GetService("StarterGui")

local initialized = false

local CameraUI: any = {}

do

	function CameraUI.setCameraModeToastEnabled(enabled: boolean)
		if not enabled and not initialized then
			return
		end

		if not initialized then
			initialized = true
		end

		if not enabled then
			CameraUI.setCameraModeToastOpen(false)
		end
	end

	function CameraUI.setCameraModeToastOpen(open: boolean)
		assert(initialized)

		if open then
			StarterGui:SetCore("SendNotification", {
				Title = "Camera Control Enabled",
				Text = "Right click to toggle",
				Duration = 3,
			})
		end
	end
end

return CameraUI
