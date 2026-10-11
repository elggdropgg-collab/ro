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

local Uploaded = require(script.Parent.UploadedSounds)

local function ids(...: number): { string }
	local list = {}
	for _, id in { ... } do
		table.insert(list, `rbxassetid://{id}`)
	end
	return list
end

-- Library IDs come from Roblox's licensed Pro Sound Effects and APM catalogues (free to use in
-- any experience; find more with tools/find-sounds.ps1). Our own recordings in assets/sounds
-- are uploaded by tools/upload-sounds.ps1 and merged in below.
local Library: { [string]: { string } } = {
	-- Victim voice
	ScreamAgony = ids(9116454870, 9116454942, 9116454961, 9116455473, 9116455235, 9116455270), -- long, rough, breaking scream of a man being torn apart
	ScreamPanic = ids(9125652432, 9125652466, 9125652949, 9125652443, 9125651079), -- short "NO! NO!" type panic shouts
	ScreamChoked = ids(9113800064, 9113799288, 9114554185), -- scream cut off by blood in the throat
	Gurgle = ids(9120005520, 9113607285, 9113607822, 9114553939, 9114554180), -- wet breathing / drowning in blood
	DyingBreath = ids(9114030325, 9114030468, 9114030538, 9114029940, 9114556462), -- last rattling exhale
	Whimper = ids(9113997425, 9113996923, 9113996266, 9113996672, 9113996278), -- quiet crying, begging

	-- Body
	BoneCrunch = ids(9113540932, 9113540587, 9113542386, 9113542363, 9113546532, 9119559518, 9119559825), -- dense snaps: ribs, limbs
	BoneGrind = ids(9119560180, 9119559740, 9119558965, 9119559515, 9113734831), -- slow grinding twist of a joint
	FleshTear = ids(9114487557), -- wet ripping of skin and muscle
	WetSquelch = ids(9114447775, 9114631768), -- hands / jaws inside a body
	BloodSplatter = ids(9114741191, 9114741340, 9114741339, 9113464573, 9113464577), -- liquid hitting dirt and wheat
	BloodDrip = ids(9113464190, 9113464198, 9113463629, 9113463758), -- slow drips, loopable
	BodyDrop = ids(9113470020, 9113470969, 9113469292, 9113475819, 9113477342), -- heavy limp body hitting the ground
	ClothRip = ids(9113835765, 9113836102, 9113836369, 9113827650, 9113828679), -- uniform being torn

	-- Monsters
	ScarecrowCreak = ids(9120839010, 9120839174, 9120839364, 9126263691, 9125407239), -- dry wood and straw creaking
	ScarecrowBreath = ids(9113983944, 9113984054, 9113984056), -- muffled breathing inside a burlap sack
	ScarecrowLurch = ids(9114518560, 9114518077, 9114518070, 9114518245), -- fast rustle of straw when it moves unseen
	HuskClick = ids(9126135650, 9126135440, 9126135811, 9126136331, 9120442381), -- echolocation clicks
	HuskShriek = ids(9125474863, 9125474518, 9125474560, 9125475139, 9125478014), -- attack shriek
	MonsterChew = ids(9113991729, 9113991859), -- rhythmic chewing that goes on after the screams stop
	MonsterGrowlLow = ids(9113971433, 9113971531, 9113972334, 9114628321, 9114628818, 9113980319), -- sub-heavy growl while feeding

	-- Radio
	RadioKeyUp = ids(9120456889, 9120456241, 9119730203), -- push-to-talk click
	RadioKeyDown = {}, -- release click + squelch tail
	RadioStatic = ids(9118026602, 9118027586, 9117158538), -- static bursts
	RadioVoiceContact = {}, -- "Contact!", "It's here!"
	RadioVoiceGrabbed = ids(9125653237, 9125653241, 9125651857), -- "It's got me! Help!"
	RadioVoiceLost = {}, -- "Where is he?", "Novak? Novak!"
	RadioSquadAttacked = {}, -- whole fight heard over the radio: burst, scream, hit, scream, crunch

	-- Weapons
	RifleShot = ids(9114726684, 9114727096, 9114729252, 9114729298, 9114727430),
	PistolShot = ids(9117399029, 9117399285, 9117402631, 9117398126, 9117400892),
	PistolDry = ids(9119717523),
	PistolReload = ids(9113104176, 9113104208, 9113104337),

	-- Player feedback
	Heartbeat = ids(9043365842),
	Tinnitus = {},
	ScareStinger = ids(9047014318, 9047014546, 9047014561, 9125404320),
	Whisper = ids(9126213995, 9126213744, 9126214616, 9126214321, 9114228524),
	FootstepWheat = ids(9114518077, 9114518070, 9114518245),
	FootstepHeavy = ids(9114523345, 9118686853, 9118688024, 9118768193),

	-- Ambience (looped)
	AmbientFieldWind = ids(9113286969, 9114057128),
	AmbientFieldCrickets = ids(9112764546, 9112764558, 9112764573),
	AmbientNight = ids(9112835862, 9112836038, 9112835836),
	AmbientTrainInterior = ids(9113117328, 9113116638),
	TrainRolling = ids(9114075238, 9116330488),
	TrainHorn = ids(9120248414, 9120249206),
	TrainBrakes = {},
	PortalHum = ids(9125566998, 9125566994, 9114031637),
}

-- Our own recordings are extra variants on top of the library ones
for slot, list in Uploaded do
	local merged = table.clone(list)
	local existing: { string } = Library[slot] or {}
	for _, id in existing do
		table.insert(merged, id)
	end
	Library[slot] = merged
end

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
			{ Slot = "RadioSquadAttacked", At = 0.35, Channel = "Radio", Volume = 0.9, Pitch = { 0.96, 1.04 } },
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
			{ Slot = "RadioSquadAttacked", At = 0.4, Channel = "Radio", Volume = 0.9, Pitch = { 0.96, 1.04 } },
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
		Duration = 7,
		Layers = {
			{ Slot = "RadioKeyUp", At = 0, Channel = "Radio" },
			{ Slot = "RadioVoiceLost", At = 0.1, Channel = "Radio" },
			{ Slot = "RadioSquadAttacked", At = 1.0, Channel = "Radio", Volume = 0.8 },
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
