-- Player input: shooting, reloading, flashlight, sprint with stamina, map and shop.
-- Keyboard/mouse, gamepad and touch buttons all go through ContextActionService.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Lang = require(script.Parent.Parent.Lang)
local Registry = require(script.Parent.Parent.Registry)

local player = Players.LocalPlayer
local Rules = GameConfig.Player

local InputController = {}
InputController.Stamina = 1
InputController.InfiniteSprint = false

local sprintHeld = false
local sprinting = false
local exhausted = false
local lastSprintEnd = 0
local lastShot = 0
local recoil = 0

local function character(): (Model?, Humanoid?, BasePart?)
	local c = player.Character
	if not c then
		return nil, nil, nil
	end
	return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function uiBlocking(): boolean
	return Registry.MenuController:IsOpen() or Registry.MapController:IsOpen() or Registry.ShopController:IsOpen()
end

local function canAct(): boolean
	local c, humanoid = character()
	return c ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and player:GetAttribute("Alive") == true
		and not c:GetAttribute("BeingKilled")
end

-- Where the player is aiming: through the cursor, or the screen centre on touch/gamepad.
local function aimPoint(useCentre: boolean): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local screenPoint = if useCentre or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		then camera.ViewportSize / 2
		else UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	for _, name in { "Squad", "Items", "Corpses" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * Weapons.Range * 1.5, params)
	return if result then result.Position else ray.Origin + ray.Direction * Weapons.Range
end

local function fire(useCentre: boolean)
	if not canAct() or uiBlocking() then
		return
	end
	local now = os.clock()
	if now - lastShot < Weapons.FireInterval or player:GetAttribute("Reloading") then
		return
	end
	lastShot = now
	local c = player.Character :: Model
	local head = c:FindFirstChild("Head") :: BasePart?
	if (player:GetAttribute("Ammo") or 0) <= 0 then
		if head then
			Registry.AudioController:PlayAt("PistolDry", head, 0.8)
		end
		if (player:GetAttribute("Reserve") or 0) > 0 then
			Net.event("Reload"):FireServer()
		end
		return
	end
	local target = aimPoint(useCentre)
	if not target then
		return
	end
	Net.event("Fire"):FireServer(target)
	if head then
		Registry.AudioController:PlayAt("PistolShot", head, 1, math.random(96, 104) / 100)
		local flash = Instance.new("PointLight")
		flash.Color = Color3.fromRGB(255, 210, 150)
		flash.Range = 16
		flash.Brightness = 5
		flash.Parent = head
		task.delay(0.05, function()
			flash:Destroy()
		end)
	end
	recoil = math.min(recoil + 0.035, 0.08)
end

local function reload()
	if not canAct() or player:GetAttribute("Reloading") then
		return
	end
	local level = Weapons.Levels[math.clamp(player:GetAttribute("WeaponLevel") or 1, 1, #Weapons.Levels)]
	if (player:GetAttribute("Ammo") or 0) >= level.Magazine or (player:GetAttribute("Reserve") or 0) <= 0 then
		return
	end
	Net.event("Reload"):FireServer()
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if head then
		Registry.AudioController:PlayAt("PistolReload", head, 0.8)
	end
end

local function setSprinting(value: boolean)
	if value ~= sprinting then
		sprinting = value
		Net.event("Sprinting"):FireServer(value)
		if not value then
			lastSprintEnd = os.clock()
		end
	end
end

local function bind()
	local Begin = Enum.UserInputState.Begin
	local Pass = Enum.ContextActionResult.Pass
	local Sink = Enum.ContextActionResult.Sink

	ContextActionService:BindAction("FodderFire", function(_, state, input)
		if state == Begin then
			fire(input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonR2)
		end
		return Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	ContextActionService:BindAction("FodderReload", function(_, state)
		if state == Begin then
			reload()
		end
		return Sink
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)

	ContextActionService:BindAction("FodderFlashlight", function(_, state)
		if state == Begin and canAct() then
			Net.event("ToggleFlashlight"):FireServer()
			local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
			if head then
				Registry.AudioController:PlayAt("RadioKeyDown", head, 0.4, 1.4)
			end
		end
		return Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.DPadUp)

	ContextActionService:BindAction("FodderSprint", function(_, state, input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if state == Begin then
				sprintHeld = not sprintHeld -- toggle on touch
			end
		else
			sprintHeld = state == Begin or state == Enum.UserInputState.Change
		end
		return Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	ContextActionService:BindAction("FodderMap", function(_, state)
		if state == Begin then
			Registry.MapController:Toggle()
		end
		return Sink
	end, true, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)

	ContextActionService:BindAction("FodderShop", function(_, state)
		if state == Begin then
			Registry.ShopController:Toggle()
		end
		return Sink
	end, false, Enum.KeyCode.B)

	-- Touch button captions
	ContextActionService:SetTitle("FodderFire", "●")
	ContextActionService:SetTitle("FodderReload", "R")
	ContextActionService:SetTitle("FodderFlashlight", "F")
	ContextActionService:SetTitle("FodderSprint", "»")
	ContextActionService:SetTitle("FodderMap", Lang.t("HUD_Map"))
	ContextActionService:SetPosition("FodderFire", UDim2.new(1, -150, 1, -150))
	ContextActionService:SetPosition("FodderReload", UDim2.new(1, -220, 1, -110))
	ContextActionService:SetPosition("FodderFlashlight", UDim2.new(1, -210, 1, -190))
	ContextActionService:SetPosition("FodderSprint", UDim2.new(1, -95, 1, -230))
	ContextActionService:SetPosition("FodderMap", UDim2.new(1, -170, 1, -260))
end

function InputController:Start()
	bind()

	RunService.RenderStepped:Connect(function(dt)
		local c, humanoid, root = character()
		self.InfiniteSprint = (player:GetAttribute("InfiniteSprintUntil") or 0) > State.now()

		local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
		local wantSprint = sprintHeld and moving and canAct() and not exhausted
		if wantSprint and not self.InfiniteSprint then
			self.Stamina = math.max(0, self.Stamina - dt / Rules.StaminaSeconds)
			if self.Stamina <= 0 then
				exhausted = true
				wantSprint = false
			end
		elseif not wantSprint and os.clock() - lastSprintEnd > 0.8 then
			self.Stamina = math.min(1, self.Stamina + Rules.StaminaRegenPerSecond * dt)
		end
		if exhausted and self.Stamina > 0.3 then
			exhausted = false
		end
		if self.InfiniteSprint then
			self.Stamina = 1
		end
		setSprinting(wantSprint)

		if humanoid and c and root and not root.Anchored then
			local speed = if wantSprint then Rules.SprintSpeed else Rules.WalkSpeed
			if c:GetAttribute("Carrying") then
				speed *= Rules.CarrySpeedMultiplier
			end
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end
		end
	end)

	-- Recoil kick, applied after the camera scripts have positioned the camera
	RunService:BindToRenderStep("FodderRecoil", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if recoil > 0.0005 then
			local camera = workspace.CurrentCamera
			if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
				camera.CFrame *= CFrame.Angles(recoil, 0, 0)
			end
			recoil = math.max(0, recoil - dt * 0.35)
		end
	end)

	player.CharacterAdded:Connect(function()
		self.Stamina = 1
		exhausted = false
		sprinting = false
	end)
end

return InputController
