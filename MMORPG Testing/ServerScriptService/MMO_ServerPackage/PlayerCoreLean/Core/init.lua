--[[
Name: Core
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.PlayerCoreLean.Core
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, Workspace, RunService, ServerStorage, PhysicsService
Requires:
  - C.ProfileService   = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
  - C.AbilityRegistry  = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("AbilityRegistry"))
  - C.RS               = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
  - C.TargetTypes      = require(C.ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("TargetTypes"))
  - C.SpatialGrid      = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("SpatialGrid"))
  - C.CombatLocks      = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("CombatLocks"))
  - C.MountInfo        = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("MountInfo"))
  - C.HumanoidStatsMod = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("HumanoidStats"))
  - C.MountHelper      = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("MountHelper"))
  - C.AbilityCore      = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))
Functions: ensure, setPart, indexNPC, unindexNPC, _buildModuleIndex, walk, _joinPath, _recurseEquip, C.SetupCollisionGroups, C.SetModelGroup, C.InitNPCIndex, C.toServerModel, C.resolveTarget, C.BuildEquipmentIndex, C.GetEquipmentModule, C.BuildLootIndex, C.GetLootModule, C.GetItemModule
Signal classes referenced: BindableEvent
Clean source lines: 263
]]
local C = {}


C.Players           = game:GetService("Players")
C.ReplicatedStorage = game:GetService("ReplicatedStorage")
C.Workspace         = game:GetService("Workspace")
C.RunService        = game:GetService("RunService")
C.ServerStorage     = game:GetService("ServerStorage")
C.PhysicsService    = game:GetService("PhysicsService")


local RemoteEvents       = C.ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")
C.AttackTarget           = RemoteEvents:WaitForChild("AttackTarget")
C.MountStatusEvent       = RemoteEvents:WaitForChild("MountStatus")
C.UpdateBasicCooldown    = RemoteEvents:WaitForChild("UpdateBasicCooldown")
C.UpdateBasicRange       = RemoteEvents:WaitForChild("UpdateBasicRange")
C.UpdateHorseStatus      = RemoteEvents:WaitForChild("UpdateHorseStatus")
C.CurrentHorseEvent      = RemoteEvents:WaitForChild("CurrentHorse")

local BindableFunctions  = C.ServerStorage:WaitForChild("MMO_ServerStoragePackage"):WaitForChild("BindableFunctions")
C.GetPlayerMountBF       = BindableFunctions:WaitForChild("GetPlayerMount")

local serverStoragePackage = C.ServerStorage:WaitForChild("MMO_ServerStoragePackage")
local beFolder = serverStoragePackage:FindFirstChild("BindableEvents")
if not beFolder then beFolder = Instance.new("Folder"); beFolder.Name = "BindableEvents"; beFolder.Parent = serverStoragePackage end
C.BEFolder = beFolder
local threat = beFolder:FindFirstChild("ThreatBump")
if not threat then threat = Instance.new("BindableEvent"); threat.Name = "ThreatBump"; threat.Parent = beFolder end
C.ThreatBump = threat


C.NPCSimFolder = C.ServerStorage:FindFirstChild("NPCSim")
if not C.NPCSimFolder then C.NPCSimFolder = Instance.new("Folder"); C.NPCSimFolder.Name = "NPCSim"; C.NPCSimFolder.Parent = C.ServerStorage end

C.EquipmentFolder = script.Parent:FindFirstChild("Equipment")
	or script.Parent.Parent:FindFirstChild("Equipment")
	or game.ServerScriptService:WaitForChild("MMO_ServerPackage"):FindFirstChild("Equipment")
	or C.ServerStorage:FindFirstChild("Equipment")

C.ProfileService   = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))


C.AbilityRegistry  = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("AbilityRegistry"))
C.RS               = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("RelationshipService"))
C.TargetTypes      = require(C.ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("TargetTypes"))
C.SpatialGrid      = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("SpatialGrid"))
C.CombatLocks      = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("CombatLocks"))
C.MountInfo        = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("MountInfo"))
C.HumanoidStatsMod = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("HumanoidStats"))
C.MountHelper      = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("MountHelper"))
C.AbilityCore      = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("Abilities"):WaitForChild("AbilityCore"))

C.updateMountHealthBar = C.MountHelper.updateMountHealthBar
C.forceDismount        = C.MountHelper.forceDismount
C.abortMounting        = C.MountHelper.abortMounting


C.humanoidStats     = C.HumanoidStatsMod.humanoidStats or {}
C.playerAttackCooldowns = {}
C.castLockUntil     = C.CombatLocks.CastLockUntil
C.gcdUntil          = C.CombatLocks.GCDUntil
C.moveSlowUntil     = {}
C.moveSlowFactor    = {}
C.nextBasicAllowed  = {}
C.GUID_TO_NPC       = {}


local function ensure(name)
	pcall(function() C.PhysicsService:RegisterCollisionGroup(name) end)
end
function C.SetupCollisionGroups()
	ensure("Character"); ensure("Horse")
	pcall(function() C.PhysicsService:CollisionGroupSetCollidable("Character","Character", false) end)
	pcall(function() C.PhysicsService:CollisionGroupSetCollidable("Character","Horse",     false) end)
end
function C.SetModelGroup(model, groupName)
	if not model then return end
	local function setPart(inst)
		if inst:IsA("BasePart") then inst.CollisionGroup = groupName end
	end
	for _, d in ipairs(model:GetDescendants()) do setPart(d) end
	model.DescendantAdded:Connect(setPart)
end


local function indexNPC(m)
	if m and m:IsA("Model") then
		local g = m:GetAttribute("RelationId")
		if g then C.GUID_TO_NPC[g] = m end
	end
end
local function unindexNPC(m)
	if m and m:IsA("Model") then
		local g = m:GetAttribute("RelationId")
		if g and C.GUID_TO_NPC[g] == m then C.GUID_TO_NPC[g] = nil end
	end
end
function C.InitNPCIndex()
	for _, m in ipairs(C.NPCSimFolder:GetChildren()) do indexNPC(m) end
	C.NPCSimFolder.ChildAdded:Connect(indexNPC)
	C.NPCSimFolder.ChildRemoved:Connect(unindexNPC)
end
function C.toServerModel(any)
	if typeof(any) == "Instance" then
		if any:IsA("Model") and C.humanoidStats[any] then return any end
		local m = any:IsA("Model") and any or any:FindFirstChildOfClass("Model")
		if m then
			local g = m:GetAttribute("RelationId")
			if g and C.GUID_TO_NPC[g] then return C.GUID_TO_NPC[g] end
		end
		return any
	end
	if typeof(any) == "table" and any.Guid and C.GUID_TO_NPC[any.Guid] then return C.GUID_TO_NPC[any.Guid] end
	if type(any) == "string" and C.GUID_TO_NPC[any] then return C.GUID_TO_NPC[any] end
	return any
end
function C.resolveTarget(model)
	local rider = C.MountInfo.horseToPlayer[model]
	if rider and rider.Character then return rider.Character end
	return model
end


C.LootRoot = game.ServerScriptService:WaitForChild("MMO_ServerPackage"):FindFirstChild("Loot")


local function _buildModuleIndex(rootFolder: Instance?)
	if not rootFolder then return { byPath = {}, byName = {} } end

	local byPath, byName = {}, {}
	local function walk(folder: Instance, pathParts: {string})
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Folder") then
				table.insert(pathParts, child.Name)
				walk(child, pathParts)
				table.remove(pathParts)
			elseif child:IsA("ModuleScript") then
				local fullPath = table.concat(pathParts, "/")
				local id = (#fullPath > 0) and (fullPath .. "/" .. child.Name) or child.Name


				local ok, mod = pcall(require, child)
				if ok then
					byPath[id] = mod

					if byName[child.Name] == nil then
						byName[child.Name] = mod
					else
						byName[child.Name] = false
					end
				else
					warn(("[Index] Failed require: %s"):format(child:GetFullName()))
				end
			end
		end
	end
	walk(rootFolder, {})
	return { byPath = byPath, byName = byName }
end


C._equipmentIndex = C._equipmentIndex or { byPath = {}, byName = {} }
function C.BuildEquipmentIndex()
	C._equipmentIndex = _buildModuleIndex(C.EquipmentFolders)
end
function C.GetEquipmentModule(id: string?)
	if not id then return nil end
	local e = C._equipmentIndex
	return e.byPath[id] or (e.byName[id] ~= false and e.byName[id]) or nil
end


C._lootIndex = C._lootIndex or { byPath = {}, byName = {} }
function C.BuildLootIndex()
	C._lootIndex = _buildModuleIndex(C.LootRoot)
end
function C.GetLootModule(id: string?)
	if not id then return nil end
	local L = C._lootIndex
	return L.byPath[id] or (L.byName[id] ~= false and L.byName[id]) or nil
end


function C.GetItemModule(id: string?)
	return C.GetEquipmentModule(id) or C.GetLootModule(id)
end


C._EquipByIdLC = {}

C._EquipByNameLC = {}

local function _joinPath(parts)
	return table.concat(parts, "/")
end

local function _recurseEquip(folder, prefixParts)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local idParts = table.clone(prefixParts)
			table.insert(idParts, child.Name)
			local id = _joinPath(idParts)
			local idLC = string.lower(id)

			local ok, mod = pcall(require, child)
			if ok and mod then
				C._EquipByIdLC[idLC] = mod

				local baseLC = string.lower(child.Name)
				C._EquipByNameLC[baseLC] = C._EquipByNameLC[baseLC] or {}
				table.insert(C._EquipByNameLC[baseLC], idLC)
			else
				warn("Failed to require equipment module: " .. child:GetFullName())
			end
		elseif child:IsA("Folder") then
			local nextParts = table.clone(prefixParts)
			table.insert(nextParts, child.Name)
			_recurseEquip(child, nextParts)
		end
	end
end

function C.BuildEquipmentIndex()
	C._EquipByIdLC = {}
	C._EquipByNameLC = {}
	local root = C.EquipmentFolder
	if not root then
		warn("[Equipment] Root folder not found.")
		return
	end
	_recurseEquip(root, {})
end


function C.GetEquipmentModule(idOrName)
	if not idOrName or type(idOrName) ~= "string" then return nil end
	local s = string.lower(idOrName)


	if C._EquipByIdLC[s] then return C._EquipByIdLC[s] end


	local list = C._EquipByNameLC[s]
	if list and #list == 1 then
		return C._EquipByIdLC[list[1]]
	elseif list and #list > 1 then
		warn(("[Equipment] Ambiguous name '%s' matches multiple modules: %s. Prefer a full path e.g. 'Category/Subcategory/%s'.")
			:format(idOrName, table.concat(list, ", "), idOrName))
		return C._EquipByIdLC[list[1]]
	end


	for idLC, mod in pairs(C._EquipByIdLC) do
		if string.sub(idLC, -#s) == s then
			return mod
		end
	end

	return nil
end

return C
