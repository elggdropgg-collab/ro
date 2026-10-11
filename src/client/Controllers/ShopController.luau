-- Supply drop: developer products presented as requisition slips on the field radio.
-- The server decides whether a product can be used right now; this only shows and requests.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Products = require(ReplicatedStorage.Shared.Config.Products)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Lang = require(script.Parent.Parent.Lang)
local Theme = require(script.Parent.Parent.UI.Theme)
local Registry = require(script.Parent.Parent.Registry)

local player = Players.LocalPlayer
local C = Theme.Colors

local ShopController = {}

local screen: ScreenGui
local entries: { [string]: { Card: Frame, Buy: TextButton, Note: TextLabel } } = {}
local prices: { [string]: string } = {}
local open = false

local function available(key: string): boolean
	local def = Products.Defs[key]
	return def.ProductId ~= 0 or RunService:IsStudio()
end

local function priceText(key: string): string
	local def = Products.Defs[key]
	if def.ProductId == 0 then
		return "STUDIO"
	end
	return prices[key] or "R$ …"
end

function ShopController:Purchase(key: string)
	Net.event("RequestPurchase"):FireServer(key)
	Registry.AudioController:Play2D("RadioKeyUp", "Ui", 0.45)
end

local function refresh()
	local phase = State.get("Phase")
	for key, entry in entries do
		local blocked = key == "CleanupWave" and phase ~= "Finale"
		entry.Note.Text = if blocked then Lang.t("Shop_FinaleOnly") else ""
		entry.Buy.Text = priceText(key)
		entry.Buy.AutoButtonColor = false
		entry.Buy.BackgroundColor3 = if blocked then C.PanelLight else C.Olive
		entry.Buy.TextTransparency = if blocked then 0.5 else 0
	end
end

local function build()
	screen = Theme.screen("Shop", 13, player:WaitForChild("PlayerGui"))
	screen.Enabled = false
	Theme.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = screen,
	}).Activated
		:Connect(function()
			ShopController:Close()
		end)

	local panel = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		Parent = screen,
	})
	Theme.padding(panel, 18)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })

	local head = Theme.new(
		"Frame",
		{ Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 0, Parent = panel }
	)
	Theme.label({
		Text = Lang.t("Shop_Title"),
		TextColor3 = C.Amber,
		FontFace = Theme.Fonts.Header,
		TextSize = 22,
		Size = UDim2.new(1, -40, 1, 0),
		Parent = head,
	})
	Theme.button(
		{
			Text = "✕",
			TextSize = 18,
			Size = UDim2.fromOffset(30, 28),
			Position = UDim2.new(1, -30, 0, 0),
			Parent = head,
		},
		"Radio",
		function()
			ShopController:Close()
		end
	)
	Theme.label({
		Text = Lang.t("Shop_Note"),
		TextColor3 = C.AmberDim,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = panel,
	})

	local keys = {}
	for key in Products.Defs do
		if key ~= "SelfRevive" and available(key) then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		return Products.Defs[a].Order < Products.Defs[b].Order
	end)

	for i, key in keys do
		local def = Products.Defs[key]
		local card = Theme.new("Frame", {
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundColor3 = C.PanelLight,
			BorderSizePixel = 0,
			LayoutOrder = 10 + i,
			Parent = panel,
		})
		Theme.corner(card, 3)
		Theme.stroke(card, C.AmberDim, 1, 0.6)
		Theme.label({
			Text = Lang.t(def.NameKey),
			TextColor3 = C.White,
			FontFace = Theme.Fonts.Header,
			TextSize = 18,
			Size = UDim2.new(1, -150, 0, 22),
			Position = UDim2.fromOffset(12, 8),
			Parent = card,
		})
		Theme.label({
			Text = Lang.t(def.DescKey),
			TextColor3 = C.AmberDim,
			TextSize = 13,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -150, 0, 36),
			Position = UDim2.fromOffset(12, 32),
			Parent = card,
		})
		local note = Theme.label({
			Text = "",
			TextColor3 = C.Warn,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(120, 14),
			Position = UDim2.new(1, -132, 1, -18),
			Parent = card,
		})
		local buy = Theme.button(
			{
				Text = priceText(key),
				TextSize = 17,
				Size = UDim2.fromOffset(120, 40),
				Position = UDim2.new(1, -132, 0, 10),
				Parent = card,
			},
			"Radio",
			function()
				if key == "CleanupWave" and State.get("Phase") ~= "Finale" then
					return
				end
				ShopController:Purchase(key)
			end
		)
		entries[key] = { Card = card, Buy = buy, Note = note }
	end

	for key, def in Products.Defs do
		if def.ProductId ~= 0 then
			task.spawn(function()
				local ok, info =
					pcall(MarketplaceService.GetProductInfo, MarketplaceService, def.ProductId, Enum.InfoType.Product)
				if ok and info and info.PriceInRobux then
					prices[key] = "R$ " .. info.PriceInRobux
					refresh()
				end
			end)
		end
	end
end

function ShopController:GetPriceText(key: string): string
	return priceText(key)
end

function ShopController:Open()
	local phase = State.get("Phase")
	if phase == "Lobby" or phase == "Ended" then
		return
	end
	open = true
	refresh()
	screen.Enabled = true
	Registry.MapController:Close()
end

function ShopController:Close()
	open = false
	screen.Enabled = false
end

function ShopController:Toggle()
	if open then
		self:Close()
	else
		self:Open()
	end
end

function ShopController:IsOpen(): boolean
	return open
end

function ShopController:Init()
	build()
end

function ShopController:Start()
	State.changed("Phase"):Connect(function()
		if open then
			refresh()
		end
		local phase = State.get("Phase")
		if phase == "Lobby" or phase == "Ended" then
			self:Close()
		end
	end)
end

return ShopController
