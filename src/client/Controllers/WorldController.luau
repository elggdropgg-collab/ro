-- World dressing on the client: station signs, flickering lamps, tracers and muzzle flashes,
-- and the sensation of travel (camera sway, scenery rushing past, thick fog).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Lang = require(script.Parent.Parent.Lang)
local Theme = require(script.Parent.Parent.UI.Theme)
local Registry = require(script.Parent.Parent.Registry)

local player = Players.LocalPlayer

local WorldController = {}

local signs: { [BasePart]: TextLabel } = {}
local scenery: { BasePart } = {}
local travelling = false

local function signFor(part: BasePart)
	if signs[part] then
		return
	end
	local gui = Theme.new("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0.3,
		Parent = part,
	})
	local label = Theme.label({
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(235, 232, 220),
		FontFace = Theme.Fonts.Header,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = gui,
	})
	Theme.padding(label, 8)
	signs[part] = label
	label.Text = Lang.t(State.get("StationKey") or "Station_Lobby")
end

local function flicker(part: BasePart)
	local light = part:FindFirstChildWhichIsA("Light")
	if not light then
		return
	end
	local base = (light :: any).Brightness
	task.spawn(function()
		while part.Parent do
			task.wait(math.random(15, 80) / 10)
			for _ = 1, math.random(2, 6) do
				if not part.Parent then
					return
				end
				(light :: any).Brightness = base * math.random(0, 40) / 100
				part.Transparency = 0.6
				task.wait(math.random(3, 12) / 100);
				(light :: any).Brightness = base
				part.Transparency = 0
				task.wait(math.random(3, 15) / 100)
			end
		end
	end)
end

local function tracer(origin: Vector3, hit: Vector3, kind: string)
	local length = (hit - origin).Magnitude
	if length < 0.5 then
		return
	end
	local color = if kind == "Super" then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(255, 214, 150)
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(0.06, 0.06, length)
	beam.CFrame = CFrame.lookAt(origin, hit) * CFrame.new(0, 0, -length / 2)
	beam.Transparency = 0.35
	beam.Parent = workspace.Terrain
	TweenService:Create(beam, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	Debris:AddItem(beam, 0.15)

	local flash = Instance.new("Attachment")
	flash.WorldPosition = origin
	flash.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 4
	light.Parent = flash
	Debris:AddItem(flash, 0.06)

	if kind == "Pistol" then
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if not head or (head.Position - origin).Magnitude > 3 then
			Registry.AudioController:PlayAt("PistolShot", origin, 1, math.random(95, 105) / 100)
		end
	end
end

local function spawnScenery()
	local rng = Random.new()
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local kind = rng:NextNumber()
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Wood
	part.Color = Color3.fromRGB(40, 34, 30)
	if kind < 0.6 then
		part.Size = Vector3.new(0.6, 14, 0.6) -- telegraph pole
	elseif kind < 0.85 then
		part.Size = Vector3.new(1.4, rng:NextNumber(12, 22), 1.4) -- dead tree
	else
		part.Size = Vector3.new(4, 0.6, 0.4) -- broken fence
	end
	part.CFrame = CFrame.new(320, part.Size.Y / 2, side * rng:NextNumber(12, 40))
	part.Parent = workspace.Terrain
	table.insert(scenery, part)
end

function WorldController:Init()
	for _, part in CollectionService:GetTagged("StationSign") do
		signFor(part)
	end
	CollectionService:GetInstanceAddedSignal("StationSign"):Connect(signFor)
	for _, part in CollectionService:GetTagged("Flicker") do
		flicker(part)
	end
	CollectionService:GetInstanceAddedSignal("Flicker"):Connect(flicker)

	State.observe("StationKey", function(key)
		for _, label in signs do
			label.Text = Lang.t(key or "Station_Lobby")
		end
	end)
	Net.event("Tracer").OnClientEvent:Connect(tracer)
end

function WorldController:Start()
	State.observe("TrainMoving", function(moving)
		travelling = moving == true
		if not travelling then
			for _, part in scenery do
				part:Destroy()
			end
			scenery = {}
		end
	end)

	local spawnTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		if not travelling then
			return
		end
		spawnTimer -= dt
		if spawnTimer <= 0 then
			spawnTimer = math.random(25, 70) / 100
			spawnScenery()
		end
		for i = #scenery, 1, -1 do
			local part = scenery[i]
			part.CFrame -= Vector3.new(70 * dt, 0, 0)
			if part.Position.X < -320 then
				part:Destroy()
				table.remove(scenery, i)
			end
		end
	end)

	-- Wagon sway while moving
	local t = 0
	RunService:BindToRenderStep("TrainSway", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not travelling then
			return
		end
		t += dt
		local camera = workspace.CurrentCamera
		if camera then
			local roll = math.sin(t * 1.7) * 0.006 + math.sin(t * 11) * 0.0015
			local bump = math.noise(t * 6, 0, 0) * 0.04
			camera.CFrame *= CFrame.new(0, bump, 0) * CFrame.Angles(0, 0, roll)
		end
	end)
end

return WorldController
