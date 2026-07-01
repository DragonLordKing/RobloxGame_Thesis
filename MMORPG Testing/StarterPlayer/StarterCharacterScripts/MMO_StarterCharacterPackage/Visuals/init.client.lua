--[[
Name: Visuals
Class: LocalScript
Original path: game.StarterPlayer.StarterCharacterScripts.MMO_StarterCharacterPackage.Visuals
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Enabled=true, LinkedSource="", Disabled=false, RunContext="Enum.RunContext.Legacy", Archivable=true
Services: ReplicatedStorage, Workspace, TweenService, Debris, RunService, Players
Functions: flashPart, rebuildIgnore, getLiveOrigin, rigFeetY, markedNonGround, skipGroundHit, groundYAt, anchorY, lockY, resolveDir, rectOrigin, rectCFFromOrigin, cylCF, fx.LineStatic, fx.LineTween, fx.LineProjectile, fx.CylStatic, fx.CylLocation, fx.CylTween, fx.CylProjectile, fx.RectInstant, fx.RectTelegraph, fx.CylTelegraph, fx.ConeTelegraph, fx.BeamStart, fx.BeamEnd, fx.SphStatic, fx.SphLocation, fx.SphTween, fx.SphProjectile, fx.JumpLaunch
Clean source lines: 476
]]
local RS      = game:GetService("ReplicatedStorage")
local WS      = game:GetService("Workspace")
local TS      = game:GetService("TweenService")
local Debris  = game:GetService("Debris")
local RunSrv  = game:GetService("RunService")
local Players = game:GetService("Players")

local REMOTES = RS:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("RemoteEvents")
local AbilityVisual = REMOTES:WaitForChild("AbilityVisual")
local LocalAbilityVisual = RS:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("BindableEvents"):WaitForChild("LocalAbilityVisual")

local INDICATOR_TIME = 5


local VFX_Y_MODE    = "ground"
local VFX_Y_OFFSET  = 0.05
local VFX_FIXED_Y   = 0.05


local function flashPart(cfg)
	local p             = Instance.new("Part")
	p.Anchored          = true
	p.CanCollide        = false
	p.CanQuery          = false
	p.CanTouch          = false
	p.CastShadow        = false
	p.Material          = Enum.Material.Neon
	p.Color             = cfg.Color or Color3.new(1,0,0)
	p.Transparency      = cfg.Transparency or 0.35
	p.Shape             = cfg.Shape or Enum.PartType.Block
	p.Size              = cfg.Size  or Vector3.new(2,2,2)
	p.CFrame            = cfg.CFrame or CFrame.new()
	p.Parent            = WS
	Debris:AddItem(p, cfg.Lifetime or INDICATOR_TIME)
	return p
end


local RAYCAST_IGNORE = {}

local function rebuildIgnore()
	table.clear(RAYCAST_IGNORE)


	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(RAYCAST_IGNORE, plr.Character)
		end
	end


	for _, inst in ipairs(WS:GetDescendants()) do
		if inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") then
			table.insert(RAYCAST_IGNORE, inst)
		end
	end
end


rebuildIgnore()


Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(rebuildIgnore)
	p.CharacterRemoving:Connect(rebuildIgnore)
end)
Players.PlayerRemoving:Connect(rebuildIgnore)

WS.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") then
		table.insert(RAYCAST_IGNORE, inst)
	end
end)
WS.DescendantRemoving:Connect(function(inst)
	if inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") then
		rebuildIgnore()
	end
end)


local function getLiveOrigin(info, caster)

	return info.Origin
end

local function rigFeetY(who)
	local char = who and who.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	local half = hrp.Size.Y * 0.5
	return hum and (hrp.Position.Y - (hum.HipHeight + half)) or (hrp.Position.Y - half)
end

local function markedNonGround(inst)
	local current = inst
	while current and current ~= WS do
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

local function skipGroundHit(inst)
	if not inst or inst == WS.Terrain then
		return false
	end
	if markedNonGround(inst) then
		return true
	end
	if inst:IsA("BasePart") then
		return inst.CanCollide == false or inst.CollisionGroup == "Non-Collidable" or inst.CollisionGroup == "NonCollidable" or inst.CollisionGroup == "Walkthrough"
	end
	return false
end

local function groundYAt(xz: Vector3)
	local origin = xz + Vector3.new(0, 128, 0)
	local direction = Vector3.new(0, -4096, 0)
	local excludes = table.clone(RAYCAST_IGNORE)
	for _ = 1, 12 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excludes
		params.IgnoreWater = true
		local hit = WS:Raycast(origin, direction, params)
		if not hit then
			return xz.Y
		end
		if not skipGroundHit(hit.Instance) then
			return hit.Position.Y
		end
		table.insert(excludes, hit.Instance)
	end
	return xz.Y
end


local function anchorY(info, caster)
	if typeof(info.LevelY) == "number" then
		return info.LevelY + (info.YOffset or VFX_Y_OFFSET)
	end

	if VFX_Y_MODE == "fixed" then
		return VFX_FIXED_Y
	elseif VFX_Y_MODE == "hrp" then
		local char = caster and caster.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		return (hrp and hrp.Position.Y or (info.Origin and info.Origin.Y) or 0) + VFX_Y_OFFSET
	elseif VFX_Y_MODE == "feet" then
		local y = rigFeetY(caster)
		if y then return y + VFX_Y_OFFSET end
		local base = info.Origin or info.Centre or info.Position or info.Target or info.Start or Vector3.new()
		return groundYAt(base) + VFX_Y_OFFSET
	else
		local base = info.Origin or info.Centre or info.Position or info.Target or info.Start or Vector3.new()
		return groundYAt(base) + VFX_Y_OFFSET
	end
end

local function lockY(vec: Vector3, y: number)
	return Vector3.new(vec.X, y, vec.Z)
end


local function resolveDir(v)
	if not v then return Vector3.new(1,0,0) end
	v = Vector3.new(v.X, 0, v.Z)
	local m = v.Magnitude
	return (m > 1e-3) and (v / m) or Vector3.new(1,0,0)
end


local function rectOrigin(i, caster)
	local dir    = resolveDir(i.Dir)
	local origin = i.Origin
	if (not origin) and i.Centre and i.Length then
		origin = i.Centre - dir * (i.Length * 0.5)
	end
	origin = origin or i.Position or Vector3.new()
	origin = lockY(origin, anchorY(i, caster))
	return origin, dir
end

local function rectCFFromOrigin(origin, dir, len)
	local centre = origin + dir * (len * 0.5)
	return CFrame.lookAt(centre, centre + dir, Vector3.yAxis)
end


local fx = {}


fx.LineStatic = function(info, caster)
	local y      = anchorY(info, caster)
	local origin = lockY(getLiveOrigin(info, caster), y)
	local centre = origin + info.Dir * (info.Range * 0.5)
	local cf     = CFrame.lookAt(centre, centre + info.Dir, Vector3.yAxis)
	flashPart{
		Size   = Vector3.new(info.Width, 0.2, info.Range),
		CFrame = cf,
	}
end

fx.LineTween = function(info, caster)
	local y      = anchorY(info, caster)
	local origin = lockY(getLiveOrigin(info, caster), y)
	local dir      = info.Dir
	local width    = info.Width
	local range    = info.Range
	local dur      = info.Duration

	local part = flashPart{
		Size     = Vector3.new(width, 0.2, 0.1),
		CFrame   = CFrame.lookAt(origin, origin + dir, Vector3.yAxis),
		Lifetime = dur + INDICATOR_TIME,
	}

	local goal = {
		Size   = Vector3.new(width, 0.2, range),
		CFrame = part.CFrame + dir * (range * 0.5),
	}

	TS:Create(part, TweenInfo.new(dur, Enum.EasingStyle.Linear), goal):Play()
end

fx.LineProjectile = function(info, caster)
	local y      = anchorY(info, caster)
	local origin = lockY(info.Origin or Vector3.new(), y)
	local cf0    = CFrame.lookAt(origin, origin + info.Dir, Vector3.yAxis)
	local dur    = (info.Range or 0) / (info.Speed or 1)

	local part = flashPart{
		Size     = Vector3.new(info.Width, 0.2, info.Width),
		CFrame   = cf0,
		Lifetime = dur + 0.1,
	}
	TS:Create(part, TweenInfo.new(dur, Enum.EasingStyle.Linear),
		{ CFrame = cf0 + info.Dir * (info.Range or 0) }):Play()
end


local function cylCF(pos)
	return CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
end

fx.CylStatic = function(i, caster)
	local y = anchorY(i, caster)
	local c = lockY(i.Centre or Vector3.new(), y)
	flashPart{
		Shape  = Enum.PartType.Cylinder,
		Size   = Vector3.new(0.2, i.Radius*2, i.Radius*2),
		CFrame = cylCF(c),
	}
end

fx.CylLocation = function(i, caster)
	local y = anchorY(i, caster)
	local centre = lockY(i.Centre or i.Position or Vector3.new(), y)

	flashPart{
		Shape        = Enum.PartType.Cylinder,
		Size         = Vector3.new(0.2, i.Radius*2, i.Radius*2),
		CFrame       = cylCF(centre),
		Transparency = 0.85,
	}

	if i.Duration and i.Duration > 0 then
		local inner = flashPart{
			Shape    = Enum.PartType.Cylinder,
			Size     = Vector3.new(0.2, 0.1, 0.1),
			CFrame   = cylCF(centre),
			Lifetime = i.Duration,
		}
		TS:Create(inner, TweenInfo.new(i.Duration, Enum.EasingStyle.Linear),
			{ Size = Vector3.new(0.2, i.Radius*2, i.Radius*2) }):Play()
	end
end

fx.CylTween = function(i, caster)
	local y = anchorY(i, caster)
	local c = lockY(i.Centre or Vector3.new(), y)

	local part = flashPart{
		Shape    = Enum.PartType.Cylinder,
		Size     = Vector3.new(0.2, 0.1, 0.1),
		CFrame   = cylCF(c),
		Lifetime = (i.Duration or 0) + 0.1,
	}
	TS:Create(part, TweenInfo.new(i.Duration or 0, Enum.EasingStyle.Linear),
		{ Size = Vector3.new(0.2, i.Radius*2, i.Radius*2) }):Play()
end

fx.CylProjectile = function(i, caster)
	local y      = anchorY(i, caster)
	local origin = lockY(i.Origin or Vector3.new(), y)
	local dur    = (i.Range or 0) / (i.Speed or 1)

	local part = flashPart{
		Shape    = Enum.PartType.Cylinder,
		Size     = Vector3.new(0.2, i.Radius*2, i.Radius*2),
		CFrame   = cylCF(origin),
		Lifetime = dur + 0.1,
	}
	TS:Create(part, TweenInfo.new(dur, Enum.EasingStyle.Linear),
		{ CFrame = part.CFrame + i.Dir * (i.Range or 0) }):Play()
end


fx.RectInstant = function(i, caster)
	local origin, dir = rectOrigin(i, caster)
	local len   = i.Length or 0
	local cf    = rectCFFromOrigin(origin, dir, len)
	flashPart{
		Size         = Vector3.new(i.Width, 0.2, len),
		CFrame       = cf,
		Transparency = 0.35,
		Lifetime     = 0.25,
	}
end

fx.RectTelegraph = function(i, caster)
	local origin, dir = rectOrigin(i, caster)
	local len   = i.Length or 0
	local dur   = i.Duration or 0.6

	flashPart{
		Size         = Vector3.new(i.Width, 0.2, len),
		CFrame       = rectCFFromOrigin(origin, dir, len),
		Transparency = 0.85,
		Lifetime     = dur + 0.05,
	}

	local startLen = 0.1
	local fill = flashPart{
		Size     = Vector3.new(i.Width, 0.2, startLen),
		CFrame   = rectCFFromOrigin(origin, dir, startLen),
		Lifetime = dur + 0.05,
	}
	TS:Create(fill, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
		Size   = Vector3.new(i.Width, 0.2, len),
		CFrame = rectCFFromOrigin(origin, dir, len),
	}):Play()
end


fx.CylTelegraph = function(i, caster)
	fx.CylLocation(i, caster)
end


fx.ConeTelegraph = function(i, caster)
	local y      = anchorY(i, caster)
	local origin = lockY(i.Origin or Vector3.new(), y)
	local dir    = resolveDir(i.Dir)
	local full   = i.Range or 12
	local halfA  = (i.AngleRad or math.rad(60)) * 0.5
	local dur    = i.Duration or 0.6

	local finalWidth = 2 * full * math.tan(halfA)

	flashPart{
		Size         = Vector3.new(finalWidth, 0.2, full),
		CFrame       = rectCFFromOrigin(origin, dir, full),
		Transparency = 0.85,
		Lifetime     = dur + 0.05,
	}

	local startLen   = 0.1
	local startWidth = 2 * startLen * math.tan(halfA)
	local fill = flashPart{
		Size     = Vector3.new(startWidth, 0.2, startLen),
		CFrame   = rectCFFromOrigin(origin, dir, startLen),
		Lifetime = dur + 0.05,
	}
	TS:Create(fill, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
		Size   = Vector3.new(finalWidth, 0.2, full),
		CFrame = rectCFFromOrigin(origin, dir, full),
	}):Play()
end


fx.BeamStart = function(i, caster)
	local y      = anchorY(i, caster)
	local origin = lockY(i.Origin or Vector3.new(), y)
	local dir    = resolveDir(i.Dir)
	local dur    = i.Duration or 1.0
	local cf     = rectCFFromOrigin(origin, dir, i.Range or 0)
	flashPart{
		Size         = Vector3.new(i.Width or 4, 0.2, i.Range or 0),
		CFrame       = cf,
		Transparency = 0.4,
		Lifetime     = dur + 0.1,
	}
end
fx.BeamEnd = function(_) end


fx.SphStatic = function(i, caster)
	fx.CylStatic({ Centre = i.Centre, Radius = i.Radius }, caster)
end

fx.SphLocation = function(i, caster)
	fx.CylLocation({ Centre = i.Centre or i.Position, Radius = i.Radius, Duration = i.Duration }, caster)
end

fx.SphTween = function(i, caster)
	fx.CylTween({ Centre = i.Centre, Radius = i.Radius, Duration = i.Duration }, caster)
end

fx.SphProjectile = function(i, caster)
	fx.CylProjectile({ Origin = i.Origin, Dir = i.Dir, Radius = i.Radius, Range = i.Range, Speed = i.Speed }, caster)
end


fx.JumpLaunch = function(i, caster)
	local targetSource = i.Target or i.Position or i.Centre or Vector3.new()
	local y = groundYAt(targetSource) + VFX_Y_OFFSET
	local target = lockY(targetSource, y)
	local radius = math.max(0.1, tonumber(i.Radius) or 1)
	local duration = math.max(0.05, tonumber(i.Duration) or 0.05)


	flashPart{
		Shape        = Enum.PartType.Cylinder,
		Size         = Vector3.new(0.2, radius*2, radius*2),
		CFrame       = CFrame.new(target) * CFrame.Angles(0,0,math.rad(90)),
		Color        = Color3.new(1,1,0),
		Transparency = 0.85,
		Lifetime     = duration,
	}


	local inner = flashPart{
		Shape    = Enum.PartType.Cylinder,
		Size     = Vector3.new(0.2, 0.1, 0.1),
		CFrame   = CFrame.new(target) * CFrame.Angles(0,0,math.rad(90)),
		Color    = Color3.new(1,1,0),
		Lifetime = duration,
	}
	TS:Create(inner, TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Size = Vector3.new(0.2, radius*2, radius*2) }):Play()


	local localPlayer = Players.LocalPlayer
	if caster ~= localPlayer then
		local char = caster.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local now        = os.clock()
			local elapsed    = math.max(0, now - (i.LaunchTime or now))
			local totalTime  = i.Duration ~= 0 and i.Duration
				or ((i.Target - i.Start).Magnitude / (i.Speed or 1))
			local remain     = math.clamp(totalTime - elapsed, 0, totalTime)

			if remain > 0 then
				TS:Create(hrp, TweenInfo.new(remain, Enum.EasingStyle.Linear),
					{ CFrame = CFrame.new(target) }):Play()
			else
				hrp.CFrame = CFrame.new(target)
			end
		end
	end
end


LocalAbilityVisual.Event:Connect(function(tag, info)
	local f = fx[tag]
	if f then pcall(f, info, Players.LocalPlayer) end
end)
