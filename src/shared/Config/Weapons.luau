--!strict
-- The player's sidearm. Ammo is deliberately scarce: running and hiding is the main tool.

export type WeaponLevel = {
	Damage: number,
	Stun: number,
	Magazine: number,
	Reserve: number,
	Cost: number, -- coins to reach this level
}

local Levels: { WeaponLevel } = {
	{ Damage = 22, Stun = 18, Magazine = 6, Reserve = 6, Cost = 0 },
	{ Damage = 26, Stun = 22, Magazine = 6, Reserve = 9, Cost = 150 },
	{ Damage = 30, Stun = 27, Magazine = 7, Reserve = 10, Cost = 320 },
	{ Damage = 35, Stun = 33, Magazine = 8, Reserve = 12, Cost = 600 },
	{ Damage = 42, Stun = 40, Magazine = 8, Reserve = 14, Cost = 1000 },
}

return {
	Levels = Levels,
	FireInterval = 0.42,
	ReloadSeconds = 1.8,
	Range = 160,
	SpreadDegrees = 0.8,
}
