-- Pick-up items: diesel, scrap, supplies, fuses and dog tags of fallen players.
-- Players and soldiers carry one item on their back. Pooled items are delivered to the train.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local State = require(ReplicatedStorage.Shared.State)
local Server = ServerScriptService.Server
local Builder = require(Server.World.Builder)
local Notify = require(Server.Util.Notify)
local Registry = require(Server.Registry)

local ResourceService = {}

local folder: Folder
local nextId = 0
local carried: { [Model]: Model } = {} -- carrier -> item
local pools: { [string]: number } = { Diesel = 0, Scrap = 0, Supplies = 0 }

local function setPool(kind: string, value: number)
	pools[kind] = value
	State.set(kind .. "Pool", value)
	if kind == "Diesel" then
		Registry.TrainService:UpdateGauge(value, State.get("DieselNeeded") or 0)
	end
end

local function decorate(model: Model, handle: BasePart, kind: string)
	local def = Resources.Kinds[kind]
	if kind == "Diesel" then
		Builder.detail(
			model,
			handle.CFrame * CFrame.new(0.35, 1.1, 0),
			Vector3.new(0.4, 0.3, 0.4),
			Enum.Material.Metal,
			Color3.fromRGB(40, 40, 40)
		)
		Builder.detail(
			model,
			handle.CFrame * CFrame.new(-0.2, 1.05, 0),
			Vector3.new(0.7, 0.15, 0.2),
			Enum.Material.Metal,
			def.Color
		)
	elseif kind == "Scrap" then
		for i = 1, 3 do
			Builder.detail(
				model,
				handle.CFrame * CFrame.new((i - 2) * 0.5, 0.45, 0) * CFrame.Angles(0, i, 0.4 * i),
				Vector3.new(1.2, 0.2, 0.6),
				Enum.Material.CorrodedMetal,
				Color3.fromRGB(120, 84, 60)
			)
		end
	elseif kind == "Supplies" then
		Builder.detail(
			model,
			handle.CFrame * CFrame.new(0, 0, -0.71),
			Vector3.new(0.9, 0.9, 0.02),
			Enum.Material.SmoothPlastic,
			Color3.fromRGB(200, 200, 190)
		)
	elseif kind == "Fuse" then
		Builder.detail(
			model,
			handle.CFrame,
			Vector3.new(0.75, 0.3, 0.75),
			Enum.Material.Neon,
			Color3.fromRGB(255, 210, 90)
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 90)
		light.Range = 8
		light.Brightness = 1
		light.Parent = handle
	elseif kind == "DogTag" then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(180, 210, 255)
		light.Range = 7
		light.Brightness = 0.8
		light.Parent = handle
	end
end

function ResourceService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Items"
	folder.Parent = workspace
	for kind in pools do
		setPool(kind, 0)
	end
end

function ResourceService:Start()
	-- Players deliver automatically when they step into the train with a pooled item
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				if character and carried[character] then
					local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and Registry.TrainService:IsInSafeZone(root.Position) then
						local item = carried[character]
						local def = Resources.Kinds[item:GetAttribute("Kind")]
						if def and def.Pooled then
							self:Deposit(character)
						end
					end
				end
			end
		end
	end)
end

function ResourceService:SpawnItem(kind: string, position: Vector3, attributes: { [string]: any }?): Model
	local def = Resources.Kinds[kind]
	assert(def, "Unknown resource " .. kind)
	nextId += 1
	local model = Instance.new("Model")
	model.Name = kind
	local handle = Builder.part(
		model,
		CFrame.new(position + Vector3.new(0, def.Size.Y / 2, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0),
		def.Size,
		Enum.Material.Metal,
		def.Color,
		{
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Massless = true,
		}
	)
	handle.Name = "Handle"
	if kind == "Supplies" then
		handle.Material = Enum.Material.WoodPlanks
	elseif kind == "Scrap" then
		handle.Material = Enum.Material.CorrodedMetal
	end
	model.PrimaryPart = handle
	decorate(model, handle, kind)
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Id", nextId)
	if attributes then
		for k, v in attributes do
			model:SetAttribute(k, v)
		end
	end

	local objectKey = def.NameKey
	local prompt =
		Builder.prompt(handle, if kind == "DogTag" then "Prompt_TakeTag" else "Prompt_PickUp", objectKey, 0.35, 8)
	if attributes and attributes.OwnerName then
		prompt:SetAttribute("ObjectArg", attributes.OwnerName)
	end
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		if not character or not Registry.PlayerService:IsAlive(player) then
			return
		end
		if carried[character] then
			Notify.player(player, "Notify_HandsFull", nil, "warn")
			return
		end
		self:PickUp(character, model)
	end)

	model:AddTag("Resource")
	model.Parent = folder
	return model
end

function ResourceService:SpawnFromLayout(layout: any)
	for _, entry in layout.Resources or {} do
		self:SpawnItem(entry.Kind, entry.Position)
	end
	for _, position in layout.Fuses or {} do
		self:SpawnItem("Fuse", position)
	end
end

function ResourceService:ClearWorld()
	for _, item in folder:GetChildren() do
		if not item:GetAttribute("Carrier") then
			item:Destroy()
		end
	end
end

function ResourceService:ClearAll()
	for carrier in carried do
		carrier:SetAttribute("Carrying", nil)
	end
	carried = {}
	folder:ClearAllChildren()
end

local function attachPoint(carrier: Model): BasePart?
	local part = carrier:FindFirstChild("UpperTorso") or carrier:FindFirstChild("Torso") or carrier.PrimaryPart
	return if part and part:IsA("BasePart") then part else nil
end

function ResourceService:PickUp(carrier: Model, item: Model): boolean
	if carried[carrier] or item:GetAttribute("Carrier") or not item.Parent then
		return false
	end
	local torso = attachPoint(carrier)
	local handle = item.PrimaryPart
	if not torso or not handle then
		return false
	end
	carried[carrier] = item
	item:SetAttribute("Carrier", carrier.Name)
	item:SetAttribute("Claim", nil)
	carrier:SetAttribute("Carrying", item:GetAttribute("Kind"))

	local prompt = handle:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	local offset = CFrame.new(0, 0.1, 0.95) * CFrame.Angles(0, math.pi, 0)
	for _, part in item:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			if part ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	handle.CFrame = torso.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = torso
	weld.Part1 = handle
	weld.Parent = handle
	item.Parent = carrier
	return true
end

local function release(item: Model, position: Vector3?)
	local handle = item.PrimaryPart
	if not handle then
		return
	end
	local carryWeld = handle:FindFirstChild("CarryWeld")
	if carryWeld then
		carryWeld:Destroy()
	end
	item:SetAttribute("Carrier", nil)
	item.Parent = folder
	local ground = position or handle.Position
	local def = Resources.Kinds[item:GetAttribute("Kind") :: string]
	local y = if def then def.Size.Y / 2 else 0.5
	item:PivotTo(
		CFrame.new(Vector3.new(ground.X, math.max(0, ground.Y - 2.6) + y, ground.Z))
			* CFrame.Angles(0, math.random() * 6.28, 0)
	)
	for _, part in item:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	local prompt = handle:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = true
	end
end

function ResourceService:Drop(carrier: Model): Model?
	local item = carried[carrier]
	if not item then
		return nil
	end
	carried[carrier] = nil
	carrier:SetAttribute("Carrying", nil)
	local root = carrier.PrimaryPart or carrier:FindFirstChild("HumanoidRootPart") :: BasePart?
	release(item, if root then root.Position else nil)
	return item
end

function ResourceService:GetCarried(carrier: Model): Model?
	return carried[carrier]
end

-- Removes the carried item without delivering it (used for fuses and dog tags).
function ResourceService:Consume(carrier: Model): Model?
	local item = carried[carrier]
	if not item then
		return nil
	end
	carried[carrier] = nil
	carrier:SetAttribute("Carrying", nil)
	item:Destroy()
	return item
end

function ResourceService:Deposit(carrier: Model): string?
	local item = carried[carrier]
	if not item then
		return nil
	end
	local kind = item:GetAttribute("Kind")
	local def = Resources.Kinds[kind]
	if not def or not def.Pooled then
		return nil
	end
	self:Consume(carrier)
	setPool(kind, pools[kind] + 1)
	Notify.all("Notify_Deposit", { def.NameKey }, "good")
	return kind
end

function ResourceService:GetPool(kind: string): number
	return pools[kind] or 0
end

function ResourceService:SpendPool(kind: string, amount: number): boolean
	if (pools[kind] or 0) < amount then
		return false
	end
	setPool(kind, pools[kind] - amount)
	return true
end

function ResourceService:ResetPools()
	for kind in pools do
		setPool(kind, 0)
	end
end

function ResourceService:RefreshGauge()
	Registry.TrainService:UpdateGauge(pools.Diesel, State.get("DieselNeeded") or 0)
end

function ResourceService:GetItems(): { Model }
	return folder:GetChildren() :: { any }
end

function ResourceService:FindNearest(position: Vector3, radius: number, filter: ((Model) -> boolean)?): Model?
	local best, bestDist = nil, radius
	for _, item in folder:GetChildren() do
		if item:IsA("Model") and not item:GetAttribute("Carrier") and item.PrimaryPart then
			local dist = (item.PrimaryPart.Position - position).Magnitude
			if dist < bestDist and (not filter or filter(item)) then
				best, bestDist = item, dist
			end
		end
	end
	return best
end

function ResourceService:FindTag(userId: number): Model?
	for _, item in folder:GetChildren() do
		if item:GetAttribute("Kind") == "DogTag" and item:GetAttribute("OwnerUserId") == userId then
			return item
		end
	end
	for _, item in carried do
		if item:GetAttribute("Kind") == "DogTag" and item:GetAttribute("OwnerUserId") == userId then
			return item
		end
	end
	return nil
end

function ResourceService:GetCarrierOf(item: Model): Model?
	for carrier, carriedItem in carried do
		if carriedItem == item then
			return carrier
		end
	end
	return nil
end

function ResourceService:RemoveTag(userId: number)
	local tag = self:FindTag(userId)
	if tag then
		local carrier = self:GetCarrierOf(tag)
		if carrier then
			self:Consume(carrier)
		else
			tag:Destroy()
		end
	end
end

-- The carrier is gone (left the game, destroyed). Forget it without dropping anything.
function ResourceService:ForgetCarrier(carrier: Model)
	carried[carrier] = nil
end

return ResourceService
