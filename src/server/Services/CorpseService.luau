-- Mauled remains. The server builds the geometry; the client adds the tape-glitch censor,
-- the pulsing of fresh bodies and the twitching (see CorpseController).
--
-- Parts named "Pulse" swell on fresh corpses, parts named "Twitch" jerk. Everything is
-- tagged "Corpse" with a FreshUntil attribute (server time).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local State = require(ReplicatedStorage.Shared.State)
local Builder = require(ServerScriptService.Server.World.Builder)

local CorpseService = {}

local folder: Folder
local order: { Model } = {}

local BONE = Color3.fromRGB(214, 200, 176)
local FLESH = Color3.fromRGB(96, 22, 20)
local FLESH_DARK = Color3.fromRGB(58, 10, 10)
local BLOOD = Color3.fromRGB(70, 6, 6)

export type Palette = { Skin: Color3, Cloth: Color3 }

function CorpseService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Corpses"
	folder.Parent = workspace
	State.set("CensorLevel", GameConfig.Censor.Level)
end

local function bloodEmitter(parent: BasePart, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Bleed"
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 8, 8), Color3.fromRGB(50, 0, 0))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.05) })
	emitter.Transparency = NumberSequence.new(0, 0.3)
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Drag = 1
	emitter.Parent = parent
	return emitter
end

-- Ribs and spine on top of an opened torso, all in local space of `torso`.
local function exposeRibcage(model: Model, torso: BasePart, rng: Random)
	local length = torso.Size.Z
	local spine = Builder.detail(
		model,
		torso.CFrame * CFrame.new(0, torso.Size.Y / 2 - 0.05, 0),
		Vector3.new(0.3, 0.3, length * 0.95),
		Enum.Material.SmoothPlastic,
		BONE
	)
	spine.Name = "Spine"
	local vertebrae = math.floor(length / 0.35)
	for i = 0, vertebrae - 1 do
		Builder.detail(
			model,
			torso.CFrame * CFrame.new(0, torso.Size.Y / 2 + 0.08, -length / 2 + 0.2 + i * 0.35),
			Vector3.new(0.42, 0.18, 0.18),
			Enum.Material.SmoothPlastic,
			BONE
		)
	end
	local pairs_ = 6
	for i = 1, pairs_ do
		local z = -length / 2 + 0.35 + (i - 1) * (length * 0.62 / pairs_)
		for _, side in { -1, 1 } do
			if rng:NextNumber() > 0.18 then
				local broken = rng:NextNumber() < 0.35
				local ribLength = if broken then rng:NextNumber(0.4, 0.7) else 0.95
				Builder.detail(
					model,
					torso.CFrame
						* CFrame.new(side * 0.42, torso.Size.Y / 2 + 0.05, z)
						* CFrame.Angles(0, 0, side * -0.5)
						* CFrame.new(side * ribLength / 2, 0.12, 0),
					Vector3.new(ribLength, 0.11, 0.12),
					Enum.Material.SmoothPlastic,
					BONE:Lerp(FLESH, rng:NextNumber(0.1, 0.35))
				)
			end
		end
	end
	-- Wet mass in the open chest; it pulses while the body is fresh
	local mass = Builder.detail(
		model,
		torso.CFrame * CFrame.new(0, torso.Size.Y / 2 - 0.1, length * 0.12),
		Vector3.new(torso.Size.X * 0.7, 0.45, length * 0.45),
		Enum.Material.Glass,
		FLESH,
		{
			Shape = Enum.PartType.Ball,
			Reflectance = 0.08,
		}
	)
	mass.Name = "Pulse"
end

-- Builds remains at `position`. `palette` comes from the victim.
function CorpseService:Create(position: Vector3, palette: Palette, seed: number?): Model
	local rng = Random.new(seed or math.random(1, 2 ^ 30))
	local model = Instance.new("Model")
	model.Name = "Remains"

	local ground = Vector3.new(position.X, math.max(position.Y - 2.8, 0), position.Z)
	local base = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	-- Torso lying on its back, uniform torn open
	local torso = Builder.detail(
		model,
		base * CFrame.new(0, 0.55, 0),
		Vector3.new(1.8, 0.9, 2.2),
		Enum.Material.Fabric,
		palette.Cloth:Lerp(FLESH_DARK, 0.35)
	)
	torso.Name = "Torso"
	exposeRibcage(model, torso, rng)

	-- Head, twisted at a wrong angle
	local head = Builder.detail(
		model,
		base
			* CFrame.new(rng:NextNumber(-0.3, 0.3), 0.55, -1.75)
			* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0.6, 1.4), rng:NextNumber(-0.3, 0.3)),
		Vector3.new(1.05, 1.05, 1.05),
		Enum.Material.SmoothPlastic,
		palette.Skin:Lerp(Color3.new(0.55, 0.5, 0.5), 0.35)
	)
	head.Name = "Twitch"

	-- Limbs: some still attached, some thrown aside, some missing
	local limbs = {
		{ CFrame.new(-1.25, 0.35, -0.6) * CFrame.Angles(0, 0.3, 0.2), Vector3.new(0.6, 0.6, 1.9) },
		{ CFrame.new(1.25, 0.35, -0.4) * CFrame.Angles(0, -0.5, -0.2), Vector3.new(0.6, 0.6, 1.9) },
		{ CFrame.new(-0.5, 0.4, 1.9) * CFrame.Angles(0, 0.15, 0), Vector3.new(0.75, 0.75, 2.2) },
		{ CFrame.new(0.5, 0.4, 1.9) * CFrame.Angles(0, -0.2, 0), Vector3.new(0.75, 0.75, 2.2) },
	}
	for index, limb in limbs do
		local roll = rng:NextNumber()
		if roll < 0.2 then
			continue -- missing; the stump bleeds
		end
		local cf = base * limb[1]
		if roll > 0.75 then
			-- torn off and dragged away
			local away = rng:NextNumber(2.5, 6)
			local angle = rng:NextNumber(0, math.pi * 2)
			cf = CFrame.new(ground + Vector3.new(math.cos(angle) * away, 0.35, math.sin(angle) * away))
				* CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			Builder.detail(
				model,
				cf * CFrame.new(0, 0, -limb[2].Z / 2 - 0.05),
				Vector3.new(limb[2].X * 0.9, limb[2].Y * 0.9, 0.12),
				Enum.Material.SmoothPlastic,
				FLESH
			)
			Builder.detail(
				model,
				cf * CFrame.new(0, 0, -limb[2].Z / 2 - 0.15),
				Vector3.new(0.18, 0.18, 0.35),
				Enum.Material.SmoothPlastic,
				BONE
			)
		end
		local part = Builder.detail(
			model,
			cf,
			limb[2],
			Enum.Material.Fabric,
			if index <= 2 then palette.Cloth else palette.Cloth:Lerp(Color3.new(0, 0, 0), 0.2)
		)
		if index <= 2 and rng:NextNumber() < 0.6 then
			part.Name = "Twitch"
		end
	end

	-- Chunks scattered around
	for _ = 1, rng:NextInteger(3, 7) do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(1.5, 5)
		Builder.detail(
			model,
			CFrame.new(ground + Vector3.new(math.cos(angle) * r, 0.12, math.sin(angle) * r))
				* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
			Vector3.new(rng:NextNumber(0.2, 0.5), rng:NextNumber(0.15, 0.3), rng:NextNumber(0.2, 0.6)),
			Enum.Material.Glass,
			FLESH:Lerp(FLESH_DARK, rng:NextNumber()),
			{
				Reflectance = 0.05,
			}
		)
	end

	-- Blood pool that spreads over a few seconds
	local pool = Builder.detail(
		model,
		CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.05, 1, 1),
		Enum.Material.Glass,
		BLOOD,
		{
			Shape = Enum.PartType.Cylinder,
			Reflectance = 0.12,
			CastShadow = false,
		}
	)
	pool.Name = "BloodPool"
	local poolSize = rng:NextNumber(6, 9)
	TweenService:Create(pool, TweenInfo.new(14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, poolSize, poolSize),
	}):Play()

	local now = State.now()
	local freshUntil = now + GameConfig.Corpses.FreshSeconds
	model:SetAttribute("FreshUntil", freshUntil)
	model:SetAttribute("Seed", rng:NextInteger(1, 2 ^ 30))
	model.PrimaryPart = torso

	local bleeding = { bloodEmitter(torso, 40), bloodEmitter(head, 8) }
	task.delay(GameConfig.Corpses.FreshSeconds, function()
		for _, emitter in bleeding do
			if emitter.Parent then
				emitter.Rate = 2
			end
		end
	end)

	model:AddTag("Corpse")
	model.Parent = folder

	table.insert(order, model)
	while #order > GameConfig.Corpses.MaxCorpses do
		local oldest = table.remove(order, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	return model
end

-- Reads skin and uniform colours from a character or soldier model.
function CorpseService:PaletteOf(model: Model): Palette
	local skin = Color3.fromRGB(200, 160, 130)
	local cloth = Color3.fromRGB(70, 78, 56)
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		skin = head.Color
	end
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		cloth = torso.Color
	end
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		skin = bodyColors.HeadColor3
		cloth = bodyColors.TorsoColor3
	end
	local shirt = model:FindFirstChildOfClass("Shirt")
	if shirt then
		cloth = cloth:Lerp(Color3.fromRGB(70, 70, 60), 0.5)
	end
	return { Skin = skin, Cloth = cloth }
end

function CorpseService:Clear()
	folder:ClearAllChildren()
	order = {}
end

return CorpseService
