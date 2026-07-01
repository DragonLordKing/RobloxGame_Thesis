--[[
Name: SmartChestService
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.WorldRuntime.SmartChestService
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: Players, ReplicatedStorage, ServerStorage, Workspace
Functions: sanitizeKey, sourceToPlayer, objectPosition, chestKeyFor, normalizeType, normalizeScope, normalizeValorBucket, reqValorBucket, reqTarget, reqRadius, reqId, isNpcKillRequirement, isValorRequirement, copyRequirement, addRequirement, requirementsFromModule, buildRequirements, progressBucket, progressFor, firstBasePart, setChestReadyEmitter, requirementsReadyForServer, refreshChestReadyVisual, setProgressFor, addProgress, withinChest, isChestCandidate, requirementLabel, eventPositionFromNpc, onNPCDied, onValorEarned, SmartChestService.RegisterChest, SmartChestService.BuildContext, SmartChestService.GetProgressSummary, SmartChestService.CanOpen, SmartChestService.ResetProgress, SmartChestService.Start, GetProgress, SetProgress
Signal classes referenced: BindableEvent
Clean source lines: 465
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local SmartChestService = {}

local ReplicatedPackage = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage")
local bindableFolder = ServerStorage:WaitForChild("MMO_ServerStoragePackage"):FindFirstChild("BindableEvents")
if not bindableFolder then
	bindableFolder = Instance.new("Folder")
	bindableFolder.Name = "BindableEvents"
	bindableFolder.Parent = ServerStorage:WaitForChild("MMO_ServerStoragePackage")
end

local NPCDied = bindableFolder:FindFirstChild("NPCDied")
if not NPCDied then
	NPCDied = Instance.new("BindableEvent")
	NPCDied.Name = "NPCDied"
	NPCDied.Parent = bindableFolder
end

local ValorEarned = bindableFolder:FindFirstChild("ValorEarned")
if not ValorEarned then
	ValorEarned = Instance.new("BindableEvent")
	ValorEarned.Name = "ValorEarned"
	ValorEarned.Parent = bindableFolder
end

local started = false
local registeredChests = {}
local progressByChest = {}
local requirementCache = setmetatable({}, { __mode = "k" })

local DEFAULT_RADIUS = 120

local function sanitizeKey(value)
	return tostring(value or "Chest"):gsub("[^%w_%-]", "_")
end

local function sourceToPlayer(source)
	if typeof(source) ~= "Instance" then return nil end
	if source:IsA("Player") then return source end
	if source:IsA("Model") then return Players:GetPlayerFromCharacter(source) end
	return nil
end

local function objectPosition(inst)
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst.Position end
	if inst:IsA("Model") then
		local ok, pivot = pcall(function() return inst:GetPivot() end)
		if ok then return pivot.Position end
		local part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
		return part and part.Position or nil
	end
	local part = inst:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position or nil
end

local function chestKeyFor(chest)
	local explicit = chest and (chest:GetAttribute("ChestKey") or chest:GetAttribute("ChestId") or chest:GetAttribute("RequirementKey"))
	if explicit and tostring(explicit) ~= "" then
		return sanitizeKey(explicit)
	end
	local debugId = ""
	pcall(function() debugId = chest:GetDebugId(8) end)
	return sanitizeKey((chest and chest:GetFullName() or "Chest") .. "_" .. debugId)
end

local function normalizeType(value)
	return tostring(value or ""):lower():gsub("[%s_%-]", "")
end

local function normalizeScope(value)
	local scope = tostring(value or "Server")
	local lower = scope:lower()
	if lower == "player" or lower == "user" or lower == "personal" then return "Player" end
	return "Server"
end

local function normalizeValorBucket(value)
	local bucket = tostring(value or ""):lower():gsub("[%s_%-]", "")
	if bucket == "" or bucket == "any" or bucket == "all" or bucket == "total" then return nil end
	if bucket == "pve" or bucket == "mob" or bucket == "npc" or bucket == "combat" then return "PvE" end
	if bucket == "pvp" or bucket == "player" then return "PvP" end
	if bucket == "gather" or bucket == "gathering" then return "Gathering" end
	if bucket == "craft" or bucket == "crafting" or bucket == "refining" then return "Crafting" end
	return nil
end

local function reqValorBucket(req, chest)
	local explicit = req.Bucket or req.ValorBucket or req.ValorType or req.Activity or (chest and (chest:GetAttribute("RequiredValorBucket") or chest:GetAttribute("RequiredValorType") or chest:GetAttribute("ValorBucket") or chest:GetAttribute("ValorType")))
	return normalizeValorBucket(explicit) or "PvE"
end

local function reqTarget(req)
	return math.max(1, math.floor(tonumber(req.Amount or req.Count or req.Target or req.Required or req.Value) or 1))
end

local function reqRadius(req, chest)
	return math.max(1, tonumber(req.Radius or req.NearbyRadius or req.Distance or (chest and (chest:GetAttribute("RequirementRadius") or chest:GetAttribute("NearbyRadius")))) or DEFAULT_RADIUS)
end

local function reqId(req, index)
	if req.Id and tostring(req.Id) ~= "" then return sanitizeKey(req.Id) end
	local kind = normalizeType(req.Type or req.Kind or req.Requirement)
	return sanitizeKey((kind ~= "" and kind or "requirement") .. "_" .. tostring(index or 1))
end

local function isNpcKillRequirement(req)
	local kind = normalizeType(req.Type or req.Kind or req.Requirement)
	return kind == "npckillnearby" or kind == "npckill" or kind == "killnpcsnearby" or kind == "killsnearby" or kind == "npckillsnearby"
end

local function isValorRequirement(req)
	local kind = normalizeType(req.Type or req.Kind or req.Requirement)
	return kind == "valornearby" or kind == "earnvalornearby" or kind == "valor" or kind == "valoramountnearby"
end

local function copyRequirement(raw)
	local req = {}
	for key, value in pairs(raw) do req[key] = value end
	return req
end

local function addRequirement(out, raw)
	if type(raw) ~= "table" then return end
	if raw.Type or raw.Kind or raw.Requirement then
		table.insert(out, copyRequirement(raw))
	end
end

local function requirementsFromModule(chest, moduleScript, out)
	local ok, result = pcall(require, moduleScript)
	if not ok then
		table.insert(out, { Type = "BlockingError", Id = moduleScript.Name, Message = "Chest requirement module failed: " .. tostring(moduleScript.Name) })
		return
	end
	if type(result) ~= "table" then return end
	if type(result.GetRequirements) == "function" then
		local okList, list = pcall(result.GetRequirements, chest)
		if okList then
			if type(list) == "table" then
				if list.Type or list.Kind or list.Requirement then
					addRequirement(out, list)
				else
					for _, entry in ipairs(list) do addRequirement(out, entry) end
				end
			end
		else
			table.insert(out, { Type = "BlockingError", Id = moduleScript.Name, Message = "Chest requirement module failed: " .. tostring(moduleScript.Name) })
		end
	end
	if type(result.Requirements) == "table" then
		for _, entry in ipairs(result.Requirements) do addRequirement(out, entry) end
	end
	addRequirement(out, result)
end

local function buildRequirements(chest)
	local cached = requirementCache[chest]
	if cached then return cached end

	local reqs = {}
	local radius = chest:GetAttribute("RequirementRadius") or chest:GetAttribute("NearbyRadius") or DEFAULT_RADIUS
	local scope = chest:GetAttribute("RequirementScope") or chest:GetAttribute("ProgressScope") or "Server"
	local npcKills = chest:GetAttribute("RequiredNpcKills") or chest:GetAttribute("RequiredNpcKillsNearby") or chest:GetAttribute("NpcKillsRequired")
	local valor = chest:GetAttribute("RequiredValorNearby") or chest:GetAttribute("RequiredValor") or chest:GetAttribute("ValorRequired")

	if tonumber(npcKills) and tonumber(npcKills) > 0 then
		table.insert(reqs, { Id = "npc_kills_nearby", Type = "NpcKillsNearby", Count = tonumber(npcKills), Radius = radius, Scope = scope, Label = "NPC kills nearby" })
	end
	if tonumber(valor) and tonumber(valor) > 0 then
		table.insert(reqs, { Id = "valor_nearby", Type = "ValorNearby", Amount = tonumber(valor), Radius = radius, Scope = scope, Bucket = reqValorBucket({}, chest), Label = "Valor earned nearby" })
	end

	for _, child in ipairs(chest:GetChildren()) do
		if child:IsA("ModuleScript") then
			requirementsFromModule(chest, child, reqs)
		end
	end

	requirementCache[chest] = reqs
	return reqs
end

local function progressBucket(chestKey, scope, player)
	local chestProgress = progressByChest[chestKey]
	if not chestProgress then
		chestProgress = {}
		progressByChest[chestKey] = chestProgress
	end
	local scopeKey = scope == "Player" and player and ("User_" .. tostring(player.UserId)) or "Server"
	local bucket = chestProgress[scopeKey]
	if not bucket then
		bucket = {}
		chestProgress[scopeKey] = bucket
	end
	return bucket
end

local function progressFor(chestKey, req, player, index)
	local scope = normalizeScope(req.Scope)
	local bucket = progressBucket(chestKey, scope, player)
	return math.max(0, math.floor(tonumber(bucket[reqId(req, index)]) or 0))
end

local function firstBasePart(root)
	if not root then return nil end
	if root:IsA("BasePart") then return root end
	if root:IsA("Model") then return root.PrimaryPart or root:FindFirstChildWhichIsA("BasePart", true) end
	return root:FindFirstChildWhichIsA("BasePart", true)
end

local function setChestReadyEmitter(chest, enabled)
	for _, inst in ipairs(chest:GetDescendants()) do
		if inst:IsA("ParticleEmitter") and inst:GetAttribute("RuntimeChestUnlockedEmitter") == true then
			inst:Destroy()
		end
	end
	if enabled ~= true then return end
	local assets = ReplicatedPackage:FindFirstChild("Assets")
	local emitters = assets and assets:FindFirstChild("PurityEmitters")
	local template = emitters and emitters:FindFirstChild("ChestUnlocked")
	local part = firstBasePart(chest)
	if not (template and template:IsA("ParticleEmitter") and part) then return end
	local emitter = template:Clone()
	emitter:SetAttribute("RuntimeChestUnlockedEmitter", true)
	emitter.Parent = part
end

local function requirementsReadyForServer(chest, reqs)
	local key = chestKeyFor(chest)
	local sawRequirement = false
	for index, req in ipairs(reqs or {}) do
		if normalizeType(req.Type) == "blockingerror" then return false end
		if isNpcKillRequirement(req) or isValorRequirement(req) then
			sawRequirement = true
			if normalizeScope(req.Scope) == "Player" then return false end
			if progressFor(key, req, nil, index) < reqTarget(req) then return false end
		end
	end
	return sawRequirement
end

local function refreshChestReadyVisual(chest)
	if not (chest and chest.Parent) then return end
	local reqs = buildRequirements(chest)
	local ready = chest:GetAttribute("ChestUnlocked") == true or requirementsReadyForServer(chest, reqs)
	if ready then chest:SetAttribute("ChestUnlocked", true) end
	setChestReadyEmitter(chest, ready)
end

local function setProgressFor(chest, req, player, index, amount)
	local key = chestKeyFor(chest)
	local scope = normalizeScope(req.Scope)
	local id = reqId(req, index)
	local bucket = progressBucket(key, scope, player)
	bucket[id] = math.max(0, math.floor(tonumber(amount) or 0))
	if scope == "Server" then
		if isNpcKillRequirement(req) then chest:SetAttribute("NpcKillsNearbyProgress", bucket[id]) end
		if isValorRequirement(req) then chest:SetAttribute("ValorNearbyProgress", bucket[id]) end
		task.defer(refreshChestReadyVisual, chest)
	end
end

local function addProgress(chest, req, player, index, amount)
	setProgressFor(chest, req, player, index, progressFor(chestKeyFor(chest), req, player, index) + amount)
end

local function withinChest(chest, position, radius)
	local chestPos = objectPosition(chest)
	return chestPos and typeof(position) == "Vector3" and (position - chestPos).Magnitude <= radius
end

local function isChestCandidate(inst)
	if not (inst and (inst:IsA("Model") or inst:IsA("BasePart"))) then return false end
	local name = string.lower(inst.Name)
	if inst:GetAttribute("LootChest") == true or name:find("treasurechesttype", 1, true) then return true end
	if inst:GetAttribute("RequiredNpcKills") or inst:GetAttribute("RequiredNpcKillsNearby") or inst:GetAttribute("RequiredValorNearby") or inst:GetAttribute("RequiredValor") then return true end
	return false
end

function SmartChestService.RegisterChest(chest)
	if not isChestCandidate(chest) then return false end
	registeredChests[chest] = true
	requirementCache[chest] = nil
	if chest:GetAttribute("ChestKey") == nil then
		chest:SetAttribute("RuntimeChestKey", chestKeyFor(chest))
	end
	return true
end

function SmartChestService.BuildContext(player, chest)
	SmartChestService.RegisterChest(chest)
	return {
		Player = player,
		Chest = chest,
		ChestKey = chestKeyFor(chest),
		Position = objectPosition(chest),
		Requirements = buildRequirements(chest),
		ProgressByChest = progressByChest,
		GetProgress = function(req, index)
			return progressFor(chestKeyFor(chest), req, player, index)
		end,
		SetProgress = function(req, index, amount)
			setProgressFor(chest, req, player, index, amount)
		end,
	}
end

local function requirementLabel(req)
	if req.Label then return tostring(req.Label) end
	if isNpcKillRequirement(req) then return "NPC kills nearby" end
	if isValorRequirement(req) then
		local bucket = reqValorBucket(req)
		return bucket and (bucket .. " Valor earned nearby") or "Valor earned nearby"
	end
	return tostring(req.Type or req.Kind or "requirement")
end

function SmartChestService.GetProgressSummary(player, chest)
	SmartChestService.RegisterChest(chest)
	local reqs = buildRequirements(chest)
	local lines = {}
	for index, req in ipairs(reqs) do
		if normalizeType(req.Type) == "blockingerror" then
			table.insert(lines, req.Message or "Requirement error")
		elseif isNpcKillRequirement(req) or isValorRequirement(req) then
			local current = progressFor(chestKeyFor(chest), req, player, index)
			local target = reqTarget(req)
			table.insert(lines, string.format("%s: %d/%d", requirementLabel(req), math.min(current, target), target))
		end
	end
	return table.concat(lines, " | ")
end

function SmartChestService.CanOpen(player, chest)
	if not (player and chest) then return false, "Chest is unavailable." end
	SmartChestService.RegisterChest(chest)
	local reqs = buildRequirements(chest)
	if #reqs <= 0 then return true end

	local mode = tostring(chest:GetAttribute("RequirementMode") or "All"):lower()
	local anySatisfied = false
	local missing = {}

	for index, req in ipairs(reqs) do
		if normalizeType(req.Type) == "blockingerror" then
			return false, req.Message or "Chest requirement failed."
		end
		if isNpcKillRequirement(req) or isValorRequirement(req) then
			local current = progressFor(chestKeyFor(chest), req, player, index)
			local target = reqTarget(req)
			if current >= target then
				anySatisfied = true
			else
				table.insert(missing, string.format("%s %d/%d", requirementLabel(req), current, target))
			end
		end
	end

	if mode == "any" then
		if anySatisfied then chest:SetAttribute("ChestUnlocked", true); refreshChestReadyVisual(chest); return true end
		local message = "Chest locked: " .. (#missing > 0 and table.concat(missing, " or ") or "requirement not met")
		chest:SetAttribute("RequirementProgressText", message)
		return false, message
	end

	if #missing == 0 then
		chest:SetAttribute("ChestUnlocked", true)
		refreshChestReadyVisual(chest)
		return true
	end
	local message = "Chest locked: " .. table.concat(missing, ", ")
	chest:SetAttribute("RequirementProgressText", message)
	return false, message
end

local function eventPositionFromNpc(npcModel, meta)
	if type(meta) == "table" and typeof(meta.Position) == "Vector3" then return meta.Position end
	if type(meta) == "table" and typeof(meta.NpcPosition) == "Vector3" then return meta.NpcPosition end
	return objectPosition(npcModel)
end

local function onNPCDied(npcModel, source, meta)
	local player = type(meta) == "table" and meta.KillerPlayer or nil
	player = player or sourceToPlayer(source)
	local pos = eventPositionFromNpc(npcModel, meta)
	if not pos then return end
	for chest in pairs(registeredChests) do
		if chest.Parent then
			local reqs = buildRequirements(chest)
			for index, req in ipairs(reqs) do
				if isNpcKillRequirement(req) and withinChest(chest, pos, reqRadius(req, chest)) then
					addProgress(chest, req, player, index, 1)
				end
			end
		else
			registeredChests[chest] = nil
			requirementCache[chest] = nil
		end
	end
end

local function onValorEarned(payload)
	if type(payload) ~= "table" then return end
	local player = payload.Player
	local amount = math.max(0, math.floor(tonumber(payload.Amount) or 0))
	if amount <= 0 then return end
	local pos = payload.Position
	if typeof(pos) ~= "Vector3" and player and player.Character then
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		pos = root and root.Position or nil
	end
	if typeof(pos) ~= "Vector3" then return end
	for chest in pairs(registeredChests) do
		if chest.Parent then
			local reqs = buildRequirements(chest)
			for index, req in ipairs(reqs) do
				if isValorRequirement(req) and withinChest(chest, pos, reqRadius(req, chest)) then
					local requiredBucket = reqValorBucket(req, chest)
					local earnedBucket = normalizeValorBucket(payload.Bucket or payload.Type or payload.Activity)
					if not requiredBucket or requiredBucket == earnedBucket then
						addProgress(chest, req, player, index, amount)
					end
				end
			end
		else
			registeredChests[chest] = nil
			requirementCache[chest] = nil
		end
	end
end

function SmartChestService.ResetProgress(chest)
	if not chest then return end
	local key = chestKeyFor(chest)
	progressByChest[key] = nil
	requirementCache[chest] = nil
	chest:SetAttribute("ChestUnlocked", false)
	chest:SetAttribute("NpcKillsNearbyProgress", 0)
	chest:SetAttribute("ValorNearbyProgress", 0)
	chest:SetAttribute("RequirementProgressText", nil)
	setChestReadyEmitter(chest, false)
end

function SmartChestService.Start()
	if started then return end
	started = true
	for _, inst in ipairs(Workspace:GetDescendants()) do
		SmartChestService.RegisterChest(inst)
	end
	Workspace.DescendantAdded:Connect(function(inst)
		task.defer(function()
			SmartChestService.RegisterChest(inst)
		end)
	end)
	NPCDied.Event:Connect(onNPCDied)
	ValorEarned.Event:Connect(onValorEarned)
end

return SmartChestService
