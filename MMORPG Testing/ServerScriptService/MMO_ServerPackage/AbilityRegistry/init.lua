--[[
Name: AbilityRegistry
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.AbilityRegistry
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ServerScriptService, ReplicatedStorage
Functions: scanAbilities, eachEquipmentModule, addUniqueEFromEquipment, buildPublicSnapshot, AbilityRegistry:Get, AbilityRegistry:CanFire, AbilityRegistry:SetFired, rf.OnServerInvoke
Signal classes referenced: RemoteFunction
Clean source lines: 112
]]
local SSS               = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverPackage = SSS:WaitForChild("MMO_ServerPackage")
local replicatedPackage = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")

local equipmentFolder = serverPackage:WaitForChild("Equipment")
local abilitiesFolder = serverPackage:WaitForChild("Abilities")
local AbilityRegistry   = {}
local Cooldowns         = {}


local function scanAbilities()
	for _, wFolder in ipairs(abilitiesFolder:GetChildren()) do
		if not wFolder:IsA("Folder") then continue end
		AbilityRegistry[wFolder.Name] = AbilityRegistry[wFolder.Name] or {}
		for _, mod in ipairs(wFolder:GetChildren()) do
			if not mod:IsA("ModuleScript") then continue end
			local ok, ability = pcall(require, mod)
			if ok and ability.Key and ability.Index and ability.Execute then
				local tbl = AbilityRegistry[wFolder.Name][ability.Key] or {}
				tbl[ability.Index] = ability
				AbilityRegistry[wFolder.Name][ability.Key] = tbl
				ability.AbilityId = string.format("%s:%s%d", wFolder.Name, ability.Key, ability.Index)
			else
				warn(("Bad ability module: %s"):format(mod:GetFullName()))
			end
		end
	end
end


local function eachEquipmentModule(folder, pathParts, fn)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Folder") then
			local np = table.clone(pathParts); table.insert(np, child.Name)
			eachEquipmentModule(child, np, fn)
		elseif child:IsA("ModuleScript") then
			local np = table.clone(pathParts); table.insert(np, child.Name)
			fn(child, np)
		end
	end
end

local function addUniqueEFromEquipment()
	eachEquipmentModule(equipmentFolder, {}, function(mod, pathParts)
		local ok, weapon = pcall(require, mod)
		if ok and weapon and weapon.WeaponType and weapon.UniqueE then
			local ue = weapon.UniqueE
			local metaOnly = {}
			for k,v in pairs(ue) do
				if k ~= "Execute" then metaOnly[k] = v end
			end
			metaOnly.Key   = "E"
			metaOnly.Index = 1
			local wt = weapon.WeaponType
			AbilityRegistry[wt] = AbilityRegistry[wt] or {}
			AbilityRegistry[wt]["E"] = AbilityRegistry[wt]["E"] or {}
			if not AbilityRegistry[wt]["E"][1] then
				AbilityRegistry[wt]["E"][1] = metaOnly
			end
		end
	end)
end

local function buildPublicSnapshot()
	local snap = {}
	for wType, slots in pairs(AbilityRegistry) do
		snap[wType] = snap[wType] or {}
		for key, idxTbl in pairs(slots) do
			snap[wType][key] = snap[wType][key] or {}
			for idx, ab in pairs(idxTbl) do
				local pub = {}
				for k, v in pairs(ab) do
					if k ~= "Execute" then pub[k] = v end
				end
				snap[wType][key][idx] = pub
			end
		end
	end
	return snap
end

scanAbilities()
addUniqueEFromEquipment()

local PUBLIC_SNAPSHOT = buildPublicSnapshot()

local rf = Instance.new("RemoteFunction")
rf.Name  = "GetAbilityMeta"
rf.Parent = replicatedPackage
rf.OnServerInvoke = function(player)
	return PUBLIC_SNAPSHOT
end

function AbilityRegistry:Get(weaponType, slot, idx)
	local wt = AbilityRegistry[weaponType]
	return wt and wt[slot] and wt[slot][idx] or nil
end
function AbilityRegistry:CanFire(player, ability)
	if not ability then return false end
	local uid = player.UserId
	Cooldowns[uid] = Cooldowns[uid] or {}
	local last = Cooldowns[uid][ability.AbilityId]
	return (not last) or (os.clock() - last >= ability.Cooldown)
end
function AbilityRegistry:SetFired(player, ability)
	Cooldowns[player.UserId][ability.AbilityId] = os.clock()
end

return AbilityRegistry
