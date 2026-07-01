--[[
Name: AbilityCore
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.Abilities.AbilityCore
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: RunService, Debris, ReplicatedStorage, ServerStorage, ServerScriptService, Players
Requires:
  - local SpatialGrid = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("SpatialGrid"))
  - local HumanoidStats = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("HumanoidStats"))
  - local MountInfo     = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("MountInfo"))
  - local MountHelper   = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("MountHelper"))
  - local CombatState   = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
  - local WorldBus = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("WorldBus"))
Functions: sourceToPlayer, _deleteDismountedHorseIfNear, _applyMountDamage, _threatBump, _hflat, playerHasWorldBarrier, partsOf, makeTargetPredicate, applyDamageOrHeal, alreadyProcessed, frameFrom, anyPartInOrientedRect, _halfDiag, scanRectOnce, gatherModels, _isHumanoidPart, _clampFlatFrom, _npcPredPos, _aimDir, _aimPos, getOrigin, isReasonable, _hasNonCollidableMarker, _isNonBlockingRayPart, safeFlatTarget, groundYAt, rootGroundOffset, snapRootTargetToGround, emitVisual, withVFXTag, _scanRing, _scanCylinder, _scanSphere, cleanupMover, _scanCone, _resolveConeParams, Core.applyDamage, Core.applyHeal, Core.PlayerApplyDamage, Core.NPCApplyDamage, Core.Visual.RectTelegraph, Core.Move.DashDelayed, Core.Move.JumpImpactDelayed, Core.Move.Blink, Core.Move.BlinkDelayed, Core.Move.Dash, Core.Effect.OverTime, Core.Effect.DoT, Core.Effect.HoT, Core.Force.Knockback, Core.Force.Pull, Core.Force.KnockbackDelayed, Core.Force.PullDelayed, Core.Beam.Channel, Core.Beam.DelayedChannel, Core.Ring.Static, Core.Ring.Delayed, Core.Line.Static, Core.Line.StaticDelayed, Core.Line.Tween
Signal classes referenced: BindableEvent
Clean source lines: 1992
]]
local Workspace       = game.Workspace
local RunSrv          = game:GetService("RunService")
local Debris          = game:GetService("Debris")
local ReplicatedStore = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local BEFolder = ServerStorage:WaitForChild("MMO_ServerStoragePackage"):FindFirstChild("BindableEvents")
if not BEFolder then
	BEFolder = Instance.new("Folder")
	BEFolder.Name = "BindableEvents"
	BEFolder.Parent = ServerStorage:WaitForChild("MMO_ServerStoragePackage")
end
local ThreatBumpBE = BEFolder:FindFirstChild("ThreatBump")
if not ThreatBumpBE then
	ThreatBumpBE = Instance.new("BindableEvent")
	ThreatBumpBE.Name = "ThreatBump"
	ThreatBumpBE.Parent = BEFolder
end
local NPCDiedBE = BEFolder:FindFirstChild("NPCDied")
if not NPCDiedBE then
	NPCDiedBE = Instance.new("BindableEvent")
	NPCDiedBE.Name = "NPCDied"
	NPCDiedBE.Parent = BEFolder
end
local LogoutProxyKilledBE = BEFolder:FindFirstChild("LogoutProxyKilled")
if not LogoutProxyKilledBE then
	LogoutProxyKilledBE = Instance.new("BindableEvent")
	LogoutProxyKilledBE.Name = "LogoutProxyKilled"
	LogoutProxyKilledBE.Parent = BEFolder
end

local SpatialGrid = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("SpatialGrid"))
local HumanoidStats = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("HumanoidStats"))
local Players       = game:GetService("Players")
local MountInfo     = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("MountInfo"))
local MountHelper   = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("MountHelper"))
local CombatState   = require(game.ServerScriptService:WaitForChild("MMO_ServerPackage"):WaitForChild("PlayerCombatStateService"))
local updateMountHealthBar = MountHelper.updateMountHealthBar
local forceDismount        = MountHelper.forceDismount
local abortMounting        = MountHelper.abortMounting


local replicatedPackage = ReplicatedStore:WaitForChild("MMO_ReplicatedPackage")
local RemoteEvents       = replicatedPackage:WaitForChild("RemoteEvents")
local AbilityVisual      = RemoteEvents:FindFirstChild("AbilityVisual")
local UpdateHorseStatus  = RemoteEvents:WaitForChild("UpdateHorseStatus")
local CurrentHorseEvent  = RemoteEvents:WaitForChild("CurrentHorse")
local WorldBus = require(game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage"):WaitForChild("WorldBus"))

local Core = {}
local HITBOX_HEIGHT = 200
local SAMPLE_COUNT = 6

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

function Core.applyDamage(targetModel, dmg, source)
	local s = HumanoidStats.humanoidStats and HumanoidStats.humanoidStats[targetModel]
	if not s then return nil end

	local victimPlayer = Players:GetPlayerFromCharacter(targetModel)
	local sourcePlayer = sourceToPlayer(source)
	if targetModel:GetAttribute("LogoutProxy") == true and targetModel:GetAttribute("WorldSpawnBarrier") == true then
		return nil
	end
	if victimPlayer then
		if CombatState.IsDowned(victimPlayer) then return nil end
		if not sourcePlayer and not CombatState.CanMobDamage(victimPlayer) then return nil end
	end
	local oldHp = math.max(tonumber(s.Health) or 0, 0)
	local newHp = math.max(oldHp - (tonumber(dmg) or 0), 0)
	local dealt = oldHp - newHp
	s.Health    = newHp
	if targetModel then
		targetModel:SetAttribute("Health", newHp)
		targetModel:SetAttribute("MaxHealth", s.MaxHealth)
	end


	local head = targetModel:FindFirstChild("Head")
	if head and head:FindFirstChild("TopBar") then
		local hb = head.TopBar:FindFirstChild("HealthBar")
		if hb and hb:FindFirstChild("Health") then
			hb.Health.Size = UDim2.new(newHp / s.MaxHealth, 0, 1, 0)
		end
	end

	if dealt > 0 then
		if victimPlayer then
			CombatState.MarkDamageReceived(victimPlayer, sourcePlayer)
		end
		if sourcePlayer then
			CombatState.OnHostileAction(sourcePlayer, targetModel)
		end
	end

	if dealt > 0 and oldHp > 0 and newHp <= 0 then
		if targetModel:GetAttribute("LogoutProxy") == true then
			LogoutProxyKilledBE:Fire(targetModel, source, {
				Damage = dealt,
				KillerPlayer = sourcePlayer,
			})
		elseif s.IsNPC then
			NPCDiedBE:Fire(targetModel, source, {
				Damage = dealt,
				KillerPlayer = sourcePlayer,
				Tier = targetModel:GetAttribute("Tier"),
				ValorReward = targetModel:GetAttribute("ValorReward"),
			})
		elseif victimPlayer then
			CombatState.HandlePlayerDefeat(victimPlayer, source, {
				Damage = dealt,
			})
		end
	end

	return {
		Model     = targetModel,
		Damage    = dealt,
		NewHealth = newHp,
		MaxHealth = s.MaxHealth,
	}
end

local function _deleteDismountedHorseIfNear(ownerPlr, maxDist)
	local horse = MountInfo.mountedHorses[ownerPlr.UserId]
	if not horse or horse:GetAttribute("Mounted") then return false end

	local hrp = ownerPlr.Character and ownerPlr.Character:FindFirstChild("HumanoidRootPart")
	local hpp = horse.PrimaryPart
	if hrp and hpp then
		local d = (hrp.Position - hpp.Position).Magnitude
		if d > (maxDist or 25) then return false end
	end


	CurrentHorseEvent:FireClient(ownerPlr, nil, false)
	pcall(function() SpatialGrid.Remove(horse) end)
	horse:Destroy()

	MountInfo.horseToPlayer[horse]              = nil
	MountInfo.mountedHorses[ownerPlr.UserId]    = nil
	MountInfo.movementTimers[ownerPlr.UserId]   = nil
	MountInfo.horseSpeeds[horse]                = nil
	return true
end

local function _applyMountDamage(victimPlr, dmg)
	local horse = MountInfo.mountedHorses[victimPlr.UserId]
	if not horse then

		if MountInfo.mountingPlayers[victimPlr.UserId] then
			abortMounting(victimPlr)
			UpdateHorseStatus:FireClient(victimPlr, false)
		end
		return nil
	end


	if horse:GetAttribute("Mounted") then
		local hHum = horse:FindFirstChildWhichIsA("Humanoid")
		local sdat = MountInfo.horseSpeeds[horse]
		if hHum and sdat then
			hHum.WalkSpeed = sdat.BaseSpeed
		end
		MountInfo.movementTimers[victimPlr.UserId] = 0

		horse:SetAttribute("Health",    horse:GetAttribute("Health")    or 300)
		horse:SetAttribute("MaxHealth", horse:GetAttribute("MaxHealth") or 300)

		local old = horse:GetAttribute("Health")
		local newHp = math.max(old - (dmg or 0), 0)
		horse:SetAttribute("Health", newHp)
		updateMountHealthBar(horse)

		if newHp <= 0 then
			forceDismount(victimPlr, horse)
			UpdateHorseStatus:FireClient(victimPlr, false)
			pcall(function() SpatialGrid.Remove(horse) end)
			horse:Destroy()
			CurrentHorseEvent:FireClient(victimPlr, nil, false)
			MountInfo.mountedHorses[victimPlr.UserId] = nil
			MountInfo.horseToPlayer[horse]           = nil
			MountInfo.mountDebounce[victimPlr.UserId]   = false
			MountInfo.mountingPlayers[victimPlr.UserId] = nil
		end

		return { Model = horse, Damage = old - newHp, NewHealth = newHp, MaxHealth = horse:GetAttribute("MaxHealth") }
	else

		if MountInfo.mountingPlayers[victimPlr.UserId] then
			abortMounting(victimPlr)
			UpdateHorseStatus:FireClient(victimPlr, false)
		end
		return nil
	end
end

function Core.applyHeal(targetModel, amount)
	local s = HumanoidStats.humanoidStats and HumanoidStats.humanoidStats[targetModel]
	if not s or amount <= 0 then return nil end

	local newHp  = math.min(s.Health + amount, s.MaxHealth)
	local healed = newHp - s.Health
	if healed <= 0 then return nil end
	s.Health = newHp
	if targetModel then
		targetModel:SetAttribute("Health", newHp)
		targetModel:SetAttribute("MaxHealth", s.MaxHealth)
	end


	local head = targetModel:FindFirstChild("Head")
	if head and head:FindFirstChild("TopBar") then
		local hb = head.TopBar:FindFirstChild("HealthBar")
		if hb and hb:FindFirstChild("Health") then
			hb.Health.Size = UDim2.new(newHp / s.MaxHealth, 0, 1, 0)
		end
	end

	return {
		Model     = targetModel,
		Heal      = healed,
		NewHealth = newHp,
		MaxHealth = s.MaxHealth,
	}
end

local function _threatBump(victimModel, attackerModel, amount)
	if ThreatBumpBE and victimModel and attackerModel and (amount or 0) > 0 then
		pcall(function() ThreatBumpBE:Fire(victimModel, attackerModel, amount) end)
	end
end

local function _hflat(v) return Vector3.new(v.X, 0, v.Z) end

local function playerHasWorldBarrier(player)
	local character = player and player.Character
	return player and (player:GetAttribute("WorldSpawnBarrier") == true or (character and character:GetAttribute("WorldSpawnBarrier") == true))
end

local _partCache = setmetatable({}, {__mode = "k"})
local function partsOf(mdl)
	local cached = _partCache[mdl]
	if cached then return cached end
	local list = {}
	for _, bp in ipairs(mdl:GetDescendants()) do
		if bp:IsA("BasePart") then list[#list+1] = bp end
	end
	_partCache[mdl] = list
	return list
end

local function makeTargetPredicate(ctx, p)
	local allowSelf = p and p.AllowSelf
	if p and typeof(p.TargetPredicate) == "function" then
		return p.TargetPredicate
	end

	local mode = (p and p.TargetFilter) or "Enemies"
	if mode == "Allies" then
		return function(m) return (allowSelf or m ~= ctx.Character) and not ctx.IsHostile(m) end
	elseif mode == "Any" then
		return function(m) return (allowSelf or m ~= ctx.Character) end
	else

		return function(m) return (allowSelf or m ~= ctx.Character) and ctx.IsHostile(m) end
	end
end

local function applyDamageOrHeal(ctx, p, mdl)
	if p and p.Heal and p.Heal > 0 then
		return Core.applyHeal(mdl, p.Heal)
	end

	local dmg = (p and p.Damage) or (ctx and ctx._Damage) or 0
	if ctx and ctx.Player and dmg > 0 then
		local scale = math.max(0, tonumber(ctx.DamageScale) or 1)
		local stats = ctx.Stats
		local abilityBonus = math.max(0, tonumber(stats and stats.PhysicalAbilityBonus) or 0)
		dmg = math.max(0, math.floor(dmg * scale + abilityBonus + 0.5))
	end


	local vPlr = Players:GetPlayerFromCharacter(mdl)
	if vPlr and ctx and ctx.Player == nil and not CombatState.CanMobDamage(vPlr) then
		return nil
	end
	if vPlr and playerHasWorldBarrier(vPlr) then
		return nil
	end
	if vPlr and MountInfo.mountingPlayers[vPlr.UserId] then
		abortMounting(vPlr)
		UpdateHorseStatus:FireClient(vPlr, false)
	end


	ctx._mountDedup = ctx._mountDedup or {}

	local function alreadyProcessed(horse)
		if not horse then return false end
		if ctx._mountDedup[horse] then return true end
		ctx._mountDedup[horse] = true
		return false
	end


	if ctx and ctx.Player == nil then
		if vPlr then

			local horse = MountInfo.mountedHorses[vPlr.UserId]
			if horse and horse:GetAttribute("Mounted") then
				if alreadyProcessed(horse) then return nil end
				return _applyMountDamage(vPlr, dmg)
			end
		end


		local ownerPlr = MountInfo.horseToPlayer[mdl]
		if ownerPlr then
			if playerHasWorldBarrier(ownerPlr) then return nil end
			local horse = mdl
			if alreadyProcessed(horse) then return nil end
			return _applyMountDamage(ownerPlr, dmg)
		end


		local r = Core.applyDamage(mdl, dmg, ctx and (ctx.Player or ctx.Character))
		if r and ctx and ctx.Character then
			_threatBump(r.Model, ctx.Character, r.Damage)
		end
		return r
	end


	do

		local vPlr = Players:GetPlayerFromCharacter(mdl)
		if vPlr and MountInfo.mountingPlayers[vPlr.UserId] then
			abortMounting(vPlr)
			UpdateHorseStatus:FireClient(vPlr, false)
		end

		if vPlr then

			local horse = MountInfo.mountedHorses[vPlr.UserId]
			if horse then
				if horse:GetAttribute("Mounted") then
					if alreadyProcessed(horse) then return nil end
					return _applyMountDamage(vPlr, dmg)
				else


					_deleteDismountedHorseIfNear(vPlr, 25)

					local r = Core.applyDamage(mdl, dmg, ctx and (ctx.Player or ctx.Character))
					if r and ctx and ctx.Character then
						_threatBump(r.Model, ctx.Character, r.Damage)
					end
					return r
				end
			end


			local r = Core.applyDamage(mdl, dmg, ctx and (ctx.Player or ctx.Character))
			if r and ctx and ctx.Character then
				_threatBump(r.Model, ctx.Character, r.Damage)
			end
			return r
		end


		local ownerPlr = MountInfo.horseToPlayer[mdl]
		if ownerPlr then
			if playerHasWorldBarrier(ownerPlr) then return nil end
			if mdl:GetAttribute("Mounted") then
				if alreadyProcessed(mdl) then return nil end
				return _applyMountDamage(ownerPlr, dmg)
			else

				_deleteDismountedHorseIfNear(ownerPlr, 25)
				return nil
			end
		end

		local r = Core.applyDamage(mdl, dmg, ctx and (ctx.Player or ctx.Character))
		if r and ctx and ctx.Character then
			_threatBump(r.Model, ctx.Character, r.Damage)
		end
		return r
	end
end

local function frameFrom(center: Vector3, dir: Vector3)
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 1e-3 then dir = Vector3.new(1,0,0) end
	return CFrame.new(center, center + dir.Unit)
end

local function anyPartInOrientedRect(mdl: Model, cf: CFrame, halfW: number, halfL: number): boolean
	for _, bp in ipairs(partsOf(mdl)) do
		local lp = cf:PointToObjectSpace(bp.Position)
		if math.abs(lp.X) <= halfW and math.abs(lp.Z) <= halfL then
			return true
		end
	end
	return false
end

local function _halfDiag(halfW: number, halfL: number)
	return math.sqrt(halfW*halfW + halfL*halfL)
end


local function scanRectOnce(ctx, cf: CFrame, halfW: number, halfL: number, p, done, hits)
	done = done or {}
	hits = hits or {}
	local centre = cf.Position
	local radius = _halfDiag(halfW, halfL) + 2
	local pred = makeTargetPredicate(ctx, p)
	for _, mdl in ipairs(SpatialGrid.Query(centre, radius)) do
		if not done[mdl] and pred(mdl) and anyPartInOrientedRect(mdl, cf, halfW, halfL) then
			done[mdl] = true
			local r = applyDamageOrHeal(ctx, p, mdl)
			if r then hits[#hits+1] = r end
		end
	end
	return hits, done
end

function Core.PlayerApplyDamage(targetModel, dmg, sourcePlayer)
	local vPlr = Players:GetPlayerFromCharacter(targetModel)
	if vPlr then
		if MountInfo.mountingPlayers[vPlr.UserId] then
			abortMounting(vPlr)
			UpdateHorseStatus:FireClient(vPlr, false)
		end
		local horse = MountInfo.mountedHorses[vPlr.UserId]
		if horse then
			if horse:GetAttribute("Mounted") then
				return _applyMountDamage(vPlr, dmg)
			else
				_deleteDismountedHorseIfNear(vPlr, 25)
				return Core.applyDamage(targetModel, dmg, sourcePlayer)
			end
		end
	end

	local ownerPlr = MountInfo.horseToPlayer[targetModel]
	if ownerPlr then
		if targetModel:GetAttribute("Mounted") then
			return _applyMountDamage(ownerPlr, dmg)
		else
			_deleteDismountedHorseIfNear(ownerPlr, 25)
			return nil
		end
	end

	return Core.applyDamage(targetModel, dmg, sourcePlayer)
end

function Core.NPCApplyDamage(targetModel, dmg)
	local Players = game:GetService("Players")
	local vPlr = Players:GetPlayerFromCharacter(targetModel)
	if vPlr then
		if not CombatState.CanMobDamage(vPlr) then return nil end

		if MountInfo.mountingPlayers[vPlr.UserId] then
			abortMounting(vPlr)
			UpdateHorseStatus:FireClient(vPlr, false)
		end
		local horse = MountInfo.mountedHorses[vPlr.UserId]
		if horse and horse:GetAttribute("Mounted") then
			return _applyMountDamage(vPlr, dmg)
		end
	end


	local ownerPlr = MountInfo.horseToPlayer[targetModel]
	if ownerPlr then
		return _applyMountDamage(ownerPlr, dmg)
	end


	return Core.applyDamage(targetModel, dmg, nil)
end

local function gatherModels(ctx, centre, radius, p)
	local r2   = radius * radius
	local list = {}
	local pred = makeTargetPredicate(ctx, p)
	for _, mdl in ipairs(SpatialGrid.Query(centre, radius)) do
		if pred(mdl) then
			for _, bp in ipairs(partsOf(mdl)) do
				local dx = bp.Position.X - centre.X
				local dz = bp.Position.Z - centre.Z
				if dx*dx + dz*dz <= r2 then
					list[#list+1] = mdl
					break
				end
			end
		end
	end
	return list
end


local function _isHumanoidPart(part: BasePart?)
	if not part then return false end
	local mdl = part:FindFirstAncestorWhichIsA("Model")
	return mdl and mdl:FindFirstChildOfClass("Humanoid") ~= nil
end


local function _clampFlatFrom(startPos: Vector3, targetPos: Vector3, maxRange: number?)
	if not maxRange or maxRange <= 0 then return targetPos end
	local flatTarget = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
	local disp      = flatTarget - startPos
	local d         = disp.Magnitude
	if d <= maxRange then return flatTarget end
	return startPos + disp.Unit * maxRange
end


local function _npcPredPos(ctx: any): Vector3?
	if ctx and ctx.Player == nil and ctx.TargetPred and ctx.TargetPred.Pos then
		return ctx.TargetPred.Pos
	end
	return nil
end


local function _aimDir(ctx, p, root, origin)

	if p and p.Dir and p.Dir.Magnitude > 1e-3 then
		return Vector3.new(p.Dir.X, 0, p.Dir.Z).Unit
	end

	if not (p and p.NoPred) then
		local pos = _npcPredPos(ctx)
		if pos then
			local d = Vector3.new(pos.X - origin.X, 0, pos.Z - origin.Z)
			if d.Magnitude > 1e-3 then return d.Unit end
		end
	end

	local look = root and root.CFrame.LookVector or Vector3.new(1,0,0)
	look = Vector3.new(look.X, 0, look.Z)
	return (look.Magnitude > 1e-3 and look.Unit) or Vector3.new(1,0,0)
end

local function _aimPos(ctx, p, origin, maxRange)

	local pos = p and p.Position

	if not pos and not (p and p.NoPred) then pos = _npcPredPos(ctx) end

	pos = pos or origin
	return _clampFlatFrom(origin, pos, maxRange)
end

local ORIGIN_TOLERANCE = 3

local function getOrigin(ctx, p)
	local root      = ctx.Character and ctx.Character:FindFirstChild("HumanoidRootPart")
	local serverPos = root and root.Position


	local function isReasonable(pos)
		return serverPos and (pos - serverPos).Magnitude <= ORIGIN_TOLERANCE
	end


	if p and p.Origin and isReasonable(p.Origin) then
		return p.Origin
	end


	if ctx and ctx.StartPos and isReasonable(ctx.StartPos) then
		return ctx.StartPos
	end


	return serverPos
end

local LANDING_BUFFER    = 2
local RAY_HEIGHT_OFFSET = 2

local ALLOWED_GROUP = {
	Mobs        = true,
	Character   = true,
	Horse       = true,
	Walkthrough = true,
}

local function _hasNonCollidableMarker(inst)
	local current = inst
	while current and current ~= Workspace do
		if current.Name == "Non-Collidable" or current.Name == "NonCollidable" or current.Name == "Ignore" then
			return true
		end
		if current:GetAttribute("NonCollidable") == true or current:GetAttribute("Non-Collidable") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

local function _isNonBlockingRayPart(part)
	if not part then return false end
	if _isHumanoidPart(part) or _hasNonCollidableMarker(part) then return true end
	if part:IsA("BasePart") then
		if part.CanCollide == false then return true end
		if ALLOWED_GROUP[part.CollisionGroup] or part.CollisionGroup == "Non-Collidable" or part.CollisionGroup == "NonCollidable" then return true end
	end
	return false
end

local function safeFlatTarget(ctx, startPos, desiredPos)

	local flatDesired = Vector3.new(desiredPos.X, startPos.Y, desiredPos.Z)
	local disp        = flatDesired - startPos
	local totalDist   = disp.Magnitude
	if totalDist < 0.1 then return flatDesired end

	local dir         = disp.Unit
	local origin      = startPos - Vector3.new(0, RAY_HEIGHT_OFFSET, 0)

	local params      = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.Character }
	params.IgnoreWater = true

	local travelled   = 0
	while travelled < totalDist do
		local result = Workspace:Raycast(origin + dir * travelled,
			dir * (totalDist - travelled),
			params)
		if not result then
			return flatDesired
		end

		local part = result.Instance
		if not _isNonBlockingRayPart(part) then
			local allowedDist = math.max(travelled + result.Distance - LANDING_BUFFER, 0)
			return startPos + dir * allowedDist
		end

		travelled += result.Distance + 0.05
	end

	return flatDesired
end

local function groundYAt(ctx, pos)
	local excludes = {}
	if ctx and ctx.Character then table.insert(excludes, ctx.Character) end
	local origin = Vector3.new(pos.X, pos.Y + 512, pos.Z)
	local direction = Vector3.new(0, -2048, 0)
	for _ = 1, 12 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excludes
		params.IgnoreWater = true
		local hit = Workspace:Raycast(origin, direction, params)
		if not hit then return nil end
		if hit.Instance == Workspace.Terrain or not _isNonBlockingRayPart(hit.Instance) then
			return hit.Position.Y
		end
		table.insert(excludes, hit.Instance)
	end
	return nil
end

local function rootGroundOffset(character, root)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local halfRoot = root and root.Size.Y * 0.5 or 1
	return (humanoid and humanoid.HipHeight or 0) + halfRoot
end

local function snapRootTargetToGround(ctx, targetPos, root)
	local y = groundYAt(ctx, targetPos)
	if not y then return targetPos end
	return Vector3.new(targetPos.X, y + rootGroundOffset(ctx and ctx.Character, root), targetPos.Z)
end


local function emitVisual(caster, effectName, data)

	local pos = data.Origin or data.Start or data.Centre or data.Target or nil
	if pos then
		WorldBus.FXInRange(pos, 128, effectName, data)
	else

		local ch = caster and caster.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
		WorldBus.FXInRange(hrp and hrp.Position or Vector3.new(), 128, effectName, data)
	end
end


local function withVFXTag(data, p)
	if p and p.VFX ~= nil then
		data.VFX = p.VFX
	end
	return data
end


Core.Visual = Core.Visual or {}


function Core.Visual.RectTelegraph(ctx, p)

	local root = ctx.Character and ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local origin = getOrigin(ctx, p) or (root and root.Position)
	local dir    = _aimDir(ctx, p, root, origin)
	if not (origin and dir) then return end

	local length = p.Length or (p.Range or 12)
	local width  = (p.Width or 4) + 1.0
	local centre = origin + dir * (length * 0.5)

	emitVisual(ctx.Player, "RectTelegraph", {
		Centre   = centre,
		Dir      = dir,
		Width    = width,
		Length   = length,
		Height   = HITBOX_HEIGHT,
		Duration = p.Duration or 0.6,
	})
end


Core.Move = Core.Move or {}


function Core.Move.DashDelayed(ctx, p)
	local root = ctx.Character and ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin)
	dir = Vector3.new(dir.X, 0, dir.Z); if dir.Magnitude < 1e-3 then dir = Vector3.new(1,0,0) end
	dir = dir.Unit


	local distance = p.Distance or p.Range or 12
	Core.Visual.RectTelegraph(ctx, {
		Origin   = origin,
		Dir      = dir,
		Length   = distance,
		Width    = p.Width or 4,
		Duration = p.Delay or 0.6,
	})
	if (p.Delay or 0) > 0 then task.wait(p.Delay) end


	return Core.Move.Dash(ctx, p)
end


function Core.Move.JumpImpactDelayed(ctx, p)
	local hrp = ctx.Character and ctx.Character:FindFirstChild("HumanoidRootPart")
	if not (hrp and p and (p.TargetPos or (ctx.TargetPred and ctx.TargetPred.Pos))) then return end

	local start   = getOrigin(ctx, p) or hrp.Position
	local target  = p.TargetPos or ctx.TargetPred.Pos
	local flatT   = _clampFlatFrom(start, target, p.Range)
	local safeT   = safeFlatTarget(ctx, start, flatT)
	local disp    = Vector3.new(safeT.X - start.X, 0, safeT.Z - start.Z)
	local length  = math.max(disp.Magnitude, 0.01)

	Core.Visual.RectTelegraph(ctx, {
		Origin   = start,
		Dir      = (length > 0.01) and disp.Unit or Vector3.new(1,0,0),
		Length   = length,
		Width    = p.PathWidth or 4,
		Duration = p.Delay or 0.6,
	})
	if (p.Delay or 0) > 0 then task.wait(p.Delay) end

	return Core.JumpImpact(ctx, {
		TargetPos = safeT,
		Duration  = p.Duration or 0.9,
		Radius    = p.Radius or 6,
		Damage    = p.Damage,
		Heal      = p.Heal,
		Range     = p.Range,
		TargetFilter = p.TargetFilter,
	})
end


Core.Move = Core.Move or {}


function Core.Move.Blink(ctx, p)
	local hrp = ctx.Character:FindFirstChild("HumanoidRootPart"); if not hrp or not p.TargetPos then return end
	local start = hrp.Position
	local desired = _clampFlatFrom(start, p.TargetPos, p.Range)
	local dest    = safeFlatTarget(ctx, start, desired)

	emitVisual(ctx.Player, "Blink", { Start = start, Target = dest })
	hrp.CFrame = CFrame.new(dest)

	local hits = {}
	if p.ArrivalRadius and ((p.Damage or 0) > 0 or (p.Heal or 0) > 0) then
		hits = Core.Sphere.Location(ctx, {
			Position = dest,
			Radius   = p.ArrivalRadius,
			Damage   = p.Damage,
			Heal     = p.Heal,
			TargetFilter = p.TargetFilter,
		})
		emitVisual(ctx.Player, "BlinkImpact", { Centre = dest, Radius = p.ArrivalRadius })
	end
	return hits
end

function Core.Move.BlinkDelayed(ctx, p)
	local hrp = ctx.Character:FindFirstChild("HumanoidRootPart"); if not hrp or not p.TargetPos then return end
	local start = hrp.Position
	local desired = _clampFlatFrom(start, p.TargetPos, p.Range)
	local dest    = safeFlatTarget(ctx, start, desired)
	local dur = math.max(p.Duration or 0.6, 0)


	local dir = (dest - start); local len = math.max(dir.Magnitude, 0.01); dir = (dir / len)
	Core.Visual.RectTelegraph(ctx, { Origin = start, Dir = dir, Length = len, Width = p.PathWidth or 3, Duration = dur })
	if dur > 0 then task.wait(dur) end

	return Core.Move.Blink(ctx, { TargetPos = dest, ArrivalRadius = p.ArrivalRadius, Damage = p.Damage, Heal = p.Heal, TargetFilter = p.TargetFilter })
end


function Core.Move.Dash(ctx, p)
	local hrp = ctx.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
	local look = hrp.CFrame.LookVector
	local dir  = p.Dir or look
	dir = Vector3.new(dir.X, 0, dir.Z); if dir.Magnitude < 1e-3 then dir = Vector3.new(1,0,0) end
	dir = dir.Unit

	local distance = p.Distance or 12
	local speed    = p.Speed or 48
	local duration = p.Duration or (distance / speed)
	local traveled = 0
	local vel      = dir * (distance / duration)
	local width    = (p.Width or 4) + 1.0

	local att = Instance.new("Attachment", hrp)
	local lv  = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.VectorVelocity = vel
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.Parent = hrp

	local oldOwner = hrp:GetNetworkOwner()
	hrp:SetNetworkOwner(ctx.Player)

	local hits, done = {}, {}
	emitVisual(ctx.Player, "Dash", { Start = hrp.Position, Dir = dir, Distance = distance, Duration = duration, Width = width })

	local prevPos = hrp.Position
	local conn
	conn = RunSrv.Heartbeat:Connect(function(dt)
		if traveled >= distance then conn:Disconnect() return end
		local step = math.min(distance - traveled, (distance / duration) * dt)
		traveled += step

		if ((p.Damage or 0) > 0) or ((p.Heal or 0) > 0) then
			local currPos = hrp.Position
			local mid     = (prevPos + currPos) * 0.5
			local segLen  = (currPos - prevPos).Magnitude
			if segLen > 0 then
				local halfW, halfL = (width * 0.5), (segLen * 0.5 + 0.125)
				local cf = frameFrom(mid, currPos - prevPos)
				hits, done = scanRectOnce(ctx, cf, halfW, halfL, p, done, hits)
			end
			prevPos = currPos
		end
	end)

	task.wait(duration)
	if conn and conn.Connected then conn:Disconnect() end
	hrp:SetNetworkOwner(oldOwner)
	lv:Destroy(); att:Destroy()
	return hits
end

Core.Effect = Core.Effect or {}

function Core.Effect.OverTime(ctx, model, opts)
	local tick = math.max(opts.Tick or 0.5, 0.05)
	local t0   = os.clock()
	while os.clock() - t0 < (opts.Duration or 0) do
		if not model or not model.Parent then break end
		if opts.Kind == "Heal" then
			Core.applyHeal(model, opts.AmountPerTick or 0)
		else
			Core.applyDamage(model, opts.AmountPerTick or 0, ctx and (ctx.Player or ctx.Character))
		end
		task.wait(tick)
	end
end

function Core.Effect.DoT(ctx, model, dps, duration, tick)
	Core.Effect.OverTime(ctx, model, {
		Kind = "Damage", AmountPerTick = (dps or 10) * (tick or 0.5),
		Duration = duration or 4, Tick = tick or 0.5
	})
end

function Core.Effect.HoT(ctx, model, hps, duration, tick)
	Core.Effect.OverTime(ctx, model, {
		Kind = "Heal", AmountPerTick = (hps or 10) * (tick or 0.5),
		Duration = duration or 4, Tick = tick or 0.5
	})
end

Core.Force = Core.Force or {}


function Core.Force.Knockback(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local centre = _clampFlatFrom(origin, p.Position or origin, p.Range)
	local power  = p.Power or 70
	local dur    = p.Duration or 0.25

	for _, mdl in ipairs(gatherModels(ctx, centre, p.Radius, p)) do
		local hrp = mdl:FindFirstChild("HumanoidRootPart")
		if hrp then
			local dir = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(centre.X, 0, centre.Z)).Unit
			local att = Instance.new("Attachment", hrp)
			local lv  = Instance.new("LinearVelocity")
			lv.Attachment0 = att
			lv.MaxForce    = math.huge
			lv.RelativeTo  = Enum.ActuatorRelativeTo.World
			lv.VectorVelocity = dir * power
			lv.Parent = hrp
			Debris:AddItem(att, dur); Debris:AddItem(lv, dur)
		end
	end
	emitVisual(ctx.Player, "RadialKnockback", { Centre = centre, Radius = p.Radius, Power = power, Duration = dur })
end

function Core.Force.Pull(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local centre = _clampFlatFrom(origin, p.Position or origin, p.Range)
	local power  = p.Power or 70
	local dur    = p.Duration or 0.25

	for _, mdl in ipairs(gatherModels(ctx, centre, p.Radius, p)) do
		local hrp = mdl:FindFirstChild("HumanoidRootPart")
		if hrp then
			local dir = (Vector3.new(centre.X, 0, centre.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Unit
			local att = Instance.new("Attachment", hrp)
			local lv  = Instance.new("LinearVelocity")
			lv.Attachment0 = att
			lv.MaxForce    = math.huge
			lv.RelativeTo  = Enum.ActuatorRelativeTo.World
			lv.VectorVelocity = dir * power
			lv.Parent = hrp
			Debris:AddItem(att, dur); Debris:AddItem(lv, dur)
		end
	end
	emitVisual(ctx.Player, "RadialPull", { Centre = centre, Radius = p.Radius, Power = power, Duration = dur })
end

function Core.Force.KnockbackDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local centre = _clampFlatFrom(origin, p.Position or origin, p.Range)
	local dur = math.max(p.Duration or 0.6, 0)

	emitVisual(ctx.Player, "CylTelegraph", withVFXTag({
		Centre = centre, Radius = p.Radius, Height = HITBOX_HEIGHT, Duration = dur
	}, p))
	if dur > 0 then task.wait(dur) end

	return Core.Force.Knockback(ctx, p)
end

function Core.Force.PullDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local centre = _clampFlatFrom(origin, p.Position or origin, p.Range)
	local dur = math.max(p.Duration or 0.6, 0)

	emitVisual(ctx.Player, "CylTelegraph", withVFXTag({
		Centre = centre, Radius = p.Radius, Height = HITBOX_HEIGHT, Duration = dur
	}, p))
	if dur > 0 then task.wait(dur) end

	return Core.Force.Pull(ctx, p)
end

Core.Beam = Core.Beam or {}


function Core.Beam.Channel(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin)
	dir = Vector3.new(dir.X, 0, dir.Z); if dir.Magnitude < 1e-3 then dir = Vector3.new(1,0,0) end
	dir = dir.Unit

	local length = p.Range or 16
	local width  = (p.Width or 4) + 1.0
	local dur    = p.Duration or 1.0
	local tickDt = math.max(p.Tick or 0.1, 0.05)

	emitVisual(ctx.Player, "BeamStart", { Origin = origin, Dir = dir, Range = length, Width = width, Duration = dur })

	local hits = {}
	local tickP = {}
	for k,v in pairs(p) do tickP[k] = v end
	tickP.Damage = (p.DamagePerTick ~= nil) and p.DamagePerTick or p.Damage
	tickP.Heal   = (p.HealPerTick   ~= nil) and p.HealPerTick   or p.Heal

	local t0 = os.clock()
	while os.clock() - t0 < dur do
		local centre = origin + dir * (length * 0.5)
		local halfW, halfL = (width * 0.5), (length * 0.5)
		local cf = frameFrom(centre, dir)
		hits = select(1, scanRectOnce(ctx, cf, halfW, halfL, tickP, nil, hits))
		task.wait(tickDt)
	end
	emitVisual(ctx.Player, "BeamEnd", { Origin = origin, Dir = dir })
	return hits
end

function Core.Beam.DelayedChannel(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir = _aimDir(ctx, p, root, origin)
	local length = p.Range or 16
	local width  = p.Width or 4
	local delay  = math.max(p.Delay or 0.6, 0)

	Core.Visual.RectTelegraph(ctx, {
		Origin = origin, Dir = dir, Length = length, Width = width, Duration = delay, VFX = p.VFX
	})
	if delay > 0 then task.wait(delay) end

	return Core.Beam.Channel(ctx, p)
end

Core.Ring = Core.Ring or {}

local function _scanRing(ctx, centre, rInner, rOuter, p)
	local hits, done = {}, {}
	local r2i, r2o = rInner*rInner, rOuter*rOuter
	for _, mdl in ipairs(gatherModels(ctx, centre, rOuter, p)) do
		if not done[mdl] then
			for _, bp in ipairs(partsOf(mdl)) do
				local dx = bp.Position.X - centre.X
				local dz = bp.Position.Z - centre.Z
				local d2 = dx*dx + dz*dz
				if d2 <= r2o and d2 >= r2i then
					done[mdl] = true
					local r = applyDamageOrHeal(ctx, p, mdl)
					if r then hits[#hits+1] = r end
					break
				end
			end
		end
	end
	return hits
end


function Core.Ring.Static(ctx, p)
	ctx._Damage = p.Damage
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local pos    = _aimPos(ctx, p, origin, p.Range)

	local hits = _scanRing(ctx, pos, p.InnerRadius or 4, p.OuterRadius or 10, p)
	emitVisual(ctx.Player, "RingStatic", { Centre = pos, Inner = p.InnerRadius or 4, Outer = p.OuterRadius or 10 })
	return hits
end


function Core.Ring.Delayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local pos    = _aimPos(ctx, p, origin, p.Range)

	local inner, outer = p.InnerRadius or 4, p.OuterRadius or 10
	emitVisual(ctx.Player, "RingTelegraph", { Centre = pos, Inner = inner, Outer = outer, Duration = p.Duration or 1.0 })
	if (p.Duration or 0) > 0 then task.wait(p.Duration) end

	ctx._Damage = p.Damage
	return _scanRing(ctx, pos, inner, outer, p)
end


Core.Line = {}


function Core.Line.Static(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin); if dir.Magnitude < 1e-3 then return end
	dir = dir.Unit

	local PAD_W, PAD_L = 1.0, 0.25
	local width  = (p.Width or 4) + PAD_W
	local length = (p.Range or 12) + PAD_L

	local centre = origin + dir * (length * 0.5)
	local halfW, halfL = (width * 0.5), (length * 0.5)
	local cf = frameFrom(centre, dir)

	local hits = select(1, scanRectOnce(ctx, cf, halfW, halfL, p))
	emitVisual(ctx.Player, "LineStatic", withVFXTag({ Origin = origin, Dir = dir, Width = width, Height = HITBOX_HEIGHT, Range = length }), p)
	return hits
end


function Core.Line.StaticDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin)
	local length = p.Range or 12
	local width  = p.Width or 4
	local dur    = math.max(p.Duration or 0.6, 0)


	Core.Visual.RectTelegraph(ctx, {
		Origin = origin, Dir = dir, Length = length, Width = width, Duration = dur, VFX = p.VFX
	})

	if dur > 0 then task.wait(dur) end


	return Core.Line.Static(ctx, {
		Range = length, Width = width, Damage = p.Damage, Dir = dir, TargetFilter = p.TargetFilter, VFX = p.VFX
	})
end


function Core.Line.Tween(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin); if dir.Magnitude < 1e-3 then return end
	dir = dir.Unit

	local PAD_W, PAD_L = 1.0, 0.25
	local total   = (p.Range or 12)
	local width   = (p.Width or 4) + PAD_W
	local steps   = math.max(6, math.ceil(total / 12))
	local stepLen = total / steps

	local hits, done = {}, {}
	for i = 1, steps do
		local segMid = origin + dir * (stepLen * (i - 0.5))
		local halfW, halfL = (width * 0.5), (stepLen * 0.5 + PAD_L*0.5)
		local cf = frameFrom(segMid, dir)
		hits, done = scanRectOnce(ctx, cf, halfW, halfL, p, done, hits)
		RunSrv.Heartbeat:Wait()
	end

	emitVisual(ctx.Player, "LineTween", withVFXTag({ Origin = origin, Dir = dir, Width = width, Height = HITBOX_HEIGHT, Range = total, Duration = p.Duration }), p)
	return hits
end


function Core.Line.TweenDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin)
	local length = p.Range or 12
	local width  = p.Width or 4
	local dur    = math.max(p.Duration or 0.6, 0)

	Core.Visual.RectTelegraph(ctx, {
		Origin = origin, Dir = dir, Length = length, Width = width, Duration = dur, VFX = p.VFX
	})
	if dur > 0 then task.wait(dur) end


	return Core.Line.Tween(ctx, {
		Range = length, Width = width, Damage = p.Damage, Dir = dir, Duration = (p.SweepDuration or 0.15),
		TargetFilter = p.TargetFilter, VFX = p.VFX
	})
end


function Core.Line.Projectile(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin)

	local travelled  = 0
	local speed      = (p.Speed or 120)
	local startPos   = origin
	local hits, done = {}, {}

	local conn
	conn = RunSrv.Heartbeat:Connect(function(dt)
		if travelled >= p.Range then conn:Disconnect() return end
		local prevPos = startPos + dir * travelled
		travelled += speed * dt
		local currPos = startPos + dir * travelled

		local seg     = currPos - prevPos
		local segLen  = seg.Magnitude
		if segLen > 0 then
			local mid      = (prevPos + currPos) * 0.5
			local width    = (p.Width or 4) + 1.0

			local coverLen = math.max(segLen, width)

			local halfW, halfL = (width * 0.5), (coverLen * 0.5 + 0.125)
			local cf = frameFrom(mid, seg)
			hits, done = scanRectOnce(ctx, cf, halfW, halfL, p, done, hits)
		end
	end)

	emitVisual(ctx.Player, "LineProjectile", withVFXTag({
		Origin = origin, Dir = dir, Width = (p.Width or 4), Height = HITBOX_HEIGHT, Range = p.Range, Speed = speed, Model = p.ModelName,
	}), p)

	task.wait(p.Range / speed)
	if conn and conn.Connected then conn:Disconnect() end
	return hits
end


function Core.Line.ProjectileDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin)
	local length = p.Range or 20
	local width  = p.Width or 2
	local dur    = math.max(p.Duration or 0.5, 0)

	Core.Visual.RectTelegraph(ctx, {
		Origin = origin, Dir = dir, Length = length, Width = width, Duration = dur, VFX = p.VFX
	})
	if dur > 0 then task.wait(dur) end

	return Core.Line.Projectile(ctx, {
		Range = length, Width = width, Damage = p.Damage, Speed = p.Speed or 120, Dir = dir,
		TargetFilter = p.TargetFilter, VFX = p.VFX
	})
end


function Core.Line.Location(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local centre = _aimPos(ctx, p, origin, p.Range)
	local dir    = _aimDir(ctx, p, root, centre)
	if not dir or dir.Magnitude < 1e-3 then dir = root.CFrame.LookVector end
	dir = _hflat(dir); if dir.Magnitude < 1e-3 then dir = Vector3.new(1,0,0) end
	dir = dir.Unit

	local PAD_W, PAD_L = 1.0, 0.25
	local width  = (p.Width  or 6) + PAD_W
	local length = (p.Length or 6) + PAD_L
	local halfW, halfL = (width * 0.5), (length * 0.5)
	local cf = frameFrom(centre, dir)

	local hits = select(1, scanRectOnce(ctx, cf, halfW, halfL, p))
	emitVisual(ctx.Player, "RectInstant", withVFXTag({ Centre = centre, Dir = dir, Width = width, Length = length, Height = HITBOX_HEIGHT }), p)
	return hits
end


function Core.Line.LocationDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end

	local origin  = getOrigin(ctx, p) or root.Position
	local centre  = _aimPos(ctx, p, origin, p.Range)
	local dir     = _aimDir(ctx, p, root, centre)

	local PAD_W, PAD_L = 1.0, 0.25
	local width   = (p.Width  or 6) + PAD_W
	local length  = (p.Length or 6) + PAD_L
	local duration = math.max(p.Duration or 0, 0)

	emitVisual(ctx.Player, "RectTelegraph", withVFXTag({
		Centre = centre, Dir = dir, Width = width, Length = length, Height = HITBOX_HEIGHT, Duration = duration
	}), p)

	if duration > 0 then task.wait(duration) end

	local halfW, halfL = (width * 0.5), (length * 0.5)
	local cf = frameFrom(centre, dir)
	local hits = select(1, scanRectOnce(ctx, cf, halfW, halfL, p))
	return hits
end


Core.Cylinder = {}

local function _scanCylinder(center, radius, ctx, p)
	local hits, done = {}, {}
	for _, mdl in ipairs(gatherModels(ctx, center, radius, p)) do
		if not done[mdl] then
			done[mdl] = true
			local res = applyDamageOrHeal(ctx, p, mdl)
			if res then hits[#hits+1] = res end
		end
	end
	return hits
end


function Core.Cylinder.Static(ctx, p)

	ctx._Damage = p.Damage
	local root  = ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local origin   = getOrigin(ctx, p) or root.Position
	local hits = _scanCylinder(origin, p.Radius, ctx, p)
	emitVisual(ctx.Player, "CylStatic", withVFXTag({Centre = origin, Radius = p.Radius, Height = HITBOX_HEIGHT}), p)
	return hits
end

function Core.Cylinder.StaticDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local centre = getOrigin(ctx, p) or root.Position
	local dur = math.max(p.Duration or 0.6, 0)

	emitVisual(ctx.Player, "CylTelegraph", withVFXTag({
		Centre = centre, Radius = p.Radius, Height = HITBOX_HEIGHT, Duration = dur
	}, p))
	if dur > 0 then task.wait(dur) end

	return Core.Cylinder.Static(ctx, p)
end


function Core.Cylinder.Tween(ctx, p)

	ctx._Damage = p.Damage
	local root  = ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local origin   = getOrigin(ctx, p) or root.Position
	local steps   = SAMPLE_COUNT
	local hits, done = {}, {}
	for i = 1, steps do
		local rNow   = p.Radius * (i / steps)
		local partHits = _scanCylinder(origin, rNow, ctx, p)

		for _, h in ipairs(partHits) do
			if not done[h.Model] then
				table.insert(hits, h)
				done[h.Model] = true
			end
		end
		RunSrv.Heartbeat:Wait()
	end
	emitVisual(ctx.Player, "CylTween", withVFXTag({Centre = origin, Radius = p.Radius, Height = HITBOX_HEIGHT, Duration = p.Duration}), p)
	return hits
end

function Core.Cylinder.TweenDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local centre = getOrigin(ctx, p) or root.Position
	local dur = math.max(p.Duration or 0.6, 0)

	emitVisual(ctx.Player, "CylTelegraph", withVFXTag({
		Centre = centre, Radius = p.Radius, Height = HITBOX_HEIGHT, Duration = dur
	}, p))
	if dur > 0 then task.wait(dur) end

	return Core.Cylinder.Tween(ctx, p)
end


function Core.Cylinder.Projectile(ctx, p)

	ctx._Damage = p.Damage
	local root = ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin)
	local startPos  = origin
	local travelled = 0
	local speed     = p.Speed or 80
	local hits, done = {}, {}

	local prevPos = startPos
	local conn
	conn = RunSrv.Heartbeat:Connect(function(dt)
		if travelled >= p.Range then conn:Disconnect() return end
		local prev = prevPos
		travelled += speed * dt
		local curr = startPos + dir * travelled
		local seg  = curr - prev
		local segLen = seg.Magnitude
		if segLen > 0 then
			local width    = (p.Radius or 4) * 2 + 1.0
			local coverLen = segLen + (p.Radius or 4) * 2
			local halfW, halfL = (width * 0.5), (coverLen * 0.5 + 0.125)
			local mid = (prev + curr) * 0.5
			local cf  = frameFrom(mid, seg)
			hits, done = scanRectOnce(ctx, cf, halfW, halfL, p, done, hits)
		end
		prevPos = curr
	end)

	emitVisual(ctx.Player, "CylProjectile", withVFXTag({
		Origin  = startPos,
		Dir     = dir,
		Radius  = p.Radius,
		Height  = HITBOX_HEIGHT,
		Range   = p.Range,
		Speed   = speed,
		Model   = p.ModelName,
	}), p)

	task.wait(p.Range / speed)
	if conn and conn.Connected then conn:Disconnect() end
	return hits
end

function Core.Cylinder.ProjectileDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir = _aimDir(ctx, p, root, origin)
	local length = p.Range or 16
	local width  = (p.Radius or 4) * 2
	local dur = math.max(p.Duration or 0.6, 0)

	Core.Visual.RectTelegraph(ctx, {
		Origin = origin, Dir = dir, Length = length, Width = width, Duration = dur, VFX = p.VFX
	})
	if dur > 0 then task.wait(dur) end

	return Core.Cylinder.Projectile(ctx, p)
end


function Core.Cylinder.Location(ctx, p)

	ctx._Damage = p.Damage
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local centre = _aimPos(ctx, p, origin, p.Range)

	local hits = _scanCylinder(centre, p.Radius, ctx, p)

	emitVisual(ctx.Player, "CylLocation", withVFXTag({
		Centre   = centre,
		Radius   = p.Radius,
		Height   = HITBOX_HEIGHT,
		Duration = p.Duration or 0,
	}), p)

	return hits
end


function Core.Cylinder.Delayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin  = getOrigin(ctx, p) or root.Position
	local centre = _aimPos(ctx, p, origin, p.Range)
	local radius  = p.Radius or 6
	local duration = math.max(p.Duration or 0, 0)

	emitVisual(ctx.Player, "CylTelegraph", withVFXTag({
		Centre   = centre,
		Radius   = radius,
		Height   = HITBOX_HEIGHT,
		Duration = duration,
	}), p)

	if duration > 0 then task.wait(duration) end


	return Core.Cylinder.Location(ctx, {
		Position = centre,
		Radius   = radius,
		Damage   = p.Damage,
		Heal     = p.Heal,
		TargetFilter = p.TargetFilter,
		Duration = 0,
	})
end


Core.Sphere = {}


local function _scanSphere(center, radius, ctx, p)
	local hits, done = {}, {}
	for _, mdl in ipairs(gatherModels(ctx, center, radius, p)) do
		if not done[mdl] then
			done[mdl] = true
			local res = applyDamageOrHeal(ctx, p, mdl)
			if res then hits[#hits+1] = res end
		end
	end
	return hits
end


function Core.Sphere.Static(ctx, p)

	ctx._Damage = p.Damage
	local root  = ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local origin   = getOrigin(ctx, p) or root.Position
	local hits = _scanSphere(origin, p.Radius, ctx, p)

	emitVisual(ctx.Player, "SphStatic", withVFXTag({Centre = origin, Radius = p.Radius}), p)
	return hits
end

function Core.Sphere.StaticDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local centre = getOrigin(ctx, p) or root.Position
	local dur = math.max(p.Duration or 0.6, 0)

	emitVisual(ctx.Player, "CylTelegraph", withVFXTag({
		Centre = centre, Radius = p.Radius, Height = HITBOX_HEIGHT, Duration = dur
	}, p))
	if dur > 0 then task.wait(dur) end

	return Core.Sphere.Static(ctx, p)
end


function Core.Sphere.Tween(ctx, p)

	ctx._Damage = p.Damage
	local root  = ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local origin   = getOrigin(ctx, p) or root.Position
	local steps = SAMPLE_COUNT
	local hits, done = {}, {}
	for i = 1, steps do
		local rNow = p.Radius * (i / steps)
		local partHits = _scanSphere(origin, rNow, ctx, p)
		for _, h in ipairs(partHits) do
			if not done[h.Model] then
				table.insert(hits, h)
				done[h.Model] = true
			end
		end
		RunSrv.Heartbeat:Wait()
	end

	emitVisual(ctx.Player, "SphTween", withVFXTag({
		Centre   = origin,
		Radius   = p.Radius,
		Duration = p.Duration,
	}), p)
	return hits
end

function Core.Sphere.TweenDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local centre = getOrigin(ctx, p) or root.Position
	local dur = math.max(p.Duration or 0.6, 0)

	emitVisual(ctx.Player, "CylTelegraph", withVFXTag({
		Centre = centre, Radius = p.Radius, Height = HITBOX_HEIGHT, Duration = dur
	}, p))
	if dur > 0 then task.wait(dur) end

	return Core.Sphere.Tween(ctx, p)
end


function Core.Sphere.Projectile(ctx, p)

	ctx._Damage = p.Damage
	local root = ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin)
	local startPos  = origin
	local travelled = 0
	local speed     = p.Speed or 80
	local hits, done = {}, {}

	local prevPos = origin
	local conn
	conn = RunSrv.Heartbeat:Connect(function(dt)
		if travelled >= p.Range then conn:Disconnect() return end
		local prev = prevPos
		travelled += speed * dt
		local curr = startPos + dir * travelled
		local seg  = curr - prev
		local segLen = seg.Magnitude
		if segLen > 0 then

			local width    = (p.Radius or 3) * 2 + 1.0
			local coverLen = segLen + (p.Radius or 3) * 2
			local halfW, halfL = (width * 0.5), (coverLen * 0.5 + 0.125)
			local mid = (prev + curr) * 0.5
			local cf  = frameFrom(mid, seg)
			hits, done = scanRectOnce(ctx, cf, halfW, halfL, p, done, hits)
		end
		prevPos = curr
	end)

	emitVisual(ctx.Player, "SphProjectile", withVFXTag({
		Origin  = startPos,
		Dir     = dir,
		Radius  = p.Radius,
		Range   = p.Range,
		Speed   = speed,
		Model   = p.ModelName,
	}), p)

	task.wait(p.Range / speed)
	if conn and conn.Connected then conn:Disconnect() end
	return hits
end

function Core.Sphere.ProjectileDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local dir = _aimDir(ctx, p, root, origin)
	local length = p.Range or 16
	local width  = (p.Radius or 3) * 2
	local dur = math.max(p.Duration or 0.5, 0)

	Core.Visual.RectTelegraph(ctx, {
		Origin = origin, Dir = dir, Length = length, Width = width, Duration = dur, VFX = p.VFX
	})
	if dur > 0 then task.wait(dur) end

	return Core.Sphere.Projectile(ctx, p)
end


function Core.Sphere.Location(ctx, p)

	ctx._Damage = p.Damage
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local centre = _aimPos(ctx, p, origin, p.Range)

	local hits = _scanSphere(centre, p.Radius, ctx, p)

	emitVisual(ctx.Player, "SphLocation", withVFXTag({
		Centre   = centre,
		Radius   = p.Radius,
		Duration = p.Duration or 0,
	}), p)

	return hits
end

function Core.Sphere.LocationDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin = getOrigin(ctx, p) or root.Position
	local centre = _aimPos(ctx, p, origin, p.Range)
	local dur = math.max(p.Duration or 0.6, 0)

	emitVisual(ctx.Player, "CylTelegraph", withVFXTag({
		Centre = centre, Radius = p.Radius, Height = HITBOX_HEIGHT, Duration = dur
	}, p))
	if dur > 0 then task.wait(dur) end

	return Core.Sphere.Location(ctx, { Position = centre, Radius = p.Radius, Damage = p.Damage, Heal = p.Heal, TargetFilter = p.TargetFilter })
end


function Core.JumpImpact(ctx, params)
	local hrp = ctx.Character and ctx.Character:FindFirstChild("HumanoidRootPart")
	if not (hrp and params) then return end


	local hum = ctx.Character:FindFirstChildOfClass("Humanoid")


	local wasAnchored = hrp.Anchored
	local cleaned = false
	local function cleanupMover()
		if cleaned then return end
		cleaned = true
		if hum then
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.Running)
		end
		if wasAnchored then hrp.Anchored = true end
	end
	if wasAnchored then hrp.Anchored = false end


	if hum then hum.PlatformStand = true end
	hrp.AssemblyLinearVelocity = Vector3.zero
	RunSrv.Stepped:Wait()

	local startPos = ctx.StartPos or hrp.Position
	local aimPos   = params.TargetPos or ((not params.NoPred) and _npcPredPos(ctx))
	if not aimPos then
		cleanupMover()
		return {}
	end
	if (hrp.Position - startPos).Magnitude > 3 then
		startPos = hrp.Position
	else
		hrp.CFrame = CFrame.new(startPos)
	end

	local desired   = _clampFlatFrom(startPos, aimPos, params.Range)
	local targetPos = snapRootTargetToGround(ctx, safeFlatTarget(ctx, startPos, desired), hrp)
	local disp      = targetPos - startPos
	local distance  = disp.Magnitude
	if distance < 0.1 then
		cleanupMover()
		return {}
	end


	local oldOwner
	local giveToPlayer = (ctx.Player ~= nil) and (not hrp.Anchored)
	if giveToPlayer then
		pcall(function()
			oldOwner = hrp:GetNetworkOwner()
			hrp:SetNetworkOwner(ctx.Player)
		end)
	end

	local dur      = params.Duration or 0.9
	local velocity = disp.Unit * (distance / dur)

	local att = Instance.new("Attachment")
	att.Parent = hrp

	local lv  = Instance.new("LinearVelocity")
	lv.Attachment0            = att
	lv.VectorVelocity         = velocity
	lv.MaxForce               = math.huge
	lv.RelativeTo             = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.Parent = hrp

	emitVisual(ctx.Player, "JumpLaunch", withVFXTag({
		Start = startPos, Target = targetPos, Duration = dur, Radius = params.Radius
	}), params)

	task.wait(dur)

	if giveToPlayer then
		pcall(function() hrp:SetNetworkOwner(oldOwner) end)
	end

	lv:Destroy(); att:Destroy()
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame                 = CFrame.new(targetPos)
	cleanupMover()

	return Core.Sphere.Location(ctx, {
		Position = targetPos,
		Radius   = params.Radius,
		Damage   = params.Damage,
		Heal     = params.Heal,
		TargetFilter = params.TargetFilter
	})
end


local function _scanCone(ctx, origin, dir, halfAngRad, range, p)
	dir = _hflat(dir).Unit
	local cosThresh = math.cos(halfAngRad)
	local r2 = range * range

	local hits, done = {}, {}
	for _, mdl in ipairs(gatherModels(ctx, origin, range, p)) do
		if not done[mdl] then
			for _, bp in ipairs(partsOf(mdl)) do
				local v = _hflat(bp.Position - origin)
				local d2 = v.X*v.X + v.Z*v.Z
				if d2 > 1e-6 and d2 <= r2 then
					if (v / math.sqrt(d2)):Dot(dir) >= cosThresh then
						done[mdl] = true
						local r = applyDamageOrHeal(ctx, p, mdl)
						if r then hits[#hits+1] = r end
						break
					end
				end
			end
		end
	end
	return hits
end


Core.Cone = {}


local function _resolveConeParams(ctx, root, p)
	local origin = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, origin)
	if not dir or dir.Magnitude < 1e-3 then dir = root.CFrame.LookVector end
	dir = _hflat(dir); if dir.Magnitude < 1e-3 then dir = Vector3.new(1,0,0) end
	dir = dir.Unit

	local fullAngRad
	if p.AngleRad then fullAngRad = p.AngleRad
	elseif p.AngleDeg then fullAngRad = math.rad(p.AngleDeg)
	else fullAngRad = math.rad(60) end

	local halfAng = fullAngRad * 0.5
	local range   = p.Range or 12
	return origin, dir, halfAng, range
end


function Core.Cone.Static(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local origin, dir, halfAng, range = _resolveConeParams(ctx, root, p)
	ctx._Damage = p.Damage

	local hits = _scanCone(ctx, origin, dir, halfAng, range, p)

	emitVisual(ctx.Player, "ConeStatic", withVFXTag({
		Origin = origin, Dir = dir, AngleRad = halfAng*2, Range = range, Height = HITBOX_HEIGHT
	}), p)
	return hits
end


function Core.Cone.Tween(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local origin, dir, halfAng, range = _resolveConeParams(ctx, root, p)
	ctx._Damage = p.Damage

	local steps = math.max(SAMPLE_COUNT, 6)
	local hits, done = {}, {}

	emitVisual(ctx.Player, "ConeTween", withVFXTag({
		Origin = origin, Dir = dir, AngleRad = halfAng*2, Range = range, Duration = p.Duration or 0.5, Height = HITBOX_HEIGHT
	}), p)

	for i = 1, steps do
		local rNow = range * (i / steps)
		for _, h in ipairs(_scanCone(ctx, origin, dir, halfAng, rNow, p)) do
			if not done[h.Model] then done[h.Model] = true; hits[#hits+1] = h end
		end
		RunSrv.Heartbeat:Wait()
	end
	return hits
end


function Core.Cone.Delayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local base    = getOrigin(ctx, p) or root.Position
	local source  = _aimPos(ctx, p, base, p.Range)
	local dir     = _aimDir(ctx, p, root, source)

	local fullAngRad = p.AngleRad or (p.AngleDeg and math.rad(p.AngleDeg)) or math.rad(60)
	local halfAng    = fullAngRad * 0.5
	local range      = p.Range or 12
	local duration   = math.max(p.Duration or 0.8, 0)

	emitVisual(ctx.Player, "ConeTelegraph", withVFXTag({
		Origin = source, Dir = dir, AngleRad = fullAngRad, Range = range, Duration = duration, Height = HITBOX_HEIGHT
	}), p)

	if duration > 0 then task.wait(duration) end

	ctx._Damage = p.Damage
	return _scanCone(ctx, source, dir, halfAng, range, p)
end


function Core.Cone.Projectile(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local origin, dir, halfAng, range = _resolveConeParams(ctx, root, p)
	local n    = math.max(1, math.floor(p.Projectiles or 5))
	local speed= p.Speed or 120
	local rad  = p.ProjectileRadius or 1.75
	local dmgEach = p.DamageEach and p.Damage or (p.Damage / n)
	local healEach = p.HealEach and p.Heal or nil

	emitVisual(ctx.Player, "ConeProjectile", withVFXTag({
		Origin = origin, Dir = dir, AngleRad = halfAng*2, Range = range, Speed = speed, Count = n, Radius = rad
	}), p)


	local hits, done = {}, {}
	local maxFlight = range / speed
	local threads = {}

	for i = 1, n do
		local t = (n == 1) and 0 or ( (i-1)/(n-1) * 2 - 1 )
		local ang = t * halfAng
		local rot = CFrame.fromAxisAngle(Vector3.new(0,1,0), ang)
		local shotDir = (rot * dir)

		local co = coroutine.create(function()

			local sub = Core.Sphere.Projectile(ctx, {
				Dir    = shotDir,
				Radius = rad,
				Damage = dmgEach,
				Heal = healEach,
				Range  = range,
				Speed  = speed,
				TargetFilter = p.TargetFilter
			}) or {}
			for _, h in ipairs(sub) do
				if not done[h.Model] then done[h.Model] = true; hits[#hits+1] = h end
			end
		end)
		table.insert(threads, co)
		coroutine.resume(co)
	end

	task.wait(maxFlight + 0.05)
	return hits
end

function Core.Cone.ProjectileDelayed(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local origin, dir, halfAng, range = (function()
		local o,d,h,r = _resolveConeParams(ctx, root, p); return o,d,h,r
	end)()
	local dur = math.max(p.Duration or 0.6, 0)
	local fullAng = halfAng * 2

	emitVisual(ctx.Player, "ConeTelegraph", withVFXTag({
		Origin = origin, Dir = dir, AngleRad = fullAng, Range = range, Duration = dur, Height = HITBOX_HEIGHT
	}, p))
	if dur > 0 then task.wait(dur) end

	return Core.Cone.Projectile(ctx, p)
end

Core.Experimental = Core.Experimental or {}

function Core.Experimental.SlamBlink(ctx, p)
	local root = ctx.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
	local start  = getOrigin(ctx, p) or root.Position
	local dir    = _aimDir(ctx, p, root, start)
	local length = p.Range or 14
	local width  = p.Width or 5
	local delay  = math.max(p.Delay or 0.7, 0)


	Core.Visual.RectTelegraph(ctx, {
		Origin = start, Dir = dir, Length = length, Width = width, Duration = delay, VFX = p.VFX
	})
	if delay > 0 then task.wait(delay) end


	local hits = Core.Line.Static(ctx, {
		Range = length, Width = width, Damage = p.Damage, Dir = dir,
		TargetFilter = p.TargetFilter, VFX = p.VFX
	}) or {}


	local desiredEnd = start + dir * length
	local hrp = ctx.Character:FindFirstChild("HumanoidRootPart")
	local safeEnd    = safeFlatTarget(ctx, start, desiredEnd)
	if hrp then
		safeEnd = snapRootTargetToGround(ctx, safeEnd, hrp)
		hrp.CFrame = CFrame.new(safeEnd)
	end

	return hits
end


return Core
