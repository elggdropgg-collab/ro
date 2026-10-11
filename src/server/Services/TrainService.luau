-- The train: the only safe place in the game. Built once at the origin; stations are
-- generated around it. Locomotive (cab with the departure lever), HQ wagon and cargo wagon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SquadConfig = require(ReplicatedStorage.Shared.Config.Squad)
local State = require(ReplicatedStorage.Shared.State)
local Server = ServerScriptService.Server
local Builder = require(Server.World.Builder)
local Registry = require(Server.Registry)

local P = Builder.Palette

local FLOOR_Y = 3.4
local WAGON_HEIGHT = 10
local WAGON_WIDTH = 10

local SAFE_MIN = Vector3.new(-66, -4, -17)
local SAFE_MAX = Vector3.new(68, 28, 6)

local TrainService = {}

local trainModel: Model
local gauge: BasePart
local lever: BasePart
local horn: Sound

local function bogies(parent: Instance, centerX: number, length: number)
	for _, offset in { -length / 2 + 6, length / 2 - 6 } do
		local x = centerX + offset
		Builder.part(parent, CFrame.new(x, 1.9, 0), Vector3.new(7, 1.2, 6), Enum.Material.Metal, P.MetalDark)
		for _, dx in { -2, 2 } do
			for _, z in { -2.4, 2.4 } do
				Builder.part(
					parent,
					CFrame.new(x + dx, 1.4, z),
					Vector3.new(0.6, 2.2, 2.2),
					Enum.Material.Metal,
					P.MetalDark,
					{
						Shape = Enum.PartType.Cylinder,
					}
				)
			end
		end
	end
	Builder.part(
		parent,
		CFrame.new(centerX, 2.8, 0),
		Vector3.new(length, 0.8, WAGON_WIDTH - 0.6),
		Enum.Material.Metal,
		P.MetalDark
	)
end

local function wagonShell(parent: Instance, centerX: number, length: number, color: Color3, platformDoors: { number })
	local floor = Builder.part(
		parent,
		CFrame.new(centerX, FLOOR_Y - 0.3, 0),
		Vector3.new(length, 0.6, WAGON_WIDTH),
		Enum.Material.WoodPlanks,
		P.WoodDark
	)
	floor.Name = "Floor"
	local base = CFrame.new(centerX, FLOOR_Y, 0)
	local t = 0.6

	local doors = {}
	for _, x in platformDoors do
		table.insert(doors, { x = x, width = 4.5, bottom = 0, top = 7.6 })
	end
	for _, x in { -length / 2 + 8, -length / 4 + 2, length / 4 - 2, length / 2 - 8 } do
		local blocked = false
		for _, door in platformDoors do
			if math.abs(door - x) < 5 then
				blocked = true
			end
		end
		if not blocked then
			table.insert(doors, { x = x, width = 3.4, bottom = 3.6, top = 6.6, glass = true })
		end
	end
	-- Platform side (-Z) has the doors, the far side only windows
	Builder.wall(
		parent,
		base * CFrame.new(0, 0, -WAGON_WIDTH / 2 + t / 2),
		length,
		WAGON_HEIGHT,
		t,
		Enum.Material.Metal,
		color,
		doors
	)
	local windows = {}
	for i = 1, 5 do
		table.insert(windows, { x = -length / 2 + length * i / 6, width = 3.4, bottom = 3.6, top = 6.6, glass = true })
	end
	Builder.wall(
		parent,
		base * CFrame.new(0, 0, WAGON_WIDTH / 2 - t / 2),
		length,
		WAGON_HEIGHT,
		t,
		Enum.Material.Metal,
		color,
		windows
	)
	-- End walls with gangway doors
	for _, side in { -1, 1 } do
		Builder.wall(
			parent,
			base * CFrame.new(side * (length / 2 - t / 2), 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
			WAGON_WIDTH - 2 * t,
			WAGON_HEIGHT,
			t,
			Enum.Material.Metal,
			color,
			{
				{ x = 0, width = 3.4, bottom = 0, top = 7.6 },
			}
		)
	end
	-- Curved roof
	Builder.part(
		parent,
		base * CFrame.new(0, WAGON_HEIGHT + 0.25, 0),
		Vector3.new(length + 0.6, 0.5, WAGON_WIDTH - 3),
		Enum.Material.Metal,
		P.MetalDark
	)
	for _, side in { -1, 1 } do
		Builder.part(
			parent,
			base
				* CFrame.new(0, WAGON_HEIGHT - 0.1, side * (WAGON_WIDTH / 2 - 0.9))
				* CFrame.Angles(side * math.rad(28), 0, 0),
			Vector3.new(length + 0.6, 0.5, 2.4),
			Enum.Material.Metal,
			P.MetalDark
		)
	end
	-- Stripe along the body
	for _, z in { -WAGON_WIDTH / 2 - 0.02, WAGON_WIDTH / 2 + 0.02 } do
		Builder.detail(
			parent,
			base * CFrame.new(0, 1.6, z),
			Vector3.new(length, 0.5, 0.05),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(150, 120, 60)
		)
	end
end

local function terminal(parent: Instance, cf: CFrame, color: Color3, name: string): BasePart
	local body = Builder.part(parent, cf, Vector3.new(2.6, 4.2, 1.6), Enum.Material.Metal, P.MetalDark)
	body.Name = name
	Builder.detail(parent, cf * CFrame.new(0, 0.9, -0.81), Vector3.new(2, 1.4, 0.05), Enum.Material.Neon, color, {
		Transparency = 0.15,
	})
	return body
end

local function buildRailway()
	local railway = Builder.folder(workspace, "Railway")
	for _, z in { -2.4, 2.4 } do
		Builder.part(
			railway,
			CFrame.new(0, 0.55, z),
			Vector3.new(1400, 0.5, 0.35),
			Enum.Material.Metal,
			Color3.fromRGB(70, 66, 62)
		)
	end
	for x = -700, 700, 5 do
		Builder.part(
			railway,
			CFrame.new(x, 0.15, 0),
			Vector3.new(1.2, 0.3, 7.2),
			Enum.Material.Wood,
			Color3.fromRGB(52, 42, 34)
		)
	end
end

local function buildPlatform(parent: Instance)
	local platform = Builder.model(parent, "Platform")
	Builder.part(platform, CFrame.new(0, 1.6, -11.2), Vector3.new(150, 3.2, 10), Enum.Material.Concrete, P.Concrete)
	Builder.detail(
		platform,
		CFrame.new(0, 3.21, -6.7),
		Vector3.new(150, 0.02, 0.6),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(190, 160, 50)
	)
	for _, side in { -1, 1 } do
		Builder.wedge(
			platform,
			CFrame.new(side * 81, 1.6, -11.2) * CFrame.Angles(0, side * math.pi / 2, 0),
			Vector3.new(10, 3.2, 12),
			Enum.Material.Concrete,
			P.Concrete
		)
	end
	for x = -62, 62, 31 do
		Builder.part(platform, CFrame.new(x, 8.2, -15), Vector3.new(0.4, 10, 0.4), Enum.Material.Metal, P.MetalDark)
		Builder.part(platform, CFrame.new(x, 13, -14), Vector3.new(0.4, 0.4, 2.4), Enum.Material.Metal, P.MetalDark)
		Builder.lamp(platform, CFrame.new(x, 12.5, -13), Color3.fromRGB(255, 214, 160), 1.6, 26, x == 31)
	end
	-- Station sign; the client renders the station name in the player's language
	for _, x in { -30, 30 } do
		local sign = Builder.part(
			platform,
			CFrame.new(x, 9, -15.6),
			Vector3.new(14, 2.4, 0.3),
			Enum.Material.Metal,
			Color3.fromRGB(28, 40, 70)
		)
		sign.Name = "StationSign"
		sign:AddTag("StationSign")
		for _, dx in { -6, 6 } do
			Builder.part(
				platform,
				CFrame.new(x + dx, 5.6, -15.6),
				Vector3.new(0.3, 4.8, 0.3),
				Enum.Material.Metal,
				P.MetalDark
			)
		end
	end
	for _, x in { -48, 12 } do
		Builder.part(platform, CFrame.new(x, 4, -14.2), Vector3.new(6, 0.4, 1.6), Enum.Material.WoodPlanks, P.Wood)
	end
end

local function buildHQ(parent: Instance)
	local hq = Builder.model(parent, "HQ")
	bogies(hq, 0, 40)
	wagonShell(hq, 0, 40, Color3.fromRGB(64, 74, 58), { -10, 10 })

	-- Tactical table
	local table_ =
		Builder.part(hq, CFrame.new(0, FLOOR_Y + 1.6, 1), Vector3.new(7, 0.4, 4.6), Enum.Material.Wood, P.WoodDark)
	table_.Name = "TacticalTable"
	for _, x in { -3, 3 } do
		for _, z in { -1.8, 1.8 } do
			Builder.part(
				hq,
				CFrame.new(x, FLOOR_Y + 0.7, 1 + z),
				Vector3.new(0.3, 1.4, 0.3),
				Enum.Material.Wood,
				P.WoodDark
			)
		end
	end
	local mapSheet = Builder.detail(
		hq,
		CFrame.new(0, FLOOR_Y + 1.82, 1),
		Vector3.new(6.2, 0.05, 3.8),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(196, 184, 150)
	)
	mapSheet.Name = "MapSheet"
	mapSheet:AddTag("TacticalSheet")
	local mapPrompt = Builder.prompt(table_, "HUD_Map", "Map_Title", 0, 8)
	mapPrompt:SetAttribute("ClientAction", "OpenMap")

	-- Terminals
	local upgrade = terminal(
		hq,
		CFrame.new(-16, FLOOR_Y + 2.1, 3.6) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(110, 200, 140),
		"UpgradeTerminal"
	)
	Builder.prompt(upgrade, "Prompt_Upgrade", "Prompt_Terminal", 0.6).Triggered:Connect(function(player)
		Registry.PlayerService:UpgradeWeapon(player)
	end)

	local recruit = terminal(
		hq,
		CFrame.new(-11.5, FLOOR_Y + 2.1, 3.6) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(220, 170, 80),
		"RecruitTerminal"
	)
	local recruitPrompt = Builder.prompt(recruit, "Prompt_Recruit", "Resource_Scrap", 0.6)
	recruitPrompt:SetAttribute("ObjectArg", SquadConfig.RecruitScrapCost)
	recruitPrompt.Triggered:Connect(function(player)
		Registry.SquadService:Recruit(player)
	end)

	local radio = terminal(
		hq,
		CFrame.new(16, FLOOR_Y + 2.1, 3.6) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(200, 80, 70),
		"SupplyRadio"
	)
	local shopPrompt = Builder.prompt(radio, "HUD_Shop", "Prompt_Terminal", 0, 8)
	shopPrompt:SetAttribute("ClientAction", "OpenShop")

	local ammo = Builder.part(
		hq,
		CFrame.new(11.5, FLOOR_Y + 0.8, 3.4),
		Vector3.new(3, 1.6, 1.8),
		Enum.Material.WoodPlanks,
		P.Military
	)
	ammo.Name = "AmmoCrate"
	Builder.prompt(ammo, "Prompt_Ammo", "Resource_Supplies", 0.8).Triggered:Connect(function(player)
		Registry.PlayerService:RefillAmmo(player)
	end)

	-- Bunks and clutter
	for _, x in { -16, 16 } do
		for _, y in { 0.8, 3.6 } do
			Builder.part(hq, CFrame.new(x, FLOOR_Y + y, -3.2), Vector3.new(6, 0.5, 2.4), Enum.Material.Fabric, P.Cloth)
		end
	end
	for _, x in { -12, 0, 12 } do
		Builder.lamp(hq, CFrame.new(x, FLOOR_Y + WAGON_HEIGHT - 0.8, 0), Color3.fromRGB(255, 200, 140), 1.2, 18, false)
	end
end

local function buildLocomotive(parent: Instance)
	local loco = Builder.model(parent, "Locomotive")
	local cx = 46
	bogies(loco, cx, 44)
	local cabColor = Color3.fromRGB(110, 34, 30)
	-- Cab next to the HQ wagon so players can walk in through the gangway
	wagonShell(loco, 30, 12, cabColor, { 0 })
	-- Engine hood
	Builder.part(loco, CFrame.new(51, FLOOR_Y + 4, 0), Vector3.new(30, 8, 7.4), Enum.Material.Metal, cabColor)
	Builder.part(
		loco,
		CFrame.new(51, FLOOR_Y + 8.2, 0),
		Vector3.new(30, 0.4, 6.4),
		Enum.Material.DiamondPlate,
		P.MetalDark
	)
	for x = 40, 62, 5.5 do
		Builder.detail(
			loco,
			CFrame.new(x, FLOOR_Y + 4, -3.72),
			Vector3.new(3, 5, 0.05),
			Enum.Material.DiamondPlate,
			P.MetalDark
		)
	end
	Builder.part(loco, CFrame.new(67, FLOOR_Y + 2, 0), Vector3.new(2, 4, 9.6), Enum.Material.Metal, P.MetalDark)
	local headlight = Builder.detail(
		loco,
		CFrame.new(68.1, FLOOR_Y + 6, 0),
		Vector3.new(0.3, 1.4, 1.4),
		Enum.Material.Neon,
		Color3.fromRGB(255, 240, 210),
		{
			Shape = Enum.PartType.Cylinder,
		}
	)
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Right
	beam.Angle = 50
	beam.Range = 60
	beam.Brightness = 4
	beam.Shadows = true
	beam.Color = Color3.fromRGB(255, 236, 200)
	beam.Parent = headlight

	lever = Builder.part(
		loco,
		CFrame.new(33.5, FLOOR_Y + 2.2, 2.5),
		Vector3.new(0.4, 2.4, 0.4),
		Enum.Material.Metal,
		Color3.fromRGB(160, 30, 24)
	)
	lever.Name = "DepartLever"
	Builder.part(
		loco,
		CFrame.new(33.5, FLOOR_Y + 0.8, 2.5),
		Vector3.new(1.6, 1.2, 1.6),
		Enum.Material.Metal,
		P.MetalDark
	)
	Builder.prompt(lever, "Prompt_Depart", "Prompt_Lever", 1.5, 7).Triggered:Connect(function(player)
		Registry.MatchService:RequestDepart(player)
	end)

	horn = Instance.new("Sound")
	horn.Name = "Horn"
	horn.RollOffMaxDistance = 900
	horn.RollOffMinDistance = 40
	horn.Volume = 1.2
	horn.Parent = headlight
end

local function buildCargo(parent: Instance)
	local cargo = Builder.model(parent, "Cargo")
	local cx = -44
	bogies(cargo, cx, 40)
	Builder.part(
		cargo,
		CFrame.new(cx, FLOOR_Y - 0.3, 0),
		Vector3.new(40, 0.6, WAGON_WIDTH),
		Enum.Material.WoodPlanks,
		P.WoodDark
	)
	local base = CFrame.new(cx, FLOOR_Y, 0)
	local color = Color3.fromRGB(70, 60, 50)
	Builder.wall(
		cargo,
		base * CFrame.new(0, 0, -WAGON_WIDTH / 2 + 0.3),
		40,
		4,
		0.6,
		Enum.Material.CorrodedMetal,
		color,
		{
			{ x = 0, width = 6, bottom = 0, top = 4 },
		}
	)
	Builder.wall(cargo, base * CFrame.new(0, 0, WAGON_WIDTH / 2 - 0.3), 40, 4, 0.6, Enum.Material.CorrodedMetal, color)
	for _, side in { -1, 1 } do
		Builder.wall(
			cargo,
			base * CFrame.new(side * 19.7, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
			WAGON_WIDTH - 1.2,
			4,
			0.6,
			Enum.Material.CorrodedMetal,
			color,
			{
				{ x = 0, width = 3.4, bottom = 0, top = 4 },
			}
		)
	end
	-- Diesel tank with a glowing level gauge
	Builder.part(
		cargo,
		CFrame.new(cx - 8, FLOOR_Y + 2.6, 2) * CFrame.Angles(0, 0, 0),
		Vector3.new(16, 4.4, 4.4),
		Enum.Material.Metal,
		Color3.fromRGB(60, 62, 64),
		{
			Shape = Enum.PartType.Cylinder,
		}
	)
	Builder.detail(
		cargo,
		CFrame.new(cx - 8, FLOOR_Y + 5, -0.25),
		Vector3.new(14, 0.6, 0.1),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(20, 20, 20)
	)
	gauge = Builder.detail(
		cargo,
		CFrame.new(cx - 15, FLOOR_Y + 5, -0.32),
		Vector3.new(0.05, 0.4, 0.05),
		Enum.Material.Neon,
		Color3.fromRGB(255, 120, 40)
	)
	gauge.Name = "DieselGauge"
	-- Crates
	for i = 1, 6 do
		Builder.part(
			cargo,
			CFrame.new(cx + 4 + (i % 3) * 4, FLOOR_Y + 1 + math.floor(i / 4) * 2, -1.5 + (i % 2) * 3.2),
			Vector3.new(3, 2, 2.6),
			Enum.Material.WoodPlanks,
			P.Military
		)
	end
end

function TrainService:Init()
	buildRailway()
	trainModel = Builder.model(workspace, "Train")
	buildPlatform(trainModel)
	buildHQ(trainModel)
	buildLocomotive(trainModel)
	buildCargo(trainModel)
	-- Gangways between wagons
	for _, x in { -22, 22 } do
		Builder.part(
			trainModel,
			CFrame.new(x, FLOOR_Y - 0.3, 0),
			Vector3.new(4.4, 0.6, 3.4),
			Enum.Material.DiamondPlate,
			P.MetalDark
		)
	end
end

function TrainService:IsInSafeZone(position: Vector3): boolean
	return position.X >= SAFE_MIN.X
		and position.X <= SAFE_MAX.X
		and position.Y >= SAFE_MIN.Y
		and position.Y <= SAFE_MAX.Y
		and position.Z >= SAFE_MIN.Z
		and position.Z <= SAFE_MAX.Z
end

function TrainService:GetSafeZone(): (Vector3, Vector3)
	return SAFE_MIN, SAFE_MAX
end

function TrainService:GetPlayerSpawn(index: number): CFrame
	local x = -15 + ((index - 1) % 7) * 5
	return CFrame.new(x, FLOOR_Y + 3, -1.5) * CFrame.Angles(0, math.pi / 2, 0)
end

function TrainService:GetPlatformSpawn(index: number): CFrame
	local x = -60 + ((index - 1) % 16) * 8
	return CFrame.new(x, 6, -11) * CFrame.Angles(0, math.pi, 0)
end

function TrainService:GetDepotPosition(): Vector3
	return Vector3.new(-44, 3.2, -10)
end

function TrainService:GetRallyPoint(index: number): Vector3
	-- Spread soldiers along the platform when they retreat
	local x = -58 + ((index - 1) % 14) * 8.5
	return Vector3.new(x, 3.2, -11)
end

function TrainService:SetMoving(moving: boolean)
	State.set("TrainMoving", moving)
end

function TrainService:PlayHorn(soundId: string?)
	if soundId and soundId ~= "" then
		horn.SoundId = soundId
		horn:Play()
	end
end

function TrainService:UpdateGauge(pool: number, needed: number)
	local fraction = if needed > 0 then math.clamp(pool / needed, 0, 1) else 1
	local width = math.max(0.05, 14 * fraction)
	gauge.Size = Vector3.new(width, 0.4, 0.05)
	gauge.CFrame = CFrame.new(-44 - 15 + width / 2, FLOOR_Y + 5, -0.32)
	gauge.Color = if fraction >= 1 then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(255, 120, 40)
end

function TrainService:GetLever(): BasePart
	return lever
end

return TrainService
