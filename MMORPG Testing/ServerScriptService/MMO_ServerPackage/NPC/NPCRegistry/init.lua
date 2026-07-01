--[[
Name: NPCRegistry
Class: ModuleScript
Original path: game.ServerScriptService.MMO_ServerPackage.NPC.NPCRegistry
Exported from: MMORPG Testing
Original comments: removed
Children: 0
Properties: Archivable=true, LinkedSource=""
Services: ReplicatedStorage
Functions: createPart, ensureAttachment, ensureMotor, NPCRegistry.BuildR6, NPCRegistry.EnsureR6, NPCRegistry.GetRig
Clean source lines: 210
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPCRegistry = {}


local RigFolder = ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):FindFirstChild("Assets")
	and ReplicatedStorage:WaitForChild("MMO_ReplicatedPackage"):WaitForChild("Assets"):FindFirstChild("NPCRigs")


NPCRegistry.Enemies = {
	DummyWanderer = {

		RigPath = RigFolder and RigFolder:FindFirstChild("Dummy"),

		BuildSpec = {
			Colors = {
				Head  = Color3.fromRGB(255, 226, 155),
				Torso = Color3.fromRGB(99,  155, 255),
				Arms  = Color3.fromRGB(255, 226, 155),
				Legs  = Color3.fromRGB(80,  80,  80),
			}
		},
	},

	TownGuard = {
		RigPath = RigFolder and RigFolder:FindFirstChild("Guard"),
		BuildSpec = {
			Colors = {
				Head  = Color3.fromRGB(255, 226, 155),
				Torso = Color3.fromRGB(40,  80,  140),
				Arms  = Color3.fromRGB(255, 226, 155),
				Legs  = Color3.fromRGB(50,  50,  50),
			}
		},
	},
}


local PART_DEF = {
	Head   = { size = Vector3.new(2, 1, 1), offset = Vector3.new(0, 2.5, 0) },
	Torso  = { size = Vector3.new(2, 2, 1), offset = Vector3.new(0, 1.5, 0) },
	["Left Arm"]  = { size = Vector3.new(1, 2, 1), offset = Vector3.new(-1.5, 1.5, 0) },
	["Right Arm"] = { size = Vector3.new(1, 2, 1), offset = Vector3.new( 1.5, 1.5, 0) },
	["Left Leg"]  = { size = Vector3.new(1, 2, 1), offset = Vector3.new(-0.5, 0.5, 0) },
	["Right Leg"] = { size = Vector3.new(1, 2, 1), offset = Vector3.new( 0.5, 0.5, 0) },
	HumanoidRootPart = { size = Vector3.new(2, 2, 1), offset = Vector3.new(0, 1.5, 0) },
}

local function createPart(name, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = PART_DEF[name].size
	p.Anchored, p.CanCollide = false, true
	p.Massless = false
	if color then p.Color = color end
	return p
end

local function ensureAttachment(parent: BasePart, name: string, cframe: CFrame)
	local a = parent:FindFirstChild(name) :: Attachment
	if not a then
		a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = cframe or CFrame.new()
		a.Parent = parent
	end
	return a
end

local function ensureMotor(parent: Instance, name: string, part0: BasePart, part1: BasePart)
	local m = parent:FindFirstChild(name) :: Motor6D
	if not m then
		m = Instance.new("Motor6D")
		m.Name = name
		m.Parent = parent
	end
	m.Part0 = part0
	m.Part1 = part1

	m.C0 = CFrame.new()
	m.C1 = part1.CFrame:ToObjectSpace(part0.CFrame)
	return m
end


function NPCRegistry.BuildR6(spec, origin: CFrame?)
	local model = Instance.new("Model")
	model.Name = "R6NPC"

	local colors = (spec and spec.Colors) or {}
	local baseCF = origin or CFrame.new()


	local parts = {}
	for name, def in pairs(PART_DEF) do
		local c = colors[name] or colors.Arms or colors.Legs or colors.Torso
		local p = createPart(name, c)
		p.CFrame = baseCF + def.offset
		p.Parent = model
		parts[name] = p
	end


	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.Parent = model
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator", hum)
	end


	local Torso = parts.Torso
	local HRP   = parts.HumanoidRootPart
	model.PrimaryPart = HRP

	ensureMotor(Torso, "Right Shoulder", Torso, parts["Right Arm"])
	ensureMotor(Torso, "Left Shoulder",  Torso, parts["Left Arm"])
	ensureMotor(Torso, "Right Hip",      Torso, parts["Right Leg"])
	ensureMotor(Torso, "Left Hip",       Torso, parts["Left Leg"])
	ensureMotor(Torso, "Neck",           Torso, parts.Head)
	ensureMotor(HRP,   "RootJoint",      HRP,   Torso)


	ensureAttachment(HRP,  "RootAttachment",   CFrame.new())
	ensureAttachment(Torso,"ChestAttachment",  CFrame.new())
	ensureAttachment(parts.Head, "FaceFrontAttachment", CFrame.new(0, 0, -0.5))
	ensureAttachment(parts.Head, "HatAttachment",       CFrame.new(0, 0.5, 0))
	ensureAttachment(parts["Right Arm"], "RightGripAttachment", CFrame.new(0, -1, 0))
	ensureAttachment(parts["Left Arm"],  "LeftGripAttachment",  CFrame.new(0, -1, 0))

	return model
end


function NPCRegistry.EnsureR6(model: Model)

	local got = {}
	for name in pairs(PART_DEF) do
		local p = model:FindFirstChild(name) :: BasePart
		if not p then
			p = createPart(name)
			p.CFrame = (model.PrimaryPart and model.PrimaryPart.CFrame) or CFrame.new()
			p.Parent = model
		end
		got[name] = p
	end


	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		hum = Instance.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R6
		hum.Parent = model
	else
		hum.RigType = Enum.HumanoidRigType.R6
	end
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator", hum)
	end


	if not model.PrimaryPart then
		model.PrimaryPart = got.HumanoidRootPart
	end


	local torsoCF = got.Torso.CFrame
	for name, def in pairs(PART_DEF) do
		got[name].CFrame = torsoCF + def.offset
	end


	ensureMotor(got.Torso, "Right Shoulder", got.Torso, got["Right Arm"])
	ensureMotor(got.Torso, "Left Shoulder",  got.Torso, got["Left Arm"])
	ensureMotor(got.Torso, "Right Hip",      got.Torso, got["Right Leg"])
	ensureMotor(got.Torso, "Left Hip",       got.Torso, got["Left Leg"])
	ensureMotor(got.Torso, "Neck",           got.Torso, got.Head)
	ensureMotor(got.HumanoidRootPart, "RootJoint", got.HumanoidRootPart, got.Torso)


	ensureAttachment(got.HumanoidRootPart, "RootAttachment", CFrame.new())
	ensureAttachment(got.Torso, "ChestAttachment", CFrame.new())
	ensureAttachment(got.Head,  "FaceFrontAttachment", CFrame.new(0, 0, -0.5))
	ensureAttachment(got.Head,  "HatAttachment",       CFrame.new(0, 0.5, 0))
	ensureAttachment(got["Right Arm"], "RightGripAttachment", CFrame.new(0, -1, 0))
	ensureAttachment(got["Left Arm"],  "LeftGripAttachment",  CFrame.new(0, -1, 0))

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CanQuery = true end
	end
end


function NPCRegistry.GetRig(name: string, originCF: CFrame?)
	local def = NPCRegistry.Enemies[name]
	assert(def, ("Unknown enemy '%s'"):format(tostring(name)))

	local model
	if def.RigPath and def.RigPath.Parent then
		model = def.RigPath:Clone()
	else
		model = NPCRegistry.BuildR6(def.BuildSpec, originCF)
	end

	NPCRegistry.EnsureR6(model)
	return model
end

return NPCRegistry
