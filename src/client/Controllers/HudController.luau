-- In-run HUD styled as a field radio display: amber text on dark glass.
--   top centre    station and what to do now
--   top left      train stores, squad, commander
--   bottom right  weapon, stamina, what you carry
--   bottom left   map and supply buttons, tokens
--   right         radio log / notifications

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local SquadConfig = require(ReplicatedStorage.Shared.Config.Squad)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Lang = require(script.Parent.Parent.Lang)
local Theme = require(script.Parent.Parent.UI.Theme)
local Registry = require(script.Parent.Parent.Registry)

local player = Players.LocalPlayer
local C = Theme.Colors

local HudController = {}

local screen: ScreenGui
local ui: { [string]: any } = {}
local feed: Frame

local KIND_COLORS = {
	info = C.Amber,
	warn = C.Warn,
	radio = C.Radio,
	death = C.Danger,
	good = C.Good,
}

local function secondsLeft(): number
	return math.max(0, math.ceil((State.get("PhaseEndsAt") or 0) - State.now()))
end

local function hintText(): string
	local phase = State.get("Phase")
	if phase == "Lobby" then
		return Lang.t("Phase_Lobby")
	elseif phase == "Starting" then
		return Lang.t("Phase_Starting", { secondsLeft() })
	elseif phase == "Vote" then
		return Lang.t("Phase_Vote")
	elseif phase == "Travel" then
		return Lang.t("Phase_Travel")
	elseif phase == "LastChance" then
		return Lang.t("Phase_LastChance", { secondsLeft() })
	elseif phase == "Location" then
		local pool, needed = State.get("DieselPool") or 0, State.get("DieselNeeded") or 0
		if pool >= needed then
			return Lang.t("Hint_ReadyToDepart")
		end
		if (State.get("SquadAlive") or 0) == 0 and (State.get("ScrapPool") or 0) >= SquadConfig.RecruitScrapCost then
			return Lang.t("Hint_CanRecruit", { pool, needed })
		end
		return Lang.t("Hint_FindDiesel", { pool, needed })
	elseif phase == "Departing" then
		return Lang.t("Hint_DepartIn", { secondsLeft() })
	elseif phase == "Finale" then
		if State.get("PortalOpen") then
			return Lang.t("Hint_PortalOpen")
		elseif State.get("PortalCharging") then
			return Lang.t("Hint_PortalCharging", { secondsLeft() })
		end
		local inserted, needed = State.get("FusesInserted") or 0, State.get("FusesNeeded") or 0
		if inserted >= needed and needed > 0 then
			return Lang.t("Hint_StartPortal")
		end
		return Lang.t("Hint_Fuses", { inserted, needed })
	elseif phase == "Ended" then
		return Lang.t("End_Return", { secondsLeft() })
	end
	return ""
end

local function hintColor(): Color3
	local phase = State.get("Phase")
	if phase == "LastChance" or phase == "Departing" or State.get("PortalOpen") then
		return C.Danger
	end
	return C.Amber
end

local function build()
	screen = Theme.screen("Hud", 2, player:WaitForChild("PlayerGui"))

	-- Top centre ---------------------------------------------------------------
	local top = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(620, 64),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	ui.Station = Theme.label({
		Text = "",
		FontFace = Theme.Fonts.Title,
		TextColor3 = C.White,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		TextStrokeTransparency = 0.6,
		Parent = top,
	})
	ui.Hint = Theme.label({
		Text = "",
		FontFace = Theme.Fonts.BodyBold,
		TextColor3 = C.Amber,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 32),
		TextStrokeTransparency = 0.5,
		Parent = top,
	})

	-- Top left: stores --------------------------------------------------------
	local stores =
		Theme.panel({ Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(230, 132), Parent = screen })
	Theme.padding(stores, 10)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stores })
	local function row(order: number, color: Color3?): TextLabel
		local holder = Theme.new(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = order, Parent = stores }
		)
		if color then
			Theme.new("Frame", {
				Size = UDim2.fromOffset(8, 8),
				Position = UDim2.new(0, 0, 0.5, -4),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Parent = holder,
			})
		end
		return Theme.label({
			Text = "",
			TextColor3 = C.Amber,
			TextSize = 15,
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(if color then 16 else 0, 0),
			TextWrapped = false,
			Parent = holder,
		})
	end
	ui.Diesel = row(1, Resources.Kinds.Diesel.Color)
	ui.Scrap = row(2, Resources.Kinds.Scrap.Color)
	ui.Supplies = row(3, Resources.Kinds.Supplies.Color)
	ui.Squad = row(4)
	ui.Commander = row(5)
	ui.Commander.TextColor3 = C.AmberDim

	ui.Badge = Theme.stamp(screen, Lang.t("Commander_Badge"), UDim2.fromOffset(130, 168), -4)
	ui.Badge.TextSize = 20
	ui.Badge.Visible = false

	-- Bottom right: weapon ------------------------------------------------------
	local weapon = Theme.panel({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(240, 104),
		Parent = screen,
	})
	ui.Ammo = Theme.label({
		Text = "",
		FontFace = Theme.Fonts.Header,
		TextColor3 = C.White,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -20, 0, 38),
		Position = UDim2.fromOffset(10, 6),
		Parent = weapon,
	})
	ui.AmmoNote = Theme.label({
		Text = "",
		TextColor3 = C.AmberDim,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.fromOffset(10, 44),
		Parent = weapon,
	})
	local staminaBack = Theme.new("Frame", {
		Size = UDim2.new(1, -20, 0, 6),
		Position = UDim2.fromOffset(10, 66),
		BackgroundColor3 = C.PanelLight,
		BorderSizePixel = 0,
		Parent = weapon,
	})
	ui.Stamina = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Amber, BorderSizePixel = 0, Parent = staminaBack }
	)
	ui.Carrying = Theme.label({
		Text = "",
		TextColor3 = C.Radio,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 78),
		Parent = weapon,
	})

	-- Bottom left: buttons -------------------------------------------------------
	local buttons = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(300, 84),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	ui.MapButton = Theme.button(
		{ Text = Lang.t("HUD_Map") .. "  [M]", Size = UDim2.fromOffset(140, 40), Parent = buttons },
		"Radio",
		function()
			Registry.MapController:Toggle()
		end
	)
	ui.ShopButton = Theme.button(
		{
			Text = Lang.t("HUD_Shop"),
			Size = UDim2.fromOffset(140, 40),
			Position = UDim2.fromOffset(150, 0),
			Parent = buttons,
		},
		"Radio",
		function()
			Registry.ShopController:Toggle()
		end
	)
	ui.Coins = Theme.label({
		Text = "",
		TextColor3 = C.AmberDim,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(2, 50),
		Parent = buttons,
	})

	-- Radio log ------------------------------------------------------------------
	feed = Theme.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 90),
		Size = UDim2.fromOffset(340, 300),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	Theme.new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Parent = feed,
	})
end

local order = 0
function HudController:Notify(key: string, args: { any }?, kind: string?)
	local k = kind or "info"
	order += 1
	local text = Lang.t(key, args)
	if k == "radio" then
		text = "◉ " .. text
		Registry.AudioController:Play2D("RadioKeyUp", "Ui", 0.5)
	end
	local item = Theme.panel({
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = feed,
	})
	Theme.padding(item, 6)
	local label = Theme.label({
		Text = text,
		TextColor3 = KIND_COLORS[k] or C.Amber,
		FontFace = if k == "death" or k == "radio" then Theme.Fonts.BodyBold else Theme.Fonts.Body,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = item,
	})
	local children = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	table.sort(children, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #children > 6 do
		local oldest = table.remove(children, 1) :: Frame
		oldest:Destroy()
	end
	task.delay(7, function()
		if item.Parent then
			TweenService:Create(item, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			local stroke = item:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
			task.wait(0.65)
			item:Destroy()
		end
	end)
end

function HudController:SetVisible(visible: boolean)
	screen.Enabled = visible
end

local function refresh()
	ui.Station.Text = string.upper(Lang.t(State.get("StationKey") or "Station_Lobby"))
	ui.Hint.Text = hintText()
	ui.Hint.TextColor3 = hintColor()

	local needed = State.get("DieselNeeded") or 0
	ui.Diesel.Text = Lang.t("Resource_Diesel")
		.. ": "
		.. (State.get("DieselPool") or 0)
		.. (if needed > 0 then " / " .. needed else "")
	ui.Scrap.Text = Lang.t("Resource_Scrap") .. ": " .. (State.get("ScrapPool") or 0)
	ui.Supplies.Text = Lang.t("Resource_Supplies") .. ": " .. (State.get("SuppliesPool") or 0)
	ui.Squad.Text = Lang.t("HUD_Squad", { State.get("SquadAlive") or 0 })

	local commanderId = State.get("CommanderUserId")
	local commander = commanderId and Players:GetPlayerByUserId(commanderId)
	ui.Commander.Text = if commander then Lang.t("Commander_Badge") .. ": " .. commander.DisplayName else ""
	ui.Badge.Visible = player:GetAttribute("IsCommander") == true

	local ammo, reserve = player:GetAttribute("Ammo") or 0, player:GetAttribute("Reserve") or 0
	ui.Ammo.Text = ammo .. " / " .. reserve
	ui.Ammo.TextColor3 = if ammo == 0 then C.Danger elseif ammo <= 2 then C.Warn else C.White
	ui.AmmoNote.Text = if player:GetAttribute("Reloading") then Lang.t("HUD_Reloading") else "R"
	local input = Registry.InputController
	ui.Stamina.Size = UDim2.fromScale(if input then input.Stamina else 1, 1)
	ui.Stamina.BackgroundColor3 = if input and input.InfiniteSprint then C.Good else C.Amber

	local carrying = player.Character and player.Character:GetAttribute("Carrying")
	ui.Carrying.Text = if carrying then Lang.t("HUD_Carrying", { "Resource_" .. carrying }) else ""
	ui.Coins.Text = Lang.t("HUD_Coins", { player:GetAttribute("Coins") or 0 })

	local phase = State.get("Phase")
	ui.ShopButton.Visible = phase ~= "Lobby" and phase ~= "Ended"
	ui.MapButton.Visible = phase ~= "Lobby" and phase ~= "Starting" and phase ~= "Ended"
end

function HudController:Init()
	build()
end

function HudController:Start()
	Net.event("Notify").OnClientEvent:Connect(function(key, args, kind)
		self:Notify(key, args, kind)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			refresh()
		end
	end)
end

return HudController
