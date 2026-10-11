-- Visual language of the interface: a classified military dossier for menus,
-- an amber field-radio display for the HUD.

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Paper = Color3.fromRGB(214, 204, 178),
	PaperDark = Color3.fromRGB(186, 174, 146),
	Ink = Color3.fromRGB(32, 30, 26),
	InkSoft = Color3.fromRGB(70, 64, 56),
	Stamp = Color3.fromRGB(164, 34, 28),
	Olive = Color3.fromRGB(74, 82, 58),
	Panel = Color3.fromRGB(14, 14, 12),
	PanelLight = Color3.fromRGB(30, 30, 26),
	Amber = Color3.fromRGB(232, 190, 110),
	AmberDim = Color3.fromRGB(150, 118, 66),
	Good = Color3.fromRGB(130, 210, 130),
	Warn = Color3.fromRGB(235, 160, 70),
	Danger = Color3.fromRGB(220, 60, 50),
	Radio = Color3.fromRGB(150, 210, 190),
	White = Color3.fromRGB(236, 232, 222),
}

Theme.Fonts = {
	Title = Font.fromEnum(Enum.Font.SpecialElite),
	Header = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular),
	BodyBold = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
}

function Theme.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	if props then
		local parent = props.Parent
		for k, v in props do
			if k ~= "Parent" then
				(instance :: any)[k] = v
			end
		end
		if children then
			for _, child in children do
				child.Parent = instance
			end
		end
		if parent then
			instance.Parent = parent
		end
	elseif children then
		for _, child in children do
			child.Parent = instance
		end
	end
	return instance
end

function Theme.corner(parent: Instance, radius: number?): UICorner
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
end

function Theme.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return Theme.new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Theme.padding(parent: Instance, pixels: number)
	Theme.new("UIPadding", {
		PaddingTop = UDim.new(0, pixels),
		PaddingBottom = UDim.new(0, pixels),
		PaddingLeft = UDim.new(0, pixels),
		PaddingRight = UDim.new(0, pixels),
		Parent = parent,
	})
end

function Theme.screen(name: string, order: number, playerGui: Instance): ScreenGui
	return Theme.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		Parent = playerGui,
	})
end

function Theme.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.Ink,
		FontFace = Theme.Fonts.Body,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return Theme.new("TextLabel", defaults)
end

-- Aged paper sheet with a darker edge.
function Theme.paper(props: { [string]: any }): Frame
	local defaults = {
		BackgroundColor3 = Theme.Colors.Paper,
		BorderSizePixel = 0,
	}
	for k, v in props do
		defaults[k] = v
	end
	local frame = Theme.new("Frame", defaults)
	Theme.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 252, 240)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(242, 234, 214)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 192, 162)),
		}),
		Rotation = 35,
		Parent = frame,
	})
	Theme.stroke(frame, Theme.Colors.PaperDark, 2)
	return frame
end

-- Red rubber stamp text, slightly rotated.
function Theme.stamp(parent: Instance, text: string, position: UDim2, rotation: number): TextLabel
	local label = Theme.label({
		Text = text,
		FontFace = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Stamp,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(240, 40),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation,
		TextTransparency = 0.15,
		Parent = parent,
	})
	Theme.new("UIStroke", { Color = Theme.Colors.Stamp, Thickness = 2, Transparency = 0.3, Parent = label })
	return label
end

export type ButtonStyle = "Dossier" | "Radio" | "Danger"

function Theme.button(props: { [string]: any }, style: ButtonStyle?, onClick: (() -> ())?): TextButton
	local s = style or "Dossier"
	local background = if s == "Radio"
		then Theme.Colors.PanelLight
		elseif s == "Danger" then Theme.Colors.Stamp
		else Theme.Colors.Ink
	local textColor = if s == "Radio" then Theme.Colors.Amber else Theme.Colors.Paper
	local defaults = {
		BackgroundColor3 = background,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		TextColor3 = textColor,
		FontFace = Theme.Fonts.Header,
		TextSize = 20,
		Size = UDim2.fromOffset(240, 44),
	}
	for k, v in props do
		defaults[k] = v
	end
	local button = Theme.new("TextButton", defaults)
	Theme.corner(button, 3)
	local stroke = Theme.stroke(button, if s == "Radio" then Theme.Colors.AmberDim else Theme.Colors.InkSoft, 1)
	local base = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.12) })
			:Play()
		stroke.Color = if s == "Radio" then Theme.Colors.Amber else Theme.Colors.Stamp
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
		stroke.Color = if s == "Radio" then Theme.Colors.AmberDim else Theme.Colors.InkSoft
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- Dark translucent radio panel for the HUD.
function Theme.panel(props: { [string]: any }): Frame
	local defaults = {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}
	for k, v in props do
		defaults[k] = v
	end
	local frame = Theme.new("Frame", defaults)
	Theme.corner(frame, 4)
	Theme.stroke(frame, Theme.Colors.AmberDim, 1, 0.5)
	return frame
end

function Theme.fade(object: GuiObject, visible: boolean, time: number?)
	local t = time or 0.25
	if visible then
		object.Visible = true
	end
	local group = object:FindFirstChildOfClass("CanvasGroup") or object
	if group:IsA("CanvasGroup") then
		TweenService:Create(group, TweenInfo.new(t), { GroupTransparency = if visible then 0 else 1 }):Play()
	end
	if not visible then
		task.delay(t, function()
			object.Visible = false
		end)
	end
end

return Theme
