-- One soldier of the squad: obeys orders, shoots what it can see, panics when out of ammo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local SquadConfig = require(ReplicatedStorage.Shared.Config.Squad)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local State = require(ReplicatedStorage.Shared.State)
local Server = ServerScriptService.Server
local Mover = require(Server.Util.Mover)
local Notify = require(Server.Util.Notify)
local NpcAnimator = require(Server.Squad.NpcAnimator)
local SoldierModel = require(Server.Squad.SoldierModel)
local Registry = require(Server.Registry)

local Orders = SquadConfig.Orders

local Soldier = {}
Soldier.__index = Soldier

function Soldier.new(id: number, kind: string, name: string, cframe: CFrame, parent: Instance)
	local rng = Random.new(id * 7919)
	local stats = SquadConfig.Kinds[kind]
	local displayName = if kind == "Super" then "Ω-" .. name else name
	local rig = SoldierModel.build(kind, displayName, rng)

	local self = setmetatable({
		Id = id,
		Kind = kind,
		Stats = stats,
		DisplayName = displayName,
		Model = rig.Model,
		Humanoid = rig.Humanoid,
		Root = rig.Root,
		Muzzle = rig.Muzzle,
		Light = rig.Light,
		Gunshot = rig.Gunshot,
		Mover = nil :: any,
		Alive = true,
		Grabbed = false,
		Order = Orders.Follow,
		OrderData = {} :: { [string]: any },
		Ammo = stats.Ammo,
		LastShot = 0,
		LastContact = 0,
		Slot = id,
		WanderGoal = nil :: Vector3?,
		WanderUntil = 0,
		RouteIndex = 1,
		ReviveTimer = 0,
		Rng = rng,
	}, Soldier)

	local model = self.Model
	model:SetAttribute("SoldierId", id)
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Order", self.Order)
	model:AddTag("Soldier")
	self.Humanoid.MaxHealth = stats.MaxHealth
	self.Humanoid.Health = stats.MaxHealth
	self.Humanoid.WalkSpeed = stats.WalkSpeed
	model:PivotTo(cframe)
	model.Parent = parent
	pcall(function()
		self.Root:SetNetworkOwner(nil)
	end)

	local shot = Sounds.Library.RifleShot
	if #shot > 0 then
		self.Gunshot.SoundId = shot[rng:NextInteger(1, #shot)]
	end

	NpcAnimator.attach(self.Humanoid, SquadConfig.Animations, (stats.WalkSpeed + stats.RunSpeed) / 2)
	self.Mover = Mover.new(self.Humanoid, self.Root)
	self:RefreshIgnore()

	self.Humanoid.Died:Connect(function()
		if self.Alive then
			Registry.SquadService:KillSoldier(self, true)
		end
	end)
	return self
end

function Soldier:RefreshIgnore()
	local ignore: { Instance } = {}
	for _, name in { "Squad", "Items", "Corpses", "Monsters" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	self.Mover:SetIgnore(ignore)
end

function Soldier:SetOrder(order: string, data: { [string]: any }?)
	local previousItem = self.OrderData.Item
	if previousItem and previousItem.Parent and previousItem:GetAttribute("Claim") == self.Id then
		previousItem:SetAttribute("Claim", nil)
	end
	self.Order = order
	self.OrderData = data or {}
	self.WanderGoal = nil
	self.RouteIndex = 1
	self.ReviveTimer = 0
	self.Model:SetAttribute("Order", order)
	self.Model:SetAttribute("Reviving", nil)
end

function Soldier:GetMuzzle(): Vector3
	return self.Muzzle.WorldPosition
end

function Soldier:OnGrabbed()
	self.Grabbed = true
	self.Mover:Stop()
end

function Soldier:OnReleased()
	self.Grabbed = false
	self.Root.Anchored = false
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Soldier:Run(goal: Vector3, fast: boolean?)
	local speed = if fast then self.Stats.RunSpeed else self.Stats.WalkSpeed
	if self.Model:GetAttribute("Carrying") then
		speed *= SquadConfig.CarrySpeedMultiplier
	end
	self.Humanoid.WalkSpeed = speed
	self.Mover:MoveTo(goal)
end

-- Combat ---------------------------------------------------------------------

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude

function Soldier:FindThreat(): (any, number)
	local best, bestScore, bestDist = nil, math.huge, math.huge
	local position = self.Root.Position
	for _, monster in Registry.MonsterService:GetMonsters() do
		if monster.Alive then
			local dist = (monster.Root.Position - position).Magnitude
			if dist <= SquadConfig.ViewRange then
				-- Monsters busy killing a comrade are the top priority
				local score = dist * (if monster.Feeding then 0.4 else 1)
				if score < bestScore then
					best, bestScore, bestDist = monster, score, dist
				end
			end
		end
	end
	return best, bestDist
end

function Soldier:CanHit(monster: any): (boolean, Vector3)
	local aim = monster:Head().Position:Lerp(monster.Root.Position, 0.4)
	local origin = self:GetMuzzle()
	local ignore: { Instance } =
		{ workspace:FindFirstChild("Squad") :: Instance, workspace:FindFirstChild("Items") :: Instance }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	losParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, aim - origin, losParams)
	return result == nil or result.Instance:IsDescendantOf(monster.Model), aim
end

function Soldier:Shoot(_monster: any, aim: Vector3)
	local now = os.clock()
	if now - self.LastShot < self.Stats.FireInterval or self.Ammo <= 0 then
		return
	end
	self.LastShot = now
	if self.Ammo ~= math.huge then
		self.Ammo -= 1
	end
	self.Humanoid.AutoRotate = false
	self.Root.CFrame = CFrame.lookAt(self.Root.Position, Vector3.new(aim.X, self.Root.Position.Y, aim.Z))
	if self.Gunshot.SoundId ~= "" then
		self.Gunshot.PlaybackSpeed = self.Rng:NextNumber(0.94, 1.06)
		self.Gunshot:Play()
	end
	Registry.CombatService:SoldierFire(self, aim)
	self.Model:SetAttribute("Ammo", self.Ammo)
end

function Soldier:Bark()
	local now = os.clock()
	if now - self.LastContact < 25 or now - Registry.SquadService.LastBark < 6 then
		return
	end
	self.LastContact = now
	Registry.SquadService.LastBark = now
	Registry.AudioService:Cue(
		"Contact",
		self.Root.Position,
		{ VictimName = self.DisplayName, VictimKind = "Soldier", Radio = true }
	)
	Notify.all("Notify_Contact", { self.DisplayName }, "radio")
end

-- Orders -------------------------------------------------------------------

function Soldier:Leader(): BasePart?
	local userId = self.OrderData.UserId or State.get("CommanderUserId")
	local player = userId and Players:GetPlayerByUserId(userId)
	if player and Registry.PlayerService:IsAlive(player) then
		return Registry.PlayerService:GetRoot(player)
	end
	-- Fall back to any living player
	local alive = Registry.PlayerService:GetAlivePlayers()
	if #alive > 0 then
		return Registry.PlayerService:GetRoot(alive[1])
	end
	return nil
end

function Soldier:DoFollow()
	local leader = self:Leader()
	if not leader then
		self.Mover:Stop()
		return
	end
	if Registry.TrainService:IsInSafeZone(leader.Position) then
		self:Run(Registry.TrainService:GetRallyPoint(self.Slot), (self.Root.Position - leader.Position).Magnitude > 30)
		return
	end
	local index = self.OrderData.Slot or self.Slot
	local column = ((index - 1) % 3) - 1
	local row = math.floor((index - 1) / 3)
	local goal = (
		leader.CFrame * CFrame.new(column * SquadConfig.FollowSpacing, 0, 6 + row * SquadConfig.FollowSpacing)
	).Position
	local dist = flat(goal - self.Root.Position).Magnitude
	if dist > 3.5 then
		self:Run(goal, dist > 22)
	else
		self.Mover:Stop()
	end
end

function Soldier:DoRoute()
	local waypoints = self.OrderData.Waypoints
	if not waypoints or #waypoints == 0 then
		self.Mover:Stop()
		return
	end
	local goal = waypoints[self.RouteIndex]
	if not goal then
		self.Mover:Stop()
		return
	end
	if self.Mover:Arrived(goal, 4) then
		self.RouteIndex += 1
		goal = waypoints[self.RouteIndex]
		if not goal then
			self.Mover:Stop()
			return
		end
	end
	self:Run(goal, self.OrderData.Fast == true)
end

function Soldier:DoWander()
	local anchor = self.OrderData.Anchor or self.Root.Position
	local now = os.clock()
	if
		not self.WanderGoal
		or (self.Mover:Arrived(self.WanderGoal, 4) and now > self.WanderUntil)
		or now > self.WanderUntil + 20
	then
		-- Every soldier spreads out in its own direction
		local base = (self.Id * 2.39996) % (math.pi * 2)
		local angle = base + self.Rng:NextNumber(-0.9, 0.9)
		local dist = self.Rng:NextNumber(25, SquadConfig.WanderRadius)
		local goal = anchor + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		if not Registry.LocationService:InBounds(goal) then
			goal = anchor
		end
		self.WanderGoal = goal
		self.WanderUntil = now + self.Rng:NextNumber(2, 5)
	end
	if not self.Mover:Arrived(self.WanderGoal :: Vector3, 4) then
		self:Run(self.WanderGoal :: Vector3, false)
	else
		self.Mover:Stop()
	end
end

function Soldier:GatherFilter(): (Model) -> boolean
	local finale = State.get("Phase") == "Finale"
	return function(item: Model): boolean
		local kind = item:GetAttribute("Kind")
		local claim = item:GetAttribute("Claim")
		if claim and claim ~= self.Id then
			return false
		end
		if kind == "Fuse" then
			return finale
		end
		local def = Resources.Kinds[kind]
		return def ~= nil and def.Pooled
	end
end

function Soldier:DoGather()
	local carrying = Registry.ResourceService:GetCarried(self.Model)
	if carrying then
		local kind = carrying:GetAttribute("Kind")
		if kind == "Fuse" then
			local panel = Registry.MatchService:GetFusePanelPosition()
			if panel then
				if self.Mover:Arrived(panel, 7) then
					Registry.MatchService:InsertFuse(self.Model)
				else
					self:Run(panel, true)
				end
				return
			end
		elseif kind == "DogTag" then
			self:SetOrder(Orders.Revive, { UserId = carrying:GetAttribute("OwnerUserId") })
			return
		end
		local depot = Registry.TrainService:GetDepotPosition()
		if
			self.Mover:Arrived(depot, SquadConfig.DepositRange)
			or Registry.TrainService:IsInSafeZone(self.Root.Position)
		then
			Registry.ResourceService:Deposit(self.Model)
		else
			self:Run(depot, false)
		end
		return
	end

	local item = self.OrderData.Item
	if
		not item
		or not item.Parent
		or item:GetAttribute("Carrier")
		or (item:GetAttribute("Claim") and item:GetAttribute("Claim") ~= self.Id)
	then
		item = Registry.ResourceService:FindNearest(
			self.Root.Position,
			SquadConfig.GatherSearchRadius,
			self:GatherFilter()
		)
		self.OrderData.Item = item
		if item then
			item:SetAttribute("Claim", self.Id)
		end
	end
	if not item then
		self.OrderData.Anchor = self.OrderData.Anchor or self.Root.Position
		self:DoWander()
		return
	end
	local position = (item.PrimaryPart :: BasePart).Position
	if (position - self.Root.Position).Magnitude <= SquadConfig.PickupRange then
		Registry.ResourceService:PickUp(self.Model, item)
		self.OrderData.Item = nil
	else
		self:Run(position, false)
	end
end

function Soldier:DoRetreat()
	local rally = Registry.TrainService:GetRallyPoint(self.Slot)
	if Registry.TrainService:IsInSafeZone(self.Root.Position) and self.Mover:Arrived(rally, 6) then
		self.Mover:Stop()
		if
			self.Ammo < self.Stats.Ammo
			and self.Ammo ~= math.huge
			and Registry.ResourceService:SpendPool("Supplies", 1)
		then
			self.Ammo = math.min(self.Stats.Ammo, self.Ammo + SquadConfig.AmmoRefillPerSupply)
			self.Humanoid.Health = self.Humanoid.MaxHealth
			self.Model:SetAttribute("Ammo", self.Ammo)
		end
		return
	end
	self:Run(rally, true)
end

function Soldier:DoRevive(dt: number)
	local userId = self.OrderData.UserId
	local tag = userId and Registry.ResourceService:FindTag(userId)
	if not tag then
		self:SetOrder(Orders.Follow)
		return
	end
	local carrier = Registry.ResourceService:GetCarrierOf(tag)
	if carrier == self.Model then
		local reanimator = Registry.ReviveService:NearestReanimator(self.Root.Position)
		if not reanimator then
			return
		end
		if self.Mover:Arrived(reanimator.Position, 5) then
			self.Mover:Stop()
			self.ReviveTimer += dt
			self.Model:SetAttribute("Reviving", true)
			if self.ReviveTimer >= GameConfig.ReviveHoldSeconds then
				Registry.ReviveService:CompleteRevive(userId, reanimator, self.Model)
				self:SetOrder(Orders.Follow)
			end
		else
			self.ReviveTimer = 0
			self:Run(reanimator.Position, true)
		end
		return
	end
	if carrier then
		self:SetOrder(Orders.Follow) -- someone else is already on it
		return
	end
	if Registry.ResourceService:GetCarried(self.Model) then
		Registry.ResourceService:Drop(self.Model)
	end
	local position = (tag.PrimaryPart :: BasePart).Position
	if (position - self.Root.Position).Magnitude <= SquadConfig.PickupRange then
		Registry.ResourceService:PickUp(self.Model, tag)
	else
		self:Run(position, true)
	end
end

-- Brain tick -----------------------------------------------------------------

function Soldier:Step(dt: number)
	if not self.Alive or self.Grabbed or not self.Model.Parent then
		return
	end
	self.Light.Enabled = (State.get("Night") or 0) > 0.3 or State.get("Phase") == "Finale"

	-- Deliver anything carried as soon as the train is reached
	local carried = Registry.ResourceService:GetCarried(self.Model)
	if carried and Registry.TrainService:IsInSafeZone(self.Root.Position) then
		local def = Resources.Kinds[carried:GetAttribute("Kind")]
		if def and def.Pooled then
			Registry.ResourceService:Deposit(self.Model)
		end
	end

	local threat, threatDist = self:FindThreat()
	if threat and self.Order ~= Orders.Retreat then
		if self.Ammo > 0 and threatDist <= self.Stats.Range then
			local canHit, aim = self:CanHit(threat)
			if canHit then
				self:Bark()
				-- Stand and fire unless the leader is getting away
				local leader = if self.Order == Orders.Follow then self:Leader() else nil
				if not leader or (leader.Position - self.Root.Position).Magnitude < 35 then
					self.Mover:Stop()
				end
				self:Shoot(threat, aim)
				return
			end
		elseif self.Ammo <= 0 and threatDist < SquadConfig.PanicDistance then
			-- Out of ammo: run for the train
			self.Humanoid.AutoRotate = true
			self:Run(Registry.TrainService:GetRallyPoint(self.Slot), true)
			return
		end
	end
	self.Humanoid.AutoRotate = true

	local order = self.Order
	if order == Orders.Follow then
		self:DoFollow()
	elseif order == Orders.Route then
		self:DoRoute()
	elseif order == Orders.Wander then
		self:DoWander()
	elseif order == Orders.Gather then
		self:DoGather()
	elseif order == Orders.Retreat then
		self:DoRetreat()
	elseif order == Orders.Revive then
		self:DoRevive(dt)
	else
		self.Mover:Stop()
	end
end

return Soldier
