-- Tactical map: a field map pinned on the HQ table, opened with [M] or at the table.
--
-- Commander controls:
--   click a soldier          toggle selection
--   drag on the map          box-select
--   Route, then drag         draw a path; release to send
--   order buttons            Follow / Sweep / Gather / Hold / Retreat / Revive
-- Everyone else can watch the map but not give orders.
--
-- Map orientation: +X to the right, +Z down (a true top-down view, not mirrored).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local SquadConfig = require(ReplicatedStorage.Shared.Config.Squad)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Lang = require(script.Parent.Parent.Lang)
local Theme = require(script.Parent.Parent.UI.Theme)
local Registry = require(script.Parent.Parent.Registry)

local player = Players.LocalPlayer
local C = Theme.Colors
local Orders = SquadConfig.Orders

local MapController = {}

local INK = Color3.fromRGB(46, 42, 36)
local WHEAT = Color3.fromRGB(176, 150, 74)
local ORDER_COLORS = {
	Follow = Color3.fromRGB(60, 110, 160),
	Route = Color3.fromRGB(150, 110, 40),
	Wander = Color3.fromRGB(120, 70, 140),
	Gather = Color3.fromRGB(60, 130, 70),
	Hold = Color3.fromRGB(90, 90, 90),
	Retreat = Color3.fromRGB(160, 60, 40),
	Revive = Color3.fromRGB(40, 150, 120),
}
local ORDER_BUTTONS = { "Follow", "Route", "Wander", "Gather", "Hold", "Retreat", "Revive" }

local screen: ScreenGui
local mapFrame: TextButton
local staticLayer: Frame
local dynamicLayer: Frame
local drawLayer: Frame
local boxFrame: Frame
local listFrame: ScrollingFrame
local hintLabel: TextLabel
local squadHeader: TextLabel
local subPanel: Frame
local orderButtons: { [string]: TextButton } = {}
local fastButton: TextButton
local transferButton: TextButton

local open = false
local layout: any = nil
local snapshot: any = { S = {}, P = {}, M = {}, I = {}, T = {} }
local selected: { [number]: true } = {}
local rows: { [number]: { Button: TextButton, Name: TextLabel, Order: TextLabel, Health: Frame } } = {}
local mode = "Select" -- "Select" | "Route"
local fast = false
local drawing: { Vector2 }? = nil
local boxStart: Vector2? = nil
local radius = 425

local function isCommander(): boolean
	return player:GetAttribute("IsCommander") == true
end

local function toScale(x: number, z: number): UDim2
	return UDim2.fromScale(0.5 + x / (2 * radius), 0.5 + z / (2 * radius))
end

local function pointer(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
end

local function toWorld(screenPos: Vector2): Vector2
	local rel = (screenPos - mapFrame.AbsolutePosition) / mapFrame.AbsoluteSize
	return Vector2.new((rel.X - 0.5) * 2 * radius, (rel.Y - 0.5) * 2 * radius)
end

local function line(
	parent: Instance,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	thickness: number,
	color: Color3,
	transparency: number?
): Frame
	local dx, dz = x2 - x1, z2 - z1
	local length = math.sqrt(dx * dx + dz * dz)
	return Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toScale((x1 + x2) / 2, (z1 + z2) / 2),
		Size = UDim2.new(length / (2 * radius), 0, 0, thickness),
		Rotation = math.deg(math.atan2(dz, dx)),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

local function dot(parent: Instance, x: number, z: number, size: number, color: Color3, round: boolean?): Frame
	local frame = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toScale(x, z),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
	if round then
		Theme.corner(frame, size)
	end
	return frame
end

local function tag(
	parent: Instance,
	x: number,
	z: number,
	text: string,
	color: Color3,
	size: number?,
	offsetY: number?
): TextLabel
	return Theme.label({
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = toScale(x, z) + UDim2.fromOffset(0, offsetY or 8),
		Size = UDim2.fromOffset(140, 14),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color,
		TextSize = size or 11,
		FontFace = Theme.Fonts.BodyBold,
		TextWrapped = false,
		Parent = parent,
	})
end

-- Static layer: terrain, roads, landmarks -------------------------------------------

local function buildStatic()
	staticLayer:ClearAllChildren()
	if not layout then
		return
	end
	radius = (layout.Radius or 400) + 25
	local cell = layout.CellSize or 16

	-- Grid every 50 studs, like a printed military map
	for v = -radius + (radius % 50), radius, 50 do
		line(staticLayer, v, -radius, v, radius, 1, INK, 0.88)
		line(staticLayer, -radius, v, radius, v, 1, INK, 0.88)
	end

	-- Wheat: merge cells into horizontal runs to keep the GUI light
	local byRow: { [number]: { number } } = {}
	local wheat = layout.Wheat or {}
	for i = 1, #wheat, 2 do
		local x, z = wheat[i], wheat[i + 1]
		byRow[z] = byRow[z] or {}
		table.insert(byRow[z], x)
	end
	for z, xs in byRow do
		table.sort(xs)
		local runStart, previous = xs[1], xs[1]
		local function flush(a: number, b: number)
			local x1, x2 = a - cell / 2, b + cell / 2
			Theme.new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = toScale(x1, z),
				Size = UDim2.fromScale((x2 - x1) / (2 * radius), cell / (2 * radius)),
				BackgroundColor3 = WHEAT,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Parent = staticLayer,
			})
		end
		for i = 2, #xs do
			if xs[i] - previous > cell + 0.5 then
				flush(runStart, previous)
				runStart = xs[i]
			end
			previous = xs[i]
		end
		if runStart then
			flush(runStart, previous)
		end
	end

	-- Dirt roads
	for _, seg in layout.Paths or {} do
		line(staticLayer, seg[1], seg[2], seg[3], seg[4], 4, Color3.fromRGB(120, 92, 62), 0.2)
	end

	-- Railway across the whole map, train in the middle
	line(staticLayer, -radius, -5, radius, -5, 3, INK, 0)
	for x = -radius, radius, 12 do
		line(staticLayer, x, -8, x, -2, 1, INK, 0.3)
	end
	local train = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = toScale(-66, -5),
		Size = UDim2.new(134 / (2 * radius), 0, 0, 10),
		BackgroundColor3 = C.Olive,
		BorderSizePixel = 0,
		Parent = staticLayer,
	})
	Theme.stroke(train, INK, 1)
	tag(staticLayer, 0, -5, Lang.t("Map_Train"), INK, 12, -24)

	-- Landmarks
	for _, poi in layout.POIs or {} do
		local kind, x, z, r = poi[1], poi[2], poi[3], poi[4]
		local ring = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toScale(x, z),
			Size = UDim2.fromScale(r * 2 / (2 * radius), r * 2 / (2 * radius)),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Parent = staticLayer,
		})
		Theme.corner(ring, 200)
		Theme.stroke(ring, INK, 1, 0.4)
		tag(staticLayer, x, z, Lang.t("Poi_" .. kind), INK, 11, -6)
	end

	-- Reanimators: green crosses
	for _, p in layout.Reanimators or {} do
		local holder = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toScale(p[1], p[2]),
			Size = UDim2.fromOffset(14, 14),
			BackgroundTransparency = 1,
			Parent = staticLayer,
		})
		local green = Color3.fromRGB(40, 150, 90)
		Theme.new("Frame", {
			Size = UDim2.new(1, 0, 0, 4),
			Position = UDim2.new(0, 0, 0.5, -2),
			BackgroundColor3 = green,
			BorderSizePixel = 0,
			Parent = holder,
		})
		Theme.new("Frame", {
			Size = UDim2.new(0, 4, 1, 0),
			Position = UDim2.new(0.5, -2, 0, 0),
			BackgroundColor3 = green,
			BorderSizePixel = 0,
			Parent = holder,
		})
	end
end

-- Dynamic layer: squad, players, sightings -------------------------------------------------

local blink = 0

local function buildDynamic()
	dynamicLayer:ClearAllChildren()
	if not open then
		return
	end
	for _, item in snapshot.I or {} do
		local def = Resources.Kinds[item[3]]
		local square = dot(dynamicLayer, item[1], item[2], 7, if def then def.Color else INK)
		Theme.stroke(square, INK, 1)
	end
	for _, t in snapshot.T or {} do
		local owner = Players:GetPlayerByUserId(t[1])
		dot(dynamicLayer, t[2], t[3], 8, Color3.fromRGB(200, 200, 205), true)
		tag(
			dynamicLayer,
			t[2],
			t[3],
			(if owner then owner.DisplayName else "?") .. " ✝",
			Color3.fromRGB(70, 70, 76),
			10
		)
	end
	for _, m in snapshot.M or {} do
		local mark = tag(dynamicLayer, m[1], m[2], "✕", C.Stamp, 18, -10)
		mark.FontFace = Theme.Fonts.Header
		tag(dynamicLayer, m[1], m[2], Lang.t("Monster_" .. m[3]), C.Stamp, 10, 6)
	end
	for _, s in snapshot.S or {} do
		local id, x, z, order, _hp, carrying, name, kind, grabbed = table.unpack(s)
		local color = ORDER_COLORS[order] or INK
		if grabbed == 1 then
			color = if blink % 2 == 0 then C.Stamp else C.White
		end
		if selected[id] then
			local ring = dot(dynamicLayer, x, z, 17, C.Amber, true)
			ring.BackgroundTransparency = 0.3
		end
		local body = dot(dynamicLayer, x, z, if kind == "Super" then 12 else 10, color, kind ~= "Super")
		Theme.stroke(body, INK, 1)
		if carrying ~= "" then
			local def = Resources.Kinds[carrying]
			local pack = dot(dynamicLayer, x + 6, z - 6, 6, if def then def.Color else INK)
			Theme.stroke(pack, INK, 1)
		end
		if selected[id] then
			tag(dynamicLayer, x, z, name, INK, 10)
		end
	end
	for _, p in snapshot.P or {} do
		local userId, x, z, name = p[1], p[2], p[3], p[4]
		local me = userId == player.UserId
		local diamond = dot(dynamicLayer, x, z, 11, if me then C.Amber else C.White)
		diamond.Rotation = 45
		Theme.stroke(diamond, INK, 2)
		tag(dynamicLayer, x, z, if me then Lang.t("Map_You") else name, INK, 11)
	end
end

-- Side panel ---------------------------------------------------------------------------

local function selectedIds(): { number }
	local ids = {}
	for _, s in snapshot.S or {} do
		if selected[s[1]] then
			table.insert(ids, s[1])
		end
	end
	return ids
end

local function refreshHint()
	if not isCommander() then
		hintLabel.Text = Lang.t("Map_NotCommander")
		hintLabel.TextColor3 = C.Stamp
	elseif mode == "Route" then
		hintLabel.Text = Lang.t("Map_DrawRoute")
		hintLabel.TextColor3 = C.Amber
	elseif #selectedIds() == 0 then
		hintLabel.Text = Lang.t("Map_NoSelection")
		hintLabel.TextColor3 = C.AmberDim
	else
		hintLabel.Text = ""
	end
	for name, button in orderButtons do
		button.AutoButtonColor = false
		button.TextTransparency = if isCommander() then 0 else 0.6
		button.BackgroundColor3 = if name == "Route" and mode == "Route" then C.Olive else C.PanelLight
	end
	fastButton.Visible = mode == "Route"
	fastButton.BackgroundColor3 = if fast then C.Olive else C.PanelLight
	transferButton.Visible = isCommander()
end

local function refreshList()
	local alive: { [number]: boolean } = {}
	for i, s in snapshot.S or {} do
		local id, _x, _z, order, hp, carrying, name, kind = table.unpack(s)
		alive[id] = true
		local row = rows[id]
		if not row then
			local button = Theme.new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.new(1, -6, 0, 30),
				BackgroundColor3 = C.PanelLight,
				BorderSizePixel = 0,
				Parent = listFrame,
			})
			Theme.corner(button, 3)
			local nameLabel = Theme.label({
				Text = "",
				TextColor3 = C.Amber,
				TextSize = 13,
				FontFace = Theme.Fonts.BodyBold,
				Size = UDim2.new(0.55, -8, 0, 18),
				Position = UDim2.fromOffset(8, 2),
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = button,
			})
			local orderLabel = Theme.label({
				Text = "",
				TextColor3 = C.AmberDim,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.new(0.45, -8, 0, 18),
				Position = UDim2.new(0.55, 0, 0, 2),
				TextWrapped = false,
				Parent = button,
			})
			local back = Theme.new("Frame", {
				Size = UDim2.new(1, -16, 0, 3),
				Position = UDim2.new(0, 8, 1, -7),
				BackgroundColor3 = C.Panel,
				BorderSizePixel = 0,
				Parent = button,
			})
			local health = Theme.new(
				"Frame",
				{ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Good, BorderSizePixel = 0, Parent = back }
			)
			button.Activated:Connect(function()
				if selected[id] then
					selected[id] = nil
				else
					selected[id] = true
				end
				refreshList()
				buildDynamic()
				refreshHint()
			end)
			row = { Button = button, Name = nameLabel, Order = orderLabel, Health = health }
			rows[id] = row
		end
		row.Button.LayoutOrder = i
		row.Name.Text = name .. (if carrying ~= "" then "  ▪" else "")
		row.Order.Text = Lang.t("Order_" .. order)
		row.Order.TextColor3 = ORDER_COLORS[order] and (ORDER_COLORS[order] :: Color3):Lerp(C.White, 0.35) or C.AmberDim
		row.Health.Size = UDim2.fromScale(hp / 100, 1)
		row.Health.BackgroundColor3 = if hp > 60 then C.Good elseif hp > 30 then C.Warn else C.Danger
		row.Button.BackgroundColor3 = if selected[id] then C.Olive else C.PanelLight
		if kind == "Super" then
			row.Name.TextColor3 = C.Radio
		end
	end
	for id, row in rows do
		if not alive[id] then
			row.Button:Destroy()
			rows[id] = nil
			selected[id] = nil
		end
	end
	squadHeader.Text = Lang.t("Map_Squad") .. "  " .. #(snapshot.S or {})
end

local function send(command: { [string]: any })
	if not isCommander() then
		Registry.HudController:Notify("Map_NotCommander", nil, "warn")
		return
	end
	Net.event("SquadCommand"):FireServer(command)
	Registry.AudioController:Play2D("RadioKeyUp", "Ui", 0.45)
end

local function closeSub()
	subPanel.Visible = false
	for _, child in subPanel:GetChildren() do
		if child:IsA("GuiButton") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function openSub(title: string, entries: { { Text: string, Action: () -> () } })
	closeSub()
	subPanel.Visible = true
	Theme.label({
		Text = title,
		TextColor3 = C.Amber,
		FontFace = Theme.Fonts.Header,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 0,
		Parent = subPanel,
	})
	for i, entry in entries do
		Theme.button(
			{ Text = entry.Text, TextSize = 15, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i, Parent = subPanel },
			"Radio",
			function()
				closeSub()
				entry.Action()
			end
		)
	end
	Theme.button({
		Text = Lang.t("Menu_Back"),
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 99,
		Parent = subPanel,
	}, "Dossier", closeSub)
end

local function issue(order: string)
	if not isCommander() then
		Registry.HudController:Notify("Map_NotCommander", nil, "warn")
		return
	end
	local ids = selectedIds()
	if order == "Route" then
		mode = if mode == "Route" then "Select" else "Route"
		refreshHint()
		return
	end
	mode = "Select"
	if order == "Revive" then
		local entries = {}
		for _, t in snapshot.T or {} do
			local owner = Players:GetPlayerByUserId(t[1])
			if owner then
				table.insert(entries, {
					Text = owner.DisplayName,
					Action = function()
						send({ Order = Orders.Revive, Ids = if #ids > 0 then ids else "all", UserId = t[1] })
					end,
				})
			end
		end
		if #entries > 0 then
			openSub(Lang.t("Map_ReviveWho"), entries)
		end
		return
	end
	if #ids == 0 then
		refreshHint()
		return
	end
	send({ Order = order, Ids = ids })
end

local function sendRoute(points: { Vector2 })
	local ids = selectedIds()
	if #ids == 0 or #points == 0 then
		return
	end
	-- Thin the path out to the waypoint budget
	local step = math.max(1, math.ceil(#points / SquadConfig.MaxRouteWaypoints))
	local waypoints = {}
	for i = 1, #points, step do
		table.insert(waypoints, { math.round(points[i].X), math.round(points[i].Y) })
	end
	local last = points[#points]
	waypoints[#waypoints] = { math.round(last.X), math.round(last.Y) }
	send({ Order = Orders.Route, Ids = ids, Waypoints = waypoints, Fast = fast })
	mode = "Select"
	refreshHint()
end

-- Construction ---------------------------------------------------------------------------

local function build()
	screen = Theme.screen("Map", 12, player:WaitForChild("PlayerGui"))
	screen.Enabled = false
	local shade = Theme.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Modal = true, -- frees the mouse in first person
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = screen,
	})
	shade.Activated:Connect(function() end)

	local paper = Theme.paper({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 24, 0.5, 0),
		Size = UDim2.new(0.62, 0, 0.9, 0),
		Parent = screen,
	})
	Theme.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = paper })
	Theme.padding(paper, 16)
	Theme.label({
		Text = Lang.t("Map_Title") .. " · " .. "",
		Name = "Title",
		FontFace = Theme.Fonts.Title,
		TextSize = 20,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, -6),
		Parent = paper,
	})
	mapFrame = Theme.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 1, -22),
		Position = UDim2.fromOffset(0, 20),
		BackgroundColor3 = Color3.fromRGB(226, 214, 184),
		BorderSizePixel = 0,
		Parent = paper,
	})
	Theme.stroke(mapFrame, INK, 2)
	Theme.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = mapFrame })
	staticLayer = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = mapFrame })
	dynamicLayer = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = mapFrame })
	drawLayer = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = mapFrame })
	boxFrame = Theme.new("Frame", {
		BackgroundColor3 = C.Amber,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Visible = false,
		Parent = screen,
	})
	Theme.stroke(boxFrame, C.Amber, 1)

	-- Side panel
	local side = Theme.panel({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.new(0, 300, 0.9, 0),
		BackgroundTransparency = 0.1,
		Parent = screen,
	})
	Theme.padding(side, 12)
	squadHeader = Theme.label({
		Text = Lang.t("Map_Squad"),
		TextColor3 = C.Amber,
		FontFace = Theme.Fonts.Header,
		TextSize = 20,
		Size = UDim2.new(1, -40, 0, 26),
		Parent = side,
	})
	Theme.button(
		{
			Text = "✕",
			TextSize = 18,
			Size = UDim2.fromOffset(30, 26),
			Position = UDim2.new(1, -30, 0, 0),
			Parent = side,
		},
		"Radio",
		function()
			MapController:Close()
		end
	)
	Theme.button(
		{
			Text = Lang.t("Map_SelectAll"),
			TextSize = 14,
			Size = UDim2.new(0.5, -4, 0, 28),
			Position = UDim2.fromOffset(0, 32),
			Parent = side,
		},
		"Radio",
		function()
			for _, s in snapshot.S or {} do
				if s[8] == "Regular" then
					selected[s[1]] = true
				end
			end
			refreshList()
			buildDynamic()
			refreshHint()
		end
	)
	Theme.button(
		{
			Text = Lang.t("Map_SelectNone"),
			TextSize = 14,
			Size = UDim2.new(0.5, -4, 0, 28),
			Position = UDim2.new(0.5, 4, 0, 32),
			Parent = side,
		},
		"Radio",
		function()
			selected = {}
			refreshList()
			buildDynamic()
			refreshHint()
		end
	)

	listFrame = Theme.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -330),
		Position = UDim2.fromOffset(0, 68),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.AmberDim,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = side,
	})
	Theme.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = listFrame })

	local ordersFrame = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -78),
		Size = UDim2.new(1, 0, 0, 176),
		BackgroundTransparency = 1,
		Parent = side,
	})
	Theme.new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 38),
		CellPadding = UDim2.fromOffset(8, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ordersFrame,
	})
	for i, order in ORDER_BUTTONS do
		local button = Theme.button(
			{ Text = Lang.t("Order_" .. order), TextSize = 16, LayoutOrder = i, Parent = ordersFrame },
			"Radio",
			function()
				issue(order)
			end
		)
		local stripe = Theme.new("Frame", {
			Size = UDim2.new(0, 4, 1, 0),
			BackgroundColor3 = ORDER_COLORS[order],
			BorderSizePixel = 0,
			Parent = button,
		})
		stripe.ZIndex = 2
		orderButtons[order] = button
	end
	fastButton = Theme.button(
		{ Text = Lang.t("Order_Fast"), TextSize = 16, LayoutOrder = 8, Parent = ordersFrame },
		"Radio",
		function()
			fast = not fast
			refreshHint()
		end
	)

	hintLabel = Theme.label({
		AnchorPoint = Vector2.new(0, 1),
		Text = "",
		TextColor3 = C.AmberDim,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 1, -38),
		Parent = side,
	})
	transferButton = Theme.button(
		{
			AnchorPoint = Vector2.new(0, 1),
			Text = Lang.t("Commander_Transfer"),
			TextSize = 14,
			Size = UDim2.new(1, 0, 0, 32),
			Position = UDim2.new(0, 0, 1, 0),
			Parent = side,
		},
		"Dossier",
		function()
			local entries = {}
			for _, p in snapshot.P or {} do
				if p[1] ~= player.UserId then
					table.insert(entries, {
						Text = p[4],
						Action = function()
							Net.event("TransferCommand"):FireServer(p[1])
						end,
					})
				end
			end
			if #entries > 0 then
				openSub(Lang.t("Commander_Transfer"), entries)
			end
		end
	)

	subPanel = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 10,
		Parent = side,
	})
	Theme.padding(subPanel, 10)
	Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = subPanel })
end

-- Pointer handling on the map ---------------------------------------------------------------

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function redrawRoute()
	drawLayer:ClearAllChildren()
	if not drawing then
		return
	end
	for i = 2, #drawing do
		local a, b = drawing[i - 1], drawing[i]
		line(drawLayer, a.X, a.Y, b.X, b.Y, 3, Color3.fromRGB(150, 110, 40), 0.1)
	end
end

local function clickSelect(world: Vector2)
	local best, bestDist = nil, 14 * radius / 300
	for _, s in snapshot.S or {} do
		local d = (Vector2.new(s[2], s[3]) - world).Magnitude
		if d < bestDist then
			best, bestDist = s[1], d
		end
	end
	if best then
		if selected[best] then
			selected[best] = nil
		else
			selected[best] = true
		end
	end
end

local function boxSelect(a: Vector2, b: Vector2)
	local wa, wb = toWorld(a), toWorld(b)
	local minX, maxX = math.min(wa.X, wb.X), math.max(wa.X, wb.X)
	local minZ, maxZ = math.min(wa.Y, wb.Y), math.max(wa.Y, wb.Y)
	if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		selected = {}
	end
	for _, s in snapshot.S or {} do
		if s[2] >= minX and s[2] <= maxX and s[3] >= minZ and s[3] <= maxZ and s[8] == "Regular" then
			selected[s[1]] = true
		end
	end
end

local function connectPointer()
	mapFrame.InputBegan:Connect(function(input)
		if not isPointer(input) or subPanel.Visible then
			return
		end
		local pos = pointer(input)
		if mode == "Route" then
			drawing = { toWorld(pos) }
		else
			boxStart = pos
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not open then
			return
		end
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local pos = pointer(input)
		if drawing then
			local world = toWorld(pos)
			if (world - drawing[#drawing]).Magnitude > 10 then
				table.insert(drawing, world)
				redrawRoute()
			end
		elseif boxStart then
			local a, b = boxStart, pos
			if (b - a).Magnitude > 8 then
				boxFrame.Visible = true
				boxFrame.Position = UDim2.fromOffset(math.min(a.X, b.X), math.min(a.Y, b.Y))
				boxFrame.Size = UDim2.fromOffset(math.abs(b.X - a.X), math.abs(b.Y - a.Y))
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not open or not isPointer(input) then
			return
		end
		local pos = pointer(input)
		if drawing then
			local points = drawing
			drawing = nil
			task.delay(1.2, redrawRoute)
			if #points >= 1 then
				sendRoute(points)
			end
		elseif boxStart then
			if (pos - boxStart).Magnitude > 8 then
				boxSelect(boxStart, pos)
			else
				clickSelect(toWorld(pos))
			end
			boxStart = nil
			boxFrame.Visible = false
			refreshList()
			buildDynamic()
			refreshHint()
		end
	end)
end

-- API ----------------------------------------------------------------------------------------

function MapController:Open()
	if open then
		return
	end
	local phase = State.get("Phase")
	if phase == "Lobby" or phase == "Starting" or phase == "Ended" then
		return
	end
	open = true
	screen.Enabled = true
	refreshList()
	buildDynamic()
	refreshHint()
	Registry.AudioController:Play2D("RadioKeyDown", "Ui", 0.4)
end

function MapController:Close()
	if not open then
		return
	end
	open = false
	mode = "Select"
	drawing = nil
	boxStart = nil
	boxFrame.Visible = false
	closeSub()
	screen.Enabled = false
end

function MapController:Toggle()
	if open then
		self:Close()
	else
		self:Open()
	end
end

function MapController:IsOpen(): boolean
	return open
end

function MapController:Init()
	build()
	connectPointer()
end

function MapController:Start()
	Net.event("MapLayout").OnClientEvent:Connect(function(data)
		layout = data
		selected = {}
		buildStatic()
		local title = mapFrame.Parent and mapFrame.Parent:FindFirstChild("Title") :: TextLabel?
		if title and layout then
			title.Text = Lang.t("Map_Title") .. " · " .. Lang.t(State.get("StationKey") or "Station_Lobby")
		end
	end)
	State.changed("StationKey"):Connect(function()
		local title = mapFrame.Parent and mapFrame.Parent:FindFirstChild("Title") :: TextLabel?
		if title then
			title.Text = Lang.t("Map_Title") .. " · " .. Lang.t(State.get("StationKey") or "Station_Lobby")
		end
	end)
	Net.event("SquadSnapshot").OnClientEvent:Connect(function(data)
		snapshot = data
		blink += 1
		if open then
			refreshList()
			buildDynamic()
			refreshHint()
		end
	end)
	State.changed("Phase"):Connect(function()
		local phase = State.get("Phase")
		if phase == "Lobby" or phase == "Ended" then
			self:Close()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if open and player:GetAttribute("IsCommander") ~= true and mode == "Route" then
			mode = "Select"
			refreshHint()
		end
	end)
end

return MapController
