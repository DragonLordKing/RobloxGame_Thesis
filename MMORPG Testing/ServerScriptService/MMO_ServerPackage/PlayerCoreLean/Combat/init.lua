--[[
Name: Combat
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.PlayerCoreLean.Combat
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Requires:
  - local C = require(script.Parent.Core)
  - local Stats = require(script.Parent.Stats)
Functions: isEnemy, isAlly, itemPowerMultiplier, targetIsValid, fireAbility, restoreWhenReady, Combat.maybeRemoveAttackerMount, Combat.applyMountDamage, Combat.Bind, IsHostile
Clean source lines: 258
]]
local C = require(script.Parent.Core)
local Stats = require(script.Parent.Stats)
local Combat = {}

local function isEnemy(model, player)
	local character = player.Character
	local m = C.toServerModel(model)
	return C.RS:GetRelation(character, m) == "Hostile"
end

local function isAlly(model, player)
	local character = player.Character
	local m = C.toServerModel(model)
	local rel = C.RS:GetRelation(character, m)
	return rel == "Party" or rel == "Guild" or rel == "Alliance" or rel == "Neutral"
end

local function itemPowerMultiplier(stats)
	local itemPower = math.max(0, tonumber(stats and stats.ItemPower) or 0)
	if itemPower <= 0 then
		return 1
	end
	return math.clamp(1 + math.max(0, itemPower - 100) * 0.0015, 1, 4)
end


function Combat.maybeRemoveAttackerMount(attackerPlr, victimModel)
	if typeof(victimModel) ~= "Instance" then return end
	local victimPlr = victimModel:IsA("Model")
		and C.Players:GetPlayerFromCharacter(victimModel)
		or C.MountInfo.horseToPlayer[victimModel]
	if not victimPlr or victimPlr == attackerPlr then return end

	local myHorse = C.MountInfo.mountedHorses[attackerPlr.UserId]
	if not (myHorse and myHorse.PrimaryPart) then return end

	local hrp = attackerPlr.Character and attackerPlr.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if (hrp.Position - myHorse.PrimaryPart.Position).Magnitude <= 25 then
		if myHorse:GetAttribute("Mounted") then C.forceDismount(attackerPlr, myHorse) end
		C.CurrentHorseEvent:FireClient(attackerPlr, nil, false)
		C.UpdateHorseStatus:FireClient(attackerPlr, false)
		C.MountInfo.horseToPlayer[myHorse]            = nil
		C.MountInfo.mountedHorses[attackerPlr.UserId] = nil
		myHorse:Destroy()
	end
end

function Combat.applyMountDamage(victimModel, dmg)
	local victimPlayer = C.Players:GetPlayerFromCharacter(victimModel)
	if not victimPlayer then return end
	local horse = C.MountInfo.mountedHorses[victimPlayer.UserId]
	if not horse then return end

	if not horse:GetAttribute("__CG_HorseSet") then
		C.SetModelGroup(horse, "Horse")
		horse:SetAttribute("__CG_HorseSet", true)
	end

	if horse:GetAttribute("Mounted") then
		local hHum = horse:FindFirstChildWhichIsA("Humanoid")
		local sdat = C.MountInfo.horseSpeeds[horse]
		if hHum and sdat then hHum.WalkSpeed = sdat.BaseSpeed end
		C.MountInfo.movementTimers[victimPlayer.UserId] = 0

		horse:SetAttribute("Health",    horse:GetAttribute("Health")    or 300)
		horse:SetAttribute("MaxHealth", horse:GetAttribute("MaxHealth") or 300)

		local newHp = math.max(horse:GetAttribute("Health") - (dmg or 0), 0)
		horse:SetAttribute("Health", newHp)
		C.updateMountHealthBar(horse)

		if newHp <= 0 then
			C.forceDismount(victimPlayer, horse)
			C.UpdateHorseStatus:FireClient(victimPlayer, false)
			horse:Destroy()
			C.CurrentHorseEvent:FireClient(victimPlayer, nil, false)
			C.MountInfo.mountedHorses[victimPlayer.UserId] = nil
			C.MountInfo.horseToPlayer[horse]              = nil
			C.MountInfo.mountDebounce[victimPlayer.UserId]   = false
			C.MountInfo.mountingPlayers[victimPlayer.UserId] = nil
		end
	else
		local uid = victimPlayer.UserId
		if C.MountInfo.mountingPlayers[uid] then C.abortMounting(victimPlayer) end
		C.UpdateHorseStatus:FireClient(victimPlayer, false)
	end
end


local function targetIsValid(tt, arg, player)
	local TT = C.TargetTypes
	if tt == TT.DIR then return typeof(arg)=="Vector3" end
	if tt == TT.LOC then return typeof(arg)=="Vector3" end
	if tt == TT.SELF then return arg == nil end
	if tt == TT.U_ANY then return typeof(arg)=="Instance" end
	if tt == TT.U_ALLY then return isAlly(arg, player) end
	if tt == TT.U_ENEMY then return isEnemy(arg, player) end
	if tt == TT.P_AE then
		return typeof(arg)=="table" and #arg==2 and ((isAlly(arg[1],player) and isEnemy(arg[2],player)) or (isEnemy(arg[1],player) and isAlly(arg[2],player)))
	end
	if tt == TT.P_AA then return typeof(arg)=="table" and #arg==2 and isAlly(arg[1],player) and isAlly(arg[2],player) end
	if tt == TT.P_EE then return typeof(arg)=="table" and #arg==2 and isEnemy(arg[1],player) and isEnemy(arg[2],player) end
	return false
end

function Combat.Bind()
	C.AttackTarget.OnServerEvent:Connect(function(player, raw, slot, idx)
		local origin, target
		if typeof(raw)=="table" then origin=raw.Origin; target=raw.Target else target=raw end
		target = C.resolveTarget(target)
		target = C.toServerModel(target)

		local uid = player.UserId
		local now = os.clock()
		if C.castLockUntil[uid] and now < C.castLockUntil[uid] then return end
		if C.gcdUntil[uid] and now < C.gcdUntil[uid] then return end

		local character = player.Character; if not character then return end
		if character:GetAttribute("Downed") == true then return end
		local stats = C.humanoidStats[character]; if not stats then return end

		local weaponId = stats.Equipment.Weapon; if not weaponId then return end
		local weaponMod = C.GetEquipmentModule(weaponId); if not weaponMod then return end
		local weaponType = weaponMod.WeaponType


		if slot == "basic" then
			local ready = not C.nextBasicAllowed[uid] or now >= C.nextBasicAllowed[uid]
			if not ready then return end
			if not target then return end
			local tgtStats = C.humanoidStats[target]; if not tgtStats then return end
			local char = player.Character; if not char then return end
			if not C.RS:CanDamage(char, target) then return end

			local pStats = C.humanoidStats[char]; if not pStats then return end
			local wMod = C.GetEquipmentModule(pStats.Equipment.Weapon)
			local cd = (wMod and wMod.BasicCooldown) or 1
			local range = (wMod and wMod.Range) or 5

			local hrp = char:FindFirstChild("HumanoidRootPart")
			local targetHrp = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
			if not (hrp and targetHrp) then return end
			if (hrp.Position - targetHrp.Position).Magnitude > (range + 1) then return end

			local haste = pStats.AttackSpeedBonus or 0
			cd = cd / (1 + haste)
			C.nextBasicAllowed[uid] = now + cd

			local baseDamage = (wMod and wMod.BaseDamage) or 10
			local bonus = pStats.PhysicalAttackBonus or 0
			local damage = math.max(1, math.floor((baseDamage + bonus) * itemPowerMultiplier(pStats) + 0.5))

			local victimPlayer = C.Players:GetPlayerFromCharacter(target)
			if victimPlayer and C.MountInfo.mountingPlayers[victimPlayer.UserId] then C.abortMounting(victimPlayer) end

			Combat.maybeRemoveAttackerMount(player, target)
			local res = C.AbilityCore.PlayerApplyDamage(target, damage, player)
			if res and res.Model then
				local vStats = C.humanoidStats[res.Model]
				local done = res.Damage or 0
				if vStats and vStats.IsNPC and done > 0 then C.ThreatBump:Fire(res.Model, character, done) end
			end
			return
		end

		local function fireAbility(ability)
			if not ability then return end

			if not ability.AbilityId then
				local key = ability.Key or slot or "?"
				local index = ability.Index or (idx or 1)
				local wt = weaponType or "Generic"
				ability.AbilityId = string.format("%s:%s%d", wt, tostring(key), tonumber(index))
			end

			local tt = ability.TargetType
			if not targetIsValid(tt, target, player) then return end
			if ability and C.AbilityRegistry:CanFire(player, ability) then
				C.AbilityRegistry:SetFired(player, ability)
				local lock = ability.CastLock or 0
				C.castLockUntil[uid] = now + lock
				C.gcdUntil[uid]      = now + 0.5

				if ability.MoveSlow and ability.MoveSlow > 0 then
					local debuff = math.clamp(ability.MoveSlow, 0, 1)
					local hum = character:FindFirstChildOfClass("Humanoid")
					if hum then
						local baseSpeed = Stats.getBaseWalkSpeed(stats)
						local slowUntil = now + lock
						C.moveSlowUntil[uid]  = slowUntil
						C.moveSlowFactor[uid] = baseSpeed
						hum.WalkSpeed = baseSpeed * (1 - debuff)
						local function restoreWhenReady(attempt)
							if C.moveSlowUntil[uid] ~= slowUntil then return end
							if os.clock() < slowUntil then
								task.delay(slowUntil - os.clock(), function() restoreWhenReady(attempt) end)
								return
							end
							local h = character:FindFirstChildOfClass("Humanoid")
							if not h then
								C.moveSlowUntil[uid] = nil
								C.moveSlowFactor[uid] = nil
								return
							end
							if character:GetAttribute("Downed") == true then
								C.moveSlowUntil[uid] = nil
								C.moveSlowFactor[uid] = nil
								return
							end
							if h.PlatformStand == true and attempt < 20 then
								task.delay(0.1, function() restoreWhenReady(attempt + 1) end)
								return
							end
							if h.PlatformStand == true then
								h.PlatformStand = false
								h:ChangeState(Enum.HumanoidStateType.Running)
							end
							h.WalkSpeed = C.moveSlowFactor[uid] or baseSpeed
							C.moveSlowUntil[uid] = nil
							C.moveSlowFactor[uid] = nil
						end
						task.delay(lock, function() restoreWhenReady(0) end)
					end
				end

				local params = OverlapParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = {character}

				local results = ability.Execute{
					Player=player, Character=character, Stats=stats, TargetArg=target, StartPos=origin,
					Damage=ability.Damage, Range=ability.Range, Params=params,
					DamageScale=itemPowerMultiplier(stats), ItemPower=stats.ItemPower,
					IsHostile=function(model) return C.RS:GetRelation(character, model) == "Hostile" end,
				}
				if results then
					for _, r in ipairs(results) do
						Combat.maybeRemoveAttackerMount(player, r.Model)
						local vStats = C.humanoidStats[r.Model]
						local dmgVal = r.Damage or r.DamageDone or 0
						if vStats and vStats.IsNPC and dmgVal > 0 then C.ThreatBump:Fire(r.Model, character, dmgVal) end
					end
				end
			end
		end


		if slot == "E" then fireAbility(weaponMod and weaponMod.UniqueE); return end

		local ability = C.AbilityRegistry:Get(weaponType, slot, idx or 1)
		fireAbility(ability)
	end)
end

return Combat
