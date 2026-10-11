-- Procedural guns: the players' pistol (a Tool) and the soldiers' assault rifle.
--
-- Both are built in "grip space": origin at the palm, -Z along the barrel, +Y up. That is the
-- frame of an R15 RightGripAttachment, so a gun welded there points forward once the arm is raised.
-- Each gun hangs off an invisible anchor part sitting exactly at the grip origin.
--
-- Art can replace them: ReplicatedStorage.Assets.Weapons.Pistol (a Tool with a Handle and a
-- "Muzzle" attachment) and ReplicatedStorage.Assets.Weapons.Rifle (a Model whose PrimaryPart sits
-- at the grip, with a "Muzzle" attachment and optionally a "Lamp" part).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunModels = {}

export type Rifle = {
	Model: Model,
	Muzzle: Attachment,
	Lamp: BasePart,
}

local POLYMER = Color3.fromRGB(28, 28, 30)
local STEEL = Color3.fromRGB(48, 48, 52)
local BLUED = Color3.fromRGB(30, 31, 34)
local WOOD = Color3.fromRGB(96, 58, 32)

local function custom(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weapons = assets and assets:FindFirstChild("Weapons")
	return weapons and weapons:FindFirstChild(name)
end

local function anchor(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = CFrame.new()
	p.Parent = parent
	return p
end

local function piece(
	parent: Instance,
	base: BasePart,
	offset: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = size.Magnitude > 0.4
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = base.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p
end

local function tilt(x: number, y: number, z: number, degrees: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(degrees), 0, 0)
end

-- Pistol ------------------------------------------------------------------------

function GunModels.pistol(): Tool
	local art = custom("Pistol")
	if art and art:IsA("Tool") and art:FindFirstChild("Handle") then
		local tool = art:Clone()
		tool.Name = "Pistol"
		tool.CanBeDropped = false
		tool.ManualActivationOnly = true
		return tool
	end

	local tool = Instance.new("Tool")
	tool.Name = "Pistol"
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.RequiresHandle = true
	local handle = anchor("Handle", tool)

	-- Grip rakes back like a real handgun
	piece(tool, handle, tilt(0, 0, 0.05, -14), Vector3.new(0.17, 0.46, 0.25), POLYMER, Enum.Material.Plastic)
	piece(tool, handle, tilt(0, -0.24, 0.11, -14), Vector3.new(0.19, 0.05, 0.28), POLYMER, Enum.Material.Plastic)
	-- Frame, slide, barrel
	piece(tool, handle, CFrame.new(0, 0.25, -0.2), Vector3.new(0.17, 0.12, 0.72), POLYMER, Enum.Material.Plastic)
	local slide =
		piece(tool, handle, CFrame.new(0, 0.39, -0.19), Vector3.new(0.19, 0.17, 0.86), STEEL, Enum.Material.Metal)
	slide.Name = "Slide"
	piece(tool, handle, CFrame.new(0, 0.4, -0.63), Vector3.new(0.09, 0.09, 0.04), BLUED, Enum.Material.Metal)
	piece(tool, handle, CFrame.new(0, 0.4, 0.1), Vector3.new(0.2, 0.12, 0.2), BLUED, Enum.Material.Metal)
	-- Sights
	piece(tool, handle, CFrame.new(0, 0.49, 0.19), Vector3.new(0.13, 0.04, 0.04), BLUED, Enum.Material.Metal)
	piece(tool, handle, CFrame.new(0, 0.49, -0.57), Vector3.new(0.04, 0.04, 0.05), BLUED, Enum.Material.Metal)
	-- Trigger guard and trigger
	piece(tool, handle, CFrame.new(0, 0.11, -0.22), Vector3.new(0.06, 0.03, 0.26), POLYMER, Enum.Material.Plastic)
	piece(tool, handle, CFrame.new(0, 0.16, -0.34), Vector3.new(0.06, 0.12, 0.03), POLYMER, Enum.Material.Plastic)
	piece(tool, handle, tilt(0, 0.17, -0.17, 10), Vector3.new(0.03, 0.09, 0.03), BLUED, Enum.Material.Metal)

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.4, -0.67)
	muzzle.Parent = handle

	return tool
end

-- Rifle -------------------------------------------------------------------------

local function customRifle(): Rifle?
	local art = custom("Rifle")
	if not (art and art:IsA("Model") and art.PrimaryPart and art:FindFirstChild("Muzzle", true)) then
		return nil
	end
	local model = art:Clone()
	local root = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	local lamp = model:FindFirstChild("Lamp", true)
	return {
		Model = model,
		Muzzle = model:FindFirstChild("Muzzle", true) :: Attachment,
		Lamp = if lamp and lamp:IsA("BasePart") then lamp else root,
	}
end

-- AK-pattern rifle. `super` gets an all-black finish and a glowing reflex sight.
function GunModels.rifle(super: boolean): Rifle
	local art = customRifle()
	if art then
		return art
	end

	local model = Instance.new("Model")
	model.Name = "Rifle"
	local root = anchor("Grip", model)
	model.PrimaryPart = root
	local metal = if super then POLYMER else BLUED
	local furniture = if super then POLYMER else WOOD
	local furnitureMaterial = if super then Enum.Material.Plastic else Enum.Material.Wood

	local function at(offset: CFrame, size: Vector3, color: Color3, material: Enum.Material): Part
		return piece(model, root, offset, size, color, material)
	end

	-- Pistol grip and receiver
	at(tilt(0, 0, 0.02, -16), Vector3.new(0.14, 0.34, 0.17), furniture, furnitureMaterial)
	local receiver = at(CFrame.new(0, 0.3, -0.25), Vector3.new(0.2, 0.3, 1.1), metal, Enum.Material.Metal)
	receiver.Name = "Receiver"
	-- Dust cover, barrel, gas tube, muzzle brake, front sight
	at(CFrame.new(0, 0.47, -0.2), Vector3.new(0.18, 0.05, 0.95), metal, Enum.Material.Metal)
	at(CFrame.new(0, 0.36, -1.3), Vector3.new(0.08, 0.08, 0.95), BLUED, Enum.Material.Metal)
	at(CFrame.new(0, 0.47, -1.05), Vector3.new(0.08, 0.08, 0.6), metal, Enum.Material.Metal)
	at(CFrame.new(0, 0.36, -1.82), Vector3.new(0.12, 0.12, 0.16), BLUED, Enum.Material.Metal)
	at(CFrame.new(0, 0.5, -1.62), Vector3.new(0.05, 0.13, 0.05), BLUED, Enum.Material.Metal)
	-- Handguard
	at(CFrame.new(0, 0.33, -1.0), Vector3.new(0.21, 0.2, 0.58), furniture, furnitureMaterial)
	at(CFrame.new(0, 0.47, -1.0), Vector3.new(0.13, 0.08, 0.5), furniture, furnitureMaterial)
	-- Curved magazine
	at(tilt(0, 0.05, -0.5, 12), Vector3.new(0.14, 0.34, 0.22), metal, Enum.Material.Metal)
	at(tilt(0, -0.22, -0.43, 28), Vector3.new(0.14, 0.26, 0.21), metal, Enum.Material.Metal)
	-- Stock
	at(tilt(0, 0.22, 0.62, -7), Vector3.new(0.16, 0.24, 0.78), furniture, furnitureMaterial)
	at(tilt(0, 0.17, 1.02, -7), Vector3.new(0.17, 0.34, 0.05), POLYMER, Enum.Material.Rubber)
	-- Trigger guard, rear sight block
	at(CFrame.new(0, 0.12, -0.16), Vector3.new(0.05, 0.03, 0.26), metal, Enum.Material.Metal)
	at(CFrame.new(0, 0.52, -0.62), Vector3.new(0.1, 0.06, 0.12), metal, Enum.Material.Metal)

	if super then
		at(CFrame.new(0, 0.58, -0.25), Vector3.new(0.14, 0.14, 0.24), POLYMER, Enum.Material.Metal)
		at(CFrame.new(0, 0.6, -0.37), Vector3.new(0.08, 0.06, 0.02), Color3.fromRGB(80, 220, 255), Enum.Material.Neon)
	end

	-- Underbarrel flashlight; its front face points down the barrel
	local lamp = at(CFrame.new(0, 0.17, -1.1), Vector3.new(0.12, 0.12, 0.32), POLYMER, Enum.Material.Metal)
	lamp.Name = "Lamp"
	at(CFrame.new(0, 0.17, -1.265), Vector3.new(0.1, 0.1, 0.01), Color3.fromRGB(255, 240, 210), Enum.Material.Neon)

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.36, -1.92)
	muzzle.Parent = root

	return { Model = model, Muzzle = muzzle, Lamp = lamp }
end

-- Welds a rifle into a character's right hand, pointing along the grip.
function GunModels.mount(rifle: Rifle, character: Model, hand: BasePart)
	local gripAttachment = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local gripFrame = if gripAttachment then hand.CFrame * gripAttachment.CFrame else hand.CFrame
	local model = rifle.Model
	local root = model.PrimaryPart :: BasePart
	model:PivotTo(gripFrame * root.CFrame:ToObjectSpace(model:GetPivot()))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = root
	weld.Parent = root
	model.Parent = character
end

return GunModels
