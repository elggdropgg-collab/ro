-- Builds a soldier: R15 body from a HumanoidDescription plus helmet, vest, pack and a rifle
-- with an underbarrel flashlight. Super soldiers wear black with glowing visors.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SquadConfig = require(ReplicatedStorage.Shared.Config.Squad)

local SoldierModel = {}

export type Rig = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Muzzle: Attachment,
	Light: SpotLight,
	Gunshot: Sound,
}

local function gear(
	parent: Instance,
	attachTo: BasePart,
	offset: CFrame,
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
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.CFrame = attachTo.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attachTo
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p
end

local function fallbackBody(): Model
	-- Used only if the avatar service is unavailable (e.g. offline Studio).
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Size = Vector3.new(2, 2.4, 1)
	torso.CFrame = root.CFrame * CFrame.new(0, 0.5, 0)
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.CFrame = root.CFrame * CFrame.new(0, 2.3, 0)
	head.Parent = model
	local hand = Instance.new("Part")
	hand.Name = "RightHand"
	hand.Size = Vector3.new(0.6, 0.6, 0.6)
	hand.CFrame = root.CFrame * CFrame.new(1.2, 0, -0.5)
	hand.Parent = model
	for _, p in { torso, head, hand } do
		p.CanCollide = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

function SoldierModel.build(kind: string, displayName: string, rng: Random): Rig
	local outfit = SquadConfig.Outfit
	local super = kind == "Super"
	local uniform = if super then outfit.SuperUniform else outfit.Uniform
	local uniformDark = if super then outfit.SuperUniform:Lerp(Color3.new(), 0.3) else outfit.UniformDark
	local skin = outfit.SkinTones[rng:NextInteger(1, #outfit.SkinTones)]

	local description = Instance.new("HumanoidDescription")
	description.HeadColor = skin
	description.TorsoColor = uniform
	description.LeftArmColor = uniform
	description.RightArmColor = uniform
	description.LeftLegColor = uniformDark
	description.RightLegColor = uniformDark
	if outfit.Shirt ~= 0 and not super then
		description.Shirt = outfit.Shirt
	end
	if outfit.Pants ~= 0 and not super then
		description.Pants = outfit.Pants
	end

	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	local model: Model = if ok and result then result else fallbackBody()
	model.Name = displayName
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	local torso = (model:FindFirstChild("UpperTorso") or root) :: BasePart
	local hand = (model:FindFirstChild("RightHand") or torso) :: BasePart

	-- Helmet
	local helmetColor = if super then Color3.fromRGB(20, 20, 22) else uniform:Lerp(Color3.new(), 0.15)
	local helmet =
		gear(model, head, CFrame.new(0, 0.42, 0.05), Vector3.new(1.35, 0.75, 1.45), helmetColor, Enum.Material.Plastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = helmet
	gear(model, head, CFrame.new(0, 0.2, -0.05), Vector3.new(1.4, 0.12, 1.5), helmetColor, Enum.Material.Plastic)
	if super then
		gear(
			model,
			head,
			CFrame.new(0, 0.12, -0.62),
			Vector3.new(1.05, 0.22, 0.08),
			Color3.fromRGB(80, 220, 255),
			Enum.Material.Neon
		)
	end

	-- Plate carrier, pouches, pack
	gear(
		model,
		torso,
		CFrame.new(0, 0, 0),
		torso.Size + Vector3.new(0.25, -0.2, 0.3),
		uniformDark,
		Enum.Material.Fabric
	)
	for _, x in { -0.55, 0, 0.55 } do
		gear(
			model,
			torso,
			CFrame.new(x, -0.45, -0.68),
			Vector3.new(0.42, 0.5, 0.25),
			uniformDark:Lerp(Color3.new(), 0.2),
			Enum.Material.Fabric
		)
	end
	gear(model, torso, CFrame.new(0, 0.1, 0.8), Vector3.new(1.4, 1.5, 0.6), uniformDark, Enum.Material.Fabric)
	local radio = gear(
		model,
		torso,
		CFrame.new(0.55, 0.75, 0.75),
		Vector3.new(0.3, 0.6, 0.3),
		Color3.fromRGB(30, 30, 30),
		Enum.Material.Plastic
	)
	gear(
		model,
		radio,
		CFrame.new(0, 0.9, 0),
		Vector3.new(0.05, 1.3, 0.05),
		Color3.fromRGB(20, 20, 20),
		Enum.Material.Plastic
	)

	-- Rifle along the hand's forward axis
	local metal = Color3.fromRGB(34, 34, 36)
	local body = gear(model, hand, CFrame.new(0, -0.25, -0.7), Vector3.new(0.22, 0.34, 2.3), metal, Enum.Material.Metal)
	body.Name = "Rifle"
	gear(model, body, CFrame.new(0, 0.02, -1.6), Vector3.new(0.1, 0.1, 1.1), metal, Enum.Material.Metal)
	gear(model, body, CFrame.new(0, -0.38, -0.2), Vector3.new(0.16, 0.6, 0.32), metal, Enum.Material.Metal)
	gear(
		model,
		body,
		CFrame.new(0, -0.1, 1.3),
		Vector3.new(0.18, 0.42, 0.7),
		Color3.fromRGB(60, 48, 36),
		Enum.Material.Wood
	)
	local lamp =
		gear(model, body, CFrame.new(0, -0.2, -1.05), Vector3.new(0.16, 0.16, 0.35), metal, Enum.Material.Metal)

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.02, -2.2)
	muzzle.Parent = body

	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 38
	light.Range = 55
	light.Brightness = if super then 4 else 2.6
	light.Shadows = true
	light.Color = if super then Color3.fromRGB(200, 235, 255) else Color3.fromRGB(255, 238, 210)
	light.Enabled = false
	light.Parent = lamp

	local gunshot = Instance.new("Sound")
	gunshot.Name = "Gunshot"
	gunshot.RollOffMinDistance = 12
	gunshot.RollOffMaxDistance = 400
	gunshot.Volume = 0.9
	gunshot.Parent = body

	-- Name tag
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(160, 26)
	tag.StudsOffset = Vector3.new(0, 2.8, 0)
	tag.MaxDistance = 45
	tag.LightInfluence = 0
	tag.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = displayName
	label.TextColor3 = if super then Color3.fromRGB(150, 230, 255) else Color3.fromRGB(220, 214, 190)
	label.TextStrokeTransparency = 0.4
	label.FontFace = Font.fromEnum(Enum.Font.RobotoMono)
	label.TextScaled = true
	label.Parent = tag
	tag.Parent = head

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Squad"
		end
	end

	return {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Muzzle = muzzle,
		Light = light,
		Gunshot = gunshot,
	}
end

return SoldierModel
