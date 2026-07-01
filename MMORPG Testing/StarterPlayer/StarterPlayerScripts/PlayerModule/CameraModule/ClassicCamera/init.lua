--[[
Name: ClassicCamera
Class: ModuleScript
Original path: game.StarterPlayer.StarterPlayerScripts.PlayerModule.CameraModule.ClassicCamera
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=false, LinkedSource=""
Services: Players
Requires:
  - local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
  - local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
  - local Util = require(script.Parent:WaitForChild("CameraUtils"))
  - local BaseCamera = require(script.Parent:WaitForChild("BaseCamera"))
Functions: ClassicCamera.new, ClassicCamera:GetCameraToggleOffset, ClassicCamera:SetCameraMovementMode, ClassicCamera:Update
Clean source lines: 218
]]
local ZERO_VECTOR2 = Vector2.new(0,0)

local tweenAcceleration = math.rad(220)
local tweenSpeed = math.rad(0)
local tweenMaxSpeed = math.rad(250)
local TIME_BEFORE_AUTO_ROTATE = 2

local INITIAL_CAMERA_ANGLE = CFrame.fromOrientation(math.rad(-15), 0, 0)
local ZOOM_SENSITIVITY_CURVATURE = 0.5
local FIRST_PERSON_DISTANCE_MIN = 0.5

local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))

local FFlagUserFixCameraFPError = FlagUtil.getUserFlag("UserFixCameraFPError")


local PlayersService = game:GetService("Players")

local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local Util = require(script.Parent:WaitForChild("CameraUtils"))


local BaseCamera = require(script.Parent:WaitForChild("BaseCamera"))
local ClassicCamera = setmetatable({}, BaseCamera)
ClassicCamera.__index = ClassicCamera

function ClassicCamera.new()
	local self = setmetatable(BaseCamera.new(), ClassicCamera)

	self.isFollowCamera = false
	self.isCameraToggle = false
	self.lastUpdate = tick()
	self.cameraToggleSpring = Util.Spring.new(5, 0)

	return self
end

function ClassicCamera:GetCameraToggleOffset(dt: number)
	if self.isCameraToggle then
		local zoom = self.currentSubjectDistance

		if CameraInput.getTogglePan() then
			self.cameraToggleSpring.goal = math.clamp(Util.map(zoom, 0.5, self.FIRST_PERSON_DISTANCE_THRESHOLD, 0, 1), 0, 1)
		else
			self.cameraToggleSpring.goal = 0
		end

		local distanceOffset: number = math.clamp(Util.map(zoom, 0.5, 64, 0, 1), 0, 1) + 1
		return Vector3.new(0, self.cameraToggleSpring:step(dt)*distanceOffset, 0)
	end

	return Vector3.new()
end


function ClassicCamera:SetCameraMovementMode(cameraMovementMode: Enum.ComputerCameraMovementMode)
	BaseCamera.SetCameraMovementMode(self, cameraMovementMode)

	self.isFollowCamera = cameraMovementMode == Enum.ComputerCameraMovementMode.Follow
	self.isCameraToggle = cameraMovementMode == Enum.ComputerCameraMovementMode.CameraToggle
end

function ClassicCamera:Update(dt)
	local now = tick()

	local camera = workspace.CurrentCamera
	local newCameraCFrame = camera.CFrame
	local newCameraFocus = camera.Focus

	local overrideCameraLookVector = nil
	if self.resetCameraAngle then
		local rootPart: BasePart = self:GetHumanoidRootPart()
		if rootPart then
			overrideCameraLookVector = (rootPart.CFrame * INITIAL_CAMERA_ANGLE).lookVector
		else
			overrideCameraLookVector = INITIAL_CAMERA_ANGLE.lookVector
		end
		self.resetCameraAngle = false
	end

	local player = PlayersService.LocalPlayer
	local humanoid = self:GetHumanoid()
	local cameraSubject = camera.CameraSubject
	local isInVehicle = cameraSubject and cameraSubject:IsA("VehicleSeat")
	local isOnASkateboard = cameraSubject and cameraSubject:IsA("SkateboardPlatform")
	local isClimbing = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Climbing

	if self.lastUpdate == nil or dt > 1 then
		self.lastCameraTransform = nil
	end

	local rotateInput = CameraInput.getRotation(dt)

	self:StepZoom()

	local cameraHeight = self:GetCameraHeight()


	if rotateInput ~= Vector2.new() then
		tweenSpeed = 0
		self.lastUserPanCamera = tick()
	end

	local userRecentlyPannedCamera = now - self.lastUserPanCamera < TIME_BEFORE_AUTO_ROTATE
	local subjectPosition: Vector3 = self:GetSubjectPosition()

	if subjectPosition and player and camera then
		local zoom = self:GetCameraToSubjectDistance()
		if zoom < 0.5 then
			zoom = 0.5
		end

		if self:GetIsMouseLocked() and not self:IsInFirstPerson() then

			local newLookCFrame: CFrame = self:CalculateNewLookCFrameFromArg(overrideCameraLookVector, rotateInput)

			local offset: Vector3 = self:GetMouseLockOffset()

			if humanoid then
				offset += humanoid.CameraOffset
			end
			local cameraRelativeOffset: Vector3 = offset.X * newLookCFrame.RightVector + offset.Y * newLookCFrame.UpVector + offset.Z * newLookCFrame.LookVector


			if Util.IsFiniteVector3(cameraRelativeOffset) then
				subjectPosition = subjectPosition + cameraRelativeOffset
			end
		else
			local userPanningTheCamera = rotateInput ~= Vector2.new()

			if not userPanningTheCamera and self.lastCameraTransform then

				local isInFirstPerson = self:IsInFirstPerson()

				if (isInVehicle or isOnASkateboard or (self.isFollowCamera and isClimbing)) and self.lastUpdate and humanoid and humanoid.Torso then
					if isInFirstPerson then
						if self.lastSubjectCFrame and (isInVehicle or isOnASkateboard) and cameraSubject:IsA("BasePart") then
							local y = -Util.GetAngleBetweenXZVectors(self.lastSubjectCFrame.lookVector, cameraSubject.CFrame.lookVector)
							if Util.IsFinite(y) then
								rotateInput = rotateInput + Vector2.new(y, 0)
							end
							tweenSpeed = 0
						end
					elseif not userRecentlyPannedCamera then
						local forwardVector = humanoid.Torso.CFrame.lookVector
						tweenSpeed = math.clamp(tweenSpeed + tweenAcceleration * dt, 0, tweenMaxSpeed)

						local percent = math.clamp(tweenSpeed * dt, 0, 1)
						if self:IsInFirstPerson() and not (self.isFollowCamera and self.isClimbing) then
							percent = 1
						end

						local y = Util.GetAngleBetweenXZVectors(forwardVector, self:GetCameraLookVector())
						if Util.IsFinite(y) and math.abs(y) > 0.0001 then
							rotateInput = rotateInput + Vector2.new(y * percent, 0)
						end
					end

				elseif self.isFollowCamera and not (isInFirstPerson or userRecentlyPannedCamera) then

					local lastVec = -(self.lastCameraTransform.p - subjectPosition)

					local y = Util.GetAngleBetweenXZVectors(lastVec, self:GetCameraLookVector())


					local thetaCutoff = 0.4


					if Util.IsFinite(y) and math.abs(y) > 0.0001 and math.abs(y) > thetaCutoff * dt then
						rotateInput = rotateInput + Vector2.new(y, 0)
					end
				end
			end
		end

		if not self.isFollowCamera then
			newCameraFocus = CFrame.new(subjectPosition)

			local cameraFocusP = newCameraFocus.p
			local newLookVector = self:CalculateNewLookVectorFromArg(overrideCameraLookVector, rotateInput)

			if FFlagUserFixCameraFPError then
				newCameraCFrame = CFrame.lookAlong(cameraFocusP - (zoom * newLookVector), newLookVector)
			else
				newCameraCFrame = CFrame.new(cameraFocusP - (zoom * newLookVector), cameraFocusP)
			end
		else
			local newLookVector = self:CalculateNewLookVectorFromArg(overrideCameraLookVector, rotateInput)

			newCameraFocus = CFrame.new(subjectPosition)

			if FFlagUserFixCameraFPError then
				newCameraCFrame = CFrame.lookAlong(newCameraFocus.p - (zoom * newLookVector), newLookVector)
			else
				newCameraCFrame = CFrame.new(newCameraFocus.p - (zoom * newLookVector), newCameraFocus.p) + Vector3.new(0, cameraHeight, 0)
			end
		end

		local toggleOffset = self:GetCameraToggleOffset(dt)
		newCameraFocus = newCameraFocus + toggleOffset
		newCameraCFrame = newCameraCFrame + toggleOffset

		self.lastCameraTransform = newCameraCFrame
		self.lastCameraFocus = newCameraFocus
		if (isInVehicle or isOnASkateboard) and cameraSubject:IsA("BasePart") then
			self.lastSubjectCFrame = cameraSubject.CFrame
		else
			self.lastSubjectCFrame = nil
		end
	end

	self.lastUpdate = now
	return newCameraCFrame, newCameraFocus
end

return ClassicCamera
