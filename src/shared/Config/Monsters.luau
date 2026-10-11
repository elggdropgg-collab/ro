--!strict
-- Monster definitions. Every location has exactly one immortal monster that can only be stunned.
-- In the finale every immortal from earlier stations returns and becomes killable.

export type MonsterDef = {
	DisplayKey: string,
	Immortal: boolean,
	MaxHealth: number,
	FinaleHealth: number?,
	WalkSpeed: number,
	HuntSpeed: number,
	DetectRange: number,
	ConcealedDetectRange: number,
	GrabRange: number,
	KillDuration: number,
	FeedDuration: number,
	ReleaseDamage: number,
	StunThreshold: number,
	StunDuration: number,
	KillRecipe: string,
	SoldierPreference: number,
}

local Monsters: { [string]: MonsterDef } = {
	-- Immortal of the wheat field. Moves only when nobody is looking at it.
	Scarecrow = {
		DisplayKey = "Monster_Scarecrow",
		Immortal = true,
		MaxHealth = math.huge,
		FinaleHealth = 1400,
		WalkSpeed = 9,
		HuntSpeed = 34,
		DetectRange = 150,
		ConcealedDetectRange = 60,
		GrabRange = 6.5,
		KillDuration = 4.8,
		FeedDuration = 3.5,
		ReleaseDamage = math.huge,
		StunThreshold = 140,
		StunDuration = 8,
		KillRecipe = "ScarecrowKill",
		SoldierPreference = 1.6,
	},
	-- Blind crawler that nests in the wheat and hunts by sound.
	Husk = {
		DisplayKey = "Monster_Husk",
		Immortal = false,
		MaxHealth = 70,
		WalkSpeed = 10,
		HuntSpeed = 22,
		DetectRange = 70,
		ConcealedDetectRange = 22,
		GrabRange = 5,
		KillDuration = 3.8,
		FeedDuration = 4,
		ReleaseDamage = 30,
		StunThreshold = 40,
		StunDuration = 2.5,
		KillRecipe = "HuskKill",
		SoldierPreference = 1.3,
	},
}

local Spawning = {
	FieldNests = 4,
	HusksPerNest = 2,
	NestRespawnSeconds = 75,
	NestMinDistanceFromTrain = 150,
	FinaleHusks = 8,
	SiegeHusks = 10,
	CleanupReinforcements = 10,
	ImmortalByLocation = {
		Field = "Scarecrow",
	},
}

return {
	Defs = Monsters,
	Spawning = Spawning,
	-- How loud actions are, in studs of hearing radius. Blind monsters rely on this.
	Noise = {
		Gunshot = 120,
		Sprint = 1.5,
		Walk = 1,
		Still = 0.4,
	},
}
