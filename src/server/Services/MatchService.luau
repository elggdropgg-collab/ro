-- The run: depot lobby -> commander vote -> stations -> terminus -> results -> depot.
--
-- Phases (State "Phase"): Lobby, Starting, Vote, Travel, Location, Departing, Finale,
-- LastChance, Ended.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local MonsterConfig = require(ReplicatedStorage.Shared.Config.Monsters)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local SquadConfig = require(ReplicatedStorage.Shared.Config.Squad)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Server = ServerScriptService.Server
local Builder = require(Server.World.Builder)
local Notify = require(Server.Util.Notify)
local Registry = require(Server.Registry)

local MatchService = {}

local participants: { Player } = {}
local ready: { [Player]: boolean } = {}
local departRequested = false
local layout: any = nil
local stats = { SoldiersLost = 0, Stations = 0, Escaped = 0, SoldiersEscaped = 0 }
local finale: any = nil

local function setPhase(phase: string, endsAt: number?)
	State.set("Phase", phase)
	State.set("PhaseEndsAt", endsAt or 0)
end

local function pick(slot: string): string?
	local list = Sounds.Library[slot]
	if list and #list > 0 then
		return list[math.random(1, #list)]
	end
	return nil
end

local function isParticipant(player: Player): boolean
	return table.find(participants, player) ~= nil
end

local function aliveParticipants(): { Player }
	local list = {}
	for _, player in participants do
		if player.Parent and Registry.PlayerService:IsAlive(player) and not player:GetAttribute("Escaped") then
			table.insert(list, player)
		end
	end
	return list
end

function MatchService:Init()
	setPhase("Lobby")
	State.set("LocationIndex", 0)
	State.set("LocationCount", #GameConfig.Locations)
	State.set("StationKey", "Station_Lobby")
	State.set("DieselNeeded", 0)
	State.set("TrainMoving", false)

	Net.event("ReadyUp").OnServerEvent:Connect(function(player)
		local phase = State.get("Phase")
		if phase == "Lobby" or phase == "Starting" then
			ready[player] = true
			player:SetAttribute("Ready", true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		local index = table.find(participants, player)
		if index then
			table.remove(participants, index)
		end
	end)
end

function MatchService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:OnJoin(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self.OnJoin, self, player)
	end

	while true do
		self:Lobby()
		local result = self:RunMatch()
		self:EndScreen(result)
	end
end

function MatchService:OnJoin(player: Player)
	Registry.DataService:WaitForProfile(player, 15)
	if not player.Parent then
		return
	end
	Registry.LocationService:SendLayout(player)
	local phase = State.get("Phase")
	if phase == "Lobby" or phase == "Starting" or phase == "Ended" or phase == "Vote" then
		Registry.PlayerService:Spawn(player, Registry.TrainService:GetPlatformSpawn(#Players:GetPlayers()))
		if phase == "Vote" and not isParticipant(player) then
			table.insert(participants, player)
		end
	else
		-- Late joiners board the train as new survivors
		table.insert(participants, player)
		Registry.PlayerService:ResetAmmo(player)
		Registry.PlayerService:Spawn(player, Registry.TrainService:GetPlayerSpawn(#participants), 3)
		Registry.CommanderService:OnPlayerAvailable(player)
	end
end

-- Lobby ----------------------------------------------------------------------

function MatchService:ResetWorld()
	Registry.MonsterService:Clear()
	Registry.SquadService:ClearAll()
	Registry.ResourceService:ClearAll()
	Registry.ResourceService:ResetPools()
	Registry.CorpseService:Clear()
	Registry.ReviveService:Reset()
	Registry.CommanderService:Reset()
	State.set("CleanupActive", false)
	State.set("SquadDamageBoost", 1)
	State.set("PortalOpen", false)
	State.set("PortalCharging", false)
	State.set("FusesInserted", 0)
	State.set("FusesNeeded", 0)
	State.set("DieselNeeded", 0)
	State.set("LocationIndex", 0)
	State.set("StationKey", "Station_Lobby")
	Registry.ResourceService:RefreshGauge()
	finale = nil
	layout = nil
end

function MatchService:Lobby()
	setPhase("Lobby")
	self:ResetWorld()
	Registry.LocationService:Generate("Lobby", math.random(1, 2 ^ 30))
	Registry.AudioService:SetAmbient("Lobby")
	ready = {}
	participants = {}
	for i, player in Players:GetPlayers() do
		player:SetAttribute("Ready", nil)
		player:SetAttribute("Escaped", nil)
		task.spawn(
			Registry.PlayerService.Spawn,
			Registry.PlayerService,
			player,
			Registry.TrainService:GetPlatformSpawn(i)
		)
	end

	local endsAt: number? = nil
	while true do
		task.wait(0.25)
		local players = Players:GetPlayers()
		local readyCount = 0
		for _, player in players do
			if ready[player] then
				readyCount += 1
			end
		end
		if readyCount == 0 then
			if endsAt then
				endsAt = nil
				setPhase("Lobby")
			end
			continue
		end
		local now = State.now()
		if not endsAt then
			endsAt = now + GameConfig.LobbyCountdown
			setPhase("Starting", endsAt)
		end
		if readyCount == #players and (endsAt :: number) - now > GameConfig.LobbyCountdownAllReady then
			endsAt = now + GameConfig.LobbyCountdownAllReady
			setPhase("Starting", endsAt)
		end
		if now >= (endsAt :: number) then
			break
		end
	end
	participants = table.clone(Players:GetPlayers())
end

-- Run ------------------------------------------------------------------------

function MatchService:RunMatch(): string
	stats = { SoldiersLost = 0, Stations = 0, Escaped = 0, SoldiersEscaped = 0 }
	for i, player in participants do
		Registry.PlayerService:ResetAmmo(player)
		player:SetAttribute("Escaped", nil)
		task.spawn(
			Registry.PlayerService.Spawn,
			Registry.PlayerService,
			player,
			Registry.TrainService:GetPlayerSpawn(i)
		)
	end
	task.wait(1)

	setPhase("Vote")
	Registry.CommanderService:RunVote(participants)
	local size = math.min(SquadConfig.BaseSize + SquadConfig.PerPlayer * #participants, SquadConfig.MaxSize)
	Registry.SquadService:CreateSquad(size)

	for index, name in GameConfig.Locations do
		self:Travel(index, name)
		if #participants == 0 then
			return "Defeat"
		end
		if name == "Finale" then
			return self:RunFinale()
		end
		if self:RunLocation(name) == "Wiped" then
			return "Defeat"
		end
		stats.Stations += 1
	end
	return "Defeat"
end

function MatchService:Travel(index: number, name: string)
	local started = os.clock()
	setPhase("Travel", State.now() + GameConfig.TravelDuration)
	Registry.TrainService:SetMoving(true)
	Registry.TrainService:PlayHorn(pick("TrainHorn"))
	Registry.AudioService:SetAmbient("Travel")

	Registry.MonsterService:Clear()
	Registry.ResourceService:ClearWorld()
	Registry.CorpseService:Clear()
	Registry.ReviveService:Clear()

	local info = GameConfig.LocationInfo[name]
	State.set("DieselNeeded", info.DieselNeeded)
	Registry.ResourceService:RefreshGauge()
	local spawnCounts = Resources.Spawn[name] or {}
	layout = Registry.LocationService:Generate(name, math.random(1, 2 ^ 30), {
		ResourceCounts = {
			Diesel = info.DieselNeeded + (spawnCounts.DieselExtra or 0),
			Scrap = spawnCounts.Scrap or 0,
			Supplies = spawnCounts.Supplies or 0,
		},
		NestCount = MonsterConfig.Spawning.FieldNests,
		NestMinDistance = MonsterConfig.Spawning.NestMinDistanceFromTrain,
		FusesNeeded = GameConfig.FusesNeeded,
	})
	Registry.LocationService:ApplyLighting("Travel", 0)

	local remaining = GameConfig.TravelDuration - (os.clock() - started)
	if remaining > 0 then
		task.wait(remaining)
	end

	Registry.TrainService:SetMoving(false)
	Registry.LocationService:ApplyLighting(name, 0)
	State.set("LocationIndex", index)
	State.set("StationKey", info.StationKey)
	Registry.ReviveService:RespawnDeadOnTrain(participants)
	Registry.ResourceService:SpawnFromLayout(layout)
	Registry.ReviveService:BuildFromLayout(layout)
	Registry.MonsterService:SpawnForLocation(layout, name == "Finale")
	Registry.AudioService:SetAmbient(name)
	local commander = Registry.CommanderService:GetCommander()
	if not commander or not Registry.PlayerService:IsAlive(commander) then
		local alive = aliveParticipants()
		if alive[1] then
			Registry.CommanderService:OnPlayerAvailable(alive[1])
		end
	end
end

function MatchService:RunLocation(name: string): string
	setPhase("Location")
	departRequested = false
	local info = GameConfig.LocationInfo[name]
	local started = os.clock()
	local function tickNight()
		local t = if info.DuskSeconds > 0 then (os.clock() - started) / info.DuskSeconds else 0
		Registry.LocationService:ApplyLighting(name, t)
	end

	while not departRequested do
		task.wait(0.5)
		tickNight()
		if self:CheckWipe() == "Wiped" then
			return "Wiped"
		end
	end

	local endsAt = State.now() + GameConfig.DepartCountdown
	setPhase("Departing", endsAt)
	Registry.TrainService:PlayHorn(pick("TrainHorn"))
	while State.now() < endsAt do
		task.wait(0.5)
		tickNight()
		if self:CheckWipe() == "Wiped" then
			return "Wiped"
		end
	end

	Registry.ResourceService:SpendPool("Diesel", info.DieselNeeded)
	for _, player in aliveParticipants() do
		local root = Registry.PlayerService:GetRoot(player)
		if root and not Registry.TrainService:IsInSafeZone(root.Position) then
			Notify.all("Notify_LeftBehind", { player.DisplayName }, "death")
			Registry.AudioService:Cue(
				"LeftBehind",
				Vector3.zero,
				{ VictimName = player.DisplayName, VictimKind = "Player", Radio = true, RadioOnly = true } :: any
			)
			Registry.PlayerService:KillSilently(player)
		end
	end
	Registry.SquadService:AbandonOutside()
	return "Departed"
end

function MatchService:RequestDepart(player: Player)
	if State.get("Phase") ~= "Location" then
		return
	end
	if not Registry.CommanderService:IsCommander(player) then
		Notify.player(player, "Notify_NotCommander", nil, "warn")
		return
	end
	if Registry.ResourceService:GetPool("Diesel") < (State.get("DieselNeeded") or 0) then
		Notify.player(player, "Notify_NotEnoughDiesel", nil, "warn")
		return
	end
	Registry.CommanderService:NoteActivity(player)
	departRequested = true
end

-- Wipe handling ---------------------------------------------------------------

function MatchService:CheckWipe(): string
	if #aliveParticipants() > 0 then
		return "OK"
	end
	local dead = Registry.ReviveService:GetDeadUserIds(participants)
	if Registry.SquadService:GetAliveCount() > 0 and #dead > 0 then
		local anyTag = false
		for _, userId in dead do
			if Registry.ResourceService:FindTag(userId) then
				anyTag = true
			end
		end
		if anyTag then
			Registry.SquadService:AutoRevive(dead)
			return "OK"
		end
	end
	if #dead == 0 then
		return "OK" -- everyone escaped
	end
	return self:LastChance()
end

-- Nobody can bring anyone back. A short window for a self-revive before the run is lost.
function MatchService:LastChance(): string
	local previous = State.get("Phase")
	local previousEnds = State.get("PhaseEndsAt")
	local endsAt = State.now() + GameConfig.LastChanceSeconds
	setPhase("LastChance", endsAt)
	while State.now() < endsAt do
		task.wait(0.25)
		if #aliveParticipants() > 0 then
			setPhase(previous, previousEnds)
			return "OK"
		end
	end
	return "Wiped"
end

function MatchService:OnPlayerDied(_player: Player) end

function MatchService:OnPlayerRevived(player: Player)
	Registry.CommanderService:OnPlayerAvailable(player)
end

function MatchService:OnSoldierLost(_soldier: any)
	stats.SoldiersLost += 1
end

-- Finale ----------------------------------------------------------------------

local function setSocket(index: number, lit: boolean)
	local bunker = finale and finale.Bunker
	local socket = bunker and bunker.Model:FindFirstChild("Socket" .. index, true) :: BasePart?
	if socket then
		socket.Color = if lit then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(80, 20, 20)
	end
end

function MatchService:GetFusePanelPosition(): Vector3?
	if finale then
		return finale.Bunker.Panel.Position
	end
	return nil
end

function MatchService:InsertFuse(carrier: Model)
	if not finale then
		return
	end
	local item = Registry.ResourceService:GetCarried(carrier)
	if not item or item:GetAttribute("Kind") ~= "Fuse" then
		return
	end
	Registry.ResourceService:Consume(carrier)
	finale.Fuses += 1
	State.set("FusesInserted", finale.Fuses)
	setSocket(finale.Fuses, true)
	Notify.all("Notify_FuseInserted", nil, "good")
	if finale.Fuses >= GameConfig.FusesNeeded then
		finale.LeverPrompt.Enabled = true
	end
end

function MatchService:StartPortal(player: Player)
	if not finale or finale.Charging or finale.Open or finale.Fuses < GameConfig.FusesNeeded then
		return
	end
	finale.Charging = true
	finale.LeverPrompt.Enabled = false
	local endsAt = State.now() + GameConfig.PortalChargeSeconds
	State.set("PortalCharging", true)
	State.set("PhaseEndsAt", endsAt)
	Registry.CommanderService:NoteActivity(player)

	local bunker = finale.Bunker
	local core: BasePart = bunker.PortalCore
	core.Transparency = 0.75
	local light = core:FindFirstChild("PortalLight") :: PointLight
	light.Brightness = 1
	-- Everything on the field hears the machine wake up
	Registry.MonsterService:EmitNoise(bunker.Hall, 600)
	Registry.MonsterService:SpawnReinforcements(MonsterConfig.Spawning.SiegeHusks, bunker.Entrance, 90)
	Notify.all("Notify_Reinforcements", nil, "warn")

	task.delay(GameConfig.PortalChargeSeconds, function()
		if finale and finale.Bunker == bunker then
			finale.Charging = false
			finale.Open = true
			State.set("PortalCharging", false)
			State.set("PortalOpen", true)
			core.Transparency = 0.1
			light.Brightness = 3
			local particles = core:FindFirstChild("PortalParticles") :: ParticleEmitter
			particles.Rate = 80
			local hum = Instance.new("Sound")
			hum.Name = "Hum"
			hum.SoundId = pick("PortalHum") or ""
			hum.Looped = true
			hum.RollOffMaxDistance = 200
			hum.Volume = 1
			hum.Parent = core
			if hum.SoundId ~= "" then
				hum:Play()
			end
		end
	end)
end

function MatchService:LaunchCleanup()
	if not finale then
		return
	end
	local bunker = finale.Bunker
	Registry.SquadService:SpawnSuperSquad(bunker.Hall)
	local midpoint = Vector3.new(0, 0, 14):Lerp(bunker.Entrance, 0.55)
	Registry.MonsterService:SpawnReinforcements(MonsterConfig.Spawning.CleanupReinforcements, midpoint, 70)
	Notify.all("Notify_CleanupArrived", nil, "good")
	Notify.all("Notify_Reinforcements", nil, "warn")
end

function MatchService:Escape(player: Player)
	if player:GetAttribute("Escaped") then
		return
	end
	player:SetAttribute("Escaped", true)
	stats.Escaped += 1
	Notify.all("Notify_Escaped", { player.DisplayName }, "good")
	Registry.PlayerService:Despawn(player)
	Registry.CommanderService:Succeed()
end

function MatchService:RunFinale(): string
	setPhase("Finale")
	local bunker = layout.Bunker
	finale = { Bunker = bunker, Fuses = 0, Charging = false, Open = false, LeverPrompt = nil }
	State.set("FusesInserted", 0)
	State.set("FusesNeeded", GameConfig.FusesNeeded)
	State.set("PortalCharging", false)
	State.set("PortalOpen", false)
	Registry.LocationService:ApplyLighting("Finale", 0)

	Builder.prompt(bunker.Panel, "Prompt_InsertFuse", "Resource_Fuse", 0.6, 8).Triggered:Connect(function(player)
		local character = player.Character
		if character and Registry.PlayerService:IsAlive(player) then
			self:InsertFuse(character)
		end
	end)
	local lever = Builder.prompt(bunker.Lever, "Prompt_StartPortal", "Prompt_Lever", 2, 8)
	lever.Enabled = false
	lever.Triggered:Connect(function(player)
		if Registry.PlayerService:IsAlive(player) then
			self:StartPortal(player)
		end
	end)
	finale.LeverPrompt = lever

	local core: BasePart = bunker.PortalCore
	while true do
		task.wait(0.25)
		if finale.Open then
			for _, player in aliveParticipants() do
				local root = Registry.PlayerService:GetRoot(player)
				if root and (root.Position - core.Position).Magnitude < 7 then
					self:Escape(player)
				end
			end
			for _, soldier in table.clone(Registry.SquadService:GetSoldiers()) do
				if soldier.Alive and (soldier.Root.Position - core.Position).Magnitude < 7 then
					stats.SoldiersEscaped += 1
					soldier.Alive = false
					Registry.ResourceService:ForgetCarrier(soldier.Model)
					soldier.Model:Destroy()
					local list = Registry.SquadService:GetSoldiers()
					local i = table.find(list, soldier)
					if i then
						table.remove(list, i)
					end
				end
			end
		end
		if #aliveParticipants() == 0 then
			if stats.Escaped > 0 and #Registry.ReviveService:GetDeadUserIds(participants) == 0 then
				return "Victory"
			end
			if stats.Escaped > 0 and Registry.SquadService:GetAliveCount() == 0 then
				return "Victory"
			end
			if self:CheckWipe() == "Wiped" then
				return if stats.Escaped > 0 then "Victory" else "Defeat"
			end
		end
	end
end

-- Results ---------------------------------------------------------------------

function MatchService:EndScreen(result: string)
	local endsAt = State.now() + GameConfig.EndScreenSeconds
	setPhase("Ended", endsAt)
	local rewards = GameConfig.Rewards
	for _, player in participants do
		if player.Parent then
			local escaped = player:GetAttribute("Escaped") == true
			local coins = rewards.Participation + rewards.PerLocation * stats.Stations
			if escaped then
				coins += rewards.Escape + rewards.PerSurvivingSoldier * stats.SoldiersEscaped
			end
			Registry.DataService:AddCoins(player, coins)
			Registry.DataService:AddStat(player, "Runs", 1)
			Registry.DataService:AddStat(player, "SoldiersLost", stats.SoldiersLost)
			if escaped then
				Registry.DataService:AddStat(player, "Escapes", 1)
			end
			Net.event("RunSummary"):FireClient(player, {
				Victory = result == "Victory",
				Escaped = escaped,
				Stations = stats.Stations,
				SoldiersLost = stats.SoldiersLost,
				EscapedCount = stats.Escaped,
				Coins = coins,
			})
			task.spawn(Registry.DataService.SaveNow, Registry.DataService, player)
		end
	end
	task.wait(GameConfig.EndScreenSeconds)
end

return MatchService
