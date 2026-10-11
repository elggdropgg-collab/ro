-- Shooting (players and soldiers), monster damage and the kill sequence.
--
-- Kill sequence: the monster pins its victim for KillDuration seconds while the layered
-- death recipe plays. Damaging the monster enough (or stunning an immortal) tears the
-- victim free. Otherwise the victim dies, and the monster keeps eating for a while.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.Monsters)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Server = ServerScriptService.Server
local Notify = require(Server.Util.Notify)
local Registry = require(Server.Registry)

local CombatService = {}

export type Target = {
	Kind: string, -- "Soldier" | "Player"
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Name: string,
	Player: Player?,
	Soldier: any?,
}

local tracerRemote
local killCamRemote
local lastShot: { [Player]: number } = {}
local reloading: { [Player]: boolean } = {}

local function finite(v: Vector3): boolean
	return v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) < 1e5
		and math.abs(v.Y) < 1e5
		and math.abs(v.Z) < 1e5
end

local function spread(direction: Vector3, degrees: number, rng: Random?): Vector3
	local r = rng or Random.new()
	local angle = math.rad(degrees)
	local cf = CFrame.lookAt(Vector3.zero, direction)
	return (cf * CFrame.Angles(r:NextNumber(-angle, angle), r:NextNumber(-angle, angle), 0)).LookVector
end

-- Raycast that only stops at world geometry and monsters.
local function shotParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	for _, name in { "Squad", "Items", "Corpses" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

function CombatService:Init()
	tracerRemote = Net.event("Tracer")
	killCamRemote = Net.event("KillCam")

	Net.event("Fire").OnServerEvent:Connect(function(player, aimPoint)
		if typeof(aimPoint) == "Vector3" and finite(aimPoint) then
			self:PlayerFire(player, aimPoint)
		end
	end)
	Net.event("Reload").OnServerEvent:Connect(function(player)
		self:Reload(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
		reloading[player] = nil
	end)
	State.set("SquadDamageBoost", 1)
end

function CombatService:Fire(
	origin: Vector3,
	direction: Vector3,
	range: number,
	damage: number,
	stun: number,
	kind: string,
	source: any
): RaycastResult?
	local params = shotParams()
	local result = workspace:Raycast(origin, direction.Unit * range, params)
	local hitPosition = if result then result.Position else origin + direction.Unit * range
	tracerRemote:FireAllClients(origin, hitPosition, kind)
	Registry.MonsterService:EmitNoise(origin, MonsterConfig.Noise.Gunshot)
	if result then
		local monster = Registry.MonsterService:GetByPart(result.Instance)
		if monster then
			self:DamageMonster(monster, damage, stun, source)
		end
	end
	return result
end

function CombatService:PlayerFire(player: Player, aimPoint: Vector3)
	if not Registry.PlayerService:IsAlive(player) or reloading[player] then
		return
	end
	local character = player.Character :: Model
	if character:GetAttribute("BeingKilled") then
		return
	end
	local now = os.clock()
	if now - (lastShot[player] or 0) < Weapons.FireInterval * 0.85 then
		return
	end
	local ammo = player:GetAttribute("Ammo") or 0
	if ammo <= 0 then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local origin = head.Position
	local toAim = aimPoint - origin
	if toAim.Magnitude < 0.5 then
		return
	end
	lastShot[player] = now
	player:SetAttribute("Ammo", ammo - 1)
	local level = Weapons.Levels[math.clamp((player:GetAttribute("WeaponLevel") or 1) :: number, 1, #Weapons.Levels)]
	self:Fire(
		origin,
		spread(toAim.Unit, Weapons.SpreadDegrees),
		Weapons.Range,
		level.Damage,
		level.Stun,
		"Pistol",
		player
	)
end

function CombatService:Reload(player: Player)
	if reloading[player] or not Registry.PlayerService:IsAlive(player) then
		return
	end
	local level = Weapons.Levels[math.clamp((player:GetAttribute("WeaponLevel") or 1) :: number, 1, #Weapons.Levels)]
	local ammo, reserve = player:GetAttribute("Ammo") or 0, player:GetAttribute("Reserve") or 0
	if ammo >= level.Magazine or reserve <= 0 then
		return
	end
	reloading[player] = true
	player:SetAttribute("Reloading", true)
	task.delay(Weapons.ReloadSeconds, function()
		reloading[player] = nil
		if not player.Parent then
			return
		end
		player:SetAttribute("Reloading", false)
		if not Registry.PlayerService:IsAlive(player) then
			return
		end
		local currentAmmo = player:GetAttribute("Ammo") or 0
		local currentReserve = player:GetAttribute("Reserve") or 0
		local moved = math.min(level.Magazine - currentAmmo, currentReserve)
		player:SetAttribute("Ammo", currentAmmo + moved)
		player:SetAttribute("Reserve", currentReserve - moved)
	end)
end

function CombatService:SoldierFire(soldier: any, aimPoint: Vector3)
	local stats = soldier.Stats
	local muzzle = soldier:GetMuzzle()
	local boost = State.get("SquadDamageBoost") or 1
	self:Fire(
		muzzle,
		spread((aimPoint - muzzle).Unit, stats.SpreadDegrees),
		stats.Range,
		stats.Damage * boost,
		stats.StunPower * boost,
		if soldier.Kind == "Super" then "Super" else "Rifle",
		soldier
	)
end

function CombatService:DamageMonster(monster: any, damage: number, stun: number, source: any)
	if not monster.Alive then
		return
	end
	monster:TakeDamage(damage, stun, source)
end

-- Victims a monster may go after: soldiers and players outside the train.
function CombatService:GetTargets(): { Target }
	local list: { Target } = {}
	for _, soldier in Registry.SquadService:GetSoldiers() do
		if
			soldier.Alive
			and not soldier.Model:GetAttribute("BeingKilled")
			and not Registry.TrainService:IsInSafeZone(soldier.Root.Position)
		then
			table.insert(list, {
				Kind = "Soldier",
				Model = soldier.Model,
				Root = soldier.Root,
				Humanoid = soldier.Humanoid,
				Name = soldier.DisplayName,
				Soldier = soldier,
			})
		end
	end
	for _, player in Registry.PlayerService:GetAlivePlayers() do
		local character = player.Character :: Model
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if
			root
			and humanoid
			and humanoid.Health > 0
			and not character:GetAttribute("BeingKilled")
			and not Registry.TrainService:IsInSafeZone(root.Position)
			and not Registry.PlayerService:IsInvulnerable(player)
		then
			table.insert(list, {
				Kind = "Player",
				Model = character,
				Root = root,
				Humanoid = humanoid,
				Name = player.DisplayName,
				Player = player,
			})
		end
	end
	return list
end

function CombatService:StartKill(monster: any, target: Target): boolean
	local model = target.Model
	if model:GetAttribute("BeingKilled") or not monster.Alive then
		return false
	end
	model:SetAttribute("BeingKilled", true)
	local def = monster.Def
	local root = target.Root
	local monsterRoot = monster.Root

	monster:BeginFeeding(target)
	local flat = Vector3.new(root.Position.X, monsterRoot.Position.Y, root.Position.Z)
	local facing = CFrame.lookAt(monsterRoot.Position, flat)
	monsterRoot.CFrame = facing
	local pinned = facing
		* CFrame.new(0, monster.GripHeight or 0, -(monster.GripDistance or 2.6))
		* CFrame.Angles(0, math.pi, 0)
		* CFrame.Angles(math.rad(monster.GripTilt or -20), 0, 0)
	root.Anchored = true
	root.CFrame = pinned

	if target.Soldier then
		target.Soldier:OnGrabbed()
	end
	if target.Player then
		killCamRemote:FireClient(target.Player, monster.Model, def.KillDuration)
		Registry.AudioService:CueFor(target.Player, "PlayerKilledSelf", root.Position)
	end
	Registry.AudioService:Cue(def.KillRecipe, root.Position, {
		Follow = root,
		VictimName = target.Name,
		VictimKind = target.Kind,
		VictimUserId = if target.Player then target.Player.UserId else nil,
		Radio = true,
	})
	Notify.all("Notify_Grabbed", { target.Name }, "radio")
	Registry.MonsterService:EmitNoise(root.Position, 90)

	local released = false
	local damageTaken = 0
	local connection = monster.Damaged:Connect(function(amount: number)
		damageTaken += amount
		if (def.Immortal and monster.Stunned) or damageTaken >= def.ReleaseDamage then
			released = true
		end
	end)

	local rng = Random.new()
	local elapsed = 0
	while elapsed < def.KillDuration do
		elapsed += task.wait(0.1)
		if released or not monster.Alive or not model.Parent then
			released = true
			break
		end
		-- The victim struggles
		root.CFrame = pinned
			* CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.1, 0.1))
	end
	connection.Disconnect()

	if released then
		if model.Parent then
			root.Anchored = false
			model:SetAttribute("BeingKilled", nil)
			target.Humanoid.Health = math.min(target.Humanoid.Health, GameConfig.RescueHealth)
			if target.Soldier then
				target.Soldier:OnReleased()
			end
			if target.Player then
				killCamRemote:FireClient(target.Player, monster.Model, 0)
			end
		end
		if monster.Alive then
			monster:Stagger(2)
		end
		return false
	end

	model:SetAttribute("BeingKilled", nil)
	if target.Soldier then
		Registry.SquadService:KillSoldier(target.Soldier, true)
	else
		root.Anchored = false
		target.Humanoid.Health = 0
	end
	task.delay(def.FeedDuration, function()
		if monster.Alive then
			monster:EndFeeding()
		end
	end)
	return true
end

return CombatService
