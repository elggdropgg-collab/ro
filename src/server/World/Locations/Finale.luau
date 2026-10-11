-- The terminus: an open night field, three wrecked outposts holding the fuses,
-- and a concrete bunker with the portal back to the ordinary world.

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server
local Builder = require(Server.World.Builder)
local Placement = require(Server.World.Placement)

local P = Builder.Palette

local FIELD_RADIUS = 380
local BUNKER_DISTANCE = 230

local Finale = {}

local function sandbags(parent: Instance, cf: CFrame, length: number)
	local count = math.floor(length / 2.2)
	for row = 0, 1 do
		for i = 0, count - 1 do
			local x = -length / 2 + i * 2.2 + (row * 1.1) + 1.1
			Builder.part(
				parent,
				cf * CFrame.new(x, 0.55 + row * 1.05, 0),
				Vector3.new(2.1, 1.05, 1.3),
				Enum.Material.Fabric,
				P.Sandbag
			)
		end
	end
end

local function watchtower(parent: Instance, cf: CFrame): Vector3
	local model = Builder.model(parent, "Watchtower")
	for _, x in { -3, 3 } do
		for _, z in { -3, 3 } do
			Builder.part(model, cf * CFrame.new(x, 8, z), Vector3.new(0.7, 16, 0.7), Enum.Material.Wood, P.WoodDark)
		end
	end
	Builder.part(model, cf * CFrame.new(0, 16, 0), Vector3.new(8, 0.6, 8), Enum.Material.WoodPlanks, P.Wood)
	Builder.part(model, cf * CFrame.new(0, 22, 0), Vector3.new(9, 0.5, 9), Enum.Material.CorrodedMetal, P.MetalDark)
	for _, x in { -4, 4 } do
		Builder.part(model, cf * CFrame.new(x, 19, 0), Vector3.new(0.4, 6, 0.4), Enum.Material.Wood, P.WoodDark)
	end
	-- Ladder
	for y = 1, 15, 1.4 do
		Builder.part(model, cf * CFrame.new(0, y, -3.6), Vector3.new(2, 0.25, 0.25), Enum.Material.Wood, P.Wood)
	end
	local lamp = Builder.lamp(model, cf * CFrame.new(0, 20, 0), Color3.fromRGB(255, 120, 90), 1.6, 28, true)
	lamp.Name = "TowerLamp"
	sandbags(model, cf * CFrame.new(0, 0, -6), 10)
	return (cf * CFrame.new(0, 16.8, 0)).Position
end

local function checkpoint(parent: Instance, cf: CFrame): Vector3
	local model = Builder.model(parent, "Checkpoint")
	Builder.house(model, cf * CFrame.new(-6, 0, 0), Vector3.new(8, 8, 8), {
		WallMaterial = Enum.Material.Concrete,
		WallColor = P.ConcreteDark,
		RoofColor = P.MetalDark,
		DoorWidth = 3.5,
		DoorHeight = 6.5,
	})
	-- Barrier arm, snapped
	Builder.part(model, cf * CFrame.new(4, 1.5, -5), Vector3.new(0.8, 3, 0.8), Enum.Material.Metal, P.Metal)
	Builder.part(
		model,
		cf * CFrame.new(8, 2.4, -5) * CFrame.Angles(0, 0, math.rad(-20)),
		Vector3.new(8, 0.4, 0.4),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(170, 40, 34)
	)
	sandbags(model, cf * CFrame.new(6, 0, 4), 9)
	sandbags(model, cf * CFrame.new(-6, 0, -7) * CFrame.Angles(0, 0.3, 0), 7)
	return (cf * CFrame.new(-6, 1, 1)).Position
end

local function truckWreck(parent: Instance, cf: CFrame): Vector3
	local model = Builder.model(parent, "Truck")
	local base = cf * CFrame.Angles(0, 0, math.rad(14))
	Builder.part(model, base * CFrame.new(0, 2.8, 2), Vector3.new(7, 3.8, 12), Enum.Material.CorrodedMetal, P.Military)
	Builder.part(
		model,
		base * CFrame.new(0, 3.2, -6),
		Vector3.new(6.6, 4.4, 4.5),
		Enum.Material.CorrodedMetal,
		P.Military
	)
	Builder.part(
		model,
		base * CFrame.new(0, 5.4, 2),
		Vector3.new(7.2, 0.3, 12.2),
		Enum.Material.Fabric,
		Color3.fromRGB(70, 66, 50)
	)
	for _, x in { -3.4, 3.4 } do
		for _, z in { -6, 1, 5 } do
			Builder.part(
				model,
				base * CFrame.new(x, 1.3, z),
				Vector3.new(1.2, 2.6, 2.6),
				Enum.Material.Rubber,
				Color3.fromRGB(24, 22, 22),
				{
					Shape = Enum.PartType.Cylinder,
				}
			)
		end
	end
	local fire = Builder.detail(
		model,
		base * CFrame.new(0, 4, -6),
		Vector3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		Color3.new(0, 0, 0),
		{
			Transparency = 1,
		}
	)
	local flames = Instance.new("Fire")
	flames.Size = 6
	flames.Heat = 9
	flames.Color = Color3.fromRGB(255, 120, 40)
	flames.SecondaryColor = Color3.fromRGB(120, 20, 10)
	flames.Parent = fire
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 130, 70)
	glow.Brightness = 2
	glow.Range = 30
	glow.Shadows = true
	glow.Parent = fire
	fire:AddTag("Flicker")
	return (cf * CFrame.new(6, 1, 2)).Position
end

local function bunker(parent: Instance, origin: CFrame): any
	local model = Builder.model(parent, "Bunker")
	local w, h, d = 56, 12, 46
	local t = 2
	local concrete, dark = P.Concrete, P.ConcreteDark

	-- Floor, roof, earth mound around it
	Builder.part(model, origin * CFrame.new(0, 0.5, 0), Vector3.new(w, 1, d), Enum.Material.Concrete, dark)
	Builder.part(
		model,
		origin * CFrame.new(0, h + 1, 0),
		Vector3.new(w + 2, 2, d + 2),
		Enum.Material.Concrete,
		concrete
	)
	workspace.Terrain:FillBlock(
		origin * CFrame.new(0, h + 3.5, 2) * CFrame.Angles(0, 0, 0),
		Vector3.new(w + 18, 4, d + 14),
		Enum.Material.Ground
	)

	-- Outer walls with a single entrance facing the train
	Builder.wall(model, origin * CFrame.new(0, 1, -d / 2 + t / 2), w, h, t, Enum.Material.Concrete, concrete, {
		{ x = 0, width = 8, bottom = 0, top = 9 },
	})
	Builder.wall(model, origin * CFrame.new(0, 1, d / 2 - t / 2), w, h, t, Enum.Material.Concrete, concrete)
	for _, side in { -1, 1 } do
		Builder.wall(
			model,
			origin * CFrame.new(side * (w / 2 - t / 2), 1, 0) * CFrame.Angles(0, math.pi / 2, 0),
			d - 2 * t,
			h,
			t,
			Enum.Material.Concrete,
			concrete
		)
	end

	-- Entrance corridor
	for _, side in { -1, 1 } do
		Builder.part(
			model,
			origin * CFrame.new(side * 5, 1 + h / 2, -d / 2 + 9),
			Vector3.new(1.5, h, 14),
			Enum.Material.Concrete,
			dark
		)
	end
	Builder.wall(model, origin * CFrame.new(0, 1, -d / 2 + 16), w - 2 * t, h, 1.5, Enum.Material.Concrete, dark, {
		{ x = 0, width = 8.5, bottom = 0, top = 9 },
	})
	-- Blast door, jammed half open
	Builder.part(
		model,
		origin * CFrame.new(5.5, 5.5, -d / 2 + 15.5),
		Vector3.new(6, 9, 0.8),
		Enum.Material.DiamondPlate,
		P.MetalDark
	)

	-- Warning lights along the corridor
	for z = -d / 2 + 4, -d / 2 + 14, 5 do
		Builder.lamp(model, origin * CFrame.new(0, h - 0.5, z), Color3.fromRGB(255, 50, 40), 1.2, 16, true)
	end
	Builder.lamp(model, origin * CFrame.new(-14, h - 0.5, 6), Color3.fromRGB(255, 70, 50), 1.4, 28, true)
	Builder.lamp(model, origin * CFrame.new(14, h - 0.5, 6), Color3.fromRGB(255, 70, 50), 1.4, 28, true)

	-- Portal frame on the back wall
	local portalCenter = origin * CFrame.new(0, 1 + 6.2, d / 2 - 4)
	local ring = Builder.model(model, "PortalRing")
	local segments = 16
	local radius = 5.4
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		Builder.part(
			ring,
			portalCenter * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0) * CFrame.Angles(0, 0, a),
			Vector3.new(0.8, 2.3, 1.2),
			Enum.Material.DiamondPlate,
			P.MetalDark
		)
	end
	local core = Builder.part(
		model,
		portalCenter * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(0.3, radius * 2 - 1, radius * 2 - 1),
		Enum.Material.Neon,
		Color3.fromRGB(160, 220, 255),
		{
			Shape = Enum.PartType.Cylinder,
			Transparency = 1,
			CanCollide = false,
			CastShadow = false,
		}
	)
	core.Name = "PortalCore"
	local portalLight = Instance.new("PointLight")
	portalLight.Name = "PortalLight"
	portalLight.Color = Color3.fromRGB(150, 210, 255)
	portalLight.Brightness = 0
	portalLight.Range = 40
	portalLight.Shadows = true
	portalLight.Parent = core
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "PortalParticles"
	particles.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255), Color3.fromRGB(80, 120, 255))
	particles.LightEmission = 1
	particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	particles.Transparency = NumberSequence.new(0.2, 1)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 0
	particles.Speed = NumberRange.new(2, 6)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = core

	-- Fuse panel and lever
	local panel = Builder.part(
		model,
		origin * CFrame.new(-w / 2 + 3.2, 5, 10) * CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new(5, 4, 0.8),
		Enum.Material.Metal,
		P.Metal
	)
	panel.Name = "FusePanel"
	for i = 1, 3 do
		local socket = Builder.detail(
			model,
			panel.CFrame * CFrame.new(-1.6 + (i - 1) * 1.6, 0, -0.45),
			Vector3.new(0.8, 1.8, 0.2),
			Enum.Material.Neon,
			Color3.fromRGB(80, 20, 20)
		)
		socket.Name = "Socket" .. i
	end
	local lever = Builder.part(
		model,
		origin * CFrame.new(w / 2 - 3.2, 4, 10) * CFrame.Angles(0, -math.pi / 2, 0),
		Vector3.new(2, 3, 1),
		Enum.Material.Metal,
		P.MetalDark
	)
	lever.Name = "PortalLever"

	-- Cover inside the hall
	for _ = 1, 6 do
		local x = math.random(-20, 20)
		local z = math.random(-2, 14)
		Builder.part(model, origin * CFrame.new(x, 2.5, z), Vector3.new(4, 3, 3), Enum.Material.WoodPlanks, P.Wood)
	end

	return {
		Model = model,
		Panel = panel,
		Lever = lever,
		PortalCore = core,
		Entrance = (origin * CFrame.new(0, 0, -d / 2 - 4)).Position,
		Hall = (origin * CFrame.new(0, 1, 6)).Position,
	}
end

function Finale.generate(ctx: any): any
	local rng: Random = ctx.Random
	local folder: Instance = ctx.Folder
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(58, 62, 48))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(62, 54, 46))
	terrain:FillBlock(
		CFrame.new(0, -6, 0),
		Vector3.new(FIELD_RADIUS * 2 + 200, 12, FIELD_RADIUS * 2 + 200),
		Enum.Material.Grass
	)

	local buildings = Builder.folder(folder, "Buildings")
	-- Local -Z (the entrance wall) faces the train, the portal sits against the far wall.
	local bunkerOrigin = CFrame.lookAt(Vector3.new(0, 0, BUNKER_DISTANCE), Vector3.new(0, 0, 0))
	local bunkerInfo = bunker(buildings, bunkerOrigin)
	Placement.carvePath(rng, Vector3.new(0, 0, 14), bunkerInfo.Entrance, 7, Enum.Material.Ground)

	local pois = Placement.scatter(rng, {
		{ Kind = "Watchtower", Radius = 10, MinDist = 120, MaxDist = 320, Count = 1 },
		{ Kind = "Checkpoint", Radius = 14, MinDist = 120, MaxDist = 320, Count = 1 },
		{ Kind = "Truck", Radius = 10, MinDist = 120, MaxDist = 320, Count = 1 },
	}, {
		FieldRadius = FIELD_RADIUS - 20,
		TrackClearance = 30,
		Gap = 110,
		Existing = {
			{ Kind = "Station", Position = Vector3.zero, Radius = 60, CFrame = CFrame.new() },
			{ Kind = "Bunker", Position = bunkerOrigin.Position, Radius = 40, CFrame = bunkerOrigin },
		},
	})

	local fuses: { Vector3 } = {}
	local builders: { [string]: (Instance, CFrame) -> Vector3 } = {
		Watchtower = watchtower,
		Checkpoint = checkpoint,
		Truck = truckWreck,
	}
	for _, poi in pois do
		table.insert(fuses, builders[poi.Kind](buildings, poi.CFrame))
	end
	-- If the field was too crowded for an outpost, fall back to the bunker surroundings.
	while #fuses < ctx.FusesNeeded do
		local angle = rng:NextNumber(0, math.pi * 2)
		table.insert(fuses, bunkerOrigin.Position + Vector3.new(math.cos(angle) * 60, 1, math.sin(angle) * 60))
	end

	-- Sparse dead wheat: open ground, nowhere good to hide
	local decor = Builder.folder(folder, "Decor")
	local concealed: { [string]: boolean } = {}
	local cell = 16
	local wheatCells = {}
	local noiseSeed = rng:NextNumber(0, 1000)
	for cx = -22, 22 do
		for cz = -22, 22 do
			local center = Vector3.new(cx * cell, 0, cz * cell)
			local farFromAll = center.Magnitude > 70
				and center.Magnitude < FIELD_RADIUS
				and math.abs(center.Z) > 30
				and Placement.flatDistance(center, bunkerOrigin.Position) > 55
			if farFromAll then
				for _, poi in pois do
					if Placement.flatDistance(center, poi.Position) < poi.Radius + 10 then
						farFromAll = false
					end
				end
			end
			if farFromAll and math.noise(cx / 4, cz / 4, noiseSeed) > 0.25 then
				concealed[cx .. "," .. cz] = true
				table.insert(wheatCells, center)
				local height = rng:NextNumber(2.4, 3.4)
				Builder.detail(
					decor,
					CFrame.new(center.X, height / 2, center.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
					Vector3.new(rng:NextNumber(8, 14), height, rng:NextNumber(8, 14)),
					Enum.Material.Grass,
					Color3.fromRGB(92, 84, 58)
				)
			end
		end
	end

	-- Floodlights along the path, most of them dead
	for i = 1, 6 do
		local p = Vector3.new(0, 0, 14):Lerp(bunkerInfo.Entrance, i / 7) + Vector3.new(8, 0, 0)
		Builder.part(
			decor,
			CFrame.new(p + Vector3.new(0, 5, 0)),
			Vector3.new(0.5, 10, 0.5),
			Enum.Material.Metal,
			P.MetalDark
		)
		if i % 2 == 0 then
			Builder.lamp(decor, CFrame.new(p + Vector3.new(0, 10, 0)), Color3.fromRGB(200, 210, 255), 1.1, 24, i == 4)
		end
	end

	local reanimators = {
		CFrame.lookAt(Vector3.new(30, 0, 40), Vector3.zero),
		CFrame.lookAt(bunkerInfo.Entrance + Vector3.new(-16, 0, -8), Vector3.zero),
	}

	local mapPois = { { Kind = "Bunker", Position = bunkerOrigin.Position, Radius = 30 } }
	for _, poi in pois do
		table.insert(mapPois, { Kind = poi.Kind, Position = poi.Position, Radius = poi.Radius })
	end

	return {
		Name = "Finale",
		Radius = FIELD_RADIUS,
		CellSize = cell,
		Concealed = concealed,
		WheatCells = wheatCells,
		POIs = mapPois,
		Paths = { { Vector3.new(0, 0, 14), bunkerInfo.Entrance } },
		Resources = {},
		Fuses = fuses,
		Reanimators = reanimators,
		Bunker = bunkerInfo,
		Monsters = { Nests = {} },
	}
end

return Finale
