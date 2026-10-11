-- Two things that grab the screen:
--   * the paid scare from a teammate: a face on the tape, a stinger, then paranoia;
--   * the kill camera: when something takes you, you are made to look at it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Visuals = require(ReplicatedStorage.Shared.Config.Visuals)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local Registry = require(script.Parent.Parent.Registry)

local player = Players.LocalPlayer

local ScareController = {}

local screen: ScreenGui
local scareFrame: Frame
local face: Frame
local image: ImageLabel
local redOverlay: Frame

local killMonster: Model? = nil
local killUntil = 0

-- A face made of rectangles, for when no scare images are uploaded yet.
local function buildFace(parent: Instance): Frame
	local holder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.9),
		BackgroundColor3 = Color3.fromRGB(196, 186, 160),
		BorderSizePixel = 0,
		Parent = parent,
	})
	Theme.new("UIAspectRatioConstraint", { AspectRatio = 0.78, Parent = holder })
	Theme.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 250, 235), Color3.fromRGB(90, 80, 60)),
		Rotation = 90,
		Parent = holder,
	})
	Theme.corner(holder, 60)
	local function hole(x: number, y: number, w: number, h: number, color: Color3?)
		local f = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			BackgroundColor3 = color or Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = holder,
		})
		Theme.corner(f, 40)
		return f
	end
	hole(0.3, 0.36, 0.2, 0.15)
	hole(0.7, 0.36, 0.2, 0.15)
	hole(0.3, 0.37, 0.05, 0.04, Color3.fromRGB(255, 40, 30))
	hole(0.7, 0.37, 0.05, 0.04, Color3.fromRGB(255, 40, 30))
	hole(0.5, 0.74, 0.62, 0.3)
	-- Stitched grin
	for i = 0, 7 do
		local tooth = hole(0.24 + i * 0.075, 0.64, 0.035, 0.1, Color3.fromRGB(220, 210, 180))
		tooth.Rotation = (i % 2) * 10 - 5
	end
	return holder
end

local function build()
	screen = Theme.screen("Scare", 30, player:WaitForChild("PlayerGui"))
	screen.ScreenInsets = Enum.ScreenInsets.None
	redOverlay = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(120, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = screen,
	})
	Theme.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.85),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = redOverlay,
	})
	scareFrame = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Visible = false,
		Parent = screen,
	})
	face = buildFace(scareFrame)
	image = Theme.new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Crop,
		Visible = false,
		Parent = scareFrame,
	})
end

function ScareController:Scare(paranoiaSeconds: number)
	local images = Visuals.ScareImages
	local useImage = #images > 0
	image.Visible = useImage
	face.Visible = not useImage
	if useImage then
		image.Image = images[math.random(1, #images)]
	end
	local camera = workspace.CurrentCamera
	Registry.AudioController:PlayRecipe(
		"Scare",
		if camera then camera.CFrame.Position else Vector3.zero,
		{ Seed = math.random(1, 2 ^ 30) }
	)
	Registry.TapeController:Glitch(1.6, 1)

	scareFrame.Visible = true
	scareFrame.BackgroundTransparency = 0
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local target = if useImage then image else face
		local jitter = (1 - math.min(t / 0.9, 1)) * 0.03
		target.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * jitter, 0.5 + (math.random() - 0.5) * jitter)
		target.Size = if useImage
			then UDim2.fromScale(1 + t * 0.15, 1 + t * 0.15)
			else UDim2.fromScale(0.62 + t * 0.2, 0.9 + t * 0.2)
		if t > 0.9 then
			connection:Disconnect()
			TweenService:Create(scareFrame, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
			task.delay(0.05, function()
				scareFrame.Visible = false
			end)
		end
	end)
	task.delay(4, function()
		Registry.AudioController:StartParanoia(paranoiaSeconds)
	end)
end

-- Kill camera ----------------------------------------------------------------------------

local function monsterHead(model: Model): BasePart?
	local head = model:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") then
		return head
	end
	return model.PrimaryPart
end

local function endKillCam()
	killMonster = nil
	RunService:UnbindFromRenderStep("KillCam")
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	TweenService:Create(redOverlay, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

local function startKillCam(monster: Model, duration: number)
	killMonster = monster
	killUntil = os.clock() + duration
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	Registry.TapeController:Glitch(duration, 0.5)
	Registry.MapController:Close()
	Registry.ShopController:Close()
	local started = os.clock()
	RunService:BindToRenderStep("KillCam", Enum.RenderPriority.Camera.Value + 2, function()
		local now = os.clock()
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local target = killMonster and monsterHead(killMonster)
		if now > killUntil + 0.5 or not head or not target then
			endKillCam()
			return
		end
		local t = now - started
		local shake = 0.04 + math.min(t / duration, 1) * 0.1
		local eye = head.Position + Vector3.new(0, 0.3, 0)
		local look = CFrame.lookAt(eye, target.Position)
		camera.CFrame = look
			* CFrame.Angles(
				(math.random() - 0.5) * shake,
				(math.random() - 0.5) * shake,
				(math.random() - 0.5) * shake * 2
			)
		camera.FieldOfView = 70 - math.min(t / duration, 1) * 22
		local pulse = (math.sin(t * 9) + 1) / 2
		redOverlay.BackgroundTransparency = 0.25 + pulse * 0.35
	end)
end

function ScareController:Init()
	build()
end

function ScareController:Start()
	Net.event("Scare").OnClientEvent:Connect(function(_fromName, paranoiaSeconds)
		self:Scare(paranoiaSeconds or 120)
	end)
	Net.event("KillCam").OnClientEvent:Connect(function(monster, duration)
		if duration and duration > 0 and typeof(monster) == "Instance" and monster:IsA("Model") then
			startKillCam(monster, duration)
		else
			endKillCam()
			workspace.CurrentCamera.FieldOfView = 70
		end
	end)
	player.CharacterRemoving:Connect(function()
		if killMonster then
			endKillCam()
		end
		workspace.CurrentCamera.FieldOfView = 70
	end)
end

return ScareController
