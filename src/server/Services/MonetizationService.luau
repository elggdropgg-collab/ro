-- Developer products. The server decides whether a purchase can be used right now *before*
-- prompting. If the situation changed by the time the receipt arrives, the purchase is
-- stored as a credit in the profile instead of being lost.
--
-- In Studio, products with ProductId = 0 are granted for free so everything can be tested.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Products = require(ReplicatedStorage.Shared.Config.Products)
local SquadConfig = require(ReplicatedStorage.Shared.Config.Squad)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Server = ServerScriptService.Server
local Notify = require(Server.Util.Notify)
local Registry = require(Server.Registry)

local MonetizationService = {}

local lastScare: { [Player]: number } = {}
local productKeyById: { [number]: string } = {}

local RUN_PHASES = { Location = true, Departing = true, Travel = true, Finale = true, LastChance = true }

local function inRun(): boolean
	return RUN_PHASES[State.get("Phase")] == true
end

type Handler = {
	CanApply: (Player) -> boolean,
	Apply: (Player) -> (),
}

local handlers: { [string]: Handler } = {
	SelfRevive = {
		CanApply = function(player)
			return Registry.ReviveService:CanSelfRevive(player)
		end,
		Apply = function(player)
			Registry.ReviveService:SelfRevive(player)
		end,
	},
	ExtraSquad = {
		CanApply = function()
			return inRun()
		end,
		Apply = function(player)
			Registry.SquadService:AddSoldiers(
				SquadConfig.ExtraSquadSize,
				"Regular",
				"Follow",
				{ UserId = player.UserId },
				true
			)
			Notify.all("Notify_ExtraSquad", { SquadConfig.ExtraSquadSize }, "good")
		end,
	},
	DamageBoost = {
		CanApply = function()
			return inRun() and (State.get("SquadDamageBoost") or 1) <= 1
		end,
		Apply = function()
			State.set("SquadDamageBoost", Products.Tuning.DamageBoostMultiplier)
			Notify.all("Notify_DamageBoost", nil, "good")
		end,
	},
	ScareAll = {
		CanApply = function(player)
			return inRun() and os.clock() - (lastScare[player] or -math.huge) >= Products.Tuning.ScareCooldown
		end,
		Apply = function(player)
			lastScare[player] = os.clock()
			for _, other in Players:GetPlayers() do
				if other ~= player then
					Net.event("Scare"):FireClient(other, player.DisplayName, Products.Tuning.ParanoiaSeconds)
				end
			end
			Notify.all("Notify_Scared", { player.DisplayName }, "radio")
		end,
	},
	CleanupWave = {
		CanApply = function()
			return State.get("Phase") == "Finale" and not State.get("CleanupActive")
		end,
		Apply = function()
			State.set("CleanupActive", true)
			Registry.MatchService:LaunchCleanup()
		end,
	},
}

function MonetizationService:Init()
	for key, def in Products.Defs do
		if def.ProductId ~= 0 then
			productKeyById[def.ProductId] = key
		end
	end

	Net.event("RequestPurchase").OnServerEvent:Connect(function(player, key)
		if type(key) == "string" then
			self:Request(player, key)
		end
	end)

	MarketplaceService.ProcessReceipt = function(info)
		return self:ProcessReceipt(info)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastScare[player] = nil
	end)
end

function MonetizationService:Request(player: Player, key: string)
	local def = Products.Defs[key]
	local handler = handlers[key]
	if not def or not handler then
		return
	end
	if key == "ScareAll" and inRun() and not handler.CanApply(player) then
		local remaining = math.ceil(Products.Tuning.ScareCooldown - (os.clock() - (lastScare[player] or 0)))
		Notify.player(player, "Notify_ScareCooldown", { remaining }, "warn")
		return
	end
	if not handler.CanApply(player) then
		Notify.player(player, "Notify_ProductUnavailable", nil, "warn")
		return
	end

	local profile = Registry.DataService:GetProfile(player)
	if profile and (profile.Data.Credits[key] or 0) > 0 then
		profile.Data.Credits[key] -= 1
		handler.Apply(player)
		return
	end

	if def.ProductId == 0 then
		if RunService:IsStudio() then
			handler.Apply(player)
		else
			Notify.player(player, "Notify_ProductUnavailable", nil, "warn")
		end
		return
	end
	MarketplaceService:PromptProductPurchase(player, def.ProductId)
end

function MonetizationService:ProcessReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Registry.DataService:WaitForProfile(player, 10)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if profile.Data.Receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productKeyById[info.ProductId]
	local handler = key and handlers[key]
	if not key or not handler then
		warn(`[Shop] unknown product {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if handler.CanApply(player) then
		local ok, err = pcall(handler.Apply, player)
		if not ok then
			warn(`[Shop] {key} failed for {player.Name}: {err}`)
			profile.Data.Credits[key] = (profile.Data.Credits[key] or 0) + 1
			Notify.player(player, "Notify_CreditSaved", nil, "info")
		end
	else
		profile.Data.Credits[key] = (profile.Data.Credits[key] or 0) + 1
		Notify.player(player, "Notify_CreditSaved", nil, "info")
	end

	-- Recorded in memory first, so a retry in this session never grants twice
	profile.Data.Receipts[purchaseId] = os.time()
	if not Registry.DataService:SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return MonetizationService
