-- Analogue tape filter painted over the picture: grain, scanlines, vignette, tracking band,
-- colour grading, and tearing that grows with fear. Also computes the Fear value (0..1)
-- used by audio and other effects.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Visuals = require(ReplicatedStorage.Shared.Config.Visuals)
local Settings = require(script.Parent.Parent.Settings)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer
local Tape = Visuals.Tape

local TapeController = {}
TapeController.Fear = 0

local gui: ScreenGui
local grainHolder: Frame
local scanHolder: Frame
local band: Frame
local tears: { Frame } = {}
local specks: { Frame } = {}
local vignette: { Frame } = {}
local grading: ColorCorrectionEffect
local blur: BlurEffect
local glitchUntil = 0
local glitchStrength = 0
local nextBand = 0
local intensity = 0

local function buildScanlines()
	scanHolder:ClearAllChildren()
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 1080
	for y = 0, height, Tape.ScanlineSpacing do
		Theme.new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1 - (1 - Tape.ScanlineTransparency) * intensity,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromOffset(0, y),
			Parent = scanHolder,
		})
	end
end

local function edge(anchor: Vector2, size: UDim2, position: UDim2, rotation: number)
	local frame = Theme.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AnchorPoint = anchor,
		Size = size,
		Position = position,
		Parent = gui,
	})
	Theme.new("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, Tape.VignetteTransparency),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = frame,
	})
	table.insert(vignette, frame)
end

local function applyIntensity()
	intensity = Tape.Intensity[Settings.Tape] or 0
	gui.Enabled = intensity > 0
	grading.Enabled = intensity > 0
	grading.Saturation = Tape.Saturation * intensity
	grading.Contrast = Tape.Contrast * intensity
	grading.TintColor = Color3.new(1, 1, 1):Lerp(Tape.Tint, intensity)
	for _, frame in vignette do
		frame.BackgroundTransparency = 1 - intensity
	end
	buildScanlines()
end

function TapeController:Init()
	gui = Theme.screen("Tape", 5, player:WaitForChild("PlayerGui"))
	gui.ScreenInsets = Enum.ScreenInsets.None

	scanHolder = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	grainHolder = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	for i = 1, Tape.GrainSpecks do
		local s = math.random(1, 3)
		table.insert(
			specks,
			Theme.new("Frame", {
				BackgroundColor3 = if i % 2 == 0 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0),
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(s, s),
				Parent = grainHolder,
			})
		)
	end

	edge(Vector2.new(0, 0), UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0), 90)
	edge(Vector2.new(0, 1), UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 1), -90)
	edge(Vector2.new(0, 0), UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0, 0), 0)
	edge(Vector2.new(1, 0), UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(1, 0), 180)

	band = Theme.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(230, 230, 220),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.035, 0),
		Position = UDim2.fromScale(0, -0.1),
		Parent = gui,
	})
	Theme.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.86),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = band,
	})

	for _ = 1, 6 do
		table.insert(
			tears,
			Theme.new("Frame", {
				BorderSizePixel = 0,
				Visible = false,
				Parent = gui,
			})
		)
	end

	grading = Instance.new("ColorCorrectionEffect")
	grading.Name = "TapeGrading"
	grading.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "FearBlur"
	blur.Size = 0
	blur.Parent = Lighting

	applyIntensity()
	Settings.Changed:Connect(function(key)
		if key == "Tape" then
			applyIntensity()
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(buildScanlines)
	end
end

-- Short burst of tearing, used when the radio carries a death.
function TapeController:RadioGlitch(duration: number)
	glitchUntil = math.max(glitchUntil, os.clock() + math.min(duration, 3))
	glitchStrength = math.max(glitchStrength, 0.6)
end

function TapeController:Glitch(duration: number, strength: number)
	glitchUntil = math.max(glitchUntil, os.clock() + duration)
	glitchStrength = math.max(glitchStrength, strength)
end

local function computeFear(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 0
	end
	local position = camera.Focus.Position
	local fear = 0
	for _, model in CollectionService:GetTagged("Monster") do
		if model:IsA("Model") and model.PrimaryPart then
			local d = (model.PrimaryPart.Position - position).Magnitude
			fear = math.max(fear, math.clamp(1 - (d - 8) / 60, 0, 1))
		end
	end
	return fear
end

function TapeController:Start()
	local lastGrain = 0
	RunService.RenderStepped:Connect(function(dt)
		local target = computeFear()
		self.Fear += (target - self.Fear) * math.min(1, dt * 2.5)
		local fear = self.Fear
		blur.Size = if fear > 0.75 then (fear - 0.75) * 10 else 0
		if intensity <= 0 then
			return
		end
		local now = os.clock()

		-- Grain
		if now - lastGrain > 1 / Tape.GrainFps then
			lastGrain = now
			local alpha = 0.55 + (1 - intensity) * 0.45 - fear * 0.2
			for _, speck in specks do
				speck.Position = UDim2.fromScale(math.random(), math.random())
				speck.BackgroundTransparency = math.clamp(alpha + math.random() * 0.35, 0, 1)
			end
			grading.Brightness = (math.random() - 0.5) * 0.015 * intensity
		end

		-- Tracking band rolling down now and then
		if now > nextBand then
			nextBand = now + math.random(Tape.TrackingBandEvery[1], Tape.TrackingBandEvery[2])
			band.Position = UDim2.fromScale(0, -0.05)
		end
		if band.Position.Y.Scale < 1.1 then
			band.Position = UDim2.fromScale(0, band.Position.Y.Scale + dt * 0.7)
		end

		-- Tearing: fear and radio bursts
		local glitching = now < glitchUntil or (fear > Tape.FearGlitchThreshold and math.random() < (fear - 0.5) * 0.25)
		local strength = math.max(if now < glitchUntil then glitchStrength else 0, fear * 0.7) * intensity
		if now >= glitchUntil then
			glitchStrength = 0
		end
		for _, tear in tears do
			if glitching and math.random() < 0.55 then
				tear.Visible = true
				tear.BackgroundColor3 = if math.random() < 0.5
					then Color3.fromRGB(240, 240, 235)
					else Color3.fromRGB(math.random(120, 255), 40, 40)
				tear.BackgroundTransparency = 1 - strength * math.random(25, 60) / 100
				tear.Size = UDim2.new(math.random(20, 100) / 100, 0, 0, math.random(2, 10))
				tear.Position = UDim2.new(math.random(-20, 60) / 100, 0, math.random(), 0)
			else
				tear.Visible = false
			end
		end
	end)
end

return TapeController
