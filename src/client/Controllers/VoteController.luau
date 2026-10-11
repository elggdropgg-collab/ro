-- Commander vote: personnel cards with photos, one ballot per player.

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

local VoteController = {}

local screen: ScreenGui
local sheet: Frame
local list: Frame
local timer: TextLabel
local endsAt = 0
local cards: { [number]: { Frame: TextButton, Mark: TextLabel } } = {}

local function build()
	screen = Theme.screen("Vote", 15, player:WaitForChild("PlayerGui"))
	screen.Enabled = false
	Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = screen,
	})
	sheet = Theme.paper({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 440),
		Rotation = 1,
		Parent = screen,
	})
	Theme.padding(sheet, 26)
	Theme.label({
		Text = Lang.t("Vote_Title"),
		FontFace = Theme.Fonts.Title,
		TextSize = 34,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = sheet,
	})
	Theme.label({
		Text = Lang.t("Vote_Hint"),
		TextColor3 = C.InkSoft,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 42),
		Parent = sheet,
	})
	timer = Theme.label({
		Text = "",
		FontFace = Theme.Fonts.Header,
		TextColor3 = C.Stamp,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(80, 40),
		Position = UDim2.new(1, -80, 0, 0),
		Parent = sheet,
	})
	list = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 1, -100),
		Position = UDim2.fromOffset(0, 96),
		BackgroundTransparency = 1,
		Parent = sheet,
	})
	Theme.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(186, 146),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
end

local function choose(userId: number)
	Net.event("CastVote"):FireServer(userId)
	Registry.AudioController:Play2D("RadioKeyDown", "Ui", 0.4)
	for id, card in cards do
		card.Mark.Visible = id == userId
		card.Frame.BackgroundColor3 = if id == userId then C.Paper else C.PaperDark
	end
end

local function open(candidates: { { UserId: number, Name: string } }, voteEndsAt: number)
	endsAt = voteEndsAt
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	cards = {}
	for i, candidate in candidates do
		local card = Theme.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.PaperDark,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = list,
		})
		Theme.stroke(card, C.InkSoft, 1)
		local photo = Theme.new("ImageLabel", {
			Size = UDim2.fromOffset(84, 84),
			Position = UDim2.new(0.5, -42, 0, 10),
			BackgroundColor3 = C.InkSoft,
			BorderSizePixel = 0,
			ImageColor3 = Color3.fromRGB(225, 215, 190), -- sepia-ish photo
			Parent = card,
		})
		task.spawn(function()
			local ok, image = pcall(
				Players.GetUserThumbnailAsync,
				Players,
				candidate.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
			if ok then
				photo.Image = image
			end
		end)
		Theme.label({
			Text = candidate.Name,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Size = UDim2.new(1, -10, 0, 22),
			Position = UDim2.new(0, 5, 0, 102),
			Parent = card,
		})
		local mark = Theme.stamp(card, "✔", UDim2.new(0.8, 0, 0.25, 0), 12)
		mark.Size = UDim2.fromOffset(40, 40)
		mark.TextSize = 34
		mark.Visible = false
		card.Activated:Connect(function()
			choose(candidate.UserId)
		end)
		cards[candidate.UserId] = { Frame = card, Mark = mark }
	end
	screen.Enabled = true
	sheet.Position = UDim2.fromScale(0.5, 0.6)
	TweenService:Create(sheet, TweenInfo.new(0.4, Enum.EasingStyle.Quart), { Position = UDim2.fromScale(0.5, 0.5) })
		:Play()
end

local function result(userId: number)
	local card = cards[userId]
	if card then
		local stamp = Theme.stamp(card.Frame, Lang.t("Commander_Badge"), UDim2.fromScale(0.5, 0.45), -14)
		stamp.TextSize = 26
		stamp.Size = UDim2.fromOffset(176, 40)
		stamp.ZIndex = 5
		card.Frame.BackgroundColor3 = C.Paper
		Registry.AudioController:Play2D("RadioKeyUp", "Ui", 0.5)
	end
	task.delay(2.5, function()
		screen.Enabled = false
	end)
end

function VoteController:Init()
	build()
end

function VoteController:Start()
	Net.event("VoteStart").OnClientEvent:Connect(open)
	Net.event("VoteResult").OnClientEvent:Connect(result)
	State.changed("Phase"):Connect(function()
		local phase = State.get("Phase")
		if phase ~= "Vote" and screen.Enabled then
			task.delay(3, function()
				if State.get("Phase") ~= "Vote" then
					screen.Enabled = false
				end
			end)
		end
	end)
	RunService.Heartbeat:Connect(function()
		if screen.Enabled then
			timer.Text = tostring(math.max(0, math.ceil(endsAt - State.now())))
		end
	end)
end

return VoteController
