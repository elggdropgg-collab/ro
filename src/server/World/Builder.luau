-- Procedural building blocks used by every station generator.
-- Everything is anchored. Decorative parts do not take part in physics queries.

local Builder = {}

Builder.Palette = {
	Wood = Color3.fromRGB(92, 70, 52),
	WoodDark = Color3.fromRGB(58, 44, 34),
	WoodPale = Color3.fromRGB(140, 118, 92),
	Plaster = Color3.fromRGB(176, 166, 148),
	Brick = Color3.fromRGB(122, 64, 50),
	Roof = Color3.fromRGB(66, 52, 46),
	RustMetal = Color3.fromRGB(110, 70, 48),
	Metal = Color3.fromRGB(88, 92, 96),
	MetalDark = Color3.fromRGB(46, 48, 52),
	Concrete = Color3.fromRGB(118, 116, 110),
	ConcreteDark = Color3.fromRGB(72, 70, 66),
	Hay = Color3.fromRGB(196, 164, 92),
	Wheat = Color3.fromRGB(188, 152, 78),
	WheatLight = Color3.fromRGB(214, 182, 106),
	WheatDark = Color3.fromRGB(150, 116, 58),
	Cloth = Color3.fromRGB(96, 84, 70),
	Glass = Color3.fromRGB(150, 170, 176),
	Sandbag = Color3.fromRGB(140, 124, 94),
	Military = Color3.fromRGB(70, 78, 56),
}

type Props = { [string]: any }

local function apply(instance: Instance, props: Props?)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
end

function Builder.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Builder.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Builder.part(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	props: Props?
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	apply(part, props)
	part.Parent = parent
	return part
end

-- Decorative detail: no collisions, no raycasts, no touch events.
function Builder.detail(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	props: Props?
): Part
	local part = Builder.part(parent, cframe, size, material, color, props)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

function Builder.wedge(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	props: Props?
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Material = material
	wedge.Color = color
	apply(wedge, props)
	wedge.Parent = parent
	return wedge
end

-- Vertical cylinder standing on `base` (cylinders in Roblox run along the X axis).
function Builder.column(
	parent: Instance,
	base: CFrame,
	height: number,
	diameter: number,
	material: Enum.Material,
	color: Color3,
	props: Props?
): Part
	return Builder.part(
		parent,
		base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(height, diameter, diameter),
		material,
		color,
		Builder.merge({ Shape = Enum.PartType.Cylinder }, props)
	)
end

function Builder.merge(a: Props, b: Props?): Props
	local out = table.clone(a)
	if b then
		for k, v in b do
			out[k] = v
		end
	end
	return out
end

export type Opening = { x: number, width: number, bottom: number, top: number, glass: boolean? }

-- Wall along local X, `origin` is the centre of its bottom edge.
function Builder.wall(
	parent: Instance,
	origin: CFrame,
	width: number,
	height: number,
	thickness: number,
	material: Enum.Material,
	color: Color3,
	openings: { Opening }?
)
	local list = openings and table.clone(openings) or {}
	table.sort(list, function(a, b)
		return a.x < b.x
	end)

	local function solid(x0: number, x1: number, y0: number, y1: number)
		if x1 - x0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		Builder.part(
			parent,
			origin * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0),
			Vector3.new(x1 - x0, y1 - y0, thickness),
			material,
			color
		)
	end

	local cursor = -width / 2
	for _, o in list do
		local x0, x1 = o.x - o.width / 2, o.x + o.width / 2
		solid(cursor, x0, 0, height)
		solid(x0, x1, 0, o.bottom)
		solid(x0, x1, o.top, height)
		if o.glass then
			Builder.detail(
				parent,
				origin * CFrame.new(o.x, (o.bottom + o.top) / 2, 0),
				Vector3.new(o.width, o.top - o.bottom, 0.1),
				Enum.Material.Glass,
				Builder.Palette.Glass,
				{ Transparency = 0.7, CastShadow = false }
			)
		end
		cursor = x1
	end
	solid(cursor, width / 2, 0, height)
end

function Builder.lamp(
	parent: Instance,
	cframe: CFrame,
	color: Color3,
	brightness: number,
	range: number,
	flicker: boolean?
): Part
	local bulb = Builder.detail(parent, cframe, Vector3.new(0.6, 0.6, 0.6), Enum.Material.Neon, color, {
		Shape = Enum.PartType.Ball,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = true
	light.Parent = bulb
	if flicker then
		bulb:AddTag("Flicker")
	end
	return bulb
end

-- Prompts carry string keys; the client renders them in the player's language.
function Builder.prompt(
	parent: BasePart,
	actionKey: string,
	objectKey: string,
	holdDuration: number?,
	maxDistance: number?
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionKey
	prompt.ObjectText = objectKey
	prompt:SetAttribute("ActionKey", actionKey)
	prompt:SetAttribute("ObjectKey", objectKey)
	prompt.HoldDuration = holdDuration or 0
	prompt.MaxActivationDistance = maxDistance or 9
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = parent
	return prompt
end

-- Gable roof over a rectangle of `width` x `depth`, starting at `height`, ridge along local X.
function Builder.gableRoof(
	parent: Instance,
	origin: CFrame,
	width: number,
	depth: number,
	height: number,
	rise: number,
	material: Enum.Material,
	color: Color3,
	gableColor: Color3
)
	local overhang = 1.2
	local half = depth / 2 + overhang
	local slope = math.sqrt(half * half + rise * rise)
	local angle = math.atan2(rise, half)
	for _, side in { -1, 1 } do
		Builder.part(
			parent,
			origin * CFrame.new(0, height + rise / 2, side * half / 2) * CFrame.Angles(side * angle, 0, 0),
			Vector3.new(width + overhang * 2, 0.5, slope),
			material,
			color
		)
	end
	-- Gable triangles: the wedge's high side is at +Z, so the back half is turned around.
	for _, x in { -width / 2, width / 2 } do
		Builder.wedge(
			parent,
			origin * CFrame.new(x, height + rise / 2, -depth / 4),
			Vector3.new(0.6, rise, depth / 2),
			Enum.Material.WoodPlanks,
			gableColor
		)
		Builder.wedge(
			parent,
			origin * CFrame.new(x, height + rise / 2, depth / 4) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(0.6, rise, depth / 2),
			Enum.Material.WoodPlanks,
			gableColor
		)
	end
end

export type HouseOptions = {
	WallMaterial: Enum.Material?,
	WallColor: Color3?,
	RoofColor: Color3?,
	DoorWidth: number?,
	DoorHeight: number?,
	BackDoor: boolean?,
	Windows: boolean?,
	Lamp: boolean?,
}

-- Box house with a door in the front wall (local -Z) and windows. Returns interior loot points.
function Builder.house(parent: Instance, origin: CFrame, size: Vector3, options: HouseOptions?): { Vector3 }
	local o = options or {}
	local w, h, d = size.X, size.Y, size.Z
	local wallMat = o.WallMaterial or Enum.Material.WoodPlanks
	local wallColor = o.WallColor or Builder.Palette.WoodPale
	local doorW, doorH = o.DoorWidth or 4.5, o.DoorHeight or 7.5
	local t = 0.8

	Builder.part(
		parent,
		origin * CFrame.new(0, 0.25, 0),
		Vector3.new(w, 0.5, d),
		Enum.Material.WoodPlanks,
		Builder.Palette.WoodDark
	)

	local windows = o.Windows ~= false
	local function windowsFor(length: number, avoid: number?): { Opening }
		local list: { Opening } = {}
		if not windows then
			return list
		end
		local count = math.max(1, math.floor(length / 10))
		for i = 1, count do
			local x = -length / 2 + length * (i / (count + 1))
			if not avoid or math.abs(x - avoid) > doorW then
				table.insert(list, { x = x, width = 3.2, bottom = 3.2, top = 6.2, glass = true })
			end
		end
		return list
	end

	local front = windowsFor(w, 0)
	table.insert(front, { x = 0, width = doorW, bottom = 0, top = doorH })
	Builder.wall(parent, origin * CFrame.new(0, 0, -d / 2 + t / 2), w, h, t, wallMat, wallColor, front)

	local back = windowsFor(w, if o.BackDoor then 0 else nil)
	if o.BackDoor then
		table.insert(back, { x = 0, width = doorW, bottom = 0, top = doorH })
	end
	Builder.wall(parent, origin * CFrame.new(0, 0, d / 2 - t / 2), w, h, t, wallMat, wallColor, back)

	for _, side in { -1, 1 } do
		Builder.wall(
			parent,
			origin * CFrame.new(side * (w / 2 - t / 2), 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
			d - t * 2,
			h,
			t,
			wallMat,
			wallColor,
			windowsFor(d - t * 2)
		)
	end

	Builder.gableRoof(
		parent,
		origin,
		w,
		d,
		h,
		math.min(d * 0.32, 7),
		Enum.Material.Slate,
		o.RoofColor or Builder.Palette.Roof,
		wallColor
	)

	if o.Lamp ~= false then
		Builder.lamp(parent, origin * CFrame.new(0, h - 1, 0), Color3.fromRGB(255, 196, 130), 1.4, 22, true)
	end

	local loot = {}
	for _, offset in { Vector3.new(-w / 4, 1, d / 4), Vector3.new(w / 4, 1, d / 4), Vector3.new(w / 4, 1, -d / 5) } do
		table.insert(loot, (origin * CFrame.new(offset)).Position)
	end
	return loot
end

-- Rope that sags between two points (power lines, washing lines).
function Builder.rope(
	parent: Instance,
	a: BasePart,
	aOffset: Vector3,
	b: BasePart,
	bOffset: Vector3,
	sag: number,
	color: Color3
)
	local att0 = Instance.new("Attachment")
	att0.Position = aOffset
	att0.Parent = a
	local att1 = Instance.new("Attachment")
	att1.Position = bOffset
	att1.Parent = b
	local rope = Instance.new("RopeConstraint")
	rope.Attachment0 = att0
	rope.Attachment1 = att1
	rope.Length = (a.CFrame:PointToWorldSpace(aOffset) - b.CFrame:PointToWorldSpace(bOffset)).Magnitude + sag
	rope.Visible = true
	rope.Thickness = 0.08
	rope.Color = BrickColor.new(color)
	rope.Parent = parent
end

return Builder
