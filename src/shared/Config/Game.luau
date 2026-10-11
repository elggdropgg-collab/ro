--!strict
-- Core match rules. Everything that defines the pacing of a run lives here.

local Game = {}

Game.MaxPlayers = 6

-- Lobby
Game.LobbyCountdown = 30 -- seconds after the first player is ready
Game.LobbyCountdownAllReady = 6 -- seconds once everybody is ready
Game.VoteDuration = 15

-- Run structure. "Finale" must be last.
Game.Locations = { "Field", "Finale" }

Game.LocationInfo = {
	Field = { StationKey = "Station_Field", DieselNeeded = 4, DuskSeconds = 7 * 60 },
	Finale = { StationKey = "Station_Finale", DieselNeeded = 0, DuskSeconds = 0 },
}

Game.DepartCountdown = 25
Game.TravelDuration = 16

-- Commander
Game.CommanderAfkSeconds = 60

-- Death and revival
Game.ReviveHoldSeconds = 4
Game.ReviveInvulnerability = 3
Game.SelfReviveInvulnerability = 10
Game.LastChanceSeconds = 15
Game.RescueHealth = 35 -- health a victim keeps when torn out of a monster's grip

-- Finale
Game.FusesNeeded = 3
Game.PortalChargeSeconds = 45

-- End of run
Game.EndScreenSeconds = 25
Game.Rewards = {
	Participation = 20,
	PerLocation = 30,
	Escape = 120,
	PerSurvivingSoldier = 5,
}

Game.Player = {
	MaxHealth = 100,
	WalkSpeed = 14,
	SprintSpeed = 22,
	StaminaSeconds = 6,
	StaminaRegenPerSecond = 0.22, -- fraction of the bar per second
	CarrySpeedMultiplier = 0.8,
}

Game.Corpses = {
	FreshSeconds = 60,
	MaxCorpses = 28,
}

-- How strongly gore is hidden. 1 = light interference, 3 = almost fully covered.
-- Players can raise it in settings, never lower it below this value.
Game.Censor = {
	Level = 2,
	MinLevel = 1,
	MaxLevel = 3,
}

return Game
