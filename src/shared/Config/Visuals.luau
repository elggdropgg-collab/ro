--!strict
-- Lighting presets per station and the analogue tape filter applied over the picture.

export type LightingPreset = {
	ClockStart: number,
	ClockEnd: number,
	BrightnessStart: number,
	BrightnessEnd: number,
	Ambient: Color3,
	OutdoorAmbientStart: Color3,
	OutdoorAmbientEnd: Color3,
	AtmosphereDensityStart: number,
	AtmosphereDensityEnd: number,
	AtmosphereColorStart: Color3,
	AtmosphereColorEnd: Color3,
	AtmosphereDecay: Color3,
	Haze: number,
	Glare: number,
	ExposureCompensation: number,
}

local Presets: { [string]: LightingPreset } = {
	Lobby = {
		ClockStart = 17.9,
		ClockEnd = 17.9,
		BrightnessStart = 1.6,
		BrightnessEnd = 1.6,
		Ambient = Color3.fromRGB(28, 26, 30),
		OutdoorAmbientStart = Color3.fromRGB(96, 84, 78),
		OutdoorAmbientEnd = Color3.fromRGB(96, 84, 78),
		AtmosphereDensityStart = 0.42,
		AtmosphereDensityEnd = 0.42,
		AtmosphereColorStart = Color3.fromRGB(170, 150, 135),
		AtmosphereColorEnd = Color3.fromRGB(170, 150, 135),
		AtmosphereDecay = Color3.fromRGB(92, 70, 64),
		Haze = 2.2,
		Glare = 0.4,
		ExposureCompensation = -0.1,
	},
	-- Golden dusk sinking into night over the duration of the station.
	Field = {
		ClockStart = 17.6,
		ClockEnd = 20.4,
		BrightnessStart = 2.2,
		BrightnessEnd = 0.35,
		Ambient = Color3.fromRGB(22, 20, 24),
		OutdoorAmbientStart = Color3.fromRGB(128, 104, 82),
		OutdoorAmbientEnd = Color3.fromRGB(34, 38, 52),
		AtmosphereDensityStart = 0.36,
		AtmosphereDensityEnd = 0.5,
		AtmosphereColorStart = Color3.fromRGB(214, 176, 124),
		AtmosphereColorEnd = Color3.fromRGB(70, 78, 98),
		AtmosphereDecay = Color3.fromRGB(110, 70, 52),
		Haze = 1.8,
		Glare = 0.6,
		ExposureCompensation = 0,
	},
	-- Between stations: night, thick fog, only the train lights.
	Travel = {
		ClockStart = 22,
		ClockEnd = 22,
		BrightnessStart = 0.3,
		BrightnessEnd = 0.3,
		Ambient = Color3.fromRGB(18, 18, 22),
		OutdoorAmbientStart = Color3.fromRGB(30, 32, 40),
		OutdoorAmbientEnd = Color3.fromRGB(30, 32, 40),
		AtmosphereDensityStart = 0.72,
		AtmosphereDensityEnd = 0.72,
		AtmosphereColorStart = Color3.fromRGB(40, 44, 54),
		AtmosphereColorEnd = Color3.fromRGB(40, 44, 54),
		AtmosphereDecay = Color3.fromRGB(30, 30, 36),
		Haze = 3,
		Glare = 0,
		ExposureCompensation = 0,
	},
	Finale = {
		ClockStart = 0.4,
		ClockEnd = 0.4,
		BrightnessStart = 0.6,
		BrightnessEnd = 0.6,
		Ambient = Color3.fromRGB(14, 14, 20),
		OutdoorAmbientStart = Color3.fromRGB(40, 46, 66),
		OutdoorAmbientEnd = Color3.fromRGB(40, 46, 66),
		AtmosphereDensityStart = 0.46,
		AtmosphereDensityEnd = 0.46,
		AtmosphereColorStart = Color3.fromRGB(62, 70, 92),
		AtmosphereColorEnd = Color3.fromRGB(62, 70, 92),
		AtmosphereDecay = Color3.fromRGB(40, 24, 30),
		Haze = 2.4,
		Glare = 0,
		ExposureCompensation = 0.15,
	},
}

-- Analogue tape look painted over a high quality picture. Kept subtle on purpose:
-- it should make the image feel like found footage, never look low quality.
local Tape = {
	Intensity = { 0, 0.55, 1 }, -- settings: Off, Normal, Strong
	DefaultIntensity = 2,
	GrainSpecks = 140,
	GrainFps = 24,
	ScanlineSpacing = 3,
	ScanlineTransparency = 0.94,
	Saturation = -0.18,
	Contrast = 0.14,
	Tint = Color3.fromRGB(255, 244, 232),
	VignetteTransparency = 0.25,
	TrackingBandEvery = { 7, 18 },
	FearGlitchThreshold = 0.6,
}

-- Censor overlay for corpses, by censor level.
local Censor = {
	[1] = { BlockTransparency = 0.6, Blocks = 6, DepthOfField = 0.35 },
	[2] = { BlockTransparency = 0.32, Blocks = 8, DepthOfField = 0.6 },
	[3] = { BlockTransparency = 0.06, Blocks = 10, DepthOfField = 0.9 },
}

-- Full screen scare images. Upload your own and paste the IDs.
local ScareImages: { string } = {}

return {
	Presets = Presets,
	Tape = Tape,
	Censor = Censor,
	ScareImages = ScareImages,
}
