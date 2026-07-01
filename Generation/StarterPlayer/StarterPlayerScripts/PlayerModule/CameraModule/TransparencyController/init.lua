--[[
Name: TransparencyController
Class: ModuleScript
Original path: game.StarterPlayer.StarterPlayerScripts.PlayerModule.CameraModule.TransparencyController
Exported from: Generation
Original comments: removed
Children: 0
Properties: Archivable=false, LinkedSource=""
Services: VRService
Requires:
  - local Util = require(script.Parent:WaitForChild("CameraUtils"))
Functions: TransparencyController.new, TransparencyController:HasToolAncestor, TransparencyController:IsValidPartToModify, TransparencyController:CachePartsRecursive, TransparencyController:TeardownTransparency, TransparencyController:SetupTransparency, TransparencyController:Enable, TransparencyController:SetSubject, TransparencyController:Update
Clean source lines: 223
]]
local VRService = game:GetService("VRService")
local MAX_TWEEN_RATE = 2.8


local HIDE_IN_FIRST_PERSON_CLASSES = {
	"BasePart",
	"Decal",
	"Beam",
	"ParticleEmitter",
	"Trail",
	"Fire",
	"Smoke",
	"Sparkles",
	"Explosion"
}

local Util = require(script.Parent:WaitForChild("CameraUtils"))

local FFlagUserHideCharacterParticlesInFirstPerson
do
	local success, result = pcall(function()
		return UserSettings():IsUserFeatureEnabled("UserHideCharacterParticlesInFirstPerson")
	end)
	FFlagUserHideCharacterParticlesInFirstPerson = success and result
end


local TransparencyController = {}
TransparencyController.__index = TransparencyController

function TransparencyController.new()
	local self = setmetatable({}, TransparencyController)

	self.transparencyDirty = false
	self.enabled = false
	self.lastTransparency = nil

	self.descendantAddedConn, self.descendantRemovingConn = nil, nil
	self.toolDescendantAddedConns = {}
	self.toolDescendantRemovingConns = {}
	self.cachedParts = {}

	return self
end


function TransparencyController:HasToolAncestor(object: Instance)
	if object.Parent == nil then return false end
	assert(object.Parent, "")
	return object.Parent:IsA('Tool') or self:HasToolAncestor(object.Parent)
end

function TransparencyController:IsValidPartToModify(part: BasePart)
	if FFlagUserHideCharacterParticlesInFirstPerson then
		for _, className in HIDE_IN_FIRST_PERSON_CLASSES do
			if part:IsA(className) then
				return not self:HasToolAncestor(part)
			end
		end
	else
		if part:IsA('BasePart') or part:IsA('Decal') then
			return not self:HasToolAncestor(part)
		end
	end
	return false
end


function TransparencyController:CachePartsRecursive(object)
	if object then
		if self:IsValidPartToModify(object) then
			self.cachedParts[object] = true
			self.transparencyDirty = true
		end
		for _, child in pairs(object:GetChildren()) do
			self:CachePartsRecursive(child)
		end
	end
end

function TransparencyController:TeardownTransparency()
	for child, _ in pairs(self.cachedParts) do
		child.LocalTransparencyModifier = 0
	end
	self.cachedParts = {}
	self.transparencyDirty = true
	self.lastTransparency = nil

	if self.descendantAddedConn then
		self.descendantAddedConn:disconnect()
		self.descendantAddedConn = nil
	end
	if self.descendantRemovingConn then
		self.descendantRemovingConn:disconnect()
		self.descendantRemovingConn = nil
	end
	for object, conn in pairs(self.toolDescendantAddedConns) do
		conn:Disconnect()
		self.toolDescendantAddedConns[object] = nil
	end
	for object, conn in pairs(self.toolDescendantRemovingConns) do
		conn:Disconnect()
		self.toolDescendantRemovingConns[object] = nil
	end
end

function TransparencyController:SetupTransparency(character)
	self:TeardownTransparency()

	if self.descendantAddedConn then self.descendantAddedConn:disconnect() end
	self.descendantAddedConn = character.DescendantAdded:Connect(function(object)

		if self:IsValidPartToModify(object) then
			self.cachedParts[object] = true
			self.transparencyDirty = true

		elseif object:IsA('Tool') then
			if self.toolDescendantAddedConns[object] then self.toolDescendantAddedConns[object]:Disconnect() end
			self.toolDescendantAddedConns[object] = object.DescendantAdded:Connect(function(toolChild)
				self.cachedParts[toolChild] = nil
				if toolChild:IsA('BasePart') or toolChild:IsA('Decal') then

					toolChild.LocalTransparencyModifier = 0
				end
			end)
			if self.toolDescendantRemovingConns[object] then self.toolDescendantRemovingConns[object]:disconnect() end
			self.toolDescendantRemovingConns[object] = object.DescendantRemoving:Connect(function(formerToolChild)
				wait()
				if character and formerToolChild and formerToolChild:IsDescendantOf(character) then
					if self:IsValidPartToModify(formerToolChild) then
						self.cachedParts[formerToolChild] = true
						self.transparencyDirty = true
					end
				end
			end)
		end
	end)
	if self.descendantRemovingConn then self.descendantRemovingConn:disconnect() end
	self.descendantRemovingConn = character.DescendantRemoving:connect(function(object)
		if self.cachedParts[object] then
			self.cachedParts[object] = nil

			object.LocalTransparencyModifier = 0
		end
	end)
	self:CachePartsRecursive(character)
end


function TransparencyController:Enable(enable: boolean)
	if self.enabled ~= enable then
		self.enabled = enable
	end
end

function TransparencyController:SetSubject(subject)
	local character = nil
	if subject and subject:IsA("Humanoid") then
		character = subject.Parent
	end
	if subject and subject:IsA("VehicleSeat") and subject.Occupant then
		character = subject.Occupant.Parent
	end
	if character then
		self:SetupTransparency(character)
	else
		self:TeardownTransparency()
	end
end

function TransparencyController:Update(dt)
	local currentCamera = workspace.CurrentCamera

	if currentCamera and self.enabled then

		local distance = (currentCamera.Focus.p - currentCamera.CoordinateFrame.p).magnitude
		local transparency = (distance<2) and (1.0-(distance-0.5)/1.5) or 0
		if transparency < 0.5 then
			transparency = 0
		end


		if self.lastTransparency and transparency < 1 and self.lastTransparency < 0.95 then
			local deltaTransparency = transparency - self.lastTransparency
			local maxDelta = MAX_TWEEN_RATE * dt
			deltaTransparency = math.clamp(deltaTransparency, -maxDelta, maxDelta)
			transparency = self.lastTransparency + deltaTransparency
		else
			self.transparencyDirty = true
		end

		transparency = math.clamp(Util.Round(transparency, 2), 0, 1)


		if self.transparencyDirty or self.lastTransparency ~= transparency then
			for child, _ in pairs(self.cachedParts) do
				if VRService.VREnabled and VRService.AvatarGestures then

					local hiddenAccessories = {
						    [Enum.AccessoryType.Hat] = true,
    						[Enum.AccessoryType.Hair] = true,
    						[Enum.AccessoryType.Face] = true,
    						[Enum.AccessoryType.Eyebrow] = true,
 						   [Enum.AccessoryType.Eyelash] = true,
					}
					if (child.Parent:IsA("Accessory") and hiddenAccessories[child.Parent.AccessoryType]) or child.Name == "Head" then
						child.LocalTransparencyModifier = transparency
					else

						child.LocalTransparencyModifier = 0
					end
				else
					child.LocalTransparencyModifier = transparency
				end
			end
			self.transparencyDirty = false
			self.lastTransparency = transparency
		end
	end
end

return TransparencyController
