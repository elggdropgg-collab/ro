-- Station 1: an endless wheat field at dusk. Farm buildings, a barn, a silo, wrecks,
-- and an empty scarecrow cross in a trampled circle. Its owner is already walking.

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server
local Builder = require(Server.World.Builder)
local Placement = require(Server.World.Placement)

local P = Builder.Palette

local FIELD_RADIUS = 400
local CELL = 16
local TRACK_CLEARANCE = 30

local Field = {}

type Loot = { Position: Vector3, Prefs: { [string]: number } }

local function lootAround(
	cframe: CFrame,
	radius: number,
	count: number,
	rng: Random,
	prefs: { [string]: number }
): { Loot }
	local list = {}
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius + 2)
		table.insert(list, { Position = (cframe * CFrame.new(offset)).Position + Vector3.new(0, 1, 0), Prefs = prefs })
	end
	return list
end

local function withPrefs(points: { Vector3 }, prefs: { [string]: number }): { Loot }
	local list = {}
	for _, p in points do
		table.insert(list, { Position = p, Prefs = prefs })
	end
	return list
end

-- Building builders. Each returns loot slots.

local function farmhouse(parent: Instance, cf: CFrame, rng: Random): { Loot }
	local model = Builder.model(parent, "Farmhouse")
	local points = Builder.house(model, cf, Vector3.new(30, 11, 22), {
		WallColor = P.Plaster,
		WallMaterial = Enum.Material.WoodPlanks,
		RoofColor = P.Roof,
		BackDoor = true,
	})
	-- Porch
	Builder.part(model, cf * CFrame.new(0, 0.6, -13.5), Vector3.new(30, 0.6, 5), Enum.Material.WoodPlanks, P.Wood)
	for _, x in { -14, -5, 5, 14 } do
		Builder.part(model, cf * CFrame.new(x, 4.6, -15.6), Vector3.new(0.6, 8, 0.6), Enum.Material.Wood, P.WoodDark)
	end
	Builder.part(
		model,
		cf * CFrame.new(0, 8.8, -13.5) * CFrame.Angles(math.rad(-8), 0, 0),
		Vector3.new(31, 0.4, 5.6),
		Enum.Material.Slate,
		P.Roof
	)
	-- Interior: overturned table, beds, a wardrobe blocking a window
	Builder.part(
		model,
		cf * CFrame.new(-6, 1.4, 2) * CFrame.Angles(0, 0.3, math.rad(85)),
		Vector3.new(5, 0.4, 3),
		Enum.Material.Wood,
		P.Wood
	)
	Builder.part(model, cf * CFrame.new(10, 1.2, 7), Vector3.new(4, 1.4, 7), Enum.Material.Fabric, P.Cloth)
	Builder.part(
		model,
		cf * CFrame.new(-12, 3.5, 8) * CFrame.Angles(0, 0, math.rad(-12)),
		Vector3.new(2, 7, 4),
		Enum.Material.Wood,
		P.WoodDark
	)
	-- Fence
	local fence = Builder.model(model, "Fence")
	for i = -4, 4 do
		if math.abs(i) > 1 then
			Builder.part(
				fence,
				cf * CFrame.new(i * 6, 1.6, -22),
				Vector3.new(0.5, 3.2, 0.5),
				Enum.Material.Wood,
				P.WoodDark
			)
		end
	end
	for _, row in { -22 } do
		Builder.part(fence, cf * CFrame.new(-16.5, 2.4, row), Vector3.new(15, 0.3, 0.3), Enum.Material.Wood, P.Wood)
		Builder.part(fence, cf * CFrame.new(16.5, 2.4, row), Vector3.new(15, 0.3, 0.3), Enum.Material.Wood, P.Wood)
	end
	local loot = withPrefs(points, { Supplies = 3, Diesel = 1, Scrap = 1 })
	for _, extra in lootAround(cf, 18, 2, rng, { Diesel = 1, Scrap = 1 }) do
		table.insert(loot, extra)
	end
	return loot
end

local function barn(parent: Instance, cf: CFrame, rng: Random): { Loot }
	local model = Builder.model(parent, "Barn")
	local red = Color3.fromRGB(112, 44, 36)
	local points = Builder.house(model, cf, Vector3.new(34, 16, 26), {
		WallColor = red,
		RoofColor = P.MetalDark,
		DoorWidth = 11,
		DoorHeight = 12,
		BackDoor = true,
		Windows = false,
	})
	-- Hay bales stacked inside
	for _ = 1, 7 do
		local x = rng:NextNumber(-13, 13)
		local z = rng:NextNumber(-8, 9)
		Builder.part(
			model,
			cf * CFrame.new(x, 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Vector3.new(4, 4, 4),
			Enum.Material.Grass,
			P.Hay,
			{ Shape = Enum.PartType.Cylinder }
		)
	end
	-- Loft
	Builder.part(model, cf * CFrame.new(0, 9, 7), Vector3.new(32, 0.6, 10), Enum.Material.WoodPlanks, P.Wood)
	Builder.lamp(model, cf * CFrame.new(0, 13.5, -6), Color3.fromRGB(255, 170, 110), 1.2, 26, true)
	return withPrefs(points, { Diesel = 2, Scrap = 2, Supplies = 1 })
end

local function silo(parent: Instance, cf: CFrame, rng: Random): { Loot }
	local model = Builder.model(parent, "Silo")
	Builder.column(model, cf, 28, 11, Enum.Material.CorrodedMetal, P.RustMetal)
	Builder.part(model, cf * CFrame.new(0, 28, 0), Vector3.new(11, 11, 11), Enum.Material.CorrodedMetal, P.RustMetal, {
		Shape = Enum.PartType.Ball,
	})
	Builder.column(model, cf * CFrame.new(0, -0.5, 0), 1, 14, Enum.Material.Concrete, P.Concrete)
	for y = 1, 26, 1.5 do
		Builder.detail(model, cf * CFrame.new(0, y, -5.9), Vector3.new(1.8, 0.2, 0.2), Enum.Material.Metal, P.MetalDark)
	end
	for _, x in { -0.9, 0.9 } do
		Builder.detail(
			model,
			cf * CFrame.new(x, 13.5, -5.9),
			Vector3.new(0.2, 27, 0.2),
			Enum.Material.Metal,
			P.MetalDark
		)
	end
	return lootAround(cf, 7, 2, rng, { Scrap = 2, Diesel = 1 })
end

local function tractor(parent: Instance, cf: CFrame, rng: Random): { Loot }
	local model = Builder.model(parent, "Tractor")
	local tilt = cf
		* CFrame.new(0, -0.3, 0)
		* CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), 0, math.rad(rng:NextNumber(-6, 6)))
	local body = Color3.fromRGB(120, 42, 30)
	Builder.part(model, tilt * CFrame.new(0, 2.8, 0), Vector3.new(4, 2.6, 7), Enum.Material.CorrodedMetal, body)
	Builder.part(model, tilt * CFrame.new(0, 3.4, -4.6), Vector3.new(3, 2.2, 3.4), Enum.Material.CorrodedMetal, body)
	for _, x in { -1.8, 1.8 } do
		for _, z in { 0.6, 3.2 } do
			Builder.part(
				model,
				tilt * CFrame.new(x, 6.2, z),
				Vector3.new(0.3, 4.4, 0.3),
				Enum.Material.Metal,
				P.MetalDark
			)
		end
	end
	Builder.part(model, tilt * CFrame.new(0, 8.5, 1.9), Vector3.new(4.2, 0.3, 3.4), Enum.Material.Metal, P.MetalDark)
	for _, x in { -2.6, 2.6 } do
		Builder.part(
			model,
			tilt * CFrame.new(x, 2.5, 2),
			Vector3.new(1.6, 5, 5),
			Enum.Material.Rubber,
			Color3.fromRGB(30, 28, 28),
			{
				Shape = Enum.PartType.Cylinder,
			}
		)
		Builder.part(
			model,
			tilt * CFrame.new(x * 0.85, 1.3, -4.6),
			Vector3.new(1, 2.6, 2.6),
			Enum.Material.Rubber,
			Color3.fromRGB(30, 28, 28),
			{
				Shape = Enum.PartType.Cylinder,
			}
		)
	end
	return lootAround(cf, 5, 2, rng, { Diesel = 3, Scrap = 2 })
end

local function shed(parent: Instance, cf: CFrame, rng: Random): { Loot }
	local model = Builder.model(parent, "Shed")
	local points = Builder.house(model, cf, Vector3.new(10, 8, 9), {
		WallColor = P.Wood,
		RoofColor = P.RustMetal,
		DoorWidth = 3.6,
		DoorHeight = 6.5,
		Windows = false,
		Lamp = rng:NextNumber() < 0.5,
	})
	return withPrefs({ points[1], points[3] }, { Supplies = 2, Diesel = 1, Scrap = 1 })
end

local function carWreck(parent: Instance, cf: CFrame, rng: Random): { Loot }
	local model = Builder.model(parent, "CarWreck")
	local color = Color3.fromHSV(rng:NextNumber(), 0.25, 0.45)
	local base = cf * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8)))
	Builder.part(model, base * CFrame.new(0, 1.6, 0), Vector3.new(5, 1.8, 10), Enum.Material.CorrodedMetal, color)
	Builder.part(model, base * CFrame.new(0, 3.2, 0.6), Vector3.new(4.6, 1.6, 5), Enum.Material.CorrodedMetal, color)
	Builder.detail(model, base * CFrame.new(0, 3.2, -1.95), Vector3.new(4.2, 1.3, 0.1), Enum.Material.Glass, P.Glass, {
		Transparency = 0.5,
	})
	for _, x in { -2.4, 2.4 } do
		for _, z in { -3.2, 3.2 } do
			Builder.part(
				model,
				base * CFrame.new(x, 0.9, z),
				Vector3.new(0.8, 1.9, 1.9),
				Enum.Material.Rubber,
				Color3.fromRGB(26, 24, 24),
				{
					Shape = Enum.PartType.Cylinder,
				}
			)
		end
	end
	return lootAround(cf, 5, 1, rng, { Scrap = 3, Diesel = 1 })
end

local function well(parent: Instance, cf: CFrame, rng: Random): { Loot }
	local model = Builder.model(parent, "Well")
	Builder.column(model, cf, 3, 5, Enum.Material.Cobblestone, P.Concrete)
	Builder.detail(
		model,
		cf * CFrame.new(0, 3.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.1, 4, 4),
		Enum.Material.SmoothPlastic,
		Color3.new(0, 0, 0),
		{
			Shape = Enum.PartType.Cylinder,
		}
	)
	for _, x in { -2.2, 2.2 } do
		Builder.part(model, cf * CFrame.new(x, 4.5, 0), Vector3.new(0.4, 6, 0.4), Enum.Material.Wood, P.WoodDark)
	end
	Builder.gableRoof(model, cf * CFrame.new(0, 0, 0), 5, 3.6, 7.2, 1.6, Enum.Material.WoodPlanks, P.Wood, P.Wood)
	return lootAround(cf, 3, 1, rng, { Supplies = 1 })
end

local function scarecrowPost(parent: Instance, cf: CFrame, rng: Random): Vector3
	local model = Builder.model(parent, "ScarecrowPost")
	workspace.Terrain:FillCylinder(cf * CFrame.new(0, -2, 0), 4, 15, Enum.Material.Ground)
	Builder.part(model, cf * CFrame.new(0, 5, 0), Vector3.new(0.7, 10, 0.7), Enum.Material.Wood, P.WoodDark)
	Builder.part(model, cf * CFrame.new(0, 7.6, 0), Vector3.new(7, 0.5, 0.5), Enum.Material.Wood, P.WoodDark)
	-- Cut ropes: whatever hung here pulled itself free
	for _, x in { -3, 3 } do
		Builder.detail(
			model,
			cf * CFrame.new(x, 6.9, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.3, 0.3)),
			Vector3.new(0.12, 1.4, 0.12),
			Enum.Material.Fabric,
			P.Hay
		)
	end
	-- Dead crows
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(3, 11)
		Builder.detail(
			model,
			cf * CFrame.new(math.cos(angle) * r, 0.2, math.sin(angle) * r) * CFrame.Angles(0, angle, 0),
			Vector3.new(0.6, 0.35, 1.1),
			Enum.Material.Fabric,
			Color3.fromRGB(14, 14, 16)
		)
	end
	-- Scattered straw
	for _ = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.5, 13)
		Builder.detail(
			model,
			cf * CFrame.new(math.cos(angle) * r, 0.05, math.sin(angle) * r) * CFrame.Angles(0, angle, 0),
			Vector3.new(0.15, 0.1, rng:NextNumber(0.8, 2)),
			Enum.Material.Grass,
			P.Hay
		)
	end
	return (cf * CFrame.new(0, 3, 3)).Position
end

local function deadTree(parent: Instance, position: Vector3, rng: Random)
	local model = Builder.model(parent, "DeadTree")
	local height = rng:NextNumber(14, 22)
	local base = CFrame.new(position)
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-6, 6)))
	Builder.part(
		model,
		base * CFrame.new(0, height / 2, 0),
		Vector3.new(1.4, height, 1.4),
		Enum.Material.Wood,
		Color3.fromRGB(46, 40, 36)
	)
	for _ = 1, rng:NextInteger(3, 6) do
		local y = rng:NextNumber(height * 0.45, height * 0.95)
		local length = rng:NextNumber(4, 8)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local pitch = rng:NextNumber(0.4, 1.1)
		Builder.detail(
			model,
			base
				* CFrame.new(0, y, 0)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(pitch, 0, 0)
				* CFrame.new(0, length / 2, 0),
			Vector3.new(0.5, length, 0.5),
			Enum.Material.Wood,
			Color3.fromRGB(46, 40, 36)
		)
	end
end

local function powerLine(parent: Instance, from: Vector3, to: Vector3)
	local model = Builder.model(parent, "PowerLine")
	local length = Placement.flatDistance(from, to)
	local count = math.max(2, math.floor(length / 42))
	local side = Vector3.new(-(to - from).Z, 0, (to - from).X).Unit * 6
	local previous: BasePart? = nil
	for i = 0, count do
		local p = from:Lerp(to, i / count) + side
		local pole = Builder.part(
			model,
			CFrame.lookAt(Vector3.new(p.X, 8, p.Z), Vector3.new(to.X, 8, to.Z) + side),
			Vector3.new(0.7, 16, 0.7),
			Enum.Material.Wood,
			P.WoodDark
		)
		Builder.part(
			model,
			pole.CFrame * CFrame.new(0, 7, 0),
			Vector3.new(4, 0.35, 0.35),
			Enum.Material.Wood,
			P.WoodDark
		)
		if previous then
			for _, x in { -1.7, 1.7 } do
				Builder.rope(
					model,
					previous,
					Vector3.new(x, 7.2, 0),
					pole,
					Vector3.new(x, 7.2, 0),
					1.5,
					Color3.fromRGB(20, 20, 20)
				)
			end
		end
		previous = pole
	end
end

-- Wheat grown in rows parallel to the railway. Neighbouring cells merge into long rows
-- to keep the part count low; tufts on top break the silhouette.
local function plantWheat(parent: Instance, rng: Random, isWheat: (number, number) -> boolean): { [string]: boolean }
	local concealed: { [string]: boolean } = {}
	local cellsPerSide = math.ceil(FIELD_RADIUS / CELL)
	for cz = -cellsPerSide, cellsPerSide do
		local runStart: number? = nil
		for cx = -cellsPerSide, cellsPerSide + 1 do
			local planted = cx <= cellsPerSide and isWheat(cx, cz)
			if planted then
				concealed[cx .. "," .. cz] = true
				if not runStart then
					runStart = cx
				end
			elseif runStart then
				local x0 = (runStart :: number) * CELL - CELL / 2
				local x1 = (cx - 1) * CELL + CELL / 2
				for row = -1, 1 do
					local z = cz * CELL + row * 5.3 + rng:NextNumber(-0.4, 0.4)
					local a = x0 + rng:NextNumber(0, 2.5)
					local b = x1 - rng:NextNumber(0, 2.5)
					local length = b - a
					if length > 3 then
						local height = rng:NextNumber(4.4, 5.6)
						local color = P.WheatDark:Lerp(P.WheatLight, rng:NextNumber(0.25, 0.85))
						Builder.detail(
							parent,
							CFrame.new((a + b) / 2, height / 2, z),
							Vector3.new(length, height, 4.4),
							Enum.Material.Grass,
							color,
							{
								CastShadow = true,
							}
						)
						local x = a + rng:NextNumber(1, 5)
						while x < b - 1.5 do
							local tuftHeight = rng:NextNumber(0.6, 1.3)
							Builder.detail(
								parent,
								CFrame.new(x, height + tuftHeight / 2 - 0.35, z + rng:NextNumber(-0.8, 0.8))
									* CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.12, 0.12)),
								Vector3.new(rng:NextNumber(1.4, 3), tuftHeight, rng:NextNumber(2.6, 4)),
								Enum.Material.Grass,
								P.WheatLight:Lerp(color, rng:NextNumber(0, 0.5)),
								{ CastShadow = false }
							)
							x += rng:NextNumber(5, 10)
						end
					end
				end
				runStart = nil
			end
		end
	end
	return concealed
end

local function pickWeighted(rng: Random, slots: { Loot }, used: { [Loot]: boolean }, kind: string): Loot?
	local total = 0
	for _, slot in slots do
		if not used[slot] then
			total += slot.Prefs[kind] or 0
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber(0, total)
	for _, slot in slots do
		if not used[slot] then
			roll -= slot.Prefs[kind] or 0
			if roll <= 0 then
				return slot
			end
		end
	end
	return nil
end

function Field.generate(ctx: any): any
	local rng: Random = ctx.Random
	local folder: Instance = ctx.Folder
	local spawnCounts = ctx.ResourceCounts -- { Diesel = n, Scrap = n, Supplies = n }

	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 92, 52))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(92, 74, 54))
	terrain:FillBlock(
		CFrame.new(0, -6, 0),
		Vector3.new(FIELD_RADIUS * 2 + 200, 12, FIELD_RADIUS * 2 + 200),
		Enum.Material.Grass
	)

	local buildings = Builder.folder(folder, "Buildings")

	local specs: { Placement.Spec } = {
		{ Kind = "Farmhouse", Radius = 24, MinDist = 110, MaxDist = 220, Count = 1 },
		{ Kind = "Barn", Radius = 26, MinDist = 160, MaxDist = 310, Count = 1 },
		{ Kind = "ScarecrowPost", Radius = 16, MinDist = 180, MaxDist = 290, Count = 1 },
		{ Kind = "Silo", Radius = 9, MinDist = 120, MaxDist = 330, Count = 1 },
		{ Kind = "Tractor", Radius = 8, MinDist = 80, MaxDist = 340, Count = 2 },
		{ Kind = "Shed", Radius = 8, MinDist = 70, MaxDist = 320, Count = 3 },
		{ Kind = "CarWreck", Radius = 7, MinDist = 60, MaxDist = 340, Count = 2 },
		{ Kind = "Well", Radius = 5, MinDist = 90, MaxDist = 300, Count = 1 },
	}
	local pois = Placement.scatter(rng, specs, {
		FieldRadius = FIELD_RADIUS - 20,
		TrackClearance = TRACK_CLEARANCE,
		Gap = 26,
		Existing = { { Kind = "Station", Position = Vector3.zero, Radius = 80, CFrame = CFrame.new() } },
	})

	-- Paths from the platform to every building
	local paths: { { Vector3 } } = {}
	local exits = { Vector3.new(-78, 0, -12), Vector3.new(78, 0, -12), Vector3.new(0, 0, 16) }
	for _, poi in pois do
		local nearest = exits[1]
		for _, exit in exits do
			if Placement.flatDistance(exit, poi.Position) < Placement.flatDistance(nearest, poi.Position) then
				nearest = exit
			end
		end
		local target = (poi.CFrame * CFrame.new(0, 0, -(poi.Radius + 2))).Position
		for _, segment in Placement.carvePath(rng, nearest, target, 6, Enum.Material.Ground) do
			table.insert(paths, segment)
		end
	end

	-- Buildings and loot slots
	local slots: { Loot } = {}
	local scarecrowSpawn: Vector3? = nil
	local builders: { [string]: (Instance, CFrame, Random) -> { Loot } } = {
		Farmhouse = farmhouse,
		Barn = barn,
		Silo = silo,
		Tractor = tractor,
		Shed = shed,
		CarWreck = carWreck,
		Well = well,
	}
	for i, poi in pois do
		if poi.Kind == "ScarecrowPost" then
			scarecrowSpawn = scarecrowPost(buildings, poi.CFrame, rng)
		else
			for _, slot in builders[poi.Kind](buildings, poi.CFrame, rng) do
				table.insert(slots, slot)
			end
		end
		if i % 3 == 0 then
			task.wait()
		end
	end

	-- A power line along the longest path
	if #paths > 0 then
		local longest = paths[1]
		for _, segment in paths do
			if Placement.flatDistance(segment[1], segment[2]) > Placement.flatDistance(longest[1], longest[2]) then
				longest = segment
			end
		end
		powerLine(buildings, longest[1], longest[2])
	end

	-- Wheat everywhere that is not a building, a path or the railway
	local noiseSeed = rng:NextNumber(0, 1000)
	local function isWheat(cx: number, cz: number): boolean
		local center = Vector3.new(cx * CELL, 0, cz * CELL)
		local dist = center.Magnitude
		if dist > FIELD_RADIUS or math.abs(center.Z) < TRACK_CLEARANCE or dist < 60 then
			return false
		end
		for _, poi in pois do
			if Placement.flatDistance(center, poi.Position) < poi.Radius + 8 then
				return false
			end
		end
		for _, segment in paths do
			if Placement.segmentDistance(center, segment[1], segment[2]) < 9 then
				return false
			end
		end
		return math.noise(cx / 6, cz / 6, noiseSeed) > -0.3
	end
	local wheatFolder = Builder.folder(folder, "Wheat")
	local concealed = plantWheat(wheatFolder, rng, isWheat)
	task.wait()

	local wheatCells: { Vector3 } = {}
	for key in concealed do
		local cx, cz = string.match(key, "^(-?%d+),(-?%d+)$")
		table.insert(wheatCells, Vector3.new(tonumber(cx) :: number * CELL, 0, tonumber(cz) :: number * CELL))
	end
	table.sort(wheatCells, function(a, b)
		return a.X < b.X or (a.X == b.X and a.Z < b.Z)
	end)

	-- Lonely dead trees on clear ground
	local decor = Builder.folder(folder, "Decor")
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(90, FIELD_RADIUS - 20)
		local p = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		if math.abs(p.Z) > TRACK_CLEARANCE then
			deadTree(decor, p, rng)
		end
	end
	for _ = 1, 18 do
		local cell = wheatCells[rng:NextInteger(1, math.max(1, #wheatCells))]
		if cell then
			Builder.part(
				decor,
				CFrame.new(cell + Vector3.new(rng:NextNumber(-5, 5), 2, rng:NextNumber(-5, 5)))
					* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
				Vector3.new(4, 4, 4),
				Enum.Material.Grass,
				P.Hay,
				{
					Shape = Enum.PartType.Cylinder,
				}
			)
		end
	end

	-- Distribute resources over loot slots with weighted preferences
	local used: { [Loot]: boolean } = {}
	local resources: { { Kind: string, Position: Vector3 } } = {}
	local function randomWheatPoint(minDist: number, maxDist: number): Vector3
		for _ = 1, 60 do
			local cell = wheatCells[rng:NextInteger(1, math.max(1, #wheatCells))]
			if cell and cell.Magnitude >= minDist and cell.Magnitude <= maxDist then
				return cell + Vector3.new(rng:NextNumber(-5, 5), 1, rng:NextNumber(-5, 5))
			end
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(minDist, maxDist)
		return Vector3.new(math.cos(angle) * dist, 1, math.abs(math.sin(angle) * dist) + TRACK_CLEARANCE)
	end
	for _, kind in { "Diesel", "Supplies", "Scrap" } do
		for _ = 1, spawnCounts[kind] or 0 do
			local slot = pickWeighted(rng, slots, used, kind)
			if slot then
				used[slot] = true
				table.insert(resources, { Kind = kind, Position = slot.Position })
			else
				table.insert(resources, { Kind = kind, Position = randomWheatPoint(70, FIELD_RADIUS - 30) })
			end
		end
	end
	-- Guarantee one easy diesel and two that force a deep expedition
	local near, far = 0, 0
	for _, r in resources do
		if r.Kind == "Diesel" then
			local d = r.Position.Magnitude
			if d < 130 then
				near += 1
			elseif d > 210 then
				far += 1
			end
		end
	end
	if near == 0 then
		table.insert(resources, { Kind = "Diesel", Position = randomWheatPoint(60, 125) })
	end
	for _ = far + 1, 2 do
		table.insert(resources, { Kind = "Diesel", Position = randomWheatPoint(220, FIELD_RADIUS - 30) })
	end

	-- Reanimators: one close to the station, two at the most distant buildings
	local reanimators: { CFrame } = {}
	do
		for _ = 1, 50 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local p = Vector3.new(math.cos(angle) * rng:NextNumber(55, 85), 0, 0)
			p = Vector3.new(p.X, 0, (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(36, 60))
			local clear = true
			for _, poi in pois do
				if Placement.flatDistance(p, poi.Position) < poi.Radius + 6 then
					clear = false
				end
			end
			if clear then
				table.insert(reanimators, CFrame.lookAt(p, Vector3.new(0, 0, 0)))
				break
			end
		end
		local candidates = {}
		for _, poi in pois do
			if poi.Kind ~= "ScarecrowPost" and poi.Position.Magnitude > 140 then
				table.insert(candidates, poi)
			end
		end
		local bestA, bestB, bestDist = nil, nil, -1
		for i = 1, #candidates do
			for j = i + 1, #candidates do
				local d = Placement.flatDistance(candidates[i].Position, candidates[j].Position)
				if d > bestDist then
					bestA, bestB, bestDist = candidates[i], candidates[j], d
				end
			end
		end
		for _, poi in { bestA, bestB } do
			if poi then
				local toStation = (Vector3.zero - poi.Position).Unit
				local p = poi.Position + toStation * (poi.Radius + 6)
				table.insert(reanimators, CFrame.lookAt(Vector3.new(p.X, 0, p.Z), Vector3.zero))
			end
		end
	end

	-- Husk nests deep in the wheat, spread out
	local nests: { Vector3 } = {}
	for _ = 1, 300 do
		if #nests >= ctx.NestCount then
			break
		end
		local p = randomWheatPoint(ctx.NestMinDistance, FIELD_RADIUS - 20)
		local ok = true
		for _, other in nests do
			if Placement.flatDistance(p, other) < 120 then
				ok = false
				break
			end
		end
		if ok then
			table.insert(nests, Vector3.new(p.X, 2, p.Z))
		end
	end

	local mapPois = {}
	for _, poi in pois do
		table.insert(mapPois, { Kind = poi.Kind, Position = poi.Position, Radius = poi.Radius })
	end
	local mapPaths = {}
	for _, segment in paths do
		table.insert(mapPaths, { segment[1], segment[2] })
	end

	return {
		Name = "Field",
		Radius = FIELD_RADIUS,
		CellSize = CELL,
		Concealed = concealed,
		WheatCells = wheatCells,
		POIs = mapPois,
		Paths = mapPaths,
		Resources = resources,
		Reanimators = reanimators,
		Monsters = {
			Immortal = { Kind = "Scarecrow", Position = scarecrowSpawn or Vector3.new(0, 3, 240) },
			Nests = nests,
		},
	}
end

return Field
