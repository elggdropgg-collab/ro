-- Base monster: health or stun meter, perception, roaming, feeding and death.
-- Behaviour per kind lives in Monsters/Behaviours.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.Monsters)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Server = ServerScriptService.Server
local MonsterModels = require(Server.Monsters.MonsterModels)
local Mover = require(Server.Util.Mover)
local Notify = require(Server.Util.Notify)
local Registry = require(Server.Registry)

local Monster = {}
Monster.__index = Monster

local nextId = 0

export type Options = { Finale: boolean?, Home: Vector3?, Nest: any? }

function Monster.new(kind: string, position: Vector3, parent: Instance, options: Options?)
	local def = MonsterConfig.Defs[kind]
	assert(def, "Unknown monster " .. kind)
	local opts = options or {}
	local rig = MonsterModels.build(kind)
	nextId += 1

	local self = setmetatable({
		Id = nextId,
		Kind = kind,
		Def = def,
		Model = rig.Model,
		Root = rig.Root,
		Humanoid = rig.Humanoid,
		GripHeight = rig.GripHeight,
		GripDistance = rig.GripDistance,
		GripTilt = rig.GripTilt,
		Mover = nil :: any,
		Alive = true,
		Stunned = false,
		Feeding = false,
		Immortal = def.Immortal and not opts.Finale,
		Health = 0,
		MaxHealth = 0,
		StunMeter = 0,
		State = "Roam",
		Target = nil :: any,
		Investigate = nil :: Vector3?,
		InvestigateUntil = 0,
		RoamGoal = nil :: Vector3?,
		RoamUntil = 0,
		Home = opts.Home or position,
		Nest = opts.Nest,
		Damaged = Signal.new(),
		LastHunt = 0,
	}, Monster)

	if self.Immortal then
		self.MaxHealth = math.huge
	else
		self.MaxHealth = if opts.Finale and def.FinaleHealth then def.FinaleHealth else def.MaxHealth
	end
	self.Health = self.MaxHealth

	local model = self.Model
	model:SetAttribute("Kind", kind)
	model:SetAttribute("MonsterId", self.Id)
	model:SetAttribute("Immortal", self.Immortal)
	if not self.Immortal then
		model:SetAttribute("Health", self.Health)
		model:SetAttribute("MaxHealth", self.MaxHealth)
	end
	model:AddTag("Monster")
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	self.Humanoid.WalkSpeed = def.WalkSpeed
	self.Humanoid.MaxHealth = 1e9
	self.Humanoid.Health = 1e9
	model.Parent = parent
	pcall(function()
		self.Root:SetNetworkOwner(nil)
	end)

	self.Mover = Mover.new(self.Humanoid, self.Root, {
		AgentRadius = if kind == "Scarecrow" then 2.5 else 2,
		AgentHeight = if kind == "Scarecrow" then 9 else 3,
		AgentCanJump = true,
		WaypointSpacing = 6,
	})
	self:RefreshIgnore()
	self:SetState("Roam")
	return self
end

function Monster:RefreshIgnore()
	local ignore: { Instance } = { self.Model }
	for _, name in { "Squad", "Items", "Corpses", "Monsters" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	self.Mover:SetIgnore(ignore)
end

function Monster:SetState(state: string)
	if self.State ~= state then
		self.State = state
		self.Model:SetAttribute("State", state)
	end
end

function Monster:Head(): BasePart
	return (self.Model:FindFirstChild("Head") or self.Root) :: BasePart
end

-- Perception ---------------------------------------------------------------

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

-- True when nothing solid stands between the monster's head and `position`.
function Monster:CanSee(position: Vector3, targetModel: Model?): boolean
	local origin = self:Head().Position
	local ignore: { Instance } = { self.Model }
	for _, name in { "Items", "Corpses" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	sightParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, position - origin, sightParams)
	if not result then
		return true
	end
	return targetModel ~= nil and result.Instance:IsDescendantOf(targetModel)
end

-- Picks the most attractive victim within reach. `hearing` makes noise matter (blind monsters).
function Monster:FindTarget(range: number, concealedRange: number, hearing: boolean, needsSight: boolean): any
	local best, bestScore = nil, math.huge
	local position = self.Root.Position
	for _, target in Registry.CombatService:GetTargets() do
		local dist = (target.Root.Position - position).Magnitude
		local reach = if Registry.LocationService:IsConcealed(target.Root.Position) then concealedRange else range
		if hearing then
			reach *= Registry.MonsterService:NoiseOf(target)
		end
		if dist <= reach and (not needsSight or self:CanSee(target.Root.Position, target.Model)) then
			local preference = if target.Kind == "Soldier" then self.Def.SoldierPreference else 1
			local score = dist / preference
			if self.Target and self.Target.Model == target.Model then
				score *= 0.7 -- stick to the current victim
			end
			if score < bestScore then
				best, bestScore = target, score
			end
		end
	end
	return best
end

function Monster:Hear(position: Vector3)
	if self.Target or self.Feeding or self.Stunned then
		return
	end
	self.Investigate = position
	self.InvestigateUntil = os.clock() + 15
end

-- Movement -------------------------------------------------------------------

function Monster:Roam(radius: number)
	local now = os.clock()
	if not self.RoamGoal or now > self.RoamUntil or self.Mover:Arrived(self.RoamGoal, 4) then
		self.RoamGoal = Registry.LocationService:RandomPointNear(self.Home, radius)
		self.RoamUntil = now + 14
	end
	self.Humanoid.WalkSpeed = self.Def.WalkSpeed
	self.Mover:MoveTo(self.RoamGoal)
	self:SetState("Roam")
end

-- Keeps monsters out of the train.
function Monster:SafeGoal(goal: Vector3): Vector3
	if Registry.TrainService:IsInSafeZone(goal) then
		local min, max = Registry.TrainService:GetSafeZone()
		local z = if goal.Z > (min.Z + max.Z) / 2 then max.Z + 6 else min.Z - 6
		return Vector3.new(goal.X, goal.Y, z)
	end
	return goal
end

function Monster:Hunt(target: any, speed: number): boolean
	self.Target = target
	self.LastHunt = os.clock()
	self.Humanoid.WalkSpeed = speed
	self:SetState("Hunt")
	local dist = (target.Root.Position - self.Root.Position).Magnitude
	if dist <= self.Def.GrabRange then
		self.Mover:Stop()
		Registry.CombatService:StartKill(self, target)
		self.Target = nil
		return true
	end
	self.Mover:MoveTo(self:SafeGoal(target.Root.Position))
	return false
end

-- Damage ------------------------------------------------------------------

function Monster:TakeDamage(amount: number, stun: number, source: any)
	if not self.Alive then
		return
	end
	if self.Immortal then
		self.StunMeter += stun
		if self.StunMeter >= self.Def.StunThreshold and not self.Stunned then
			self:Stun(self.Def.StunDuration)
			if typeof(source) == "Instance" and source:IsA("Player") then
				Notify.player(source, "Notify_Stunned", nil, "good")
			end
		end
	else
		self.Health = math.max(0, self.Health - amount)
		self.Model:SetAttribute("Health", self.Health)
		self.StunMeter += stun
		if self.StunMeter >= self.Def.StunThreshold and not self.Stunned and not self.Feeding then
			self:Stun(self.Def.StunDuration)
		end
	end
	self.Damaged:Fire(amount, stun)
	if not self.Immortal and self.Health <= 0 then
		self:Die()
		return
	end
	-- Whoever shot it becomes interesting
	if not self.Target and not self.Feeding then
		local root: BasePart? = nil
		if typeof(source) == "Instance" and source:IsA("Player") then
			root = Registry.PlayerService:GetRoot(source)
		elseif type(source) == "table" and source.Root then
			root = source.Root
		end
		if root then
			self:Hear(root.Position)
		end
	end
end

function Monster:Stun(duration: number)
	self.Stunned = true
	self:SetState("Stunned")
	self.Humanoid.WalkSpeed = 0
	self.Mover:Stop()
	self.Target = nil
	task.delay(duration, function()
		if self.Alive then
			self.Stunned = false
			self.StunMeter = 0
			if not self.Feeding then
				self:SetState("Roam")
			end
		end
	end)
end

function Monster:Stagger(duration: number)
	if self.Stunned then
		return
	end
	self.Stunned = true
	self.Feeding = false
	self:SetState("Stunned")
	self.Humanoid.WalkSpeed = 0
	self.Mover:Stop()
	task.delay(duration, function()
		if self.Alive then
			self.Stunned = false
			self:SetState("Roam")
		end
	end)
end

function Monster:BeginFeeding(_target: any)
	self.Feeding = true
	self.Humanoid.WalkSpeed = 0
	self.Mover:Stop()
	self:SetState("Feeding")
end

function Monster:EndFeeding()
	self.Feeding = false
	if not self.Stunned then
		self:SetState("Roam")
	end
end

function Monster:Die()
	if not self.Alive then
		return
	end
	self.Alive = false
	self:SetState("Dead")
	self.Model:RemoveTag("Monster")
	Registry.MonsterService:OnMonsterDied(self)
	-- Collapse: every part falls on its own
	for _, d in self.Model:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("Motor6D") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = true
			d.Massless = false
		end
	end
	self.Humanoid:Destroy()
	task.delay(25, function()
		for _, d in self.Model:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(3), { Transparency = 1 }):Play()
			end
		end
		task.wait(3.2)
		self.Model:Destroy()
	end)
end

function Monster:Destroy()
	self.Alive = false
	self.Model:Destroy()
end

return Monster
