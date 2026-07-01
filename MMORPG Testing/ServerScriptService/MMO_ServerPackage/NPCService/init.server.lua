--[[
Name: NPCService
Class: Script
Original path: game.ServerScriptService.MMO_ServerPackage.NPCService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: RunService, ReplicatedStorage, Players, PathfindingService, HttpService, ServerStorage, CollectionService, ServerScriptService
Requires:
  - local RS           = require(serverPackage:WaitForChild("RelationshipService"))
  - local SpatialGrid  = require(serverPackage:WaitForChild("SpatialGrid"))
  - local StatsMod     = require(serverPackage:WaitForChild("HumanoidStats"))
  - local CombatState  = require(serverPackage:WaitForChild("PlayerCombatStateService"))
  - local AbilityReg   = require(serverPackage:WaitForChild("AbilityRegistry"))
  - local NPCAbilities = require(serverPackage:WaitForChild("Abilities"):WaitForChild("NPCAbilities"))
  - local AbilityCore  = require(serverPackage:WaitForChild("Abilities"):WaitForChild("AbilityCore"))
  - local WorldBus     = require(serverPackage:WaitForChild("WorldBus"))
  - require(serverPackage:WaitForChild("NPC"):WaitForChild("NPCRegistry")).EnsureR6(model)
  - local NPCReg = require(serverPackage:WaitForChild("NPC"):WaitForChild("NPCRegistry"))
  - if vPlr and require(serverPackage:WaitForChild("MountInfo")).mountingPlayers[vPlr.UserId] then
  - require(serverPackage:WaitForChild("MountHelper")).abortMounting(vPlr)
Functions: npcDebugPrint, clampTier, valorRewardForTier, tieredArchetype, addThreat, topThreat, desiredHoldRange, computeHoldForAbility, ensureId, keepaliveForDist, moveEpsForDist, horizDist, anyPlayerWithin, maybeSetCF, fallbackHold, _pushExclude, quantizeVec3XZ, q, posQuantStep, _rebuildRayExcludes, hasNonCollidableMarker, isHumanoidRayPart, skipGroundHit, topRayHeightForRig, topRayHeightForNPC, groundAt, updateActiveFlag, flat, predictFuturePos, interceptTime, predictionForAbility, syncNPCHealth, startLeashHeal, finishLeashHeal, beginLeash, endLeash, weakModelRef, sanitizeOne, sanitizeAllTemplates, hrpOf, initStats, checkLeash, ensurePrimary, addNPC, forgetGuidForAllClients, finishNPCDeath, setCombatTarget, addNPCSpawnMarker, getNPCSpawnMarkers, spawnFromMarkers, debugCanWander, scheduleWanderSoon, acquireTarget, scheduleNextWander, computeStopAt, needGroundSnap, fmtv, clearSmartPath, raycastBlocking, obstacleBetween
Signal classes referenced: BindableEvent, RemoteEvent
Clean source lines: 1871
]]
local RunService   = game:GetService("RunService")
local Replicated   = game:GetService("ReplicatedStorage")
local Players      = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local HttpService  = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local serverStoragePackage = ServerStorage:WaitForChild("MMO_ServerStoragePackage")
local BEFolder = serverStoragePackage:FindFirstChild("BindableEvents")
if not BEFolder then
	BEFolder = Instance.new("Folder")
	BEFolder.Name = "BindableEvents"
	BEFolder.Parent = serverStoragePackage
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

local serverPackage = game:GetService("ServerScriptService"):WaitForChild("MMO_ServerPackage")
local replicatedPackage = Replicated:WaitForChild("MMO_ReplicatedPackage")

local RS           = require(serverPackage:WaitForChild("RelationshipService"))
local SpatialGrid  = require(serverPackage:WaitForChild("SpatialGrid"))
local StatsMod     = require(serverPackage:WaitForChild("HumanoidStats"))
local CombatState  = require(serverPackage:WaitForChild("PlayerCombatStateService"))
local AbilityReg   = require(serverPackage:WaitForChild("AbilityRegistry"))
local NPCAbilities = require(serverPackage:WaitForChild("Abilities"):WaitForChild("NPCAbilities"))

local AbilityCore  = require(serverPackage:WaitForChild("Abilities"):WaitForChild("AbilityCore"))
local RigFolder = replicatedPackage:FindFirstChild("Assets")
	and replicatedPackage.Assets:FindFirstChild("NPCRigs")

local WorldBus     = require(serverPackage:WaitForChild("WorldBus"))


local NPC_FOLDER = workspace:FindFirstChild("NPCS") or Instance.new("Folder", workspace)
NPC_FOLDER.Name  = "NPCS"
NPC_FOLDER.Parent = workspace

local SPAWN_FOLDER = workspace:FindFirstChild("SpawnNPC") or Instance.new("Folder", workspace)
SPAWN_FOLDER.Name  = "SpawnNPC"
SPAWN_FOLDER.Parent = workspace
local NPC_SPAWN_MARKER_TAGS = { "NPCSpawn", "NPCSpawnMarker", "MMO_NPCSpawn" }

local ServerStorage = game:GetService("ServerStorage")
local NPC_SIM = ServerStorage:FindFirstChild("NPCSim") or Instance.new("Folder", ServerStorage)
NPC_SIM.Name = "NPCSim"


local TICK_HZ      = 15
local AGGRO_HZ     = 5
local THINK_HZ     = 10
local NET_RADIUS   = 150
local CACHE_TTL    = 10
local ACTION_ID  = { Idle=0, Run=1, Attack=2, Cast=3 }
local MOVE_EPS   = 0.50
local HP_EPS     = 1
local NEAR, MID, FAR = 50, 80, NET_RADIUS
local KEEP_NEAR, KEEP_MID, KEEP_FAR = 0.35, 1.25, 2.50

local SOCIAL_AGGRO_RADIUS = 5
local MIN_WANDER_DIST    = 2.5
local MAX_WANDER_ATTEMPTS= 8
local WANDER_RETRY_DELAY = 0.25
local WANDER_RADIUS_DEFAULT = 9
local NPC_HEAD_RAY_CLEARANCE = 1.3
local NPC_DEFAULT_RAY_HEIGHT = 4.3
local PATH_REPLAN_COOLDOWN = 1.25
local PATH_WAYPOINT_REACH = 2.0
local PATH_TARGET_REPLAN_DIST = 6.0
local STUCK_CHECK_INTERVAL = 0.55
local STUCK_MIN_PROGRESS = 0.35
local STUCK_REPLAN_COUNT = 2
local OBSTACLE_PROBE_HEIGHT = 2.5
local OBSTACLE_PROBE_DISTANCE = 5.5
local LEASH_GRACE_AFTER_CASTER_MOVE = 10
local WANDER_MIN_S = 5
local WANDER_MAX_S = 9
local NPC_MIN_TIER = 1
local NPC_MAX_TIER = 20
local DEFAULT_RESPAWN_SECONDS = 14
local DEBUG_NPC_LOGS = false
local rawPrint = print
local function npcDebugPrint(...)
	if DEBUG_NPC_LOGS then
		rawPrint(...)
	end
end
local print = npcDebugPrint

local function clampTier(tier)
	return math.clamp(math.floor(tonumber(tier) or 1), NPC_MIN_TIER, NPC_MAX_TIER)
end

local function valorRewardForTier(tier, maxHealth)
	tier = clampTier(tier)
	return math.floor(18 + tier * 9 + ((tonumber(maxHealth) or 100) / 22))
end

local function tieredArchetype(baseArc, tier)
	tier = clampTier(tier or baseArc.Tier or 1)
	local arc = {}
	for key, value in pairs(baseArc) do
		arc[key] = value
	end

	local hpScale = 1 + ((tier - 1) * 0.32)
	local damageScale = 1 + ((tier - 1) * 0.18)
	arc.Tier = tier
	arc.MaxHP = math.max(1, math.floor((tonumber(baseArc.MaxHP) or 100) * hpScale + 0.5))
	arc.BaseDamage = math.max(0, math.floor((tonumber(baseArc.BaseDamage) or 0) * damageScale + 0.5))
	arc.ValorReward = tonumber(baseArc.ValorReward) or valorRewardForTier(tier, arc.MaxHP)
	return arc
end

local RemoteEvents = replicatedPackage:WaitForChild("RemoteEvents")
local REM_NPC_DELTA  = RemoteEvents:WaitForChild("NPCDelta")
local REM_NPC_DESPAWN = RemoteEvents:FindFirstChild("NPCDespawn")
if not REM_NPC_DESPAWN then
	REM_NPC_DESPAWN = Instance.new("RemoteEvent")
	REM_NPC_DESPAWN.Name = "NPCDespawn"
	REM_NPC_DESPAWN.Parent = RemoteEvents
end


local Archetypes = {
	DummyWanderer = {
		RigName     = "rig",
		MaxHP       = 100,
		Faction     = "Mob",
		BaseDamage  = 0,
		Speed       = 20,
		AggroRadius = 15,
		LeashRadius = 45,
		AutoAttack  = {Range = 4.5, Cooldown = 0.1, VFX = "MobSlash"},
		Abilities   = {
			{ Key = "MobCleave" },
			{ Key = "MobShockwave", Cooldown = 7.0 },
			{ Key = "MobLeapSmash", Cooldown = 8.0 },
			{ Key = "MobSlamBlink"},
		},
	},

	TownGuard = {
		RigName         = "guard",
		MaxHP           = 250,
		Faction         = "Guard",
		BaseDamage      = 15,
		Speed           = 9,
		AggroRadius     = 25,
		LeashRadius = 45,
		HostileOnAggro  = true,
		AutoAttack      = {Range = 5.5, Cooldown = 0.9, VFX = "GuardSlash"},
		Abilities   = {
			{ Key = "MobCleave" },
			{ Key = "MobLeapSmash" },
		},
	},
}


local npcs        = {}
local lastSent    = {}
local npcsByModel = {}
local idMap 	  = {}


local function addThreat(npc, attackerModel, amount)
	if not attackerModel or not attackerModel.Parent then return end
	npc.Threat = npc.Threat or {}
	npc.Threat[attackerModel] = (npc.Threat[attackerModel] or 0) + math.max(amount, 1)
end

local function topThreat(npc)
	local best, bestV = nil, 0
	if not npc.Threat then return nil end
	for mdl, val in pairs(npc.Threat) do
		if mdl.Parent and val > bestV then
			best, bestV = mdl, val
		end
	end
	return best
end

local function desiredHoldRange(npc)

	local autoR = npc.Template.AutoAttack and npc.Template.AutoAttack.Range
	if npc.Template.HoldAtRange then return npc.Template.HoldAtRange end
	if autoR then return math.max(0, autoR * 0.9) end
	return 3.5
end

local function computeHoldForAbility(def)
	if not def then return nil, nil end
	local minr = def.MinRange or 0
	local maxr = def.MaxRange or def.Range
	if maxr then
		local mid = (minr + maxr) * 0.5
		return math.max(0.5, mid), minr
	elseif minr > 0 then
		return minr + 0.5, minr
	end
	return nil, minr
end

local function ensureId(plr, guid)
	local m = idMap[plr]
	if not m then m = { next=1, g2i={}, i2g={} }; idMap[plr] = m end
	local i = m.g2i[guid]
	if i then return i end
	i = m.next; m.next += 1
	m.g2i[guid] = i; m.i2g[i] = guid
	return i
end

local function keepaliveForDist(d)
	if d <= NEAR then return KEEP_NEAR end
	if d <= MID  then return KEEP_MID  end
	return KEEP_FAR
end

local MOVE_EPS_NEAR, MOVE_EPS_MID, MOVE_EPS_FAR = 0.20, 0.40, 1.00
local function moveEpsForDist(d)
	if d <= NEAR then return MOVE_EPS_NEAR end
	if d <= MID  then return MOVE_EPS_MID  end
	return MOVE_EPS_FAR
end

local function horizDist(a: Vector3, b: Vector3)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx*dx + dz*dz)
end

local WAKE_RADIUS  = 120
local SLEEP_RADIUS = 150

local function anyPlayerWithin(pos, r)
	for _, plr in ipairs(Players:GetPlayers()) do
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - pos).Magnitude <= r then
			return true
		end
	end
	return false
end


local function maybeSetCF(npc)
	if not npc.Model.PrimaryPart then return end
	local prev, pos = npc._prevCF, npc.Pos
	if (not prev) or horizDist(prev.Position, pos) >= 0.35 then
		local cf = CFrame.new(pos)
		npc.Model.PrimaryPart.CFrame = cf
		npc._prevCF = cf
	end
end

local function fallbackHold(npc)
	if npc.Template.HoldAtRange then return npc.Template.HoldAtRange end
	local autoR = npc.Template.AutoAttack and npc.Template.AutoAttack.Range
	if autoR then return math.max(0, autoR * 0.9) end
	return 3.5
end


local RAY_EXCLUDES = { NPC_FOLDER }

local function _pushExclude(inst)
	if inst and inst.Parent then table.insert(RAY_EXCLUDES, inst) end
end

local function quantizeVec3XZ(v: Vector3, step: number)
	local function q(x) return math.round(x/step)*step end
	return Vector3.new(q(v.X), v.Y, q(v.Z))
end

local function posQuantStep(d)
	if d <= NEAR then return 0.02 end
	if d <= MID  then return 0.12 end
	return 0.25
end

local function _rebuildRayExcludes()
	RAY_EXCLUDES = { NPC_FOLDER }
	for _, plr in ipairs(Players:GetPlayers()) do
		_pushExclude(plr.Character)
	end

	if workspace:FindFirstChild("NPCS") then table.insert(RAY_EXCLUDES, workspace.NPCS) end
	_pushExclude(workspace:FindFirstChild("Mounts"))
	_pushExclude(workspace:FindFirstChild("Horses"))
	_pushExclude(workspace:FindFirstChild("Ignore"))
end


_rebuildRayExcludes()
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(_rebuildRayExcludes)
	p.CharacterRemoving:Connect(_rebuildRayExcludes)
	_rebuildRayExcludes()
end)
Players.PlayerRemoving:Connect(_rebuildRayExcludes)
workspace.ChildAdded:Connect(function(child)

	if child.Name == "Mounts" or child.Name == "Horses" then _rebuildRayExcludes() end
end)
workspace.ChildRemoved:Connect(function(child)
	if child.Name == "Mounts" or child.Name == "Horses" then _rebuildRayExcludes() end
end)

local function hasNonCollidableMarker(inst)
	local current = inst
	while current and current ~= workspace do
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

local function isHumanoidRayPart(inst)
	local model = inst and inst:FindFirstAncestorWhichIsA("Model")
	return model and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function skipGroundHit(inst)
	if not inst or inst == workspace.Terrain then return false end
	if hasNonCollidableMarker(inst) or isHumanoidRayPart(inst) then return true end
	if inst:IsA("BasePart") then
		if inst.CanCollide == false then return true end
		local group = inst.CollisionGroup
		if group == "Non-Collidable" or group == "NonCollidable" or group == "Walkthrough" or group == "Character" or group == "Horse" then
			return true
		end
	end
	return false
end

local RIG_RAY_HEIGHT_CACHE = {}

local function topRayHeightForRig(rigName)
	rigName = tostring(rigName or "")
	if rigName == "" then return NPC_DEFAULT_RAY_HEIGHT end
	if RIG_RAY_HEIGHT_CACHE[rigName] then return RIG_RAY_HEIGHT_CACHE[rigName] end

	local template = RigFolder and RigFolder:FindFirstChild(rigName)
	local hrp = template and template:FindFirstChild("HumanoidRootPart")
	if not hrp then
		RIG_RAY_HEIGHT_CACHE[rigName] = NPC_DEFAULT_RAY_HEIGHT
		return NPC_DEFAULT_RAY_HEIGHT
	end

	local minBottom = math.huge
	local maxTop = -math.huge
	for _, part in ipairs(template:GetDescendants()) do
		if part:IsA("BasePart") then
			local localCF = hrp.CFrame:ToObjectSpace(part.CFrame)
			local halfY = part.Size.Y * 0.5
			minBottom = math.min(minBottom, localCF.Y - halfY)
			maxTop = math.max(maxTop, localCF.Y + halfY)
		end
	end

	local height = NPC_DEFAULT_RAY_HEIGHT
	if minBottom ~= math.huge and maxTop ~= -math.huge then
		height = math.clamp((maxTop - minBottom) + NPC_HEAD_RAY_CLEARANCE, NPC_DEFAULT_RAY_HEIGHT, 24)
	end
	RIG_RAY_HEIGHT_CACHE[rigName] = height
	return height
end

local function topRayHeightForNPC(npc)
	local template = npc and npc.Template
	local rigName = npc and (npc.RigName or (template and template.RigName))
	if not rigName and template and template.RigPath then rigName = template.RigPath.Name end
	if not rigName and npc and npc.RigPath then rigName = npc.RigPath.Name end
	return topRayHeightForRig(rigName)
end

local function groundAt(pos: Vector3, npc)
	local rayHeight = topRayHeightForNPC(npc)
	local origin = pos + Vector3.new(0, rayHeight, 0)
	local direction = Vector3.new(0, -(rayHeight + 512), 0)
	local excludes = table.clone(RAY_EXCLUDES)
	for _ = 1, 12 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excludes
		params.IgnoreWater = true
		pcall(function() params.CollisionGroup = "Character" end)

		local hit = workspace:Raycast(origin, direction, params)
		if not hit then break end
		if not skipGroundHit(hit.Instance) then
			return Vector3.new(pos.X, hit.Position.Y, pos.Z)
		end
		table.insert(excludes, hit.Instance)
	end
	return pos
end

local function updateActiveFlag(npc, now)
	if now < (npc.NextActiveCheck or 0) then return end
	npc.NextActiveCheck = now + 0.5

	if npc.IsActive then

		if not anyPlayerWithin(npc.Pos, SLEEP_RADIUS) then
			npc.IsActive = false
			npc.Target = nil
			npc.Action = "Idle"
			npc.WanderTo = nil
		end
	else

		if anyPlayerWithin(npc.Pos, WAKE_RADIUS) then
			npc.IsActive = true
			npc.NextThink = 0
			npc.NextAggro = 0
		end
	end
end


local function flat(v: Vector3) return Vector3.new(v.X, 0, v.Z) end

local function predictFuturePos(target: Model, tFuture: number)
	local hrp = target and target:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local v  = hrp.AssemblyLinearVelocity or Vector3.zero
	local p0 = hrp.Position
	local pred = p0 + flat(v) * math.max(tFuture or 0, 0)
	return groundAt(pred), flat(v)
end


local function interceptTime(shooterPos: Vector3, targetPos: Vector3, targetVel: Vector3, projSpeed: number)
	local r = flat(targetPos - shooterPos)
	local v = flat(targetVel)
	local a = v:Dot(v) - projSpeed*projSpeed
	local b = 2 * r:Dot(v)
	local c = r:Dot(r)
	local disc = b*b - 4*a*c
	if disc and disc >= 0 and math.abs(a) > 1e-6 then
		local s = math.sqrt(disc)
		local t1 = (-b - s) / (2*a)
		local t2 = (-b + s) / (2*a)
		local t  = (t1 > 0 and t1) or (t2 > 0 and t2) or nil
		if t then return t end
	end

	local d = math.sqrt(c)
	return d / math.max(projSpeed, 1e-3)
end


local function predictionForAbility(npc, target: Model, def, meHRP)
	local cast = def.CastTime or 0


	if def.PredictT then
		local t = cast + def.PredictT
		local pos, vel = predictFuturePos(target, t)
		return { Pos = pos, T = t, Vel = vel }
	end
	if def.Duration and def.PredictPhase then
		local t = cast + def.Duration * math.clamp(def.PredictPhase, 0, 1)
		local pos, vel = predictFuturePos(target, t)
		return { Pos = pos, T = t, Vel = vel }
	end


	if def.ProjectileSpeed and meHRP then
		local th = target and target:FindFirstChild("HumanoidRootPart")
		if th then
			local v  = th.AssemblyLinearVelocity or Vector3.zero
			local t  = cast + interceptTime(meHRP.Position, th.Position, v, def.ProjectileSpeed)
			local pos, vel = predictFuturePos(target, t)
			return { Pos = pos, T = t, Vel = vel }
		end
	end


	local defaultLead
	if def.Duration and def.GapCloser then
		defaultLead = def.Duration * 0.95
	elseif def.Duration then
		defaultLead = def.Duration * 0.5
	else
		defaultLead = 0.15
	end

	local t = cast + defaultLead
	local pos, vel = predictFuturePos(target, t)
	return { Pos = pos, T = t, Vel = vel }
end

local _updateBar
local function syncNPCHealth(npc, stats)
	if not (npc and npc.Model and stats) then return end
	local maxHealth = tonumber(stats.MaxHealth) or 1
	local health = math.clamp(tonumber(stats.Health) or 0, 0, maxHealth)
	stats.Health = health
	npc.Model:SetAttribute("Health", health)
	npc.Model:SetAttribute("MaxHealth", maxHealth)
	local humanoid = npc.Model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = maxHealth
		humanoid.Health = health
	end
	if _updateBar then _updateBar(npc.Model) end
end

local function startLeashHeal(npc)
	if npc._healing then return end
	npc._healing = true
	task.spawn(function()
		local stats = StatsMod.humanoidStats[npc.Model]
		if not stats then npc._healing = false return end
		local rate = (stats.MaxHealth or 1) / 3
		local last = os.clock()
		while npc._leashing and stats.Health < stats.MaxHealth do
			local now = os.clock()
			local dt  = now - last
			last = now
			stats.Health = math.min(stats.MaxHealth, stats.Health + rate * dt)
			syncNPCHealth(npc, stats)
			task.wait(0.05)
		end
		npc._healing = false
	end)
end

local function finishLeashHeal(npc)
	local stats = StatsMod.humanoidStats[npc.Model]
	if not stats or not stats.MaxHealth then return end
	if stats.Health < stats.MaxHealth then
		stats.Health = stats.MaxHealth
	end
	syncNPCHealth(npc, stats)
end

local function beginLeash(npc)
	if npc._leashing then return end
	npc._leashing = true
	npc.Target = nil
	npc.Action = "Idle"
	for mdl in pairs(npc.Threat or {}) do
		local plr = Players:GetPlayerFromCharacter(mdl)
		if plr then
			CombatState.ClearPvECombat(plr)
		end
	end
	npc.Threat = {}
	npc.CDs    = {}
	npc._hadTarget = false
	npc.GCDUntil = 0
	npc.WanderTo = nil
	npc.NextWander = os.clock() + math.random(WANDER_MIN_S*2, WANDER_MAX_S*2)


	npc._leashTarget = npc._aggroCenter or npc._leashReturn or npc.Home or npc.Pos

	if npc.Template.HostileOnAggro then
		npc.Model:SetAttribute("Hostile", false)
	end
	startLeashHeal(npc)
end

local function endLeash(npc)
	if not npc._leashing then return end
	finishLeashHeal(npc)
	npc._leashing     = false
	npc._aggroCenter = nil
	npc._aggroRadius = nil
	npc._leashRadius = nil
	npc._leashReturn  = nil
	npc._leashTarget  = nil
	npc.WanderTo      = nil
	npc.NextThink     = 0
	npc.NextAggro     = 0
end

local function weakModelRef(m)

	return function()
		if m and m.Parent then return m end
		return nil
	end
end

local function sanitizeOne(model: Model)
	local ok, err = pcall(function()
		require(serverPackage:WaitForChild("NPC"):WaitForChild("NPCRegistry")).EnsureR6(model)
	end)
	if not ok then
		warn(("[NPCService] Failed to sanitize rig '%s': %s"):format(model:GetFullName(), tostring(err)))
	end
end

function _updateBar(model: Model)
	local s = StatsMod.humanoidStats[model]
	if not s then return end
	local head = model:FindFirstChild("Head"); if not head then return end
	local tb = head:FindFirstChild("TopBar"); if not tb then return end
	local hb = tb:FindFirstChild("HealthBar"); if not hb then return end
	local fill = hb:FindFirstChild("Health"); if not fill then return end
	if s.MaxHealth and s.MaxHealth > 0 then
		local ratio = math.clamp(s.Health / s.MaxHealth, 0, 1)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
	end
end

local function sanitizeAllTemplates()

	for _, arc in pairs(Archetypes) do
		if arc.RigPath and arc.RigPath:IsA("Model") then
			sanitizeOne(arc.RigPath)
		end
	end

	local NPCReg = require(serverPackage:WaitForChild("NPC"):WaitForChild("NPCRegistry"))
	for _, def in pairs(NPCReg.Enemies) do
		if def.RigPath and def.RigPath:IsA("Model") then
			sanitizeOne(def.RigPath)
		end
	end

	if RigFolder then
		for _, m in ipairs(RigFolder:GetChildren()) do
			if m:IsA("Model") then sanitizeOne(m) end
		end
	end
end

local function hrpOf(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function initStats(model, arc)
	local entry = {
		Model      = model,
		IsNPC      = true,
		Health     = arc.MaxHP,
		MaxHealth  = arc.MaxHP,
		BaseDamage = arc.BaseDamage,
		Tier       = arc.Tier or 1,
		ValorReward = arc.ValorReward,
	}
	StatsMod.humanoidStats[model] = entry
	SpatialGrid.Add(model)
end

local function checkLeash(npc)

	if os.clock() < (npc._leashSuspendUntil or 0) then return false end
	local center = npc._aggroCenter or npc.Home or npc.Pos
	local radius = npc._leashRadius
		or npc.Template.LeashRadius
		or npc.Template.AggroRadius
		or 40

	if horizDist(npc.Pos, center) > radius then
		beginLeash(npc)
		return true
	end
	return false
end


local function ensurePrimary(model, pos, arc)
	local root = Instance.new("Part")
	root.Name         = "HumanoidRootPart"
	root.Size         = Vector3.new(2,2,1)
	root.Transparency = 1
	root.Anchored     = true
	root.CanCollide   = false
	pcall(function() root.CollisionGroup = "Character" end)
	local groundProbe = arc and { RigName = arc.RigName or (arc.RigPath and arc.RigPath.Name), Template = arc } or nil
	root.CFrame       = CFrame.new(groundAt(pos, groundProbe))
	root.Parent       = model
	model.PrimaryPart = root
end

local function addNPC(archetypeName, position, homePos, wanderRadius, tier, respawnSeconds)
	local baseArc = Archetypes[archetypeName]
	assert(baseArc, "Unknown archetype "..tostring(archetypeName))
	local arc = tieredArchetype(baseArc, tier or baseArc.Tier or 1)

	local guid  = HttpService:GenerateGUID(false)

	local mdl   = Instance.new("Model")
	pcall(function() mdl.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	mdl.Name    = "npc_"..archetypeName
	mdl.Parent = NPC_SIM
	ensurePrimary(mdl, position, arc)

	local groundProbe = { RigName = arc.RigName or (arc.RigPath and arc.RigPath.Name), Template = arc }
	local groundedHome  = groundAt(homePos or position, groundProbe)
	local groundedSpawn = groundAt(position, groundProbe)


	mdl:SetAttribute("RelationId", guid)
	mdl:SetAttribute("Archetype", archetypeName)
	mdl:SetAttribute("Tier", arc.Tier or 1)
	mdl:SetAttribute("ValorReward", arc.ValorReward or valorRewardForTier(arc.Tier or 1, arc.MaxHP))
	RS.FactionOf[mdl] = arc.Faction
	if arc.Faction == "Guard" then
		mdl:SetAttribute("Hostile", false)
	elseif arc.Faction == "Mob" then
		mdl:SetAttribute("Hostile", true)
	end

	local obj = {
		Guid        = guid,
		Model       = mdl,
		Template    = arc,
		Pos   = groundedSpawn,
		Home  = groundedHome,
		Action      = "Idle",
		Target      = nil,
		Speed       = arc.Speed or 7,

		WRad        = wanderRadius or WANDER_RADIUS_DEFAULT,
		WanderTo    = nil,
		NextWander  = os.clock() + math.random(WANDER_MIN_S, WANDER_MAX_S),
		NextAggro   = 0,
		NextThink   = 0,
		NextAutoAt  = 0,
		CDs         = {},
		RigName     = arc.RigName or (arc.RigPath and arc.RigPath.Name) or "Default",
		ArchetypeName = archetypeName,
		Tier = arc.Tier or 1,
		RespawnSeconds = tonumber(respawnSeconds) or tonumber(arc.RespawnSeconds) or DEFAULT_RESPAWN_SECONDS,
	}
	obj.GCDUntil = 0
	obj.Threat   = {}
	obj._lastGridPos     = groundedSpawn
	obj._nextGroundSnap  = 0
	obj.NextMove         = 0
	obj.IsActive         = true
	obj.NextActiveCheck  = 0
	obj._lastMoveAt      = os.clock()


	npcs[guid] = obj
	npcsByModel[mdl] = obj

	initStats(mdl, arc)
	RS:BroadcastDelta(mdl)
	return obj
end

local function forgetGuidForAllClients(guid)
	for player, map in pairs(idMap) do
		local id = map.g2i[guid]
		if id then
			map.g2i[guid] = nil
			map.i2g[id] = nil
			if lastSent[player] then
				lastSent[player][id] = nil
			end
		end
	end
end

local function finishNPCDeath(npc, source, meta)
	if not npc or npc.Dead then
		return
	end
	npc.Dead = true
	meta = type(meta) == "table" and meta or {}

	local model = npc.Model
	local guid = npc.Guid
	local respawnAt = npc.Home or npc.Pos
	local archetypeName = npc.ArchetypeName
	local tier = npc.Tier or (model and model:GetAttribute("Tier")) or 1
	local wrad = npc.WRad or WANDER_RADIUS_DEFAULT
	local respawnSeconds = tonumber(npc.RespawnSeconds) or DEFAULT_RESPAWN_SECONDS

	npcs[guid] = nil
	forgetGuidForAllClients(guid)
	if model then
		model:SetAttribute("Dead", true)
		npcsByModel[model] = nil
		StatsMod.humanoidStats[model] = nil
		RS.FactionOf[model] = nil
		pcall(function() SpatialGrid.Remove(model) end)
		pcall(function() RS:BroadcastDelta(model, true) end)
	end

	REM_NPC_DESPAWN:FireAllClients(guid)

	if model and model.Parent then
		model:Destroy()
	end

	if archetypeName and respawnSeconds > 0 then
		task.delay(respawnSeconds, function()
			addNPC(archetypeName, respawnAt, respawnAt, wrad, tier, respawnSeconds)
		end)
	end
end

NPCDiedBE.Event:Connect(function(model, source, meta)
	local npc = npcsByModel[model]
	if npc then
		finishNPCDeath(npc, source, meta)
	end
end)


local function setCombatTarget(npc, targetModel, why)
	if not targetModel or not targetModel.Parent then return end


	npc._leashReturn = npc._leashReturn or npc.Pos


	npc._aggroCenter = npc._aggroCenter or npc.Pos
	npc._leashRadius = npc._leashRadius or npc.Template.LeashRadius or npc.Template.AggroRadius or 40

	npc.Target     = weakModelRef(targetModel)
	npc._hadTarget = true
	npc.Action     = "Idle"
	if npc.Template.HostileOnAggro then
		npc.Model:SetAttribute("Hostile", true)
	end


	npc.NextThink = 0
	npc.NextAggro = 0


	if npc._leashing then
		endLeash(npc)
	end


end

local function addNPCSpawnMarker(markers, seen, marker)
	if not marker:IsA("BasePart") or not marker:IsDescendantOf(workspace) or seen[marker] then
		return
	end
	seen[marker] = true
	table.insert(markers, marker)
end

local function getNPCSpawnMarkers()
	local markers = {}
	local seen = {}

	for _, child in ipairs(SPAWN_FOLDER:GetChildren()) do
		addNPCSpawnMarker(markers, seen, child)
	end

	for _, tagName in ipairs(NPC_SPAWN_MARKER_TAGS) do
		for _, marker in ipairs(CollectionService:GetTagged(tagName)) do
			addNPCSpawnMarker(markers, seen, marker)
		end
	end

	table.sort(markers, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	return markers
end

local function spawnFromMarkers()
	for _, marker in ipairs(getNPCSpawnMarkers()) do
		if marker:IsA("BasePart") then
			print("Marker", marker.Name,
				"Archetype", marker:GetAttribute("Archetype"),
				"Count", marker:GetAttribute("Count"),
				"Radius", marker:GetAttribute("Radius"),
				"Tier", marker:GetAttribute("Tier"),
				"TierMin", marker:GetAttribute("TierMin"),
				"TierMax", marker:GetAttribute("TierMax"))
			local arche  = marker:GetAttribute("Archetype") or "DummyWanderer"
			if not Archetypes[arche] then
				warn(("[NPCService] Marker %s uses unknown Archetype '%s'"):format(marker:GetFullName(), tostring(arche)))
				continue
			end
			local count  = tonumber(marker:GetAttribute("Count")) or 1
			local wrad   = tonumber(marker:GetAttribute("Radius")) or WANDER_RADIUS_DEFAULT
			local tier   = clampTier(marker:GetAttribute("Tier") or (Archetypes[arche] and Archetypes[arche].Tier) or 1)
			local tierMin = marker:GetAttribute("TierMin") and clampTier(marker:GetAttribute("TierMin")) or nil
			local tierMax = marker:GetAttribute("TierMax") and clampTier(marker:GetAttribute("TierMax")) or nil
			if tierMin and tierMax and tierMin > tierMax then
				tierMin, tierMax = tierMax, tierMin
			end
			local respawnSeconds = tonumber(marker:GetAttribute("RespawnSeconds")) or DEFAULT_RESPAWN_SECONDS
			for i = 1, count do
				local spawnTier = (tierMin and tierMax) and math.random(tierMin, tierMax) or tier
				addNPC(arche, marker.Position + Vector3.new(0,5,0), marker.Position + Vector3.new(0,5,0), wrad, spawnTier, respawnSeconds)
			end
		end
	end
end


local function debugCanWander(npc, now, context)

	local hasWanderTo  = npc.WanderTo ~= nil
	local nextWander   = npc.NextWander or 0
	local timeOk       = now >= nextWander

	local tgt          = npc.Target and npc.Target()
	local tgtValid     = tgt and tgt.Parent ~= nil
	local noTarget     = not tgtValid

	local leashing     = npc._leashing == true

	local spellLocked  = (npc.SpellLockUntil and now < npc.SpellLockUntil) and true or false
	local moveLocked   = (npc._moveLockUntil and now < npc._moveLockUntil) and true or false
	local notLocked    = (not spellLocked) and (not moveLocked)

	local active       = npc.IsActive and true or false


	print(("[WANDER:GATE] %s ctx=%s hasWanderTo=%s  (WanderTo=%s)")
		:format(npc.Guid, context, tostring(hasWanderTo), tostring(hasWanderTo and fmtv(npc.WanderTo) or "nil")))
	print(("[WANDER:GATE] %s ctx=%s timeOk=%s  (now=%.2f  NextWander=%.2f)")
		:format(npc.Guid, context, tostring(timeOk), now, nextWander))
	print(("[WANDER:GATE] %s ctx=%s noTarget=%s  (tgtValid=%s)")
		:format(npc.Guid, context, tostring(noTarget), tostring(tgtValid)))
	print(("[WANDER:GATE] %s ctx=%s leashing=%s")
		:format(npc.Guid, context, tostring(leashing)))
	print(("[WANDER:GATE] %s ctx=%s notLocked=%s  (spellLocked=%s, moveLocked=%s)")
		:format(npc.Guid, context, tostring(notLocked), tostring(spellLocked), tostring(moveLocked)))
	print(("[WANDER:GATE] %s ctx=%s IsActive=%s")
		:format(npc.Guid, context, tostring(active)))


	local canStart = (not hasWanderTo) and timeOk and noTarget and (not leashing) and notLocked
	print(("[WANDER:GATE] %s ctx=%s => canStart=%s")
		:format(npc.Guid, context, tostring(canStart)))

	return canStart
end

local function scheduleWanderSoon(npc, now, reason)
	local before = npc.NextWander or now
	local newNW  = math.min(before, now + WANDER_RETRY_DELAY)
	npc.NextWander = newNW
	print(("[WANDER] %s scheduleSoon (%s): now=%.2f  NextWander: %.2f -> %.2f")
		:format(npc.Guid, tostring(reason or "n/a"), now, before, newNW))
end


local function acquireTarget(npc)
	local now = os.clock()
	if now < npc.NextAggro then return end
	npc.NextAggro = now + (1 / AGGRO_HZ)

	local myRoot = hrpOf(npc.Model)
	if not myRoot then return end

	local radiusAggro = npc.Template.AggroRadius or 20

	local cur    = npc.Target and npc.Target()
	local curHRP = hrpOf(cur)

	if cur and cur.Parent and curHRP then
		if RS:GetRelation(npc.Model, cur) == "Hostile" then


			return
		end
		npc.Target = nil
		if npc.Template.HostileOnAggro then npc.Model:SetAttribute("Hostile", false) end
	end


	local tt = topThreat(npc)
	if tt and tt.Parent and RS:GetRelation(npc.Model, tt) == "Hostile" then
		local thrp = hrpOf(tt)
		if thrp and (thrp.Position - myRoot.Position).Magnitude <= radiusAggro * 1.5 then
			setCombatTarget(npc, tt, "top_threat")
			return
		end
	end


	local best, bestD = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local ch  = plr.Character
		local hrp = hrpOf(ch)
		if hrp and RS:GetRelation(npc.Model, ch) == "Hostile" then
			local d = (hrp.Position - myRoot.Position).Magnitude
			if d < radiusAggro and d < bestD then
				best, bestD = ch, d
			end
		end
	end

	if best then
		setCombatTarget(npc, best, "nearest_within_radius")
	else

		if npc._hadTarget then
			npc._hadTarget = false
			npc.Target = nil
			if npc.Template.HostileOnAggro then npc.Model:SetAttribute("Hostile", false) end
			scheduleWanderSoon(npc, now, "left_combat")
		else
			npc.Target = nil
			if npc.Template.HostileOnAggro then npc.Model:SetAttribute("Hostile", false) end
		end
	end
end

local function scheduleNextWander(npc)
	npc.NextWander = os.clock() + math.random(WANDER_MIN_S, WANDER_MAX_S)
end

local function computeStopAt(npc)

	local stopAt = 2.25


	local a = npc.Template.AutoAttack
	if a and a.Range then
		stopAt = math.min(stopAt, math.max(1.5, (a.Range * 0.85)))
	end


	local list = npc.Template.Abilities or {}
	for _, e in ipairs(list) do
		local def = NPCAbilities[e.Key]
		if def then
			if def.Range then stopAt = math.min(stopAt, math.max(1.5, def.Range * 0.85)) end

		end
	end
	return stopAt
end

local function needGroundSnap(npc, now, moved)
	if moved then return true end
	if now >= (npc._nextGroundSnap or 0) then
		npc._nextGroundSnap = now + 0.4
		return true
	end
	return false
end

local function fmtv(v: Vector3)
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

local function clearSmartPath(npc)
	npc._pathWaypoints = nil
	npc._pathIndex = nil
	npc._pathGoal = nil
end

local function raycastBlocking(origin, direction)
	if direction.Magnitude <= 1e-3 then return nil end
	local excludes = table.clone(RAY_EXCLUDES)
	for _ = 1, 8 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excludes
		params.IgnoreWater = true
		pcall(function() params.CollisionGroup = "Character" end)

		local hit = workspace:Raycast(origin, direction, params)
		if not hit then return nil end
		if not skipGroundHit(hit.Instance) then return hit end
		table.insert(excludes, hit.Instance)
	end
	return nil
end

local function obstacleBetween(npc, dest)
	local flat = Vector3.new(dest.X - npc.Pos.X, 0, dest.Z - npc.Pos.Z)
	local dist = flat.Magnitude
	if dist < 1 then return false end
	local origin = npc.Pos + Vector3.new(0, OBSTACLE_PROBE_HEIGHT, 0)
	local hit = raycastBlocking(origin, flat.Unit * math.min(dist, OBSTACLE_PROBE_DISTANCE))
	if not hit then return false end
	if hit.Normal and hit.Normal.Y > 0.65 then return false end
	return true
end

local function stuckNeedsPath(npc, dest, now)
	if now < (npc._nextStuckCheck or 0) then return false end
	npc._nextStuckCheck = now + STUCK_CHECK_INTERVAL
	local last = npc._lastStuckPos
	npc._lastStuckPos = npc.Pos
	if not last then
		npc._stuckCount = 0
		return false
	end
	local moved = horizDist(last, npc.Pos)
	local remaining = horizDist(npc.Pos, dest)
	if remaining > PATH_WAYPOINT_REACH * 1.5 and moved < STUCK_MIN_PROGRESS then
		npc._stuckCount = (npc._stuckCount or 0) + 1
	else
		npc._stuckCount = 0
	end
	return (npc._stuckCount or 0) >= STUCK_REPLAN_COUNT
end

local function computeSmartPath(npc, dest, now)
	if now < (npc._nextPathAt or 0) then return false end
	npc._nextPathAt = now + PATH_REPLAN_COOLDOWN

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 4,
	})

	local ok = pcall(function()
		path:ComputeAsync(npc.Pos + Vector3.new(0, 2, 0), dest + Vector3.new(0, 2, 0))
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		clearSmartPath(npc)
		return false
	end

	local points = {}
	for _, waypoint in ipairs(path:GetWaypoints()) do
		local point = groundAt(waypoint.Position, npc)
		if horizDist(npc.Pos, point) > 0.75 then
			table.insert(points, point)
		end
	end
	if #points == 0 then
		clearSmartPath(npc)
		return false
	end

	npc._pathWaypoints = points
	npc._pathIndex = 1
	npc._pathGoal = dest
	npc._stuckCount = 0
	return true
end

local function smartMoveTarget(npc, dest, now)
	if npc._pathGoal and horizDist(npc._pathGoal, dest) > PATH_TARGET_REPLAN_DIST then
		clearSmartPath(npc)
	end

	local needsPath = obstacleBetween(npc, dest) or stuckNeedsPath(npc, dest, now)
	if needsPath and not npc._pathWaypoints then
		computeSmartPath(npc, dest, now)
	end

	local points = npc._pathWaypoints
	if points then
		local index = npc._pathIndex or 1
		while points[index] and horizDist(npc.Pos, points[index]) <= PATH_WAYPOINT_REACH do
			index += 1
		end
		npc._pathIndex = index
		local waypoint = points[index]
		if waypoint then return waypoint, true end
		clearSmartPath(npc)
	end
	return dest, false
end

local function moveToward(npc, dest, speed, dtMove, arriveDist)
	local now = os.clock()
	local target, usingPath = smartMoveTarget(npc, dest, now)
	local threshold = usingPath and 0.25 or (arriveDist or 0.25)
	local flat = Vector3.new(target.X - npc.Pos.X, 0, target.Z - npc.Pos.Z)
	local dist = flat.Magnitude
	if dist <= threshold then return false end
	local step = math.min((speed or npc.Speed or 0) * dtMove, dist)
	if step <= 0 then return false end
	npc.Pos += flat.Unit * step
	return true
end


local function pickNewWanderCandidate(npc)
	local centre = npc.Home or npc.Pos
	local r      = npc.WRad or WANDER_RADIUS_DEFAULT

	for _ = 1, MAX_WANDER_ATTEMPTS do
		local theta  = math.random() * math.pi * 2
		local rad    = math.random() * r
		local offset = Vector3.new(math.cos(theta)*rad, 0, math.sin(theta)*rad)
		local raw    = centre + offset
		local dest   = groundAt(raw, npc)
		local d      = horizDist(npc.Pos, dest)
		if d >= MIN_WANDER_DIST and d <= (r + 0.25) then
			return dest, d, nil
		end
	end
	return nil, 0, "too_close"
end


local function tryStartWander(npc, now)
	local dest, d, err = pickNewWanderCandidate(npc)
	if not dest then
		print(("[WANDER] %s Wander failed due to %s (no suitable point >= %.2f)")
			:format(npc.Guid, tostring(err), MIN_WANDER_DIST))

		npc.NextWander = now + WANDER_RETRY_DELAY
		return false, err
	end

	print(("[WANDER] %s Attempting to wander -> %s (d=%.2f)")
		:format(npc.Guid, fmtv(dest), d))

	clearSmartPath(npc)
	npc.WanderTo         = dest
	npc._wanderStartPos  = npc.Pos
	npc._wanderMinDist   = MIN_WANDER_DIST

	npc.NextWander       = now + math.random(WANDER_MIN_S, WANDER_MAX_S)
	return true, nil
end


local function finishWander(npc, now)
	local moved = 0
	if npc._wanderStartPos then
		moved = horizDist(npc._wanderStartPos, npc.Pos)
	end
	local need = npc._wanderMinDist or MIN_WANDER_DIST

	if moved + 1e-3 >= need then
		print(("[WANDER] %s Wander successful (moved %.2f studs)")
			:format(npc.Guid, moved))

		scheduleNextWander(npc)
	else
		print(("[WANDER] %s Wander failed due to short_path (moved %.2f/%.2f) — retrying soon")
			:format(npc.Guid, moved, need))

		npc.NextWander = now + WANDER_RETRY_DELAY
	end

	npc._wanderStartPos = nil
	npc._wanderMinDist  = nil
	npc.WanderTo        = nil
	clearSmartPath(npc)
end


local function pickNewWander(npc)
	local centre = npc.Home
	local r = npc.WRad or WANDER_RADIUS_DEFAULT
	local theta = math.random() * math.pi * 2
	local rad   = math.random() * r
	local offset= Vector3.new(math.cos(theta)*rad, 0, math.sin(theta)*rad)
	npc.WanderTo = groundAt(centre + offset, npc)
end


local function stepMove(npc, dt)
	if npc.Dead then return end
	local now = os.clock()
	updateActiveFlag(npc, now)


	if not npc.IsActive then

		if now < (npc._nextSleepWander or 0) then return end
		npc._nextSleepWander = now + 1


		if (not npc.WanderTo) and now >= (npc.NextWander or 0) then

			if debugCanWander(npc, now, "OFFSCREEN") then
				print(("[WANDER] %s Trigger (OFFSCREEN): now=%.2f >= NextWander=%.2f")
					:format(npc.Guid, now, npc.NextWander or 0))
				tryStartWander(npc, now)
			end
		end


		if npc.WanderTo then
			if horizDist(npc.Pos, npc.WanderTo) < 0.25 then
				finishWander(npc, now)
				npc.Action = "Idle"
			else
				moveToward(npc, npc.WanderTo, npc.Speed * 0.5, 0.2, 0.25)
				npc.Action = "Run"
			end
		else
			npc.Action = "Idle"
		end


		npc.Pos = groundAt(npc.Pos, npc)
		if npc.Model.PrimaryPart then maybeSetCF(npc) end
		if horizDist(npc._lastGridPos, npc.Pos) >= 0.35 then
			SpatialGrid.Update(npc.Model)
			npc._lastGridPos = npc.Pos
		end
		return
	end


	if now < (npc.NextMove or 0) then return end
	npc.NextMove = now + 1/30

	local dtMove = now - (npc._lastMoveAt or now)
	if dtMove < 0 then dtMove = 0 end
	if dtMove > 0.2 then dtMove = 0.2 end
	npc._lastMoveAt = now

	local moved = false
	local root  = hrpOf(npc.Model); if not root then return end
	local tgt   = npc.Target and npc.Target()


	if npc.SpellLockUntil and now < npc.SpellLockUntil then
		local hrp = hrpOf(npc.Model)
		if hrp then
			npc.Pos = groundAt(hrp.Position, npc)
			if npc.Model.PrimaryPart then npc.Model.PrimaryPart.CFrame = CFrame.new(npc.Pos) end
			if horizDist(npc._lastGridPos, npc.Pos) >= 0.35 then
				SpatialGrid.Update(npc.Model)
				npc._lastGridPos = npc.Pos
			end
		end
		return
	end

	if npc._moveLockUntil and now < npc._moveLockUntil then
		local hrp = hrpOf(npc.Model)
		if hrp then
			npc.Pos = groundAt(hrp.Position, npc)
			if horizDist(npc._lastGridPos, npc.Pos) >= 0.35 then
				SpatialGrid.Update(npc.Model)
				npc._lastGridPos = npc.Pos
			end
		end
		return
	end


	if npc._leashing then
		local home = npc._leashTarget or npc.Home or npc.Pos
		if moveToward(npc, home, npc.Speed * 1.35, dtMove, 0.25) then
			moved = true
		else
			npc.Pos = groundAt(home, npc)
			if npc.Model.PrimaryPart then
				npc.Model.PrimaryPart.CFrame = CFrame.new(npc.Pos)
			end
		end

		if needGroundSnap(npc, now, true) then
			npc.Pos = groundAt(npc.Pos, npc)
		end
		if npc.Model.PrimaryPart then maybeSetCF(npc) end
		if horizDist(npc._lastGridPos, npc.Pos) >= 0.35 then
			SpatialGrid.Update(npc.Model)
			npc._lastGridPos = npc.Pos
		end

		if npc._leashing then
			local s    = StatsMod.humanoidStats[npc.Model]
			local home = npc._leashTarget or npc.Home or npc.Pos
			local atHome = horizDist(npc.Pos, home) <= 0.75
			if s and s.Health >= (s.MaxHealth or s.Health) and atHome then
				endLeash(npc)
			end
		end
		return
	end


	if tgt and tgt.Parent then
		local troot = hrpOf(tgt)
		if troot then
			local toT   = Vector3.new(troot.Position.X - npc.Pos.X, 0, troot.Position.Z - npc.Pos.Z)
			local dist  = toT.Magnitude
			local SLACK = 0.35
			local stopAt = computeStopAt(npc)

			if dist > stopAt + SLACK then
				moved = moveToward(npc, troot.Position, npc.Speed, dtMove, stopAt)
				npc.Action = "Run"
			else
				npc.Action = "Idle"
				local pp = npc.Model.PrimaryPart
				if pp then
					local look = Vector3.new(toT.X, 0, toT.Z)
					if look.Magnitude > 0.001 then
						pp.CFrame = CFrame.new(npc.Pos, npc.Pos + look.Unit)
					end
				end
			end
		end
	else

		if not npc.WanderTo then
			if now >= (npc.NextWander or 0) then

				if debugCanWander(npc, now, "ACTIVE") then
					print(("[WANDER] %s Trigger (ACTIVE): now=%.2f >= NextWander=%.2f")
						:format(npc.Guid, now, npc.NextWander or 0))
					local ok = select(1, tryStartWander(npc, now))
					npc.Action = ok and "Run" or "Idle"
				end
			else
				npc.Action = "Idle"
			end
		else
			if horizDist(npc.Pos, npc.WanderTo) < 0.25 then
				finishWander(npc, now)
				npc.Action = "Idle"
			else
				moved = moveToward(npc, npc.WanderTo, npc.Speed, dtMove, 0.25)
				npc.Action = "Run"
			end
		end

		local s = StatsMod.humanoidStats[npc.Model]
		if s and s.Health >= (s.MaxHealth or s.Health) then
			endLeash(npc)
		end
	end


	if needGroundSnap(npc, now, moved) then
		npc.Pos = groundAt(npc.Pos, npc)
	end
	if npc.Model.PrimaryPart then maybeSetCF(npc) end
	if horizDist(npc._lastGridPos, npc.Pos) >= 0.35 then
		SpatialGrid.Update(npc.Model)
		npc._lastGridPos = npc.Pos
	end
end


local function tryAutoAttack(npc)
	local now = os.clock()
	if npc.SpellLockUntil and now < npc.SpellLockUntil then return end
	local target = npc.Target and npc.Target()
	if not target then return end
	local myRoot, trgRoot = hrpOf(npc.Model), hrpOf(target)
	if not (myRoot and trgRoot) then return end

	local auto = npc.Template.AutoAttack
	if not auto then return end

	local dist = (trgRoot.Position - myRoot.Position).Magnitude
	if now >= npc.NextAutoAt and dist <= (auto.Range or 5) then

		local tgtStats = StatsMod.humanoidStats[target]
		if tgtStats and tgtStats.Health > 0 then
			npc.Action     = "Attack"
			npc.NextAutoAt = now + (auto.Cooldown or 1)
			local vPlr = game:GetService("Players"):GetPlayerFromCharacter(target)
			if vPlr and require(serverPackage:WaitForChild("MountInfo")).mountingPlayers[vPlr.UserId] then
				require(serverPackage:WaitForChild("MountHelper")).abortMounting(vPlr)
			end
			local dmg = npc.Template.BaseDamage or 8
			AbilityCore.NPCApplyDamage(target, dmg)

			if ThreatBumpBE then
				ThreatBumpBE:Fire(target, npc.Model, dmg)
			end

			npc.LastAutoAt = now


			if auto.VFX then
				WorldBus.FXInRange(myRoot.Position, 128, "NPCBasic", { VFX = auto.VFX, Caster = npc.Guid, Origin = myRoot.Position })
			end
		end
	end
end

local function abilityOffCD(npc, key)
	npc.CDs = npc.CDs or {}
	return (npc.CDs[key] or 0) <= os.clock()
end

local function setCD(npc, key, seconds)
	npc.CDs[key] = os.clock() + (seconds or 0)
end

local function castNPCAbility(npc, entry, target)
	local def = NPCAbilities[entry.Key]
	if not def then return end

	local me, th = hrpOf(npc.Model), hrpOf(target)
	if not me or not th then return end


	local pred = predictionForAbility(npc, target, def, me)
	local distNow = (th.Position - me.Position).Magnitude
	local distHit = pred and (pred.Pos - me.Position).Magnitude or distNow


	local ok = true
	if def.MinRange and distHit < def.MinRange then ok = false end
	if def.MaxRange and distHit > def.MaxRange then ok = false end
	if def.Range    and distHit > def.Range    then ok = false end
	if not ok then return end


	if typeof(def.CanHitNow) == "function" then
		local should = def.CanHitNow(npc, target, distHit, pred)
		if not should then return end
	end


	local now = os.clock()
	if now < (npc.GCDUntil or 0) then return end
	if not abilityOffCD(npc, def.Key) then return end


	local castTime = def.CastTime or 0
	local moveLock = def.MoveLock or 0
	local recovery = def.Recovery or 0
	npc.SpellLockUntil = now + castTime + moveLock + recovery


	npc.Action = "Cast"


	local shouldUnanchor = (def.GapCloser or def.MovesCaster or def.Unanchor) and not def.ManagesAnchoring
	local wasAnchored = me.Anchored
	if shouldUnanchor then pcall(function() me.Anchored = false end) end


	if def.GapCloser or def.MovesCaster then
		npc._moveLockUntil = now + math.max(moveLock, castTime)
		npc._leashSuspendUntil = math.max(npc._leashSuspendUntil or 0, now + LEASH_GRACE_AFTER_CASTER_MOVE)
	end

	print(("[NPC %s] CAST %s -> %s (dist=%.2f)")
		:format(npc.Guid, tostring(def.Key), target.Name or "?", distNow))


	if castTime > 0 then
		task.wait(castTime)

		th = hrpOf(target)
		if not th or not target.Parent then

			npc.GCDUntil = now + 0.3
			if shouldUnanchor then pcall(function() me.Anchored = wasAnchored end) end
			return
		end
	end


	local okCast, err
	local results
	okCast, err = pcall(function()
		results = def.Execute({
			Player     = nil,
			Character  = npc.Model,
			Stats      = StatsMod.humanoidStats[npc.Model],
			StartPos   = me.Position,
			Params     = (function()
				local p = OverlapParams.new()
				p.FilterType = Enum.RaycastFilterType.Exclude
				p.FilterDescendantsInstances = { npc.Model }
				return p
			end)(),
			IsHostile  = function(m) return RS:GetRelation(npc.Model, m)=="Hostile" end,
			TargetPred = pred,
		}, target)
	end)


	if shouldUnanchor then pcall(function() me.Anchored = wasAnchored end) end


	npc.Pos = groundAt(me.Position, npc)
	if npc.Model.PrimaryPart then npc.Model.PrimaryPart.CFrame = CFrame.new(npc.Pos) end
	SpatialGrid.Update(npc.Model)


	local cdUse = entry.Cooldown or def.Cooldown or 3
	if okCast then
		setCD(npc, def.Key, cdUse)
		npc.GCDUntil = os.clock() + (def.GCD or 0.6)
	else
		warn(("[NPC %s] ABILITY ERROR %s: %s"):format(npc.Guid, tostring(def.Key), tostring(err)))
	end


	local left = (npc.SpellLockUntil or 0) - os.clock()
	if left > 0 then task.delay(left, function()
			if os.clock() >= (npc.SpellLockUntil or 0) then
				npc.SpellLockUntil = 0
			end
		end) else
		npc.SpellLockUntil = 0
	end
end

local function chooseAndCast(npc)
	local now = os.clock()
	if npc.SpellLockUntil and now < npc.SpellLockUntil then return end
	if npc._moveLockUntil and now < npc._moveLockUntil then return end
	local target = npc.Target and npc.Target(); if not target then return end
	local me, th = hrpOf(npc.Model), hrpOf(target); if not (me and th) then return end
	local distNow = (th.Position - me.Position).Magnitude
	local list   = npc.Template.Abilities or {}

	local bestReady, bestReadyScore
	local bestAny,   bestAnyScore
	local bestAnyHold, bestAnyMin

	for _, e in ipairs(list) do
		local def = NPCAbilities[e.Key]
		if def and abilityOffCD(npc, def.Key) and now >= (npc.GCDUntil or 0) then
			local pred = predictionForAbility(npc, target, def, me)
			local distEval = pred and (pred.Pos - me.Position).Magnitude or distNow

			local inRange = true
			if def.MinRange and distEval < def.MinRange then inRange = false end
			if def.MaxRange and distEval > def.MaxRange then inRange = false end
			if def.Range    and distEval > def.Range    then inRange = false end

			local score = (def.Weight or e.Weight or 1)
			if def.GapCloser and distNow > (def.MinRange or 6) then
				score = score + 100 + distNow * 0.2
			end


			local hold, minWanted = computeHoldForAbility(def)
			local intentHold = hold or fallbackHold(npc)
			if pred then

				intentHold = math.max(0.5, math.min(intentHold, distEval))
			end
			if not bestAny or score > bestAnyScore then
				bestAny, bestAnyScore = e, score
				bestAnyHold, bestAnyMin = intentHold, minWanted
			end

			if inRange then
				if not bestReady or score > bestReadyScore then
					bestReady, bestReadyScore = e, score
				end
			end
		end
	end


	npc._holdRangeWanted = bestAnyHold or fallbackHold(npc)
	npc._minRangeWanted  = bestAnyMin or 0
	npc._lastBestAbility = bestAny

	if bestReady then
		castNPCAbility(npc, bestReady, target)
		return
	end
end

local function thinkAI(npc)
	if npc.Dead then return end
	local now = os.clock()
	updateActiveFlag(npc, now)
	if not npc.IsActive then return end


	if npc._leashing then return end

	if npc.SpellLockUntil and now < npc.SpellLockUntil then return end
	if now < npc.NextThink then return end
	npc.NextThink = now + (1 / THINK_HZ)


	if checkLeash(npc) then return end

	acquireTarget(npc)
	chooseAndCast(npc)
	tryAutoAttack(npc)
end


sanitizeAllTemplates()
spawnFromMarkers()


RunService.Heartbeat:Connect(function(dt)
	for _, n in pairs(npcs) do
		stepMove(n, dt)
	end
end)


RunService.Heartbeat:Connect(function()
	for _, n in pairs(npcs) do
		thinkAI(n)
	end
end)


local netTimer = 0
RunService.Heartbeat:Connect(function(dt)
	netTimer += dt
	if netTimer < 1/TICK_HZ then return end
	netTimer = 0

	local now = os.clock()
	for _, plr in ipairs(Players:GetPlayers()) do
		local present = {}
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		lastSent[plr] = lastSent[plr] or {}
		local rows, maps = {}, {}

		for _, mdl in ipairs(SpatialGrid.Query(root.Position, NET_RADIUS)) do
			local n = npcsByModel[mdl]
			if not n then continue end

			local guid = n.Guid
			if not guid then

				guid = mdl:GetAttribute("RelationId")
				if not guid then
					warn("[NPCService] Missing GUID for model ", tostring(mdl))
					continue
				end
			end

			local dist = (root.Position - n.Pos).Magnitude


			local id = ensureId(plr, guid)
			if not id then continue end
			present[id] = true

			local ls    = lastSent[plr][id]
			local hs    = StatsMod.humanoidStats[n.Model]
			local hpPct = hs and hs.MaxHealth > 0 and math.floor((hs.Health/hs.MaxHealth)*100 + 0.5) or 100
			local actId = ACTION_ID[n.Action] or 0
			local ka    = keepaliveForDist(dist)
			local eps   = moveEpsForDist(dist)
			local qstep = posQuantStep(dist)
			local qpos  = quantizeVec3XZ(n.Pos, qstep)

			if not ls then
				maps[#maps+1] = { id, guid, n.RigName, qpos, actId, hpPct, n.Tier or 1 }
				lastSent[plr][id] = { pos = qpos, hp = hpPct, act = actId, t = now }
			else
				local mask = 0
				local payload = { id, 0 }

				local moved = horizDist(qpos, ls.pos) >= eps
				local hpchg = math.abs(hpPct - ls.hp) >= HP_EPS
				local actch = actId ~= ls.act
				local stale = (now - ls.t) >= ka

				if moved or stale then
					mask = mask + 1
					payload[#payload+1] = qpos
					ls.pos = qpos
				end
				if actch then
					mask = mask + 2
					payload[#payload+1] = actId
					ls.act = actId
				end
				if hpchg then
					mask = mask + 4
					payload[#payload+1] = hpPct
					ls.hp = hpPct
				end

				if mask ~= 0 then
					payload[2] = mask
					rows[#rows+1] = payload
					ls.t = now
				end
			end
		end

		for id, rec in pairs(lastSent[plr]) do
			if not present[id] then
				lastSent[plr][id] = nil
			end
		end


		for id, rec in pairs(lastSent[plr]) do
			if now - (rec.t or 0) > CACHE_TTL then lastSent[plr][id] = nil end
		end


		local extras = WorldBus.Drain(plr)

		if #rows > 0 or #maps > 0 or #extras.fx > 0 or #extras.rel > 0 then
			REM_NPC_DELTA:FireClient(plr, { m = maps, n = rows, fx = extras.fx, rel = extras.rel })
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	idMap[p] = nil
	lastSent[p] = nil
end)


do
	local ServerStorage = game:GetService("ServerStorage")
	local serverStoragePackage = ServerStorage:WaitForChild("MMO_ServerStoragePackage")
	local BEFolder = serverStoragePackage:FindFirstChild("BindableEvents")
	if not BEFolder then
		BEFolder = Instance.new("Folder"); BEFolder.Name = "BindableEvents"; BEFolder.Parent = serverStoragePackage
	end
	local ThreatBump = BEFolder:FindFirstChild("ThreatBump")
	if not ThreatBump then
		ThreatBump = Instance.new("BindableEvent"); ThreatBump.Name = "ThreatBump"; ThreatBump.Parent = BEFolder
	end

	ThreatBump.Event:Connect(function(victimModel, attackerModel, amount)
		local npc = npcsByModel[victimModel]
		if not npc then return end

		addThreat(npc, attackerModel, amount or 0)


		if npc._leashing then
			return
		end


		if attackerModel
			and attackerModel.Parent
			and RS:GetRelation(npc.Model, attackerModel) == "Hostile"
		then
			setCombatTarget(npc, attackerModel, "threat_bump")


			local hrp = hrpOf(victimModel)
			if hrp then
				for _, mdl in ipairs(SpatialGrid.Query(hrp.Position, SOCIAL_AGGRO_RADIUS)) do
					local buddy = npcsByModel[mdl]
					if buddy and buddy ~= npc then
						if RS:GetRelation(buddy.Model, attackerModel) == "Hostile" then
							addThreat(buddy, attackerModel, (amount or 0) * 0.5 + 1)
							setCombatTarget(buddy, attackerModel, "social_aggro")
						end
					end
				end
			end
		end
	end)
end