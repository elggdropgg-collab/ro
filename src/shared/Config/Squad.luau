--!strict
-- The fodder: the shared squad that the commander sends ahead of the players.

local Squad = {}

Squad.BaseSize = 3
Squad.PerPlayer = 2
Squad.MaxSize = 16
Squad.ExtraSquadSize = 4
Squad.RecruitScrapCost = 4

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

Squad.Kinds = {
	Regular = {
		MaxHealth = 100,
		WalkSpeed = 13,
		RunSpeed = 19,
		Ammo = 24,
		Damage = 12,
		StunPower = 6,
		FireInterval = 0.55,
		Range = 85,
		SpreadDegrees = 2.4,
	},
	Super = {
		MaxHealth = 450,
		WalkSpeed = 17,
		RunSpeed = 21,
		Ammo = math.huge,
		Damage = 38,
		StunPower = 30,
		FireInterval = 0.18,
		Range = 140,
		SpreadDegrees = 1.2,
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
Squad.AmmoRefillPerSupply = 36

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
