-- Death screen with spectating, the last-chance warning and the end-of-run report.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Lang = require(script.Parent.Parent.Lang)
local Theme = require(script.Parent.Parent.UI.Theme)
local Registry = require(script.Parent.Parent.Registry)

local player = Players.LocalPlayer
local C = Theme.Colors

local DeathController = {}

local screen: ScreenGui
local deathFrame: Frame
local deathTitle: TextLabel
local deathText: TextLabel
local reviveButton: TextButton
local spectateLabel: TextLabel
local lastChance: Frame
local lastChanceTimer: TextLabel

local endScreen: ScreenGui
local endSheet: Frame
local endStamp: TextLabel
local endLines: TextLabel
local endTimer: TextLabel

local dead = false
local inRun = false
local spectateIndex = 1

-- Spectating ----------------------------------------------------------------------------

local function spectateTargets(): { { Name: string, Humanoid: Humanoid } }
	local list = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if other ~= player and humanoid and humanoid.Health > 0 then
			table.insert(list, { Name = other.DisplayName, Humanoid = humanoid })
		end
	end
	local squad = workspace:FindFirstChild("Squad")
	if squad then
		for _, model in squad:GetChildren() do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				table.insert(list, { Name = model:GetAttribute("DisplayName") or model.Name, Humanoid = humanoid })
			end
		end
	end
	return list
end

local function spectate(step: number)
	local targets = spectateTargets()
	if #targets == 0 then
		spectateLabel.Text = ""
		return
	end
	spectateIndex = ((spectateIndex - 1 + step) % #targets) + 1
	local target = targets[spectateIndex]
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = target.Humanoid
	spectateLabel.Text = Lang.t("Spectating", { target.Name })
end

-- Death screen ---------------------------------------------------------------------------

local function showDeath(info: any)
	dead = true
	inRun = info and info.InRun == true
	local lines = {}
	if info and info.Cause == "LeftBehind" then
		table.insert(lines, Lang.t("Notify_LeftBehind", { player.DisplayName }))
	elseif inRun then
		table.insert(lines, Lang.t("Death_Tag"))
	end
	if inRun then
		table.insert(lines, Lang.t("Death_Station"))
	end
	deathText.Text = table.concat(lines, "\n\n")
	reviveButton.Visible = inRun and info.Cause ~= "LeftBehind"
	reviveButton.Text = Lang.t("Death_SelfRevive") .. "   " .. Registry.ShopController:GetPriceText("SelfRevive")
	screen.Enabled = true
	deathFrame.BackgroundTransparency = 0
	TweenService:Create(deathFrame, TweenInfo.new(2.5), { BackgroundTransparency = 0.55 }):Play()
	deathTitle.TextTransparency = 1
	TweenService:Create(deathTitle, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
	Registry.TapeController:Glitch(1.2, 1)
	task.delay(1.5, function()
		if dead then
			spectate(0)
		end
	end)
end

local function hideDeath()
	dead = false
	screen.Enabled = false
	local camera = workspace.CurrentCamera
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function buildDeath()
	screen = Theme.screen("Death", 10, player:WaitForChild("PlayerGui"))
	screen.Enabled = false
	deathFrame = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(16, 2, 2),
		BorderSizePixel = 0,
		Parent = screen,
	})
	Theme.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.35, 0.75),
			NumberSequenceKeypoint.new(0.65, 0.75),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
		Rotation = 90,
		Parent = deathFrame,
	})
	deathTitle = Theme.label({
		Text = Lang.t("Death_Title"),
		FontFace = Theme.Fonts.Title,
		TextColor3 = C.Danger,
		TextSize = 72,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.16, 0),
		Size = UDim2.fromOffset(800, 80),
		Parent = screen,
	})
	deathText = Theme.label({
		Text = "",
		TextColor3 = C.White,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.16, 96),
		Size = UDim2.fromOffset(560, 110),
		Parent = screen,
	})
	reviveButton = Theme.button(
		{
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.16, 220),
			Size = UDim2.fromOffset(360, 50),
			Text = "",
			TextSize = 20,
			Parent = screen,
		},
		"Danger",
		function()
			Registry.ShopController:Purchase("SelfRevive")
		end
	)

	local bar = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(420, 46),
		Parent = screen,
	})
	Theme.button(
		{ Text = "◀", Size = UDim2.fromOffset(46, 36), Position = UDim2.fromOffset(5, 5), Parent = bar },
		"Radio",
		function()
			spectate(-1)
		end
	)
	Theme.button(
		{ Text = "▶", Size = UDim2.fromOffset(46, 36), Position = UDim2.new(1, -51, 0, 5), Parent = bar },
		"Radio",
		function()
			spectate(1)
		end
	)
	spectateLabel = Theme.label({
		Text = "",
		TextColor3 = C.Amber,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.fromOffset(60, 0),
		Parent = bar,
	})

	lastChance = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(600, 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	Theme.label({
		Text = Lang.t("LastChance_Title"),
		FontFace = Theme.Fonts.Title,
		TextColor3 = C.Danger,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 50),
		Parent = lastChance,
	})
	Theme.label({
		Text = Lang.t("LastChance_Text"),
		TextColor3 = C.White,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 52),
		Parent = lastChance,
	})
	lastChanceTimer = Theme.label({
		Text = "",
		FontFace = Theme.Fonts.Header,
		TextColor3 = C.Danger,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 78),
		Parent = lastChance,
	})
end

-- End of run -------------------------------------------------------------------------------

local function buildEnd()
	endScreen = Theme.screen("RunEnd", 18, player:WaitForChild("PlayerGui"))
	endScreen.Enabled = false
	Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = endScreen,
	})
	endSheet = Theme.paper({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 420),
		Rotation = -1,
		Parent = endScreen,
	})
	Theme.padding(endSheet, 30)
	Theme.label({
		Text = Lang.t("Menu_Dossier"),
		TextColor3 = C.InkSoft,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = endSheet,
	})
	endStamp = Theme.stamp(endSheet, "", UDim2.new(0.5, 0, 0, 80), -6)
	endStamp.Size = UDim2.fromOffset(440, 64)
	endStamp.TextSize = 44
	endLines = Theme.label({
		Text = "",
		TextSize = 18,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 160),
		Position = UDim2.fromOffset(0, 140),
		Parent = endSheet,
	})
	endTimer = Theme.label({
		Text = "",
		TextColor3 = C.InkSoft,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		Parent = endSheet,
	})
end

local function showSummary(summary: any)
	hideDeath()
	Registry.MapController:Close()
	Registry.ShopController:Close()
	endStamp.Text = Lang.t(if summary.Victory then "End_Victory" else "End_Defeat")
	endStamp.TextColor3 = if summary.Escaped then C.Olive else C.Stamp
	local stroke = endStamp:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = endStamp.TextColor3
	end
	endLines.Text = table.concat({
		Lang.t("End_Stations", { summary.Stations }),
		Lang.t("End_SoldiersLost", { summary.SoldiersLost }),
		Lang.t("End_Escaped", { summary.EscapedCount }),
		"",
		"<b>" .. Lang.t("End_Coins", { summary.Coins }) .. "</b>",
	}, "\n")
	endScreen.Enabled = true
	endSheet.Position = UDim2.fromScale(0.5, 0.58)
	TweenService:Create(endSheet, TweenInfo.new(0.6, Enum.EasingStyle.Quart), { Position = UDim2.fromScale(0.5, 0.5) })
		:Play()
	endStamp.TextTransparency = 1
	task.delay(0.7, function()
		endStamp.TextTransparency = 0
		Registry.AudioController:Play2D("BodyDrop", "Ui", 0.5, 1.6)
	end)
end

-- Lifecycle -----------------------------------------------------------------------------------

function DeathController:Init()
	buildDeath()
	buildEnd()
end

function DeathController:Start()
	Net.event("Death").OnClientEvent:Connect(showDeath)
	Net.event("RunSummary").OnClientEvent:Connect(showSummary)
	player:GetAttributeChangedSignal("Alive"):Connect(function()
		if player:GetAttribute("Alive") then
			hideDeath()
		end
	end)
	player.CharacterAdded:Connect(function()
		if dead then
			hideDeath()
		end
	end)
	State.changed("Phase"):Connect(function()
		local phase = State.get("Phase")
		if phase == "Lobby" then
			endScreen.Enabled = false
			hideDeath()
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local phase = State.get("Phase")
		local left = math.max(0, math.ceil((State.get("PhaseEndsAt") or 0) - State.now()))
		lastChance.Visible = dead and phase == "LastChance"
		lastChanceTimer.Text = tostring(left)
		if endScreen.Enabled then
			endTimer.Text = Lang.t("End_Return", { left })
		end
		if dead then
			-- The person we were watching died: move on
			local camera = workspace.CurrentCamera
			local subject = camera.CameraSubject
			if not subject or not subject.Parent or (subject:IsA("Humanoid") and subject.Health <= 0) then
				spectate(1)
			end
		end
	end)
end

return DeathController
