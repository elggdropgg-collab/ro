-- Custom interaction prompts in the style of a stencilled military label.
-- Server prompts carry localization keys as attributes (ActionKey, ObjectKey, ObjectArg),
-- and optionally ClientAction for prompts that only open local UI.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lang = require(script.Parent.Parent.Lang)
local Theme = require(script.Parent.Parent.UI.Theme)
local Registry = require(script.Parent.Parent.Registry)

local player = Players.LocalPlayer

local PromptController = {}

local active: { [ProximityPrompt]: { Gui: BillboardGui, Fill: Frame, Tween: Tween? } } = {}

local GAMEPAD_LABELS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
}

local function keyLabel(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "•"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD_LABELS[prompt.GamepadKeyCode] or prompt.GamepadKeyCode.Name
	end
	local text = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return if text ~= "" then text else prompt.KeyboardKeyCode.Name
end

local function texts(prompt: ProximityPrompt): (string, string)
	local actionKey = prompt:GetAttribute("ActionKey")
	local objectKey = prompt:GetAttribute("ObjectKey")
	local arg = prompt:GetAttribute("ObjectArg")
	local action = if actionKey then Lang.t(actionKey) else prompt.ActionText
	local object = if objectKey then Lang.t(objectKey) else prompt.ObjectText
	if arg and arg ~= "" then
		object ..= " · " .. tostring(arg)
	end
	return string.upper(action), object
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom or active[prompt] then
		return
	end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local action, object = texts(prompt)
	local gui = Theme.new("BillboardGui", {
		Name = "Prompt",
		Adornee = prompt.Parent,
		Size = UDim2.fromOffset(250, 62),
		StudsOffset = Vector3.new(0, 1.6, 0),
		AlwaysOnTop = true,
		ResetOnSpawn = false,
		Active = true,
		Parent = playerGui,
	})
	local frame = Theme.panel({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.15, Parent = gui })

	local keyBox = Theme.new("TextButton", {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Theme.Colors.Amber,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = keyLabel(prompt, inputType),
		TextColor3 = Theme.Colors.Panel,
		FontFace = Theme.Fonts.Header,
		TextSize = 22,
		Parent = frame,
	})
	Theme.corner(keyBox, 3)
	local fill = Theme.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Colors.White,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = keyBox,
	})
	Theme.corner(fill, 3)

	Theme.label({
		Text = action,
		FontFace = Theme.Fonts.Header,
		TextColor3 = Theme.Colors.Amber,
		TextSize = 19,
		Size = UDim2.new(1, -70, 0, 24),
		Position = UDim2.fromOffset(64, 8),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = frame,
	})
	Theme.label({
		Text = object,
		FontFace = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.AmberDim,
		TextSize = 14,
		Size = UDim2.new(1, -70, 0, 20),
		Position = UDim2.fromOffset(64, 33),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = frame,
	})

	-- Touch: tap/hold the key box
	if inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
		keyBox.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldBegin()
			end
		end)
		keyBox.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldEnd()
			end
		end)
	end

	frame.Size = UDim2.fromScale(0.85, 0.85)
	frame.Position = UDim2.fromScale(0.075, 0.075)
	TweenService:Create(
		frame,
		TweenInfo.new(0.12, Enum.EasingStyle.Back),
		{ Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0) }
	):Play()

	active[prompt] = { Gui = gui, Fill = fill, Tween = nil }
end

local function hide(prompt: ProximityPrompt)
	local entry = active[prompt]
	if entry then
		entry.Gui:Destroy()
		active[prompt] = nil
	end
end

function PromptController:Start()
	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(hide)

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local entry = active[prompt]
		if entry then
			entry.Fill.Size = UDim2.fromScale(0, 1)
			entry.Tween = TweenService:Create(
				entry.Fill,
				TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
				{ Size = UDim2.fromScale(1, 1) }
			)
			entry.Tween:Play()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		local entry = active[prompt]
		if entry then
			if entry.Tween then
				entry.Tween:Cancel()
			end
			entry.Fill.Size = UDim2.fromScale(0, 1)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local action = prompt:GetAttribute("ClientAction")
		if action == "OpenMap" then
			Registry.MapController:Open()
		elseif action == "OpenShop" then
			Registry.ShopController:Open()
		end
	end)
end

return PromptController
