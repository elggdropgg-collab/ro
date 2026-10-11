-- Main menu: a classified dossier on a desk, the depot blurred behind it.
-- Pages: cover (play / settings / briefing), settings, briefing.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Lang = require(script.Parent.Parent.Lang)
local Settings = require(script.Parent.Parent.Settings)
local Theme = require(script.Parent.Parent.UI.Theme)
local Registry = require(script.Parent.Parent.Registry)

local player = Players.LocalPlayer
local C = Theme.Colors

local MenuController = {}

local screen: ScreenGui
local backdrop: Frame
local dossier: Frame
local pages: { [string]: Frame } = {}
local blur: BlurEffect
local visible = false

local function showPage(name: string)
	for key, page in pages do
		page.Visible = key == name
	end
	Registry.AudioController:Play2D("RadioKeyDown", "Ui", 0.3)
end

local function header(parent: Instance, text: string)
	Theme.label({
		Text = text,
		FontFace = Theme.Fonts.Title,
		TextColor3 = C.Ink,
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = parent,
	})
	Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.fromOffset(0, 46),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

local function page(name: string): Frame
	local frame = Theme.new("Frame", {
		Name = name,
		Size = UDim2.new(1, -72, 1, -90),
		Position = UDim2.fromOffset(40, 50),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = dossier,
	})
	pages[name] = frame
	return frame
end

-- Row of mutually exclusive options, the chosen one is underlined like a pen mark.
local function choice(
	parent: Instance,
	y: number,
	title: string,
	options: { { Text: string, Value: any } },
	get: () -> any,
	set: (any) -> ()
)
	Theme.label({
		Text = title,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = 17,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, y),
		Parent = parent,
	})
	local buttons = {}
	local function refresh()
		for _, entry in buttons do
			local chosen = entry.Value == get()
			entry.Button.BackgroundColor3 = if chosen then C.Ink else C.PaperDark
			entry.Button.TextColor3 = if chosen then C.Paper else C.Ink
		end
	end
	for i, option in options do
		local button = Theme.button(
			{
				Text = option.Text,
				TextSize = 16,
				Size = UDim2.fromOffset(120, 34),
				Position = UDim2.fromOffset((i - 1) * 128, y + 28),
				Parent = parent,
			},
			"Dossier",
			function()
				set(option.Value)
				refresh()
			end
		)
		table.insert(buttons, { Button = button, Value = option.Value })
	end
	refresh()
end

local function slider(parent: Instance, y: number, title: string, get: () -> number, set: (number) -> ())
	Theme.label({
		Text = title,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = 17,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, y),
		Parent = parent,
	})
	local track = Theme.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(376, 10),
		Position = UDim2.fromOffset(0, y + 40),
		BackgroundColor3 = C.PaperDark,
		BorderSizePixel = 0,
		Parent = parent,
	})
	local fill = Theme.new(
		"Frame",
		{ Size = UDim2.fromScale(get(), 1), BackgroundColor3 = C.Ink, BorderSizePixel = 0, Parent = track }
	)
	local knob = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 22),
		Position = UDim2.fromScale(get(), 0.5),
		BackgroundColor3 = C.Stamp,
		BorderSizePixel = 0,
		Parent = track,
	})
	local dragging = false
	local function apply(x: number)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		set(alpha)
	end
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			apply(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			apply(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
end

local function build()
	screen = Theme.screen("Menu", 20, player:WaitForChild("PlayerGui"))
	backdrop = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = screen,
	})
	Theme.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.55, 0.5),
			NumberSequenceKeypoint.new(1, 0.85),
		}),
		Parent = backdrop,
	})

	dossier = Theme.paper({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.07, 0, 0.5, 0),
		Size = UDim2.fromOffset(520, 620),
		Rotation = -1.5,
		Parent = screen,
	})
	Theme.new("UISizeConstraint", { MaxSize = Vector2.new(520, 620), Parent = dossier })
	Theme.new("UIAspectRatioConstraint", { AspectRatio = 520 / 620, Parent = dossier })
	-- Paper clip and file tab
	Theme.new("Frame", {
		Size = UDim2.fromOffset(18, 70),
		Position = UDim2.new(1, -70, 0, -22),
		BackgroundColor3 = Color3.fromRGB(150, 150, 152),
		BorderSizePixel = 0,
		Rotation = 6,
		ZIndex = 3,
		Parent = dossier,
	})
	Theme.label({
		Text = Lang.t("Menu_Dossier"),
		FontFace = Theme.Fonts.Body,
		TextSize = 13,
		TextColor3 = C.InkSoft,
		Size = UDim2.new(1, -80, 0, 18),
		Position = UDim2.fromOffset(40, 20),
		Parent = dossier,
	})

	-- Cover ----------------------------------------------------------------------
	local cover = page("Cover")
	Theme.label({
		Text = Lang.t("Title"),
		FontFace = Theme.Fonts.Title,
		TextColor3 = C.Ink,
		TextSize = 104,
		Size = UDim2.new(1, 0, 0, 110),
		Position = UDim2.fromOffset(0, 10),
		Parent = cover,
	})
	Theme.label({
		Text = Lang.t("Tagline"),
		FontFace = Theme.Fonts.Body,
		TextColor3 = C.InkSoft,
		TextSize = 17,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(4, 120),
		Parent = cover,
	})
	Theme.stamp(cover, Lang.t("Menu_Classified"), UDim2.new(1, -110, 0, 210), 11)

	-- Typed "case notes"
	Theme.label({
		Text = Lang.t("Vote_Hint"),
		FontFace = Theme.Fonts.Body,
		TextColor3 = C.InkSoft,
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -120, 0, 60),
		Position = UDim2.fromOffset(4, 180),
		Parent = cover,
	})

	local playButton
	playButton = Theme.button(
		{
			Text = Lang.t("Menu_Play"),
			TextSize = 24,
			Size = UDim2.fromOffset(300, 56),
			Position = UDim2.fromOffset(0, 290),
			Parent = cover,
		},
		"Danger",
		function()
			Net.event("ReadyUp"):FireServer()
			playButton.Text = Lang.t("Menu_Waiting")
			Registry.AudioController:Play2D("TrainHorn", "Ui", 0.25)
		end
	)
	MenuController.PlayButton = playButton
	Theme.button(
		{
			Text = Lang.t("Menu_Settings"),
			Size = UDim2.fromOffset(300, 46),
			Position = UDim2.fromOffset(0, 360),
			Parent = cover,
		},
		"Dossier",
		function()
			showPage("Settings")
		end
	)
	Theme.button(
		{
			Text = Lang.t("Menu_HowTo"),
			Size = UDim2.fromOffset(300, 46),
			Position = UDim2.fromOffset(0, 416),
			Parent = cover,
		},
		"Dossier",
		function()
			showPage("Briefing")
		end
	)

	-- Settings ---------------------------------------------------------------------
	local settings = page("Settings")
	header(settings, Lang.t("Menu_Settings"))
	choice(settings, 70, Lang.t("Settings_Tape"), {
		{ Text = Lang.t("Settings_Off"), Value = 1 },
		{ Text = Lang.t("Settings_Normal"), Value = 2 },
		{ Text = Lang.t("Settings_Strong"), Value = 3 },
	}, function()
		return Settings.Tape
	end, function(v)
		Settings.set("Tape", v)
	end)
	choice(settings, 160, Lang.t("Settings_Censor"), {
		{ Text = Lang.t("Settings_Normal"), Value = 0 },
		{ Text = Lang.t("Settings_Strong"), Value = 1 },
	}, function()
		return Settings.ExtraCensor
	end, function(v)
		Settings.set("ExtraCensor", v)
	end)
	slider(settings, 250, Lang.t("Settings_Volume"), function()
		return Settings.Volume
	end, function(v)
		Settings.set("Volume", v)
	end)
	Theme.button(
		{
			Text = Lang.t("Menu_Back"),
			Size = UDim2.fromOffset(200, 44),
			Position = UDim2.new(0, 0, 1, -50),
			Parent = settings,
		},
		"Dossier",
		function()
			showPage("Cover")
		end
	)

	-- Briefing ---------------------------------------------------------------------
	local briefing = page("Briefing")
	header(briefing, Lang.t("Menu_HowTo"))
	local scroll = Theme.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -120),
		Position = UDim2.fromOffset(0, 60),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Ink,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = briefing,
	})
	Theme.label({
		Text = Lang.t("HowTo_Text"),
		FontFace = Theme.Fonts.Body,
		TextSize = 15,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = scroll,
	})
	Theme.button(
		{
			Text = Lang.t("Menu_Back"),
			Size = UDim2.fromOffset(200, 44),
			Position = UDim2.new(0, 0, 1, -50),
			Parent = briefing,
		},
		"Dossier",
		function()
			showPage("Cover")
		end
	)

	showPage("Cover")
end

function MenuController:IsOpen(): boolean
	return visible
end

function MenuController:SetVisible(show: boolean)
	if show == visible then
		return
	end
	visible = show
	if show then
		self.PlayButton.Text = Lang.t("Menu_Play")
		showPage("Cover")
		screen.Enabled = true
		dossier.Position = UDim2.new(0.07, 0, 0.56, 0)
		TweenService
			:Create(dossier, TweenInfo.new(0.5, Enum.EasingStyle.Quart), { Position = UDim2.new(0.07, 0, 0.5, 0) })
			:Play()
		TweenService:Create(blur, TweenInfo.new(0.5), { Size = 14 }):Play()
	else
		TweenService:Create(
			dossier,
			TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.07, 0, 1.6, 0) }
		):Play()
		TweenService:Create(blur, TweenInfo.new(0.4), { Size = 0 }):Play()
		task.delay(0.42, function()
			if not visible then
				screen.Enabled = false
			end
		end)
	end
	Registry.HudController:SetVisible(not show)
end

function MenuController:Init()
	blur = Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 0
	blur.Parent = Lighting
	build()
	screen.Enabled = false
end

function MenuController:Start()
	local function update()
		local phase = State.get("Phase")
		local inLobby = phase == "Lobby" or phase == "Starting"
		self:SetVisible(inLobby and player:GetAttribute("Ready") ~= true)
	end
	State.changed("Phase"):Connect(update)
	player:GetAttributeChangedSignal("Ready"):Connect(update)
	update()
end

return MenuController
