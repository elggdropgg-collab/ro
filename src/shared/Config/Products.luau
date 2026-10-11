--!strict
-- Developer products. Create them in the Creator Dashboard and paste the IDs here.
-- A product with ProductId = 0 is hidden from the shop.

export type ProductDef = {
	ProductId: number,
	NameKey: string,
	DescKey: string,
	Order: number,
}

local Products: { [string]: ProductDef } = {
	SelfRevive = { ProductId = 0, NameKey = "Product_SelfRevive", DescKey = "Product_SelfRevive_Desc", Order = 1 },
	ExtraSquad = { ProductId = 0, NameKey = "Product_ExtraSquad", DescKey = "Product_ExtraSquad_Desc", Order = 2 },
	DamageBoost = { ProductId = 0, NameKey = "Product_DamageBoost", DescKey = "Product_DamageBoost_Desc", Order = 3 },
	ScareAll = { ProductId = 0, NameKey = "Product_ScareAll", DescKey = "Product_ScareAll_Desc", Order = 4 },
	CleanupWave = { ProductId = 0, NameKey = "Product_CleanupWave", DescKey = "Product_CleanupWave_Desc", Order = 5 },
}

local Tuning = {
	DamageBoostMultiplier = 1.5,
	ScareCooldown = 180,
	ParanoiaSeconds = 150,
}

return {
	Defs = Products,
	Tuning = Tuning,
}
