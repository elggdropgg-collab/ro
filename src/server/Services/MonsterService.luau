-- Spawns monsters per station, runs their brains, tracks player gaze and noise.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MonsterConfig = require(ReplicatedStorage.Shared.Config.Monsters)
local Net = require(ReplicatedStorage.Shared.Net)
local Server = ServerScriptService.Server
local Monster = require(Server.Monsters.Monster)
local Behaviours = require(Server.Monsters.Behaviours)
local Registry = require(Server.Registry)

local MonsterService = {}

local folder: Folder
local monsters: { any } = {}
local nests: { any } = {}
local generation = 0
local looks: { [Player]: { Origin: Vector3, Direction: Vector3, Time: number } } = {}

local GAZE_RANGE = 170
local GAZE_COS = math.cos(math.rad(34))
local TICK = 0.18

function MonsterService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = workspace

	Net.event("LookReport").OnServerEvent:Connect(function(player, origin, direction)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			return
		end
		if direction.Magnitude < 0.5 or direction.Magnitude > 1.5 or origin.Magnitude > 1e4 then
			return
		end
		-- The camera must be near the character, otherwise the report is ignored
		local root = Registry.PlayerService:GetRoot(player)
		if not root or (root.Position - origin).Magnitude > 20 then
			return
		end
		looks[player] = { Origin = origin, Direction = direction.Unit, Time = os.clock() }
	end)
	Players.PlayerRemoving:Connect(function(player)
		looks[player] = nil
	end)
end

local function run(monster: any, gen: number)
	local behaviour = Behaviours[monster.Kind]
	local refresh = 0
	while monster.Alive and gen == generation do
		if not monster.Stunned and not monster.Feeding then
			local ok, err = pcall(behaviour, monster)
			if not ok then
				warn(`[Monster] {monster.Kind} brain error: {err}`)
			end
		end
		refresh += TICK
		if refresh > 5 then
			refresh = 0
			monster:RefreshIgnore()
		end
		task.wait(TICK)
	end
end

function MonsterService:Spawn(kind: string, position: Vector3, options: any?): any
	local monster = Monster.new(kind, position, folder, options)
	table.insert(monsters, monster)
	task.spawn(run, monster, generation)
	return monster
end

function MonsterService:SpawnForLocation(layout: any, isFinale: boolean)
	local spawning = MonsterConfig.Spawning
	if isFinale then
		-- Every immortal from earlier stations, now killable, waits around the bunker
		local bunker = layout.Bunker
		local index = 0
		for _, kind in spawning.ImmortalByLocation do
			index += 1
			local angle = index * 2.1
			local p = bunker.Entrance + Vector3.new(math.cos(angle) * 40, 0, math.sin(angle) * 40 - 30)
			self:Spawn(kind, p, { Finale = true, Home = p })
		end
		for i = 1, spawning.FinaleHusks do
			local angle = (i / spawning.FinaleHusks) * math.pi * 2
			local p = Vector3.new(math.cos(angle) * 170, 0, math.sin(angle) * 170 + 80)
			if math.abs(p.Z) < 40 then
				p += Vector3.new(0, 0, 60)
			end
			self:Spawn("Husk", p, { Finale = true, Home = p })
		end
		return
	end

	local immortal = layout.Monsters and layout.Monsters.Immortal
	if immortal then
		self:Spawn(immortal.Kind, immortal.Position, { Home = immortal.Position })
	end
	for _, position in (layout.Monsters and layout.Monsters.Nests) or {} do
		local nest = { Position = position, Alive = 0 }
		table.insert(nests, nest)
		for _ = 1, spawning.HusksPerNest do
			self:SpawnNestHusk(nest)
		end
	end
end

function MonsterService:SpawnNestHusk(nest: any)
	nest.Alive += 1
	local offset = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
	self:Spawn("Husk", nest.Position + offset, { Home = nest.Position, Nest = nest })
end

function MonsterService:OnMonsterDied(monster: any)
	local index = table.find(monsters, monster)
	if index then
		table.remove(monsters, index)
	end
	local nest = monster.Nest
	if nest then
		nest.Alive -= 1
		local gen = generation
		task.delay(MonsterConfig.Spawning.NestRespawnSeconds, function()
			if gen == generation and table.find(nests, nest) then
				self:SpawnNestHusk(nest)
			end
		end)
	end
end

function MonsterService:SpawnReinforcements(count: number, center: Vector3, radius: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random()
		local p = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local monster = self:Spawn("Husk", p, { Finale = true, Home = center })
		monster:Hear(center)
	end
end

function MonsterService:Clear()
	generation += 1
	for _, monster in monsters do
		monster:Destroy()
	end
	monsters = {}
	nests = {}
	folder:ClearAllChildren()
end

function MonsterService:GetMonsters(): { any }
	return monsters
end

function MonsterService:GetByPart(part: Instance): any
	for _, monster in monsters do
		if part:IsDescendantOf(monster.Model) then
			return monster
		end
	end
	return nil
end

function MonsterService:EmitNoise(position: Vector3, radius: number)
	for _, monster in monsters do
		if monster.Alive and (monster.Root.Position - position).Magnitude <= radius then
			monster:Hear(position)
		end
	end
end

-- Hearing multiplier for blind monsters.
function MonsterService:NoiseOf(target: any): number
	local noise = MonsterConfig.Noise
	if target.Player then
		if target.Player:GetAttribute("Sprinting") then
			return noise.Sprint
		end
		local velocity = target.Root.AssemblyLinearVelocity
		return if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1 then noise.Walk else noise.Still
	end
	if target.Soldier and os.clock() - (target.Soldier.LastShot or 0) < 2 then
		return noise.Sprint
	end
	return noise.Walk
end

local gazeParams = RaycastParams.new()
gazeParams.FilterType = Enum.RaycastFilterType.Exclude

local function visibleFrom(look: any, point: Vector3, model: Model?): boolean
	local toPoint = point - look.Origin
	local dist = toPoint.Magnitude
	if dist > GAZE_RANGE or dist < 0.1 then
		return false
	end
	if look.Direction:Dot(toPoint / dist) < GAZE_COS then
		return false
	end
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, name in { "Squad", "Items", "Corpses" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	gazeParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(look.Origin, toPoint, gazeParams)
	if not result then
		return true
	end
	return model ~= nil and result.Instance:IsDescendantOf(model)
end

-- True when any living player is looking at the monster (head or body) with clear sight.
function MonsterService:IsObserved(monster: any): boolean
	local now = os.clock()
	for player, look in looks do
		if now - look.Time < 0.8 and Registry.PlayerService:IsAlive(player) then
			if
				visibleFrom(look, monster:Head().Position, monster.Model)
				or visibleFrom(look, monster.Root.Position, monster.Model)
			then
				return true
			end
		end
	end
	return false
end

function MonsterService:IsPointObserved(point: Vector3): boolean
	local now = os.clock()
	for player, look in looks do
		if now - look.Time < 0.8 and Registry.PlayerService:IsAlive(player) then
			if visibleFrom(look, point + Vector3.new(0, 4, 0), nil) then
				return true
			end
		end
	end
	return false
end

return MonsterService
