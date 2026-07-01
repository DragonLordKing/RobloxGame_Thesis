--[[
Name: Stats
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.PlayerCoreLean.Stats
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Requires:
  - local C = require(script.Parent.Core)
  - local DestinyBoardConfig = require(C.ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("DestinyBoardConfig"))
  - return require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
Functions: getBaseWalkSpeed, getValorSkills, applyDestinyWeaponItemPower, removeLegacyPlayerTopBar, applyEquipmentStats, syncBasicCooldown, defaultEquipmentProfile, sanitizeEquipmentProfile, Stats.LoadEquipmentModules, Stats.LoadLootModules, Stats.RefreshPlayerStats, Stats.persistPlayerStats, Stats.initializeHumanoidStats, Stats.cleanupStats, Stats.bindDeathCleanup, Stats.updateHealthBar, Stats.addItemToInventory, Stats.removeItemFromInventory
Clean source lines: 284
]]
local C = require(script.Parent.Core)
local DestinyBoardConfig = require(C.ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("DestinyBoardConfig"))
local Stats = {}

local function getBaseWalkSpeed(stats)
	local buff = (stats.SpeedBuff or 0)/100
	return (stats.Speed or 16) * (1 + buff)
end
Stats.getBaseWalkSpeed = getBaseWalkSpeed


function Stats.LoadEquipmentModules()
	C.BuildEquipmentIndex()
end

function Stats.LoadLootModules()
	C.BuildLootIndex()
end

local function getValorSkills(player)
	local section = C.ProfileService.GetSection(player, "Valor", function()
		return { Version = 1, Skills = {} }
	end)
	return type(section.Skills) == "table" and section.Skills or {}
end

local function applyDestinyWeaponItemPower(stats, player)
	if not (stats and player and stats.Equipment) then return end
	local weaponId = stats.Equipment.Weapon
	if not weaponId then return end
	local module = C.GetEquipmentModule(weaponId)
	if not module then return end
	local weaponType = module.WeaponType or module.WeaponClass or module.ItemType or module.DisplayName or weaponId
	local line = DestinyBoardConfig.CombatLineForWeapon(weaponType, weaponId, module)
	if not (line and line.Kind == "Weapon") then return end
	local skills = getValorSkills(player)
	local currentVeterancy = line.VeterancyKey or line.DefaultVeterancyKey
	local seen = {}
	local bonus = 0
	for _, veterancyKey in pairs(line.VariantKeys or {}) do
		if veterancyKey and not seen[veterancyKey] and DestinyBoardConfig.Skills[veterancyKey] then
			seen[veterancyKey] = true
			local level = DestinyBoardConfig.GetLevelForValor(veterancyKey, skills[veterancyKey] or 0)
			if veterancyKey == currentVeterancy then
				bonus += level * 3
			else
				bonus += level * 0.6
			end
		end
	end
	if currentVeterancy and not seen[currentVeterancy] and DestinyBoardConfig.Skills[currentVeterancy] then
		local level = DestinyBoardConfig.GetLevelForValor(currentVeterancy, skills[currentVeterancy] or 0)
		bonus += level * 3
	end
	if bonus > 0 then
		stats.DestinyItemPowerBonus = bonus
		stats.ItemPower = (stats.ItemPower or 0) + bonus
	else
		stats.DestinyItemPowerBonus = 0
	end
end

local function removeLegacyPlayerTopBar(head)
	local topBar = head and head:FindFirstChild("TopBar")
	if topBar then
		topBar:Destroy()
	end
end

local function applyEquipmentStats(stats, player)

	stats.Health=1500; stats.MaxHealth=1500; stats.Speed=18; stats.SpeedBuff=0; stats.Range=0
	stats.Weight=0; stats.MaxWeight=100; stats.ItemPower=0
	stats.Armor=0; stats.MagicArmor=0; stats.PhysicalResistance=0; stats.MagicalResistance=0
	stats.CrowdControlResistance=0; stats.CrowdControlModifier=0
	stats.CooldownReduction=0; stats.AttackSpeedBonus=0
	stats.inCombat=false; stats.Will=100; stats.MaxWill=100
	stats.HealthRegen=0; stats.WillRegen=0; stats.HealthRegenBonus=0; stats.WillRegenBonus=0
	stats.MagicAttackBonus=0; stats.MagicAbilityBonus=0; stats.PhysicalAttackBonus=0; stats.PhysicalAbilityBonus=0
	stats.HealingCastBonus=0; stats.HealingReceivedBonus=0


	for slot,itemId in pairs(stats.Equipment) do
		if itemId then
			local module = C.GetEquipmentModule(itemId)
			if not module then

				warn(("[Equipment] %s slot item '%s' could not be resolved."):format(slot, tostring(itemId)))
			elseif typeof(module.ApplyStats)=="function" then
				module.ApplyStats(stats)
			end
		end
	end
	applyDestinyWeaponItemPower(stats, player)
end

local function syncBasicCooldown(player, stats)
	local weaponId = stats.Equipment.Weapon
	local weaponMod  = C.GetEquipmentModule(weaponId)
	local baseCd     = (weaponMod and weaponMod.BasicCooldown) or 1
	local range      = (weaponMod and weaponMod.Range) or 5
	local haste      = stats.AttackSpeedBonus or 0
	local finalCd    = baseCd / (1 + haste)
	C.UpdateBasicCooldown:FireClient(player, finalCd)
	C.UpdateBasicRange:FireClient(player, range)
end

function Stats.RefreshPlayerStats(player)
	local model = player and player.Character
	local stats = model and C.humanoidStats[model]
	if not stats then
		return nil
	end
	applyEquipmentStats(stats, player)
	if stats.Humanoid then
		stats.Humanoid.WalkSpeed = getBaseWalkSpeed(stats)
		stats.Humanoid:SetAttribute("InventoryBaseWalkSpeed", stats.Humanoid.WalkSpeed)
	end
	syncBasicCooldown(player, stats)
	Stats.persistPlayerStats(player, stats)
	return stats
end

local function defaultEquipmentProfile()
	local slots = {}
	for i = 1, 40 do
		slots["slot" .. i] = nil
	end
	return {
		Equipment = { Armor=nil, Helmet=nil, Boots=nil, Cape=nil, Food=nil, Potion=nil, Weapon=nil, Offhand=nil, Bag=nil, Mount=nil },
		Slots = slots,
		Mount = nil,
	}
end

local function sanitizeEquipmentProfile(section)
	if type(section.Equipment) ~= "table" then
		section.Equipment = defaultEquipmentProfile().Equipment
	end
	if type(section.Slots) ~= "table" then
		section.Slots = defaultEquipmentProfile().Slots
	end
	return section
end

function Stats.persistPlayerStats(player, stats)
	if not (player and stats) then
		return
	end
	local section = C.ProfileService.GetSection(player, "Equipment", defaultEquipmentProfile)
	section.Equipment = stats.Equipment or section.Equipment or defaultEquipmentProfile().Equipment
	section.Slots = stats.Slots or section.Slots or defaultEquipmentProfile().Slots
	section.Mount = section.Equipment and section.Equipment.Mount or stats.Mount
	C.ProfileService.MarkDirty(player)
end

function Stats.initializeHumanoidStats(humanoid)
	local model  = humanoid.Parent
	local player = C.Players:GetPlayerFromCharacter(model)
	if player then
		local stats = {
			Model=model, Humanoid=humanoid, IsPlayer=true, IsNPC=false, Speed=humanoid.WalkSpeed,
			Equipment={ Armor=nil, Helmet=nil, Boots=nil, Cape=nil, Food=nil, Potion=nil, Weapon=nil, Offhand=nil, Bag=nil, Mount=nil },
			Slots = {}, MaxSlots=40,
			Mount=nil,
			MountStats={ Health=0, MaxHealth=0, Regeneration=0, GallopTime=4, Armor=0, WillArmor=0 },
		}
		for i=1,40 do stats.Slots["slot"..i]=nil end


		local saved = sanitizeEquipmentProfile(C.ProfileService.GetSection(player, "Equipment", defaultEquipmentProfile))
		stats.Equipment = saved.Equipment
		stats.Mount     = (saved.Equipment and saved.Equipment.Mount) or saved.Mount
		stats.Slots     = saved.Slots


		if not stats.Equipment.Weapon then

			local nestedId = "Weapons/Swords/TestSword"
			stats.Equipment.Weapon = C.GetEquipmentModule(nestedId) and nestedId or "TestSword"
			C.ProfileService.MarkDirty(player)
		end

		applyEquipmentStats(stats, player)
		removeLegacyPlayerTopBar(model:FindFirstChild("Head"))
		humanoid.WalkSpeed = getBaseWalkSpeed(stats)
		C.humanoidStats[model] = stats
		C.SpatialGrid.Add(model)
		C.SetModelGroup(model, "Character")
		syncBasicCooldown(player, stats)
	else
		local stats = { Model=model, Humanoid=humanoid, IsPlayer=false, IsNPC=true, Speed=humanoid.WalkSpeed, Health=100, MaxHealth=100 }
		C.humanoidStats[model] = stats
		C.SpatialGrid.Add(model)
	end
end

function Stats.cleanupStats(model)
	C.SpatialGrid.Remove(model)
	C.humanoidStats[model] = nil
end

function Stats.bindDeathCleanup(humanoid)
	humanoid.Died:Connect(function()
		local model  = humanoid.Parent
		local player = C.Players:GetPlayerFromCharacter(model)
		if player then
			local ok, CombatStateService = pcall(function()
				return require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
			end)
			if ok and CombatStateService and type(CombatStateService.HandleHumanoidDeath) == "function" then
				CombatStateService.HandleHumanoidDeath(player)
			end
		end
		Stats.cleanupStats(model)
	end)
end

function Stats.updateHealthBar(result)
	local model = result.Model
	local head  = model:FindFirstChild("Head")
	if head then
		local topBar = head:FindFirstChild("TopBar")
		if topBar then
			local healthBar = topBar:FindFirstChild("HealthBar")
			if healthBar then
				local healthFrame = healthBar:FindFirstChild("Health")
				if healthFrame then
					local ratio = result.NewHealth / result.MaxHealth
					healthFrame.Size = UDim2.new(ratio, 0, 1, 0)
				end
			end
		end
	end
	if result.NewHealth <= 0 then
		result.NewHealth = result.MaxHealth
		if head and head:FindFirstChild("TopBar") and head.TopBar:FindFirstChild("HealthBar") then
			head.TopBar.HealthBar.Health.Size = UDim2.new(1,0,1,0)
		end
		local s = C.humanoidStats[model]
		if s then s.Health = s.MaxHealth end
	end
end


function Stats.addItemToInventory(model: Model, itemId: string, intoSlot: string?)
	local s = C.humanoidStats[model]; if not (s and itemId) then return nil end

	if not C.GetItemModule(itemId) then
		warn(("Unknown item id '%s'"):format(itemId)); return nil
	end

	if intoSlot then
		if s.Slots[intoSlot] == nil then
			s.Slots[intoSlot] = itemId
			local player = C.Players:GetPlayerFromCharacter(model)
			if player then C.ProfileService.MarkDirty(player) end
			return intoSlot
		end
		return nil
	else
		for i = 1, (s.MaxSlots or 40) do
			local k = "slot"..i
			if s.Slots[k] == nil then
				s.Slots[k] = itemId
				local player = C.Players:GetPlayerFromCharacter(model)
				if player then C.ProfileService.MarkDirty(player) end
				return k
			end
		end
		return nil
	end
end

function Stats.removeItemFromInventory(model: Model, slotKey: string)
	local s = C.humanoidStats[model]; if not (s and slotKey) then return nil end
	local prev = s.Slots[slotKey]; s.Slots[slotKey] = nil
	local player = C.Players:GetPlayerFromCharacter(model)
	if player then C.ProfileService.MarkDirty(player) end
	return prev
end

return Stats
