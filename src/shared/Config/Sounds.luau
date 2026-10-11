--!strict
-- Sound library and layered recipes. See docs/SOUND_DESIGN.md for what every slot must sound like.
--
-- Every slot holds several variants ("rbxassetid://..."). Empty slots are skipped silently,
-- so the game runs before the sounds are uploaded. Never use a single variant for kill
-- sounds: repetition is what makes horror audio feel cheap.

export type Range = { number }

export type Layer = {
	Slot: string,
	At: number | Range, -- seconds from the start of the recipe
	Volume: number?,
	Pitch: Range?,
	Repeat: number?,
	Gap: Range?, -- seconds between repeats
	Channel: string?, -- "World" (3D at the victim), "Radio" (squad radio), "Self" (2D, only for the victim)
}

export type Recipe = {
	Duration: number,
	Layers: { Layer },
	DuckAmbient: boolean?,
}

local Library: { [string]: { string } } = {
	-- Victim voice
	ScreamAgony = {}, -- long, rough, breaking scream of a man being torn apart
	ScreamPanic = {}, -- short "NO! NO!" type panic shouts
	ScreamChoked = {}, -- scream cut off by blood in the throat
	Gurgle = {}, -- wet breathing / drowning in blood
	DyingBreath = {}, -- last rattling exhale
	Whimper = {}, -- quiet crying, begging

	-- Body
	BoneCrunch = {}, -- dense snaps: ribs, limbs
	BoneGrind = {}, -- slow grinding twist of a joint
	FleshTear = {}, -- wet ripping of skin and muscle
	WetSquelch = {}, -- hands / jaws inside a body
	BloodSplatter = {}, -- liquid hitting dirt and wheat
	BloodDrip = {}, -- slow drips, loopable
	BodyDrop = {}, -- heavy limp body hitting the ground
	ClothRip = {}, -- uniform being torn

	-- Monsters
	ScarecrowCreak = {}, -- dry wood and straw creaking
	ScarecrowBreath = {}, -- muffled breathing inside a burlap sack
	ScarecrowLurch = {}, -- fast rustle of straw when it moves unseen
	HuskClick = {}, -- echolocation clicks
	HuskShriek = {}, -- attack shriek
	MonsterChew = {}, -- rhythmic chewing that goes on after the screams stop
	MonsterGrowlLow = {}, -- sub-heavy growl while feeding

	-- Radio
	RadioKeyUp = {}, -- push-to-talk click
	RadioKeyDown = {}, -- release click + squelch tail
	RadioStatic = {}, -- static bursts
	RadioVoiceContact = {}, -- "Contact!", "It's here!"
	RadioVoiceGrabbed = {}, -- "It's got me! Help!"
	RadioVoiceLost = {}, -- "Where is he?", "Novak? Novak!"

	-- Weapons
	RifleShot = {},
	PistolShot = {},
	PistolDry = {},
	PistolReload = {},

	-- Player feedback
	Heartbeat = {},
	Tinnitus = {},
	ScareStinger = {},
	Whisper = {},
	FootstepWheat = {},
	FootstepHeavy = {},

	-- Ambience (looped)
	AmbientFieldWind = {},
	AmbientFieldCrickets = {},
	AmbientNight = {},
	AmbientTrainInterior = {},
	TrainRolling = {},
	TrainHorn = {},
	TrainBrakes = {},
	PortalHum = {},
}

local Recipes: { [string]: Recipe } = {
	-- Arc: surprise -> begging -> peak of pain -> scream cut by crunch -> choking -> silence -> it is still eating.
	ScarecrowKill = {
		Duration = 8.5,
		DuckAmbient = true,
		Layers = {
			{ Slot = "ScarecrowLurch", At = 0, Volume = 0.9 },
			{ Slot = "ScreamPanic", At = 0.05, Volume = 1, Pitch = { 0.95, 1.05 } },
			{ Slot = "RadioKeyUp", At = 0.1, Channel = "Radio" },
			{ Slot = "RadioVoiceGrabbed", At = 0.2, Channel = "Radio", Pitch = { 0.97, 1.03 } },
			{ Slot = "ClothRip", At = 0.7, Volume = 0.8 },
			{ Slot = "ScreamAgony", At = 0.9, Volume = 1, Pitch = { 0.92, 1.04 } },
			{ Slot = "ScreamAgony", At = 1.0, Volume = 1, Pitch = { 0.9, 1 }, Channel = "Radio" },
			{ Slot = "BoneGrind", At = 1.3, Volume = 0.9, Pitch = { 0.85, 0.95 } },
			{
				Slot = "BoneCrunch",
				At = { 2.0, 2.4 },
				Volume = 1,
				Pitch = { 0.8, 1 },
				Repeat = 3,
				Gap = { 0.18, 0.45 },
			},
			{ Slot = "FleshTear", At = 2.6, Volume = 1, Pitch = { 0.85, 1 } },
			{ Slot = "ScreamChoked", At = 2.9, Volume = 1 },
			{ Slot = "RadioStatic", At = 3.0, Channel = "Radio", Volume = 0.8 },
			{ Slot = "BloodSplatter", At = 3.1, Volume = 0.8 },
			{ Slot = "Gurgle", At = 3.6, Volume = 0.9 },
			{ Slot = "WetSquelch", At = { 4.0, 4.3 }, Volume = 0.8, Repeat = 2, Gap = { 0.5, 0.9 } },
			{ Slot = "DyingBreath", At = 4.6, Volume = 0.7 },
			{ Slot = "BodyDrop", At = 4.8, Volume = 1 },
			{ Slot = "RadioKeyDown", At = 4.9, Channel = "Radio" },
			{ Slot = "ScarecrowBreath", At = 5.4, Volume = 0.6 },
			{ Slot = "MonsterChew", At = 5.6, Volume = 0.8, Repeat = 3, Gap = { 0.7, 1.1 } },
		},
	},
	HuskKill = {
		Duration = 8,
		DuckAmbient = true,
		Layers = {
			{ Slot = "HuskShriek", At = 0, Volume = 1, Pitch = { 0.9, 1.1 } },
			{ Slot = "ScreamPanic", At = 0.15, Volume = 1, Pitch = { 0.95, 1.06 } },
			{ Slot = "RadioKeyUp", At = 0.2, Channel = "Radio" },
			{ Slot = "RadioVoiceGrabbed", At = 0.3, Channel = "Radio" },
			{ Slot = "FleshTear", At = 0.6, Volume = 1, Pitch = { 0.95, 1.1 } },
			{ Slot = "ScreamAgony", At = 0.8, Volume = 1, Pitch = { 0.95, 1.08 } },
			{ Slot = "ScreamAgony", At = 0.9, Volume = 1, Channel = "Radio" },
			{ Slot = "WetSquelch", At = { 1.2, 1.5 }, Volume = 1, Repeat = 3, Gap = { 0.2, 0.35 } },
			{ Slot = "BoneCrunch", At = 2.0, Volume = 1, Pitch = { 0.9, 1.1 }, Repeat = 2, Gap = { 0.3, 0.6 } },
			{ Slot = "ScreamChoked", At = 2.6, Volume = 1 },
			{ Slot = "RadioStatic", At = 2.7, Channel = "Radio", Volume = 0.8 },
			{ Slot = "Gurgle", At = 3.0, Volume = 0.9 },
			{ Slot = "BodyDrop", At = 3.8, Volume = 0.9 },
			{ Slot = "RadioKeyDown", At = 3.9, Channel = "Radio" },
			{ Slot = "MonsterGrowlLow", At = 4.2, Volume = 0.8 },
			{ Slot = "MonsterChew", At = 4.4, Volume = 0.9, Repeat = 4, Gap = { 0.45, 0.8 } },
		},
	},
	-- Played only for the victim on top of the world recipe.
	PlayerKilledSelf = {
		Duration = 6,
		Layers = {
			{ Slot = "Heartbeat", At = 0, Volume = 1, Channel = "Self" },
			{ Slot = "Tinnitus", At = 2.4, Volume = 0.7, Channel = "Self" },
			{ Slot = "DyingBreath", At = 3.8, Volume = 1, Channel = "Self" },
		},
	},
	-- A soldier abandoned outside when the train leaves.
	LeftBehind = {
		Duration = 5,
		Layers = {
			{ Slot = "RadioKeyUp", At = 0, Channel = "Radio" },
			{ Slot = "RadioVoiceLost", At = 0.1, Channel = "Radio" },
			{ Slot = "ScreamPanic", At = 1.4, Channel = "Radio" },
			{ Slot = "ScreamAgony", At = 2.2, Channel = "Radio" },
			{ Slot = "RadioStatic", At = 3.6, Channel = "Radio" },
			{ Slot = "RadioKeyDown", At = 4.4, Channel = "Radio" },
		},
	},
	Contact = {
		Duration = 1.6,
		Layers = {
			{ Slot = "RadioKeyUp", At = 0, Channel = "Radio" },
			{ Slot = "RadioVoiceContact", At = 0.1, Channel = "Radio" },
			{ Slot = "RadioKeyDown", At = 1.4, Channel = "Radio" },
		},
	},
	Scare = {
		Duration = 2.5,
		Layers = {
			{ Slot = "ScareStinger", At = 0, Volume = 1, Channel = "Self" },
			{ Slot = "Tinnitus", At = 0.6, Volume = 0.5, Channel = "Self" },
		},
	},
}

return {
	Library = Library,
	Recipes = Recipes,
	-- Beyond this distance a squad death is heard through the radio instead of directly.
	RadioDistance = 70,
	-- 3D sounds are inaudible past this distance.
	WorldMaxDistance = 260,
}
