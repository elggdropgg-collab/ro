--!strict
-- Things that can be picked up, carried and delivered to the train.

export type ResourceDef = {
	NameKey: string,
	Color: Color3,
	Size: Vector3,
	Pooled: boolean,
}

local Resources = {}

Resources.Kinds = {
	Diesel = {
		NameKey = "Resource_Diesel",
		Color = Color3.fromRGB(150, 32, 26),
		Size = Vector3.new(1.4, 2, 0.9),
		Pooled = true,
	},
	Scrap = {
		NameKey = "Resource_Scrap",
		Color = Color3.fromRGB(110, 106, 98),
		Size = Vector3.new(1.8, 1, 1.4),
		Pooled = true,
	},
	Supplies = {
		NameKey = "Resource_Supplies",
		Color = Color3.fromRGB(78, 88, 54),
		Size = Vector3.new(2, 1.3, 1.4),
		Pooled = true,
	},
	Fuse = {
		NameKey = "Resource_Fuse",
		Color = Color3.fromRGB(210, 180, 70),
		Size = Vector3.new(0.7, 1.6, 0.7),
		Pooled = false,
	},
	DogTag = {
		NameKey = "Resource_DogTag",
		Color = Color3.fromRGB(190, 190, 195),
		Size = Vector3.new(0.6, 0.15, 0.9),
		Pooled = false,
	},
} :: { [string]: ResourceDef }

-- How many of each resource a station spawns on top of what is strictly needed.
Resources.Spawn = {
	Field = { DieselExtra = 3, Scrap = 16, Supplies = 5 },
}

Resources.SuppliesHeal = 40

return Resources
