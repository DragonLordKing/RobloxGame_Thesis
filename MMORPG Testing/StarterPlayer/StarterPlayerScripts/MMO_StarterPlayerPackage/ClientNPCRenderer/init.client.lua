--[[
Name: ClientNPCRenderer
Class: LocalScript
Original path: game.StarterPlayer.StarterPlayerScripts.MMO_StarterPlayerPackage.ClientNPCRenderer
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ReplicatedStorage, RunService
Requires:
  - local RelationClient = require(Replicated:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").RelationClient)
Functions: computeFootY, ensureHeadClearance, placeHRP, ensureHeadbar, acquire, recycle, forgetNPC, tweenTo, isValidAnimId, resolveAnimId, playTrack
Clean source lines: 492
]]
local Replicated   = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")

local Remotes      = Replicated:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")
local NPC_DELTA    = Remotes:WaitForChild("NPCDelta")
local NPC_DESPAWN  = Remotes:WaitForChild("NPCDespawn")
local RelationClient = require(Replicated:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Client").RelationClient)

local RigFolder            = Replicated:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Assets"):WaitForChild("NPCRigs")
local AboveHeadBarFolder   = Replicated:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Assets"):WaitForChild("AboveHeadBar")
local LocalAbilityVisual = Replicated:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("BindableEvents"):WaitForChild("LocalAbilityVisual")
local TopBarTemplate       = AboveHeadBarFolder:WaitForChild("TopBar")


local pools   = {}
local active  = {}
local id2guid, guid2id = {}, {}


local R_SMOOTH  = 50
local R_CHOPPY  = 80
local R_RENDER  = 150
local R_HYST    = 10


local K_NEAR = 18
local K_MID  = 3


local targets = {}

local seeds   = {}


local AnimMap = {


}

local warnOnce = {}


local PoolFolder = workspace:FindFirstChild("Ignore")
if not PoolFolder then
	PoolFolder = Instance.new("Folder")
	PoolFolder.Name = "Ignore"
	PoolFolder.Parent = workspace
end

local footYByRig = {}

local function computeFootY(mdl: Model): number
	local rigName = mdl:GetAttribute("rigName") or mdl.Name
	if footYByRig[rigName] then return footYByRig[rigName] end

	local hrp = mdl:FindFirstChild("HumanoidRootPart")
	if not hrp then
		footYByRig[rigName] = 0
		return 0
	end


	local footMarker = mdl:FindFirstChild("FootOrigin", true)
	if footMarker and footMarker:IsA("Attachment") then
		local localY = (hrp.CFrame:ToObjectSpace(footMarker.WorldCFrame)).Y
		local footY = -localY
		footYByRig[rigName] = footY
		mdl:SetAttribute("FootY", footY)
		return footY
	end


	local minBottom = math.huge
	for _, p in ipairs(mdl:GetDescendants()) do
		if p:IsA("BasePart") then
			local lcf = hrp.CFrame:ToObjectSpace(p.CFrame)
			local bottom = lcf.Y - (p.Size.Y * 0.5)
			if bottom < minBottom then minBottom = bottom end
		end
	end
	if minBottom == math.huge then minBottom = 0 end
	local footY = -minBottom
	footYByRig[rigName] = footY
	mdl:SetAttribute("FootY", footY)
	return footY
end

local HEAD_MARGIN = 0.00

local function ensureHeadClearance(mdl: Model)
	if mdl:GetAttribute("HeadAdjusted") then return end

	local head  = mdl:FindFirstChild("Head")
	local torso = mdl:FindFirstChild("UpperTorso") or mdl:FindFirstChild("Torso")
	if not (head and torso) then return end


	local neck = torso:FindFirstChild("Neck") or head:FindFirstChild("Neck")
	if not (neck and neck:IsA("Motor6D")) then

		local utNA = torso:FindFirstChild("NeckRigAttachment")
		local hNA  = head:FindFirstChild("NeckRigAttachment")
		if utNA and hNA and utNA:IsA("Attachment") and hNA:IsA("Attachment") then

			local torsoTop  = torso.Position.Y + (torso.Size.Y * 0.5)
			local headBottom= head.Position.Y  - (head.Size.Y  * 0.5)
			local gap = headBottom - torsoTop
			if gap < HEAD_MARGIN then
				local delta = HEAD_MARGIN - gap

				utNA.Position = utNA.Position + Vector3.new(0,  delta*0.5, 0)
				hNA.Position  = hNA.Position  + Vector3.new(0, -delta*0.5, 0)
				mdl:SetAttribute("HeadAdjusted", true)
			end
		end
		return
	end


	local torsoTop   = torso.Position.Y + (torso.Size.Y * 0.5)
	local headBottom = head.Position.Y  - (head.Size.Y  * 0.5)
	local gap = headBottom - torsoTop
	if gap < HEAD_MARGIN then
		local delta = HEAD_MARGIN - gap

		neck.C0 = neck.C0 * CFrame.new(0, delta, 0)
		mdl:SetAttribute("HeadAdjusted", true)
	end
end

local function placeHRP(hrp: BasePart, basePos: Vector3, mdl: Model)
	local footY = mdl:GetAttribute("FootY") or computeFootY(mdl)
	hrp.CFrame = CFrame.new(basePos + Vector3.new(0, footY, 0))
end

local function ensureHeadbar(mdl)
	local head = mdl:FindFirstChild("Head"); if not head then return end
	local gui = head:FindFirstChild("TopBar")
	if not gui then
		gui = TopBarTemplate:Clone()
		gui.Adornee = head
		gui.Parent  = head
	end

	local tierLabel = gui:FindFirstChild("TierLabel")
	if not tierLabel then
		tierLabel = Instance.new("TextLabel")
		tierLabel.Name = "TierLabel"
		tierLabel.BackgroundTransparency = 1
		tierLabel.TextColor3 = Color3.fromRGB(242, 228, 198)
		tierLabel.TextStrokeTransparency = 0.35
		tierLabel.Font = Enum.Font.GothamBold
		tierLabel.TextScaled = true
		tierLabel.Size = UDim2.new(1, 0, 0.22, 0)
		tierLabel.Position = UDim2.new(0, 0, -0.20, 0)
		tierLabel.Parent = gui
	end
	tierLabel.Text = "T" .. tostring(mdl:GetAttribute("Tier") or "?")
end

local function acquire(rigName: string): Model
	pools[rigName] = pools[rigName] or {}
	local mdl = table.remove(pools[rigName])

	if not mdl then
		local template = RigFolder:FindFirstChild(rigName)
		if not template then

			mdl = Instance.new("Model"); mdl.Name = "MissingRig"
			local hrp = Instance.new("Part"); hrp.Name = "HumanoidRootPart"; hrp.Size = Vector3.new(2,2,1); hrp.Anchored = true; hrp.Transparency = 1; hrp.Parent = mdl; mdl.PrimaryPart = hrp
			local box = Instance.new("Part"); box.Size = Vector3.new(2,3,1); box.Color = Color3.fromRGB(255, 0, 255); box.Anchored = true; box.CanCollide = false; box.Parent = mdl
		else
			mdl = template:Clone()
		end

		for _, d in ipairs(mdl:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.Massless = true
				pcall(function() d.CollisionGroup = "Character" end)
			end
		end
		local hum = mdl:FindFirstChildOfClass("Humanoid")
		local hrp = mdl:FindFirstChild("HumanoidRootPart")
		pcall(function() ensureHeadClearance(mdl) end)
		if hrp then hrp.Anchored = true end
	end

	mdl.Parent = PoolFolder
	return mdl
end

local function recycle(guid: string, rigName: string)
	local mdl = active[guid]; if not mdl then return end

	local hum = mdl:FindFirstChildOfClass("Humanoid")
	if hum then
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
				pcall(function() tr:Stop(0.1) end)
			end
		end
	end
	mdl.Parent = nil
	pools[rigName] = pools[rigName] or {}
	table.insert(pools[rigName], mdl)
	active[guid] = nil
end

local function forgetNPC(guid: string)
	local rigName = (active[guid] and active[guid]:GetAttribute("rigName")) or (seeds[guid] and seeds[guid].rig) or "Default"
	recycle(guid, rigName)
	local id = guid2id[guid]
	if id then
		id2guid[id] = nil
	end
	guid2id[guid] = nil
	seeds[guid] = nil
	targets[guid] = nil
end

NPC_DESPAWN.OnClientEvent:Connect(forgetNPC)

local function tweenTo(hrp: BasePart, target: Vector3)
	hrP = hrp
	hrP.CFrame = hrP.CFrame:Lerp(CFrame.new(target), 0.45)
end

local function isValidAnimId(id: any): boolean
	return type(id) == "string" and id:match("^rbxassetid://%d+$") ~= nil
end

local function resolveAnimId(mdl: Model, which: string): string?

	local f = mdl:FindFirstChild("Animations")
	local a = f and f:FindFirstChild(which)
	if a and a:IsA("Animation") and isValidAnimId(a.AnimationId) then
		return a.AnimationId
	end

	local rigKey = mdl:GetAttribute("rigName") or mdl.Name
	local template = RigFolder:FindFirstChild(rigKey)
	local tf = template and template:FindFirstChild("Animations")
	local ta = tf and tf:FindFirstChild(which)
	if ta and ta:IsA("Animation") and isValidAnimId(ta.AnimationId) then
		return ta.AnimationId
	end

	local map = AnimMap[rigKey]
	local id = map and map[which]
	if isValidAnimId(id) then return id end
	return nil
end

local function playTrack(guid: string, mdl: Model, which: string)
	local hum = mdl:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)


	local animId = resolveAnimId(mdl, which)
	if not animId then
		local rigKey = mdl:GetAttribute("rigName") or mdl.Name
		local k = rigKey..":"..which
		if not warnOnce[k] then
			warnOnce[k] = true
			warn("No valid animation id found for ", k, ". Skipping animation play.")
		end
		return
	end


	for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do

		pcall(function()
			if tr.Name == which then tr:Stop(0.1) end
		end)
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	anim.Name = which

	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track:Play(0.1, 1.0, (which == "Run") and 1.0 or 0.8)
	else
		local rigKey = mdl:GetAttribute("rigName") or mdl.Name
		local k = rigKey..":"..which
		if not warnOnce["load-"..k] then
			warnOnce["load-"..k] = true
			warn("Failed to load animation for ", k)
		end
	end
end


NPC_DELTA.OnClientEvent:Connect(function(payload)
	local rows, fx, rel, maps = {}, {}, {}, {}

	if typeof(payload) == "table" then
		rows = payload.n or payload
		fx   = payload.fx or {}
		rel  = payload.rel or {}
		maps = payload.m or {}
	end


	for _, mp in ipairs(maps) do

		local id, guid, rig, pos, actId, hpPct, tier = mp[1], mp[2], mp[3], mp[4], mp[5], mp[6], mp[7]
		id2guid[id], guid2id[guid] = guid, id
		seeds[guid] = { rig = rig, id = id, tier = tier or 1 }


		local my = game.Players.LocalPlayer.Character
		local myhrp = my and my:FindFirstChild("HumanoidRootPart")
		local inRange = myhrp and typeof(pos)=="Vector3" and ((myhrp.Position - pos).Magnitude <= R_RENDER)

		if not active[guid] and inRange then
			local mdl = acquire(rig or "Default")
			active[guid] = mdl
			mdl:SetAttribute("rigName", rig or "Default")
			mdl:SetAttribute("RelationId", guid)
			mdl:SetAttribute("Tier", tier or 1)
			ensureHeadbar(mdl)
		end


		local mdl = active[guid]
		if mdl then
			local hrp = mdl:FindFirstChild("HumanoidRootPart")
			if hrp and typeof(pos) == "Vector3" then
				placeHRP(hrp, pos, mdl)
				targets[guid] = pos
			end
			local which = (actId == 1) and "Run" or "Idle"
			playTrack(guid, mdl, which)

			local head = mdl:FindFirstChild("Head")
			local bar = head and head:FindFirstChild("TopBar")
				and head.TopBar:FindFirstChild("HealthBar")
				and head.TopBar.HealthBar:FindFirstChild("Health")
			if bar and typeof(hpPct) == "number" then
				bar.Size = UDim2.new(math.clamp(hpPct/100, 0, 1), 0, 1, 0)
			end
			if typeof(hpPct) == "number" and hpPct <= 0 then
				forgetNPC(guid)
				continue
			end
			mdl:SetAttribute("TouchedAt", os.clock())
		end
	end


	for _, row in ipairs(rows) do
		local idx  = 1
		local id   = row[idx]; idx += 1
		local mask = row[idx]; idx += 1

		local guid = id2guid[id]
		if not guid then


			continue
		end


		local hasPos = (mask % 2) >= 1
		local hasAct = (math.floor(mask/2) % 2) >= 1
		local hasHP  = (math.floor(mask/4) % 2) >= 1


		local mdl = active[guid]
		if hasPos then
			local pos = row[idx]; idx += 1
			targets[guid] = pos

			local my    = game.Players.LocalPlayer.Character
			local myhrp = my and my:FindFirstChild("HumanoidRootPart")
			if myhrp then
				local d = (myhrp.Position - pos).Magnitude


				if not mdl and d <= R_RENDER then
					local rig = (seeds[guid] and seeds[guid].rig) or "Default"
					mdl = acquire(rig)
					active[guid] = mdl
					mdl:SetAttribute("rigName", rig)
					mdl:SetAttribute("RelationId", guid)
					mdl:SetAttribute("Tier", (seeds[guid] and seeds[guid].tier) or 1)
					ensureHeadbar(mdl)
				end

				if mdl then
					local hrp = mdl:FindFirstChild("HumanoidRootPart")
					if hrp and d > R_SMOOTH then
						placeHRP(hrp, pos, mdl)
					end
				end
			end
		else

			if not active[guid] then
				continue
			end
			mdl = active[guid]
		end


		if hasAct and mdl then
			local actId = row[idx]; idx += 1
			local which = (actId == 1) and "Run" or "Idle"
			playTrack(guid, mdl, which)
		end


		if hasHP and mdl then
			local hpPct = row[idx]; idx += 1
			local head = mdl:FindFirstChild("Head")
			local bar = head and head:FindFirstChild("TopBar")
				and head.TopBar:FindFirstChild("HealthBar")
				and head.TopBar.HealthBar:FindFirstChild("Health")
			if bar and typeof(hpPct) == "number" then
				bar.Size = UDim2.new(math.clamp(hpPct/100, 0, 1), 0, 1, 0)
			end
			if typeof(hpPct) == "number" and hpPct <= 0 then
				forgetNPC(guid)
				continue
			end
		end

		if mdl then mdl:SetAttribute("TouchedAt", os.clock()) end
	end


	for _, f in ipairs(fx) do
		LocalAbilityVisual:Fire(f[1], f[2])
	end

	if rel and #rel > 0 and RelationClient.ApplyMany then
		RelationClient:ApplyMany(rel)
	end
end)


RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for guid, mdl in pairs(active) do
		local last = mdl:GetAttribute("TouchedAt") or 0
		if now - last > 3 then
			recycle(guid, mdl:GetAttribute("rigName") or "Default")
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local my = game.Players.LocalPlayer.Character
	local myhrp = my and my:FindFirstChild("HumanoidRootPart")
	if not myhrp then return end

	for guid, mdl in pairs(active) do
		local hrp = mdl:FindFirstChild("HumanoidRootPart")
		local tgt = targets[guid]
		if not (hrp and tgt) then continue end

		local d = (myhrp.Position - hrp.Position).Magnitude


		if d > (R_RENDER + R_HYST) then
			recycle(guid, mdl:GetAttribute("rigName") or "Default")
			targets[guid] = nil
		else

			if d <= R_SMOOTH then
				local k = K_NEAR
				local alpha = 1 - math.exp(-k * dt)
				local footY = mdl:GetAttribute("FootY") or computeFootY(mdl)
				hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(tgt + Vector3.new(0, footY, 0)), alpha)
			elseif d <= R_CHOPPY then


				local alpha = 1 - math.exp(-K_MID * dt)
				local footY = mdl:GetAttribute("FootY") or computeFootY(mdl)
				hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(tgt + Vector3.new(0, footY, 0)), alpha)
			end
		end
	end
end)
