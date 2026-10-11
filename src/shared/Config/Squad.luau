--!strict
-- The fodder: the shared squad that the commander sends ahead of the players.

local Squad = {}

-- The run starts with no soldiers: players haul scrap to the train and recruit them.
Squad.MaxSize = 16
Squad.ExtraSquadSize = 4
Squad.RecruitScrapCost = 2

Squad.Orders = {
	Follow = "Follow",
	Route = "Route",
	Wander = "Wander",
	Gather = "Gather",
	Hold = "Hold",
	Retreat = "Retreat",
	Revive = "Revive",
}

Squad.MaxRouteWaypoints = 32

-- Assault rifles fire in bursts: BurstSize shots FireInterval apart, then BurstPause.
Squad.Kinds = {
	Regular = {
		MaxHealth = 100,
		WalkSpeed = 13,
		RunSpeed = 19,
		Ammo = 48,
		Damage = 7,
		StunPower = 3.5,
		FireInterval = 0.1,
		BurstSize = 4,
		BurstPause = { 0.75, 1.1 },
		Range = 85,
		SpreadDegrees = 2.8,
	},
	Super = {
		MaxHealth = 450,
		WalkSpeed = 17,
		RunSpeed = 21,
		Ammo = math.huge,
		Damage = 30,
		StunPower = 24,
		FireInterval = 0.09,
		BurstSize = 8,
		BurstPause = { 0.4, 0.6 },
		Range = 140,
		SpreadDegrees = 1.4,
	},
}

Squad.SuperSquadSize = 8

Squad.PickupRange = 6
Squad.DepositRange = 10
Squad.ViewRange = 110
Squad.WanderRadius = 110
Squad.GatherSearchRadius = 220
Squad.FollowSpacing = 5
Squad.PanicDistance = 28
Squad.AmmoRefillPerSupply = 48

Squad.CarrySpeedMultiplier = 0.8

Squad.Names = {
	"Novak",
	"Petrov",
	"Miller",
	"Reyes",
	"Sato",
	"Kowalski",
	"Okafor",
	"Lindqvist",
	"Moreau",
	"Volkov",
	"Hart",
	"Brennan",
	"Duarte",
	"Ivanov",
	"Kessler",
	"Marsh",
	"Orlov",
	"Quinn",
	"Romero",
	"Tanaka",
	"Vance",
	"Weber",
	"Yilmaz",
	"Zielinski",
	"Abbott",
	"Barros",
	"Cole",
	"Dvorak",
	"Esposito",
	"Frost",
}

-- Default Roblox R15 animations. Replace with custom military animations later.
Squad.Animations = {
	Idle = "rbxassetid://507766388",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Hold = "rbxassetid://507768375", -- R15 "toolnone": right arm raised, weapon forward
}

-- Optional classic clothing. 0 = use flat uniform colours.
Squad.Outfit = {
	Shirt = 0,
	Pants = 0,
	Uniform = Color3.fromRGB(74, 82, 58),
	UniformDark = Color3.fromRGB(52, 57, 42),
	SuperUniform = Color3.fromRGB(24, 25, 28),
	SkinTones = {
		Color3.fromRGB(234, 192, 160),
		Color3.fromRGB(204, 152, 115),
		Color3.fromRGB(160, 110, 78),
		Color3.fromRGB(110, 72, 50),
		Color3.fromRGB(245, 210, 185),
	},
}

return Squad
