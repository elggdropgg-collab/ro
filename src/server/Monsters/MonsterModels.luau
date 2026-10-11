-- Procedural monster rigs. Joints that the client animates are Motor6Ds with fixed names:
-- Scarecrow: Neck, LeftHand, RightHand.  Husk: Neck, Jaw, LegFL, LegFR, LegBL, LegBR.
--
-- A custom model placed at ReplicatedStorage.Assets.Monsters.<Kind> replaces the procedural
-- one, as long as it has a HumanoidRootPart and a Humanoid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterModels = {}

export type Rig = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	GripHeight: number,
	GripDistance: number,
	GripTilt: number,
}

local function part(
	parent: Instance,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	props: { [string]: any }?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function motor(name: string, part0: BasePart, part1: BasePart, jointWorld: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(jointWorld)
	m.C1 = part1.CFrame:ToObjectSpace(jointWorld)
	m.Parent = part0
	return m
end

local function newRig(name: string, rootHeight: number, hipHeight: number): (Model, Part, Humanoid)
	local model = Instance.new("Model")
	model.Name = name
	local root = part(model, Vector3.new(2, 2, 1), Color3.new(), Enum.Material.SmoothPlastic, {
		Name = "HumanoidRootPart",
		Transparency = 1,
		CanCollide = true,
		Massless = false,
	})
	root.CFrame = CFrame.new(0, rootHeight, 0)
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = hipHeight
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	return model, root, humanoid
end

local function scarecrow(): Rig
	local model, root, humanoid = newRig("Scarecrow", 3, 2)
	local base = root.CFrame
	local coat = Color3.fromRGB(52, 42, 36)
	local burlap = Color3.fromRGB(176, 154, 112)
	local wood = Color3.fromRGB(64, 50, 38)
	local straw = Color3.fromRGB(196, 168, 96)

	local function at(offset: CFrame): CFrame
		return base * offset
	end

	local pole = part(model, Vector3.new(0.55, 9, 0.55), wood, Enum.Material.Wood, { Name = "Pole" })
	pole.CFrame = at(CFrame.new(0, 1.5, 0.25))
	weld(root, pole)

	local torso = part(model, Vector3.new(2.4, 3.6, 1.3), coat, Enum.Material.Fabric, { Name = "Torso" })
	torso.CFrame = at(CFrame.new(0, 2.8, 0))
	weld(root, torso)
	for i = 1, 6 do
		local strip = part(
			model,
			Vector3.new(0.35, Random.new(i):NextNumber(1, 2.2), 0.08),
			coat:Lerp(Color3.new(), 0.3),
			Enum.Material.Fabric
		)
		strip.CFrame = at(CFrame.new(-1.05 + (i - 1) * 0.42, 0.4, -0.6) * CFrame.Angles(0, 0, (i % 2 - 0.5) * 0.25))
		weld(torso, strip)
	end

	local bar = part(model, Vector3.new(7.6, 0.45, 0.45), wood, Enum.Material.Wood, { Name = "Crossbar" })
	bar.CFrame = at(CFrame.new(0, 4.3, 0.25))
	weld(torso, bar)

	local hands = {}
	for _, side in { -1, 1 } do
		local sleeve = part(model, Vector3.new(2.7, 1, 1), coat, Enum.Material.Fabric)
		sleeve.CFrame = at(CFrame.new(side * 2.45, 4.15, 0) * CFrame.Angles(0, 0, side * -0.08))
		weld(torso, sleeve)

		local palm = part(
			model,
			Vector3.new(0.5, 0.5, 0.5),
			straw,
			Enum.Material.Grass,
			{ Name = if side < 0 then "LeftPalm" else "RightPalm" }
		)
		palm.CFrame = at(CFrame.new(side * 3.95, 4, 0))
		for i = 1, 4 do
			local tuft =
				part(model, Vector3.new(0.14, Random.new(i * 7):NextNumber(0.9, 1.5), 0.14), straw, Enum.Material.Grass)
			tuft.CFrame = palm.CFrame * CFrame.new(side * 0.1, -0.6, (i - 2.5) * 0.15) * CFrame.Angles(0, 0, side * 0.3)
			weld(palm, tuft)
		end
		-- Long twig fingers
		for i = 1, 3 do
			local finger = part(model, Vector3.new(0.12, 2.1, 0.12), Color3.fromRGB(30, 24, 20), Enum.Material.Wood)
			finger.CFrame = palm.CFrame
				* CFrame.new(side * 0.35, -0.9, (i - 2) * 0.22)
				* CFrame.Angles((i - 2) * 0.2, 0, side * 0.55)
			weld(palm, finger)
		end
		table.insert(hands, { palm = palm, sleeve = sleeve, side = side })
	end

	local rope = part(model, Vector3.new(0.4, 1, 1), Color3.fromRGB(120, 100, 70), Enum.Material.Fabric, {
		Shape = Enum.PartType.Cylinder,
	})
	rope.CFrame = at(CFrame.new(0, 4.85, 0) * CFrame.Angles(0, 0, math.pi / 2))
	weld(torso, rope)

	local head = part(model, Vector3.new(2.3, 2.6, 2.3), burlap, Enum.Material.Fabric, { Name = "Head" })
	head.CFrame = at(CFrame.new(0, 6.35, 0))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = head
	for _, side in { -1, 1 } do
		local hole = part(model, Vector3.new(0.42, 0.52, 0.12), Color3.fromRGB(8, 6, 6), Enum.Material.SmoothPlastic)
		hole.CFrame = head.CFrame * CFrame.new(side * 0.45, 0.25, -1.08) * CFrame.Angles(0, side * 0.25, 0)
		weld(head, hole)
		local pupil = part(model, Vector3.new(0.1, 0.1, 0.05), Color3.fromRGB(255, 40, 30), Enum.Material.Neon)
		pupil.CFrame = hole.CFrame * CFrame.new(0, -0.05, -0.05)
		weld(head, pupil)
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 50, 40)
	glow.Brightness = 0.5
	glow.Range = 5
	glow.Parent = head
	-- Stitched grin, far too wide
	for i = -4, 4 do
		local stitch = part(model, Vector3.new(0.08, 0.3, 0.06), Color3.fromRGB(20, 14, 12), Enum.Material.Fabric)
		stitch.CFrame = head.CFrame
			* CFrame.new(i * 0.17, -0.42 + math.abs(i) * 0.05, -1.12 + math.abs(i) * 0.03)
			* CFrame.Angles(0, i * 0.08, 0)
		weld(head, stitch)
	end
	local seam = part(model, Vector3.new(1.55, 0.05, 0.05), Color3.fromRGB(20, 14, 12), Enum.Material.Fabric)
	seam.CFrame = head.CFrame * CFrame.new(0, -0.32, -1.1)
	weld(head, seam)
	local brim = part(model, Vector3.new(0.18, 3.9, 3.9), Color3.fromRGB(44, 36, 30), Enum.Material.Fabric, {
		Shape = Enum.PartType.Cylinder,
	})
	brim.CFrame = head.CFrame * CFrame.new(0, 1.05, 0) * CFrame.Angles(0.12, 0, math.pi / 2)
	weld(head, brim)
	local crown = part(model, Vector3.new(1.3, 2, 2), Color3.fromRGB(44, 36, 30), Enum.Material.Fabric, {
		Shape = Enum.PartType.Cylinder,
	})
	crown.CFrame = head.CFrame * CFrame.new(0, 1.7, 0.1) * CFrame.Angles(0.12, 0, math.pi / 2)
	weld(head, crown)

	motor("Neck", torso, head, at(CFrame.new(0, 5, 0)))
	for _, hand in hands do
		motor(if hand.side < 0 then "LeftHand" else "RightHand", hand.sleeve, hand.palm, hand.palm.CFrame)
	end

	return { Model = model, Root = root, Humanoid = humanoid, GripHeight = 1.6, GripDistance = 2.4, GripTilt = -20 }
end

local function husk(): Rig
	local model, root, humanoid = newRig("Husk", 1.6, 0.6)
	local base = root.CFrame
	local skin = Color3.fromRGB(132, 114, 100)
	local dark = Color3.fromRGB(70, 52, 46)
	local straw = Color3.fromRGB(176, 148, 82)
	local bone = Color3.fromRGB(220, 206, 180)

	local torso = part(model, Vector3.new(1.5, 0.9, 3.4), skin, Enum.Material.Plastic, { Name = "Torso" })
	torso.CFrame = base * CFrame.new(0, 0.1, 0)
	weld(root, torso)
	for i = 0, 6 do
		local bump = part(model, Vector3.new(0.3, 0.22, 0.3), skin:Lerp(bone, 0.4), Enum.Material.Plastic)
		bump.CFrame = torso.CFrame * CFrame.new(0, 0.5, -1.4 + i * 0.46)
		weld(torso, bump)
	end
	for i = 0, 4 do
		for _, side in { -1, 1 } do
			local rib = part(model, Vector3.new(0.06, 0.7, 0.12), dark, Enum.Material.Plastic)
			rib.CFrame = torso.CFrame * CFrame.new(side * 0.76, 0, -1 + i * 0.42) * CFrame.Angles(0, 0, side * 0.2)
			weld(torso, rib)
		end
	end
	local rng = Random.new(7)
	for _ = 1, 10 do
		local strand = part(model, Vector3.new(0.08, rng:NextNumber(0.8, 1.8), 0.08), straw, Enum.Material.Grass)
		strand.CFrame = torso.CFrame
			* CFrame.new(rng:NextNumber(-0.6, 0.6), 0.9, rng:NextNumber(-1.4, 1.6))
			* CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
		weld(torso, strand)
	end

	local head = part(model, Vector3.new(0.9, 0.75, 1.5), skin, Enum.Material.Plastic, { Name = "Head" })
	head.CFrame = torso.CFrame * CFrame.new(0, 0.2, -2.3)
	local jaw = part(model, Vector3.new(0.8, 0.3, 1.4), dark, Enum.Material.Plastic, { Name = "LowerJaw" })
	jaw.CFrame = head.CFrame * CFrame.new(0, -0.5, -0.05)
	for i = -2, 2 do
		local tooth = part(model, Vector3.new(0.08, 0.22, 0.08), bone, Enum.Material.SmoothPlastic)
		tooth.CFrame = head.CFrame * CFrame.new(i * 0.16, -0.45, -0.7)
		weld(head, tooth)
		local lower = part(model, Vector3.new(0.08, 0.2, 0.08), bone, Enum.Material.SmoothPlastic)
		lower.CFrame = jaw.CFrame * CFrame.new(i * 0.15, 0.22, -0.62)
		weld(jaw, lower)
	end
	motor("Neck", torso, head, torso.CFrame * CFrame.new(0, 0.2, -1.6))
	motor("Jaw", head, jaw, head.CFrame * CFrame.new(0, -0.35, 0.6))

	local legs = { LegFL = { -1, -1.2 }, LegFR = { 1, -1.2 }, LegBL = { -1, 1.2 }, LegBR = { 1, 1.2 } }
	for name, spec in legs do
		local side, z = spec[1], spec[2]
		local shoulder = torso.CFrame * CFrame.new(side * 0.8, 0.1, z)
		local upper = part(model, Vector3.new(0.32, 1.6, 0.32), skin, Enum.Material.Plastic, { Name = name .. "Upper" })
		upper.CFrame = shoulder * CFrame.Angles(0, 0, side * 1.05) * CFrame.new(0, 0.8, 0)
		local elbow = upper.CFrame * CFrame.new(0, 0.8, 0)
		local lower = part(model, Vector3.new(0.26, 1.9, 0.26), skin:Lerp(dark, 0.3), Enum.Material.Plastic)
		lower.CFrame = CFrame.new(elbow.Position) * CFrame.Angles(0, 0, side * -0.35) * CFrame.new(0, -0.95, 0)
		weld(upper, lower)
		local claw = part(model, Vector3.new(0.12, 0.5, 0.12), bone, Enum.Material.SmoothPlastic)
		claw.CFrame = lower.CFrame * CFrame.new(0, -1.05, -0.12) * CFrame.Angles(-0.6, 0, 0)
		weld(lower, claw)
		motor(name, torso, upper, shoulder)
	end

	return { Model = model, Root = root, Humanoid = humanoid, GripHeight = -0.8, GripDistance = 2.6, GripTilt = -75 }
end

local builders: { [string]: () -> Rig } = {
	Scarecrow = scarecrow,
	Husk = husk,
}

function MonsterModels.build(kind: string): Rig
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("Monsters") and assets.Monsters:FindFirstChild(kind)
	if
		custom
		and custom:IsA("Model")
		and custom:FindFirstChild("HumanoidRootPart")
		and custom:FindFirstChildOfClass("Humanoid")
	then
		local model = custom:Clone()
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		model.PrimaryPart = root
		return {
			Model = model,
			Root = root,
			Humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
			GripHeight = model:GetAttribute("GripHeight") or 0,
			GripDistance = model:GetAttribute("GripDistance") or 2.6,
			GripTilt = model:GetAttribute("GripTilt") or -20,
		}
	end
	local builder = builders[kind]
	assert(builder, "No model for monster " .. kind)
	return builder()
end

return MonsterModels
