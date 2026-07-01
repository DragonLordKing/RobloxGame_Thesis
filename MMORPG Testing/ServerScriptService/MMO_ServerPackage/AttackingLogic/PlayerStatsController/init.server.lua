--[[
Name: PlayerStatsController
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.AttackingLogic.PlayerStatsController
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=false, LinkedSource="", Disabled=true, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: Players, ReplicatedStorage, Workspace, RunService, ServerStorage
Functions: recursivelyRequireModules, applyEquipmentStats, initializeHumanoidStats, cleanupStats, bindDeathCleanup, findModule, GetPlayerMountBF.OnInvoke
Clean source lines: 359
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local RemoteEvents = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")
local BindableFunctions = ServerStorage:WaitForChild("MMO_ServerStoragePackage"):WaitForChild("BindableFunctions")
local AttackTarget = RemoteEvents:WaitForChild("AttackTarget")
local MountStatusEvent = RemoteEvents:WaitForChild("MountStatus")

local GetPlayerMountBF = BindableFunctions:WaitForChild("GetPlayerMount")
local EquipmentFolders = script.Parent:WaitForChild("Equipment")

local equipmentStore = nil


local function recursivelyRequireModules(folder)
	local modules = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local success, module = pcall(require, child)
			if success then

				modules[child.Name] = module
			else
				warn("Failed to require: " .. child:GetFullName())
			end
		elseif child:IsA("Folder") then
			local subModules = recursivelyRequireModules(child)

			for key, mod in pairs(subModules) do
				modules[key] = mod
			end
		end
	end
	return modules
end

local equipmentModules = recursivelyRequireModules(EquipmentFolders)
local humanoidStats = {}

local ServerAttackCooldown = 1
local playerAttackCooldowns = {}


local function applyEquipmentStats(stats)
	stats.Health = 2000
	stats.MaxHealth = 2000
	stats.Speed = 13
	stats.Range = 0
	stats.Weight = 0
	stats.MaxWeight = 100
	stats.ItemPower = 0
	stats.Armor = 0
	stats.MagicArmor = 0
	stats.PhysicalResistance = 0
	stats.MagicalResistance = 0
	stats.CrowdControlResistance = 0
	stats.CrowdControlModifier = 0
	stats.CooldownReduction = 0
	stats.AttackSpeed = 0
	stats.inCombat = false
	stats.Will = 100
	stats.MaxWill = 100
	stats.HealthRegen = 0
	stats.WillRegen = 0
	stats.HealthRegenBonus = 0
	stats.WillRegenBonus = 0
	stats.MagicAttackBonus = 0
	stats.MagicAbilityBonus = 0
	stats.PhysicalAttackBonus = 0
	stats.PhysicalAbilityBonus = 0
	stats.HealingCastBonus = 0
	stats.HealingReceivedBonus = 0


	for slot, itemName in pairs(stats.Equipment) do
		if itemName then

			local module = equipmentModules[itemName]
			if module and typeof(module.ApplyStats) == "function" then
				module.ApplyStats(stats)
			end
		end
	end
end


local function initializeHumanoidStats(humanoid)
	local model = humanoid.Parent
	local player = Players:GetPlayerFromCharacter(model)


	if player then
		local stats = {
			Model = model,
			Humanoid = humanoid,
			IsPlayer = true,
			IsNPC = false,
			Speed = humanoid.WalkSpeed,


			Equipment = {
				Armor = nil,
				Helmet = nil,
				Boots = nil,
				Cape = nil,
				Food = nil,
				Potion = nil,
				Weapon = nil,
				Offhand = nil,
				Bag = nil
			},


			Slots = {},
			MaxSlots = 40,


			Mount = nil,


			MountStats = {
				Health       = 0,
				MaxHealth    = 0,
				Regeneration = 0,
				GallopTime   = 4,
				Armor        = 0,
				WillArmor    = 0
			}

		}


		for i = 1, 40 do
			stats.Slots["slot" .. i] = nil
		end


		applyEquipmentStats(stats)

		humanoidStats[model] = stats


	else
		local stats = {
			Model = model,
			Humanoid = humanoid,
			IsPlayer = false,
			IsNPC = true,
			Speed = humanoid.WalkSpeed,
			Health = 100,
        	MaxHealth = 100,
		}
		humanoidStats[model] = stats
	end
end


local function cleanupStats(model)
	humanoidStats[model] = nil
end


for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") then
		initializeHumanoidStats(descendant:FindFirstChildOfClass("Humanoid"))
	end
end


Workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Humanoid") and desc.Parent:IsA("Model") then
		initializeHumanoidStats(desc)
	end
end)


local function bindDeathCleanup(humanoid)
	humanoid.Died:Connect(function()
		local model = humanoid.Parent
		local player = Players:GetPlayerFromCharacter(model)

		if player and humanoidStats[model] then
			local stats = humanoidStats[model]


			local retainedSlots = {}
			for slot, itemName in pairs(stats.Slots) do
				if itemName then
					for _, folder in ipairs(EquipmentFolders:GetChildren()) do
						local item = folder:FindFirstChild(itemName)
						if item and item:IsA("ModuleScript") then
							local success, module = pcall(require, item)
							if success and module.NonLosable == true then
								retainedSlots[slot] = itemName
							end
						end
					end
				end
			end
			stats.Slots = retainedSlots


			stats.Equipment = {
				Armor = nil, Helmet = nil, Boots = nil, Cape = nil,
				Food = nil, Potion = nil, Weapon = nil, Offhand = nil, Bag = nil
			}


			stats.Mount = nil


			stats.MountStats = {
				Health       = 0,
				MaxHealth    = 0,
				Regeneration = 0,
				GallopTime   = 0,
				Armor        = 0,
				WillArmor    = 0
			}
		end

		cleanupStats(model)
	end)
end


for model, stats in pairs(humanoidStats) do
	local humanoid = stats.Humanoid
	if humanoid then
		bindDeathCleanup(humanoid)
	end
end


Workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Humanoid") and desc.Parent:IsA("Model") then
		bindDeathCleanup(desc)
	end
end)


Players.PlayerRemoving:Connect(function(player)
	local model = player.Character
	if model and humanoidStats[model] then
		local stats = humanoidStats[model]
		local toSave = {
			Equipment = stats.Equipment,
			Mount     = stats.Mount
		}

		cleanupStats(model)
	end
end)


AttackTarget.OnServerEvent:Connect(function(player, targetModel, attackType)
	print("Attack Happened at " .. os.clock())
	local now = os.clock()
	local lastFired = playerAttackCooldowns[player.UserId]
	if lastFired and (now - lastFired) < ServerAttackCooldown then
		return
	end
	playerAttackCooldowns[player.UserId] = now

	if attackType == "Q" then

		local testSwordModule = nil


		local function findModule(folder, moduleName)
			for _, child in ipairs(folder:GetChildren()) do
				if child:IsA("ModuleScript") and child.Name == moduleName then
					return child
				elseif child:IsA("Folder") then
					local found = findModule(child, moduleName)
					if found then
						return found
					end
				end
			end
			return nil
		end

		local testSwordScript = findModule(EquipmentFolders, "TestSword")
		if testSwordScript then
			local success, module = pcall(require, testSwordScript)
			if success then
				testSwordModule = module
			else
				warn("Failed to require TestSword module: " .. testSwordScript:GetFullName())
			end
		else
			warn("TestSword module was not found!")
		end

		if testSwordModule and type(testSwordModule.ActivateAbility) == "function" then
			testSwordModule:ActivateAbility(player)
		else
			warn("TestSword ability is not available!")
		end

		return
	end


	if attackType == "basic" then

		local stats = humanoidStats[targetModel]
		if not stats then
			return
		end


		if stats.IsPlayer then
			return
		end


		stats.Health = math.max(stats.Health - 10, 0)


		local head = targetModel:FindFirstChild("Head")
		if head then
			local topBar = head:FindFirstChild("TopBar")
			if topBar then
				local healthBar = topBar:FindFirstChild("HealthBar")
				if healthBar then
					local healthFrame = healthBar:FindFirstChild("Health")
					if healthFrame then
						local ratio = stats.Health / stats.MaxHealth
						healthFrame.Size = UDim2.new(ratio, 0, 1, 0)
					end
				end
			end
		end


		if stats.Health <= 0 then
			stats.Health = 100
			local head = targetModel:FindFirstChild("Head")
			if head and head:FindFirstChild("TopBar") and head.TopBar:FindFirstChild("HealthBar") then
				head.TopBar.HealthBar.Health.Size = UDim2.new(1, 0, 1, 0)
			end
		end
	end
end)


GetPlayerMountBF.OnInvoke = function(_player)
	return nil
end


return humanoidStats
