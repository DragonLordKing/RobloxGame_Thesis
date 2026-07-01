--[[
Name: ValorService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Progression.ValorService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, ServerStorage
Requires:
  - local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("DestinyBoardConfig"))
  - local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
  - local HumanoidStats = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("HumanoidStats"))
  - local ProfileService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
  - local PartyService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PartyService"))
Functions: ensureRemote, sanitizeValorTotals, sanitizeData, ensurePlayerData, savePlayerData, addValorTotal, sourceToPlayer, emitValorEarned, equipmentRoot, equipmentPathFrom, resolveEquipmentModule, itemTierFor, metaForItem, weaponTypeForPlayer, addCombatValorPoints, currentSkillLevel, grantMasteryAndVeterancy, grantRoot, equipmentForPlayer, grantCombatLine, onNPCDied, ValorService.GetValorTotals, ValorService.GetSnapshot, ValorService.GrantValor, ValorService.GrantCombatValor, ValorService.GrantWeaponValor, ValorService.GrantGatheringValor, ValorService.GrantRefiningValor, ValorService.GrantCraftingValor, ValorService.Start, GetDestinyBoard.OnServerInvoke
Signal classes referenced: RemoteFunction, RemoteEvent, BindableEvent
Clean source lines: 598
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("DestinyBoardConfig"))
local ItemCatalog = require(ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Shared"):WaitForChild("ItemCatalog"))
local HumanoidStats = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("HumanoidStats"))
local ProfileService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerProfileService"))
local PartyService = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PartyService"))

local ValorService = {}

local playerData = {}
local started = false
local equipmentCache = {}

local remoteFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
end

local function ensureRemote(className, name)
	local existing = remoteFolder:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = remoteFolder
	return inst
end

local GetDestinyBoard = ensureRemote("RemoteFunction", "GetDestinyBoard")
local ValorUpdated = ensureRemote("RemoteEvent", "ValorUpdated")

local beFolder = ServerStorage:WaitForChild("MMO_ServerStoragePackage"):FindFirstChild("BindableEvents")
if not beFolder then
	beFolder = Instance.new("Folder")
	beFolder.Name = "BindableEvents"
	beFolder.Parent = ServerStorage:WaitForChild("MMO_ServerStoragePackage")
end

local NPCDied = beFolder:FindFirstChild("NPCDied")
if not NPCDied then
	NPCDied = Instance.new("BindableEvent")
	NPCDied.Name = "NPCDied"
	NPCDied.Parent = beFolder
end

local ValorEarned = beFolder:FindFirstChild("ValorEarned")
if not ValorEarned then
	ValorEarned = Instance.new("BindableEvent")
	ValorEarned.Name = "ValorEarned"
	ValorEarned.Parent = beFolder
end

local VALOR_BUCKETS = { "Total", "PvP", "PvE", "Gathering", "Crafting" }

local function sanitizeValorTotals(rawTotals)
	local totals = { Total = 0, PvP = 0, PvE = 0, Gathering = 0, Crafting = 0 }
	if type(rawTotals) == "table" then
		for _, key in ipairs(VALOR_BUCKETS) do
			totals[key] = math.max(0, math.floor(tonumber(rawTotals[key]) or tonumber(rawTotals[string.lower(key)]) or 0))
		end
	end
	return totals
end

local function sanitizeData(raw)
	local clean = { Version = 1, Skills = {}, Insight = 0, CombatValorPoints = 0, Totals = sanitizeValorTotals(type(raw) == "table" and raw.Totals or nil) }
	if type(raw) ~= "table" then
		return clean
	end

	clean.Insight = math.max(0, math.floor(tonumber(raw.Insight) or 0))
	clean.CombatValorPoints = math.max(0, math.floor(tonumber(raw.CombatValorPoints) or 0))

	local sourceSkills = raw.Skills or raw.skills or raw
	if type(sourceSkills) ~= "table" then
		return clean
	end

	for key in pairs(Config.Skills) do
		local amount = sourceSkills[key]
		if type(amount) == "table" then
			amount = amount.TotalValor or amount.totalValor or amount.Valor or amount.valor
		end
		amount = math.clamp(math.floor(tonumber(amount) or 0), 0, Config.MaxValorForSkill(key))
		if amount > 0 then
			clean.Skills[key] = amount
		end
	end

	return clean
end

local function ensurePlayerData(player)
	if playerData[player] then
		return playerData[player]
	end

	local section = ProfileService.GetSection(player, "Valor", function()
		return { Version = 1, Skills = {} }
	end)
	local data = sanitizeData(section)
	section.Version = 1
	section.Skills = data.Skills
	section.Insight = data.Insight
	section.CombatValorPoints = data.CombatValorPoints
	section.Totals = data.Totals
	playerData[player] = section
	return section
end

local function savePlayerData(player)
	local data = playerData[player]
	if not data then
		return
	end

	data.Version = 1
	data.Insight = math.max(0, math.floor(tonumber(data.Insight) or 0))
	data.CombatValorPoints = math.max(0, math.floor(tonumber(data.CombatValorPoints) or 0))
	data.Totals = sanitizeValorTotals(data.Totals)
	ProfileService.MarkDirty(player)
end

local function addValorTotal(player, data, bucket, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then return end
	data = data or ensurePlayerData(player)
	data.Totals = sanitizeValorTotals(data.Totals)
	bucket = tostring(bucket or "PvE")
	if bucket ~= "PvP" and bucket ~= "PvE" and bucket ~= "Gathering" and bucket ~= "Crafting" then
		bucket = "PvE"
	end
	data.Totals[bucket] += amount
	data.Totals.Total += amount
	ProfileService.MarkDirty(player)
end

function ValorService.GetValorTotals(player)
	local data = ensurePlayerData(player)
	return sanitizeValorTotals(data.Totals)
end

local function sourceToPlayer(source)
	if typeof(source) ~= "Instance" then
		return nil
	end
	if source:IsA("Player") then
		return source
	end
	if source:IsA("Model") then
		return Players:GetPlayerFromCharacter(source)
	end
	return nil
end

local function emitValorEarned(player, amount, bucket, reason, meta)
	if not (player and player:IsA("Player")) then return end
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then return end
	meta = type(meta) == "table" and meta or {}
	ValorEarned:Fire({
		Player = player,
		Amount = amount,
		Bucket = bucket or "PvE",
		Reason = reason or "valor",
		Position = meta.Position or meta.NpcPosition or meta.NodePosition or meta.StationPosition,
		Meta = meta,
	})
end

local function equipmentRoot()
	return game.ServerScriptService:WaitForChild("MMO_ServerPackage"):FindFirstChild("Equipment") or ServerStorage:FindFirstChild("Equipment")
end

local function equipmentPathFrom(root, moduleScript)
	local parts = {}
	local current = moduleScript
	while current and current ~= root do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, "/")
end

local function resolveEquipmentModule(id)
	if type(id) ~= "string" or id == "" then
		return nil
	end

	local lookup = id:lower()
	if equipmentCache[lookup] ~= nil then
		return equipmentCache[lookup] or nil
	end

	local root = equipmentRoot()
	if not root then
		equipmentCache[lookup] = false
		return nil
	end

	local fallback
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("ModuleScript") then
			local path = equipmentPathFrom(root, inst)
			local pathLower = path:lower()
			local nameLower = inst.Name:lower()
			if pathLower == lookup or nameLower == lookup or string.sub(pathLower, -#lookup) == lookup then
				local ok, mod = pcall(require, inst)
				if ok then
					equipmentCache[lookup] = mod
					return mod
				end
			elseif not fallback and nameLower == lookup:gsub("^.+/", "") then
				fallback = inst
			end
		end
	end

	if fallback then
		local ok, mod = pcall(require, fallback)
		if ok then
			equipmentCache[lookup] = mod
			return mod
		end
	end

	equipmentCache[lookup] = false
	return nil
end

local function itemTierFor(itemId, module)
	local def = ItemCatalog.Get(itemId)
	return math.clamp(math.floor(tonumber((def and def.Tier) or (module and module.Tier) or 1) or 1), 1, Config.MaxTier)
end

local function metaForItem(meta, itemId, module)
	local out = {}
	for k, v in pairs(type(meta) == "table" and meta or {}) do
		out[k] = v
	end
	out.ItemId = out.ItemId or itemId
	out.ItemTier = itemTierFor(itemId, module)
	return out
end

local function weaponTypeForPlayer(player)
	local character = player.Character
	local stats = character and HumanoidStats.humanoidStats[character]
	local weaponId = stats and stats.Equipment and stats.Equipment.Weapon
	local weaponModule = resolveEquipmentModule(weaponId)
	if weaponModule and weaponModule.WeaponType then
		return weaponModule.WeaponType
	end
	return "Unarmed"
end

function ValorService.GetSnapshot(player)
	local data = ensurePlayerData(player)
	local skills = {}
	for _, key in ipairs(Config.NodeOrder) do
		skills[key] = Config.BuildSkillSnapshot(key, data.Skills[key] or 0)
	end
	return {
		Skills = skills,
		Order = Config.NodeOrder,
		Currencies = {
			Insight = math.max(0, math.floor(tonumber(data.Insight) or 0)),
			CombatValorPoints = math.max(0, math.floor(tonumber(data.CombatValorPoints) or 0)),
		},
		ServerTime = os.time(),
	}
end

local function addCombatValorPoints(player, data, amount, reason, meta)
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return
	end
	data.CombatValorPoints = math.max(0, math.floor(tonumber(data.CombatValorPoints) or 0)) + amount
	ProfileService.MarkDirty(player)
	ValorUpdated:FireClient(player, {
		Currency = "CombatValorPoints",
		Amount = amount,
		Total = data.CombatValorPoints,
		Reason = reason or "combat_overflow",
		Meta = meta or {},
	})
end

function ValorService.GrantValor(player, skillKey, amount, reason, meta)
	if not (player and player:IsA("Player") and player.Parent == Players) then
		return nil, 0
	end
	local def = Config.Skills[skillKey]
	if not def then
		warn(("[Valor] Unknown skill key '%s'"):format(tostring(skillKey)))
		return nil, 0
	end

	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return nil, 0
	end
	amount = math.clamp(amount, 1, 100000)

	local data = ensurePlayerData(player)
	local old = math.floor(tonumber(data.Skills[skillKey]) or 0)
	local maxTotal = Config.MaxValorForSkill(skillKey)
	local new = math.clamp(old + amount, 0, maxTotal)
	local granted = new - old
	local overflow = math.max(0, amount - granted)

	if granted > 0 then
		data.Skills[skillKey] = new
		ProfileService.MarkDirty(player)
		local snapshot = Config.BuildSkillSnapshot(skillKey, new)
		ValorUpdated:FireClient(player, {
			Skill = snapshot,
			Amount = granted,
			Reason = reason or "unknown",
			Meta = meta or {},
		})
		if overflow > 0 and def.IsVeterancy and def.Activity == "Combat" then
			addCombatValorPoints(player, data, overflow, "combat_veterancy_overflow", meta)
		end
		return snapshot, overflow
	end

	if overflow > 0 and def.IsVeterancy and def.Activity == "Combat" then
		addCombatValorPoints(player, data, overflow, "combat_veterancy_overflow", meta)
	end
	return Config.BuildSkillSnapshot(skillKey, old), overflow
end

local function currentSkillLevel(data, skillKey)
	return Config.GetLevelForValor(skillKey, data.Skills[skillKey] or 0)
end

local function grantMasteryAndVeterancy(player, line, amount, reason, meta)
	if type(line) ~= "table" or not (line.MasteryKey and Config.Skills[line.MasteryKey]) then
		return nil
	end

	local data = ensurePlayerData(player)
	local snapshot = ValorService.GrantValor(player, line.MasteryKey, amount, reason, meta)
	local masteryLevel = snapshot and snapshot.Level or currentSkillLevel(data, line.MasteryKey)
	local itemTier = math.clamp(math.floor(tonumber(meta and (meta.ItemTier or meta.CraftedTier or meta.Tier) or 1) or 1), 1, Config.MaxTier)
	if masteryLevel >= 1 and itemTier >= 7 and line.VeterancyKey and Config.Skills[line.VeterancyKey] then
		local vetSnapshot = ValorService.GrantValor(player, line.VeterancyKey, amount, (reason or "valor") .. "_veterancy", meta)
		snapshot = vetSnapshot or snapshot
	end
	return snapshot
end

local function grantRoot(player, amount, reason, meta)
	return ValorService.GrantValor(player, Config.ActivityRootKey, amount, reason, meta)
end

local armorSlots = { "Helmet", "Armor", "Boots" }

local function equipmentForPlayer(player)
	local character = player and player.Character
	local stats = character and HumanoidStats.humanoidStats[character]
	return stats and stats.Equipment or nil
end

local function grantCombatLine(player, line, amount, reason, meta)
	if type(line) ~= "table" then
		return nil
	end

	local snapshot
	if line.BranchKey and Config.Skills[line.BranchKey] then
		snapshot = ValorService.GrantValor(player, line.BranchKey, amount, reason, meta) or snapshot
		local branchDef = Config.Skills[line.BranchKey]
		if not (snapshot and snapshot.Level >= (branchDef.MaxLevel or Config.CombatBranchMaxLevel)) then
			return snapshot
		end
	end

	local data = ensurePlayerData(player)
	if not Config.CanProgressLineMastery(data.Skills, line) then
		return snapshot
	end
	return grantMasteryAndVeterancy(player, line, amount, reason, meta) or snapshot
end

function ValorService.GrantCombatValor(player, amount, reason, meta)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return nil
	end

	reason = reason or "combat"
	meta = type(meta) == "table" and meta or {}
	local bucket = tostring(reason):lower():find("pvp", 1, true) and "PvP" or "PvE"
	addValorTotal(player, ensurePlayerData(player), bucket, amount)
	emitValorEarned(player, amount, bucket, reason, meta)
	local rootSnapshot = grantRoot(player, amount, reason .. "_root", meta)
	local combatRootSnapshot = ValorService.GrantValor(player, Config.CombatRootKey, amount, reason .. "_combat_root", meta) or rootSnapshot
	if not combatRootSnapshot or combatRootSnapshot.Level < Config.RootMaxLevel then
		return combatRootSnapshot
	end

	local equipment = equipmentForPlayer(player) or {}
	local snapshot

	local weaponId = equipment.Weapon
	local weaponModule = resolveEquipmentModule(weaponId)
	local weaponType = (weaponModule and (weaponModule.WeaponType or weaponModule.WeaponClass or weaponModule.ItemType)) or meta.WeaponType or weaponTypeForPlayer(player)
	local weaponLine = Config.CombatLineForWeapon(weaponType, weaponId, weaponModule)
	snapshot = grantCombatLine(player, weaponLine, amount, reason, metaForItem(meta, weaponId, weaponModule)) or snapshot

	for _, slotName in ipairs(armorSlots) do
		local itemId = equipment[slotName]
		local itemModule = resolveEquipmentModule(itemId)
		local armorLine = Config.CombatLineForArmor(slotName, itemId, itemModule)
		snapshot = grantCombatLine(player, armorLine, amount, reason, metaForItem(meta, itemId, itemModule)) or snapshot
	end

	return snapshot
end

function ValorService.GrantWeaponValor(player, weaponType, amount, reason, meta)
	meta = type(meta) == "table" and meta or {}
	if weaponType and not meta.WeaponType then
		meta.WeaponType = weaponType
	end
	return ValorService.GrantCombatValor(player, amount, reason or "weapon", meta)
end

function ValorService.GrantGatheringValor(player, gatherKind, itemName, amount, explicitSkillKey, tier, meta)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return nil
	end

	meta = type(meta) == "table" and meta or {}
	meta.Kind = meta.Kind or gatherKind
	meta.Item = meta.Item or itemName
	meta.Tier = meta.Tier or tier
	addValorTotal(player, ensurePlayerData(player), "Gathering", amount)
	emitValorEarned(player, amount, "Gathering", "gathering", meta)

	local activitySnapshot = grantRoot(player, amount, "activity_gathering", meta)
	local rootSnapshot = ValorService.GrantValor(player, Config.GatheringRootKey, amount, "gathering_root", meta) or activitySnapshot
	local skillKey = Config.SkillKeyForGather(gatherKind, itemName, explicitSkillKey, tier)
	if skillKey and skillKey ~= Config.GatheringRootKey and rootSnapshot and rootSnapshot.Level >= Config.RootMaxLevel then
		local data = ensurePlayerData(player)
		if Config.CanProgressGatherSkill(data.Skills, skillKey) then
			return ValorService.GrantValor(player, skillKey, amount, "gathering", meta) or rootSnapshot
		end
	end
	return rootSnapshot
end

function ValorService.GrantRefiningValor(player, resourceKind, tier, amount, explicitSkillKey, meta)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return nil
	end

	meta = type(meta) == "table" and meta or {}
	meta.Kind = meta.Kind or resourceKind
	meta.Tier = meta.Tier or tier
	addValorTotal(player, ensurePlayerData(player), "Crafting", amount)
	emitValorEarned(player, amount, "Crafting", "refining", meta)
	local activitySnapshot = grantRoot(player, amount, "activity_refining", meta)
	local craftingRootSnapshot = ValorService.GrantValor(player, Config.CraftingRootKey, amount, "crafting_root", meta) or activitySnapshot
	if not (craftingRootSnapshot and craftingRootSnapshot.Level >= Config.RootMaxLevel) then
		return craftingRootSnapshot
	end

	local refiningSnapshot = ValorService.GrantValor(player, "craft_refining", amount, "refining_foundation", meta) or craftingRootSnapshot
	local skillKey = Config.SkillKeyForRefining(resourceKind, meta.Item, explicitSkillKey, tier)
	if (not skillKey or skillKey == "craft_refining") and math.floor(tonumber(tier) or 1) <= 6 then
		skillKey = Config.SkillKeyForRefining(resourceKind, meta.Item, nil, 7)
	end
	if skillKey and skillKey ~= "craft_refining" then
		local data = ensurePlayerData(player)
		if Config.CanProgressRefiningSkill(data.Skills, skillKey) then
			return ValorService.GrantValor(player, skillKey, amount, "refining", meta) or refiningSnapshot
		end
	end
	return refiningSnapshot
end

function ValorService.GrantCraftingValor(player, itemId, amount, explicitSkillKey, meta)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return nil
	end

	meta = type(meta) == "table" and meta or {}
	meta.Item = meta.Item or itemId
	addValorTotal(player, ensurePlayerData(player), "Crafting", amount)
	emitValorEarned(player, amount, "Crafting", "crafting", meta)
	local catalogDef = ItemCatalog.Get(itemId)
	meta.Tier = meta.Tier or (catalogDef and catalogDef.Tier)
	meta.ItemTier = meta.ItemTier or meta.Tier
	local activitySnapshot = grantRoot(player, amount, "activity_crafting", meta)
	local rootSnapshot = ValorService.GrantValor(player, Config.CraftingRootKey, amount, "crafting_root", meta) or activitySnapshot
	if not (rootSnapshot and rootSnapshot.Level >= Config.RootMaxLevel) then
		return rootSnapshot
	end

	local itemModule = resolveEquipmentModule(itemId)
	local line = Config.CraftingLineForItem(itemId, itemModule, explicitSkillKey)
	if not line then
		return rootSnapshot
	end

	local snapshot = rootSnapshot
	local majorBranch = Config.MajorCraftingBranchForLine(line)
	if majorBranch and Config.Skills[majorBranch] then
		snapshot = ValorService.GrantValor(player, majorBranch, amount, "crafting_branch", meta) or snapshot
		local branchDef = Config.Skills[majorBranch]
		if not (snapshot and snapshot.Level >= (branchDef.MaxLevel or Config.CraftingBranchMaxLevel)) then
			return snapshot
		end
	end
	if line.BranchKey and line.BranchKey ~= majorBranch and Config.Skills[line.BranchKey] then
		snapshot = ValorService.GrantValor(player, line.BranchKey, amount, "crafting_family", meta) or snapshot
		if not (snapshot and snapshot.Level >= 1) then
			return snapshot
		end
	end
	local data = ensurePlayerData(player)
	if not Config.CanProgressLineMastery(data.Skills, line) then
		return snapshot
	end
	return grantMasteryAndVeterancy(player, line, amount, "crafting", meta) or snapshot
end

local function onNPCDied(npcModel, source, meta)
	meta = type(meta) == "table" and meta or {}
	local player = meta.KillerPlayer or sourceToPlayer(source)
	if not player then
		return
	end

	local tier = math.clamp(math.floor(tonumber(meta.Tier or (npcModel and npcModel:GetAttribute("Tier")) or 1) or 1), 1, Config.MaxTier)
	local amount = math.floor(tonumber(meta.ValorReward or (npcModel and npcModel:GetAttribute("ValorReward")) or Config.NpcValorForTier(tier)) or 0)
	local weaponType = weaponTypeForPlayer(player)
	local rewardMeta = {
		NpcName = npcModel and npcModel.Name or "NPC",
		Tier = tier,
		WeaponType = weaponType,
		Position = npcModel and ((npcModel:IsA("Model") and npcModel:GetPivot().Position) or nil) or nil,
	}
	if PartyService.GrantPartyCombatValor(ValorService, player, amount, "npc_kill", rewardMeta) then
		return
	end
	ValorService.GrantCombatValor(player, amount, "npc_kill", rewardMeta)
end

function ValorService.Start()
	if started then
		return
	end
	started = true

	GetDestinyBoard.OnServerInvoke = function(player)
		return ValorService.GetSnapshot(player)
	end

	NPCDied.Event:Connect(onNPCDied)

	Players.PlayerAdded:Connect(function(player)
		task.defer(ensurePlayerData, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		savePlayerData(player)
		playerData[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(ensurePlayerData, player)
	end

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayerData(player)
		end
	end)
end

return ValorService
