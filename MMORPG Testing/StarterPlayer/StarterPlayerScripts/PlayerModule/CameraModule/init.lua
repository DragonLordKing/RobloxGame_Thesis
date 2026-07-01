--[[
Name: CameraModule
Class: ModuleScript
Original path: game.StarterPlayer.StarterPlayerScripts.PlayerModule.CameraModule
Exported from: MMORPG Testing
Original comments: removed
Children: 18
Properties: Archivable=false, LinkedSource=""
Services: Players, RunService, UserInputService, VRService
Requires:
  - local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))
  - local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
  - local CameraUtils = require(script:WaitForChild("CameraUtils"))
  - local CameraInput = require(script:WaitForChild("CameraInput"))
  - local ClassicCamera = require(script:WaitForChild("ClassicCamera"))
  - local OrbitalCamera = require(script:WaitForChild("OrbitalCamera"))
  - local LegacyCamera = require(script:WaitForChild("LegacyCamera"))
  - local VehicleCamera = require(script:WaitForChild("VehicleCamera"))
  - local VRCamera = require(script:WaitForChild("VRCamera"))
  - local VRVehicleCamera = require(script:WaitForChild("VRVehicleCamera"))
  - local Invisicam = require(script:WaitForChild("Invisicam"))
  - local Poppercam = require(script:WaitForChild("Poppercam"))
  - local TransparencyController = require(script:WaitForChild("TransparencyController"))
  - local MouseLockController = require(script:WaitForChild("MouseLockController"))
Functions: CameraModule.new, CameraModule:GetCameraMovementModeFromSettings, CameraModule:ActivateOcclusionModule, CameraModule:ShouldUseVehicleCamera, CameraModule:ActivateCameraController, CameraModule:OnCameraSubjectChanged, CameraModule:OnCameraTypeChanged, CameraModule:OnCurrentCameraChanged, CameraModule:OnLocalPlayerCameraPropertyChanged, CameraModule:OnUserGameSettingsPropertyChanged, CameraModule:OnPreferredInputChanged, CameraModule:Update, CameraModule:OnCharacterAdded, CameraModule:OnCharacterRemoving, CameraModule:OnPlayerAdded, CameraModule:OnPlayerRemoving, CameraModule:OnMouseLockToggled
Clean source lines: 600
]]
local CameraModule = {}
CameraModule.__index = CameraModule


local PLAYER_CAMERA_PROPERTIES =
{
	"CameraMinZoomDistance",
	"CameraMaxZoomDistance",
	"CameraMode",
	"DevCameraOcclusionMode",
	"DevComputerCameraMode",
	"DevTouchCameraMode",


	"DevComputerMovementMode",
	"DevTouchMovementMode",
	"DevEnableMouseLock",
}

local USER_GAME_SETTINGS_PROPERTIES =
{
	"ComputerCameraMovementMode",
	"ComputerMovementMode",
	"ControlMode",
	"GamepadCameraSensitivity",
	"MouseSensitivity",
	"RotationType",
	"TouchCameraMovementMode",
	"TouchMovementMode",
}


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local CommonUtils = script.Parent:WaitForChild("CommonUtils")
local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))


local CameraUtils = require(script:WaitForChild("CameraUtils"))
local CameraInput = require(script:WaitForChild("CameraInput"))


local ClassicCamera = require(script:WaitForChild("ClassicCamera"))
local OrbitalCamera = require(script:WaitForChild("OrbitalCamera"))
local LegacyCamera = require(script:WaitForChild("LegacyCamera"))
local VehicleCamera = require(script:WaitForChild("VehicleCamera"))

local VRCamera = require(script:WaitForChild("VRCamera"))
local VRVehicleCamera = require(script:WaitForChild("VRVehicleCamera"))


local Invisicam = require(script:WaitForChild("Invisicam"))
local Poppercam = require(script:WaitForChild("Poppercam"))


local TransparencyController = require(script:WaitForChild("TransparencyController"))
local MouseLockController = require(script:WaitForChild("MouseLockController"))


local instantiatedCameraControllers = {}
local instantiatedOcclusionModules = {}

if not Players.LocalPlayer then
	return {}
end
assert(Players.LocalPlayer, "Strict typing check")


do
	local PlayerScripts: PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts") :: PlayerScripts

	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Default)
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Follow)
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Classic)

	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Default)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Follow)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Classic)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.CameraToggle)
end

local FFlagUserPlayerConnectionMemoryLeak = FlagUtil.getUserFlag("UserPlayerConnectionMemoryLeak")
local FFlagUserPSFixCameraControllerReset = FlagUtil.getUserFlag("UserPSFixCameraControllerReset")


type Generic = any
type GenericOptional = any?

type CameraModuleClass = {
	__index: CameraModuleClass,
	new: () -> CameraModule,

	ActivateCameraController: (self: CameraModule) -> (),
	ActivateOcclusionModule: (self: CameraModule, occlusionMode: Enum.DevCameraOcclusionMode) -> (),
	GetCameraMovementModeFromSettings: (self: CameraModule) -> Enum.ComputerCameraMovementMode | Enum.DevComputerCameraMovementMode,
	OnPreferredInputChanged: (self: CameraModule) -> (),
	OnCameraSubjectChanged: (self: CameraModule) -> (),
	OnCameraTypeChanged: (self: CameraModule, newCameraType: Enum.CameraType) -> (),
	OnCharacterAdded: (self: CameraModule, character: Model, player: Player) -> (),
	OnCharacterRemoving: (self: CameraModule, character: Model, player: Player) -> (),
	OnCurrentCameraChanged: (self: CameraModule) -> (),
	OnLocalPlayerCameraPropertyChanged: (self: CameraModule, propertyName: string) -> (),
	OnPlayerAdded: (self: CameraModule, player: Player) -> (),
	OnPlayerRemoving: (self: CameraModule, player: Player) -> (),
	OnMouseLockToggled: (self: CameraModule) -> (),
	OnUserGameSettingsPropertyChanged: (self: CameraModule, propertyName: string) -> (),
	ShouldUseVehicleCamera: (self: CameraModule) -> boolean,
	Update: (self: CameraModule, dt: number) -> (),
}

export type CameraModule = typeof(setmetatable({} :: {
	activeCameraController: GenericOptional,
	activeMouseLockController: GenericOptional,
	activeOcclusionModule: GenericOptional,
	activeTransparencyController: Generic,
	cameraSubjectChangedConn: RBXScriptConnection?,
	cameraTypeChangedConn: RBXScriptConnection?,
	connectionUtil: ConnectionUtil.ConnectionUtil?,
	currentComputerCameraMovementMode: Enum.ComputerCameraMovementMode? | Enum.DevComputerCameraMovementMode?,
	occlusionMode: Enum.DevCameraOcclusionMode?,
}, {} :: CameraModuleClass))

function CameraModule.new()
	local self: CameraModule = setmetatable({
		activeTransparencyController = TransparencyController.new(),
		connectionUtil = if FFlagUserPlayerConnectionMemoryLeak then ConnectionUtil.new() else nil,
	},CameraModule)


	self.activeCameraController = nil
	self.activeOcclusionModule = nil
	self.activeMouseLockController = nil

	self.currentComputerCameraMovementMode = nil


	self.cameraSubjectChangedConn = nil
	self.cameraTypeChangedConn = nil


	for _,player in pairs(Players:GetPlayers()) do
		self:OnPlayerAdded(player)
	end


	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)

	if FFlagUserPlayerConnectionMemoryLeak then
		Players.PlayerRemoving:Connect(function(player)
			self:OnPlayerRemoving(player)
		end)
	end

	self.activeTransparencyController:Enable(true)

	self.activeMouseLockController = MouseLockController.new()
	assert(self.activeMouseLockController, "Strict typing check")

	local toggleEvent = self.activeMouseLockController:GetBindableToggleEvent()
	if toggleEvent then
		toggleEvent:Connect(function()
			self:OnMouseLockToggled()
		end)
	end

	self:ActivateCameraController()
	self:ActivateOcclusionModule(Players.LocalPlayer.DevCameraOcclusionMode)
	self:OnCurrentCameraChanged()
	RunService:BindToRenderStep("cameraRenderUpdate", Enum.RenderPriority.Camera.Value, function(dt) self:Update(dt) end)


	for _, propertyName in pairs(PLAYER_CAMERA_PROPERTIES) do
		Players.LocalPlayer:GetPropertyChangedSignal(propertyName):Connect(function()
			self:OnLocalPlayerCameraPropertyChanged(propertyName)
		end)
	end

	for _, propertyName in pairs(USER_GAME_SETTINGS_PROPERTIES) do
		UserGameSettings:GetPropertyChangedSignal(propertyName):Connect(function()
			self:OnUserGameSettingsPropertyChanged(propertyName)
		end)
	end
	game.Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:OnCurrentCameraChanged()
	end)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		self:OnPreferredInputChanged()
	end)

	return self
end

function CameraModule:GetCameraMovementModeFromSettings(): Enum.ComputerCameraMovementMode | Enum.DevComputerCameraMovementMode
	local cameraMode = Players.LocalPlayer.CameraMode


	if cameraMode == Enum.CameraMode.LockFirstPerson then
		return CameraUtils.ConvertCameraModeEnumToStandard(Enum.ComputerCameraMovementMode.Classic)
	end

	local devMode, userMode
	if UserInputService.PreferredInput == Enum.PreferredInput.Touch then
		devMode = CameraUtils.ConvertCameraModeEnumToStandard(Players.LocalPlayer.DevTouchCameraMode)
		userMode = CameraUtils.ConvertCameraModeEnumToStandard(UserGameSettings.TouchCameraMovementMode)
	else
		devMode = CameraUtils.ConvertCameraModeEnumToStandard(Players.LocalPlayer.DevComputerCameraMode)
		userMode = CameraUtils.ConvertCameraModeEnumToStandard(UserGameSettings.ComputerCameraMovementMode)
	end

	if devMode == Enum.DevComputerCameraMovementMode.UserChoice then

		return userMode
	end

	return devMode
end

function CameraModule:ActivateOcclusionModule(occlusionMode: Enum.DevCameraOcclusionMode)
	local newModuleCreator
	if occlusionMode == Enum.DevCameraOcclusionMode.Zoom then
		newModuleCreator = Poppercam
	elseif occlusionMode == Enum.DevCameraOcclusionMode.Invisicam then
		newModuleCreator = Invisicam
	else
		warn("CameraScript ActivateOcclusionModule called with unsupported mode")
		return
	end

	self.occlusionMode = occlusionMode


	if self.activeOcclusionModule and self.activeOcclusionModule:GetOcclusionMode() == occlusionMode then
		if not self.activeOcclusionModule:GetEnabled() then
			self.activeOcclusionModule:Enable(true)
		end
		return
	end


	local prevOcclusionModule = self.activeOcclusionModule


	self.activeOcclusionModule = instantiatedOcclusionModules[newModuleCreator]


	if not self.activeOcclusionModule then
		self.activeOcclusionModule = newModuleCreator.new()
		if self.activeOcclusionModule then
			instantiatedOcclusionModules[newModuleCreator] = self.activeOcclusionModule
		end
	end


	if self.activeOcclusionModule then
		local newModuleOcclusionMode = self.activeOcclusionModule:GetOcclusionMode()

		if newModuleOcclusionMode ~= occlusionMode then
			warn("CameraScript ActivateOcclusionModule mismatch: ",self.activeOcclusionModule:GetOcclusionMode(),"~=",occlusionMode)
		end


		if prevOcclusionModule then

			if prevOcclusionModule ~= self.activeOcclusionModule then
				prevOcclusionModule:Enable(false)
			else
				warn("CameraScript ActivateOcclusionModule failure to detect already running correct module")
			end
		end


		if occlusionMode == Enum.DevCameraOcclusionMode.Invisicam then

			if Players.LocalPlayer.Character then
				self.activeOcclusionModule:CharacterAdded(Players.LocalPlayer.Character, Players.LocalPlayer )
			end
		else

			for _, player in pairs(Players:GetPlayers()) do
				if player and player.Character then
					self.activeOcclusionModule:CharacterAdded(player.Character, player)
				end
			end
			self.activeOcclusionModule:OnCameraSubjectChanged((game.Workspace.CurrentCamera :: Camera).CameraSubject)
		end


		self.activeOcclusionModule:Enable(true)
	end
end

function CameraModule:ShouldUseVehicleCamera(): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end

	local cameraType = camera.CameraType
	local cameraSubject = camera.CameraSubject

	local isEligibleType = cameraType == Enum.CameraType.Custom or cameraType == Enum.CameraType.Follow
	local isEligibleSubject = cameraSubject and cameraSubject:IsA("VehicleSeat") or false
	local isEligibleOcclusionMode = self.occlusionMode ~= Enum.DevCameraOcclusionMode.Invisicam

	return isEligibleSubject and isEligibleType and isEligibleOcclusionMode
end

function CameraModule:ActivateCameraController()

	local legacyCameraType = (workspace.CurrentCamera :: Camera).CameraType
	local cameraMovementMode = self:GetCameraMovementModeFromSettings()
	local newCameraCreator = nil


	if legacyCameraType == Enum.CameraType.Scriptable then
		if self.activeCameraController then
			self.activeCameraController:Enable(false)
			self.activeCameraController = nil
		end
		return
	elseif legacyCameraType == Enum.CameraType.Custom then
		cameraMovementMode = self:GetCameraMovementModeFromSettings()
	elseif legacyCameraType == Enum.CameraType.Track then


		cameraMovementMode = Enum.ComputerCameraMovementMode.Classic
	elseif legacyCameraType == Enum.CameraType.Follow then
		cameraMovementMode = Enum.ComputerCameraMovementMode.Follow
	elseif legacyCameraType == Enum.CameraType.Orbital then
		cameraMovementMode = Enum.ComputerCameraMovementMode.Orbital
	elseif
		legacyCameraType == Enum.CameraType.Attach
		or legacyCameraType == Enum.CameraType.Watch
		or legacyCameraType == Enum.CameraType.Fixed
	then
		newCameraCreator = LegacyCamera
	else
		warn("CameraScript encountered an unhandled Camera.CameraType value: ", legacyCameraType)
	end

	if not newCameraCreator then
		if VRService.VREnabled then
			newCameraCreator = VRCamera
		elseif cameraMovementMode == Enum.ComputerCameraMovementMode.Classic or
			cameraMovementMode == Enum.ComputerCameraMovementMode.Follow or
			cameraMovementMode == Enum.ComputerCameraMovementMode.Default or
			cameraMovementMode == Enum.ComputerCameraMovementMode.CameraToggle then
			newCameraCreator = ClassicCamera
		elseif cameraMovementMode == Enum.ComputerCameraMovementMode.Orbital then
			newCameraCreator = OrbitalCamera
		else
			warn("ActivateCameraController did not select a module.")
			return
		end
	end

	local isVehicleCamera = self:ShouldUseVehicleCamera()
	if isVehicleCamera then
		if VRService.VREnabled then
			newCameraCreator = VRVehicleCamera
		else
			newCameraCreator = VehicleCamera
		end
	end


	local newCameraController
	if not instantiatedCameraControllers[newCameraCreator] then
		newCameraController = newCameraCreator.new()
		instantiatedCameraControllers[newCameraCreator] = newCameraController
	else
		newCameraController = instantiatedCameraControllers[newCameraCreator]
		if FFlagUserPSFixCameraControllerReset then
			if newCameraController.Reset and self.activeCameraController ~= newCameraController then
				newCameraController:Reset()
			end
		else
			if newCameraController.Reset then
				newCameraController:Reset()
			end
		end
	end

	if self.activeCameraController then

		if self.activeCameraController ~= newCameraController then
			self.activeCameraController:Enable(false)
			self.activeCameraController = newCameraController
			self.activeCameraController:Enable(true)
		elseif not self.activeCameraController:GetEnabled() then
			self.activeCameraController:Enable(true)
		end
	elseif newCameraController ~= nil then

		self.activeCameraController = newCameraController
		assert(self.activeCameraController, "Strict typing check")

		self.activeCameraController:Enable(true)
	end

	if self.activeCameraController then


		self.activeCameraController:SetCameraMovementMode(cameraMovementMode)

		self.activeCameraController:SetCameraType(legacyCameraType)
	end
end


function CameraModule:OnCameraSubjectChanged()
	local camera = workspace.CurrentCamera
	local cameraSubject = if camera then camera.CameraSubject else nil

	if self.activeTransparencyController then
		self.activeTransparencyController:SetSubject(cameraSubject)
	end

	if self.activeOcclusionModule then
		self.activeOcclusionModule:OnCameraSubjectChanged(cameraSubject)
	end

	self:ActivateCameraController()
end

function CameraModule:OnCameraTypeChanged(newCameraType: Enum.CameraType)
	if newCameraType == Enum.CameraType.Scriptable then
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			CameraUtils.restoreMouseBehavior()
		end
	end


	self:ActivateCameraController()
end


function CameraModule:OnCurrentCameraChanged()
	local currentCamera = game.Workspace.CurrentCamera
	if not currentCamera then return end

	if self.cameraSubjectChangedConn then
		self.cameraSubjectChangedConn:Disconnect()
	end

	if self.cameraTypeChangedConn then
		self.cameraTypeChangedConn:Disconnect()
	end

	self.cameraSubjectChangedConn = currentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
		self:OnCameraSubjectChanged()
	end)

	self.cameraTypeChangedConn = currentCamera:GetPropertyChangedSignal("CameraType"):Connect(function()
		self:OnCameraTypeChanged(currentCamera.CameraType)
	end)

	self:OnCameraSubjectChanged()
	self:OnCameraTypeChanged(currentCamera.CameraType)
end

function CameraModule:OnLocalPlayerCameraPropertyChanged(propertyName: string)
	if propertyName == "CameraMode" then


		if Players.LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then

			if not self.activeCameraController or self.activeCameraController:GetModuleName() ~= "ClassicCamera" then
				self:ActivateCameraController()
			end

			if self.activeCameraController then
				self.activeCameraController:UpdateForDistancePropertyChange()
			end
		elseif Players.LocalPlayer.CameraMode == Enum.CameraMode.Classic then

			self:ActivateCameraController()
		else
			warn("Unhandled value for property player.CameraMode: ",Players.LocalPlayer.CameraMode)
		end

	elseif propertyName == "DevComputerCameraMode" or
		   propertyName == "DevTouchCameraMode" then
		self:ActivateCameraController()

	elseif propertyName == "DevCameraOcclusionMode" then
		self:ActivateOcclusionModule(Players.LocalPlayer.DevCameraOcclusionMode)

	elseif propertyName == "CameraMinZoomDistance" or propertyName == "CameraMaxZoomDistance" then
		if self.activeCameraController then
			self.activeCameraController:UpdateForDistancePropertyChange()
		end
	elseif propertyName == "DevTouchMovementMode" then
	elseif propertyName == "DevComputerMovementMode" then
	elseif propertyName == "DevEnableMouseLock" then


	end
end

function CameraModule:OnUserGameSettingsPropertyChanged(propertyName: string)
	if propertyName == "ComputerCameraMovementMode" or propertyName == "TouchCameraMovementMode" then
		self:ActivateCameraController()
	end
end

function CameraModule:OnPreferredInputChanged()
	self:ActivateCameraController()
end


function CameraModule:Update(dt)
	if self.activeCameraController then
		self.activeCameraController:UpdateMouseBehavior()

		local newCameraCFrame, newCameraFocus = self.activeCameraController:Update(dt)

		if self.activeOcclusionModule then
			newCameraCFrame, newCameraFocus = self.activeOcclusionModule:Update(dt, newCameraCFrame, newCameraFocus)
		end


		local currentCamera = game.Workspace.CurrentCamera :: Camera
		currentCamera.CFrame = newCameraCFrame
		currentCamera.Focus = newCameraFocus


		if self.activeTransparencyController then
			self.activeTransparencyController:Update(dt)
		end

		if CameraInput.getInputEnabled() then
			CameraInput.resetInputForFrameEnd()
		end
	end
end

function CameraModule:OnCharacterAdded(char: Model, player: Player)
	if self.activeOcclusionModule then
		self.activeOcclusionModule:CharacterAdded(char, player)
	end
end

function CameraModule:OnCharacterRemoving(char, player)
	if self.activeOcclusionModule then
		self.activeOcclusionModule:CharacterRemoving(char, player)
	end
end

function CameraModule:OnPlayerAdded(player: Player)
	if FFlagUserPlayerConnectionMemoryLeak then

		if self.connectionUtil then
			self.connectionUtil:trackConnection(`{player.UserId}CharacterAdded`, player.CharacterAdded:Connect(function(char)
				self:OnCharacterAdded(char, player)
			end))
			self.connectionUtil:trackConnection(`{player.UserId}CharacterRemoving`, player.CharacterRemoving:Connect(function(char)
				self:OnCharacterRemoving(char, player)
			end))
		end
	else
		player.CharacterAdded:Connect(function(char)
			self:OnCharacterAdded(char, player)
		end)
		player.CharacterRemoving:Connect(function(char)
			self:OnCharacterRemoving(char, player)
		end)
	end
end

function CameraModule:OnPlayerRemoving(player: Player)

	if self.connectionUtil then
		self.connectionUtil:disconnect(`{player.UserId}CharacterAdded`)
		self.connectionUtil:disconnect(`{player.UserId}CharacterRemoving`)
	end
end

function CameraModule:OnMouseLockToggled()
	if self.activeMouseLockController then
		local mouseLocked = self.activeMouseLockController:GetIsMouseLocked()
		local mouseLockOffset = self.activeMouseLockController:GetMouseLockOffset()
		if self.activeCameraController then
			self.activeCameraController:SetIsMouseLocked(mouseLocked)
			self.activeCameraController:SetMouseLockOffset(mouseLockOffset)
		end
	end
end

CameraModule.new()

return {}
