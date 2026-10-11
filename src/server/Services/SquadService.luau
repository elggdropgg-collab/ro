-- The shared squad: spawning, commands from the commander, deaths and the map snapshot.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SquadConfig = require(ReplicatedStorage.Shared.Config.Squad)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Server = ServerScriptService.Server
local Soldier = require(Server.Squad.Soldier)
local Notify = require(Server.Util.Notify)
local Registry = require(Server.Registry)

local Orders = SquadConfig.Orders

local SquadService = {}
SquadService.LastBark = 0

local folder: Folder
local soldiers: { any } = {}
local nextId = 0
local generation = 0
local usedNames: { [string]: boolean } = {}
local spotted: { [Model]: boolean } = {}
local snapshotRemote

local TICK = 0.2

local function pickName(): string
	local pool = SquadConfig.Names
	for _ = 1, 40 do
		local name = pool[math.random(1, #pool)]
		if not usedNames[name] then
			usedNames[name] = true
			return name
		end
	end
	return pool[math.random(1, #pool)] .. "-" .. math.random(10, 99)
end

local function updateCount()
	local count = 0
	for _, s in soldiers do
		if s.Alive then
			count += 1
		end
	end
	State.set("SquadAlive", count)
end

function SquadService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Squad"
	folder.Parent = workspace

	PhysicsService:RegisterCollisionGroup("Squad")
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:CollisionGroupSetCollidable("Squad", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Squad", "Squad", false)
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)

	snapshotRemote = Net.event("SquadSnapshot")
	Net.event("SquadCommand").OnServerEvent:Connect(function(player, command)
		self:HandleCommand(player, command)
	end)
	State.set("SquadAlive", 0)
end

function SquadService:Start()
	Registry.PlayerService.Spawned:Connect(function(_player, character)
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = "Players"
			end
		end
		character.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.CollisionGroup = "Players"
			end
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			self:BroadcastSnapshot()
		end
	end)
end

local function run(soldier: any, gen: number)
	local refresh = 0
	while soldier.Alive and gen == generation do
		local ok, err = pcall(soldier.Step, soldier, TICK)
		if not ok then
			warn(`[Squad] {soldier.DisplayName} brain error: {err}`)
		end
		refresh += TICK
		if refresh > 5 then
			refresh = 0
			soldier:RefreshIgnore()
		end
		task.wait(TICK)
	end
end

function SquadService:AddSoldiers(
	count: number,
	kind: string?,
	order: string?,
	data: { [string]: any }?,
	ignoreCap: boolean?
): { any }
	local created = {}
	local soldierKind = kind or "Regular"
	for _ = 1, count do
		if soldierKind == "Regular" and not ignoreCap and self:GetAliveCount() >= SquadConfig.MaxSize then
			break
		end
		nextId += 1
		local name = pickName()
		local soldier = Soldier.new(nextId, soldierKind, name, Registry.TrainService:GetPlatformSpawn(nextId), folder)
		soldier.Slot = #soldiers + 1
		if order then
			soldier:SetOrder(order, if data then table.clone(data) else nil)
		end
		table.insert(soldiers, soldier)
		table.insert(created, soldier)
		task.spawn(run, soldier, generation)
	end
	updateCount()
	return created
end

function SquadService:ClearAll()
	generation += 1
	for _, soldier in soldiers do
		soldier.Alive = false
		Registry.ResourceService:ForgetCarrier(soldier.Model)
		soldier.Model:Destroy()
	end
	soldiers = {}
	usedNames = {}
	spotted = {}
	folder:ClearAllChildren()
	updateCount()
end

function SquadService:GetSoldiers(): { any }
	return soldiers
end

function SquadService:GetAliveCount(): number
	local count = 0
	for _, s in soldiers do
		if s.Alive then
			count += 1
		end
	end
	return count
end

function SquadService:KillSoldier(soldier: any, leaveCorpse: boolean)
	if not soldier.Alive then
		return
	end
	soldier.Alive = false
	local position = soldier.Root.Position
	Registry.ResourceService:Drop(soldier.Model)
	Registry.ResourceService:ForgetCarrier(soldier.Model)
	if leaveCorpse then
		Registry.CorpseService:Create(position, Registry.CorpseService:PaletteOf(soldier.Model))
	end
	local index = table.find(soldiers, soldier)
	if index then
		table.remove(soldiers, index)
	end
	soldier.Model:Destroy()
	Notify.all("Notify_SoldierDown", { soldier.DisplayName }, "death")
	Registry.MatchService:OnSoldierLost(soldier)
	updateCount()
	-- Re-pack follow slots so the formation closes up
	for i, s in soldiers do
		s.Slot = i
	end
end

-- Soldiers still outside the train when it leaves are lost. A couple of them get to scream on the radio.
function SquadService:AbandonOutside()
	local abandoned = {}
	for _, soldier in table.clone(soldiers) do
		if soldier.Alive and not Registry.TrainService:IsInSafeZone(soldier.Root.Position) then
			table.insert(abandoned, soldier)
		end
	end
	for i, soldier in abandoned do
		if i <= 2 then
			task.delay((i - 1) * 2.5, function()
				Registry.AudioService:Cue(
					"LeftBehind",
					Vector3.zero,
					{ VictimName = soldier.DisplayName, VictimKind = "Soldier", Radio = true, RadioOnly = true } :: any
				)
			end)
		end
		Notify.all("Notify_LeftBehind", { soldier.DisplayName }, "death")
		self:KillSoldier(soldier, false)
	end
	return #abandoned
end

function SquadService:Recruit(player: Player)
	if self:GetAliveCount() >= SquadConfig.MaxSize then
		Notify.player(player, "Notify_SquadFull", nil, "warn")
		return
	end
	if not Registry.ResourceService:SpendPool("Scrap", SquadConfig.RecruitScrapCost) then
		Notify.player(player, "Notify_NotEnoughScrap", nil, "warn")
		return
	end
	local created = self:AddSoldiers(1)
	if created[1] then
		Notify.all("Notify_Recruited", { created[1].DisplayName }, "good")
	end
end

function SquadService:SpawnSuperSquad(target: Vector3)
	local created = self:AddSoldiers(SquadConfig.SuperSquadSize, "Super", Orders.Route, {
		Waypoints = { Vector3.new(0, 3, 20), target },
		Fast = true,
	})
	for i, soldier in created do
		soldier.OrderData.Waypoints = { Vector3.new((i - 4) * 4, 3, 20), target + Vector3.new((i - 4) * 3, 0, 0) }
	end
end

-- With no players left alive, soldiers go for the dog tags on their own.
function SquadService:AutoRevive(deadUserIds: { number })
	for _, userId in deadUserIds do
		local tag = Registry.ResourceService:FindTag(userId)
		if tag and not Registry.ResourceService:GetCarrierOf(tag) then
			local already = false
			for _, s in soldiers do
				if s.Alive and s.Order == Orders.Revive and s.OrderData.UserId == userId then
					already = true
				end
			end
			if not already then
				local best, bestDist = nil, math.huge
				local tagPosition = (tag.PrimaryPart :: BasePart).Position
				for _, s in soldiers do
					if s.Alive and s.Order ~= Orders.Revive and not s.Grabbed then
						local d = (s.Root.Position - tagPosition).Magnitude
						if d < bestDist then
							best, bestDist = s, d
						end
					end
				end
				if best then
					best:SetOrder(Orders.Revive, { UserId = userId })
				end
			end
		end
	end
end

-- Commands -------------------------------------------------------------------

local function sanitizeWaypoints(raw: any): { Vector3 }?
	if type(raw) ~= "table" then
		return nil
	end
	local list = {}
	for i, point in raw do
		if i > SquadConfig.MaxRouteWaypoints then
			break
		end
		if type(point) == "table" and type(point[1]) == "number" and type(point[2]) == "number" then
			local x, z = point[1], point[2]
			if x == x and z == z and math.abs(x) < 2000 and math.abs(z) < 2000 then
				local p = Vector3.new(x, 3, z)
				if Registry.LocationService:InBounds(p) then
					table.insert(list, p)
				end
			end
		end
	end
	return if #list > 0 then list else nil
end

function SquadService:HandleCommand(player: Player, command: any)
	if type(command) ~= "table" or type(command.Order) ~= "string" or not Orders[command.Order] then
		return
	end
	if not Registry.CommanderService:IsCommander(player) then
		Notify.player(player, "Map_NotCommander", nil, "warn")
		return
	end
	Registry.CommanderService:NoteActivity(player)

	local selected: { any } = {}
	if command.Ids == "all" then
		for _, s in soldiers do
			if s.Alive and s.Kind == "Regular" then
				table.insert(selected, s)
			end
		end
	elseif type(command.Ids) == "table" then
		local wanted = {}
		for _, id in command.Ids do
			if type(id) == "number" then
				wanted[id] = true
			end
		end
		for _, s in soldiers do
			if s.Alive and wanted[s.Id] then
				table.insert(selected, s)
			end
		end
	end
	if #selected == 0 then
		return
	end

	local order = command.Order
	if order == Orders.Route then
		local waypoints = sanitizeWaypoints(command.Waypoints)
		if not waypoints then
			return
		end
		for i, s in selected do
			-- Fan out slightly so the group does not walk in one file
			local offset = Vector3.new(((i - 1) % 3 - 1) * 3, 0, math.floor((i - 1) / 3) * 3)
			local own = {}
			for _, p in waypoints do
				table.insert(own, p + offset)
			end
			s:SetOrder(order, { Waypoints = own, Fast = command.Fast == true })
		end
	elseif order == Orders.Revive then
		if type(command.UserId) ~= "number" then
			return
		end
		-- One soldier is enough; send the closest
		local tag = Registry.ResourceService:FindTag(command.UserId)
		if not tag then
			return
		end
		local tagPosition = (tag.PrimaryPart :: BasePart).Position
		table.sort(selected, function(a, b)
			return (a.Root.Position - tagPosition).Magnitude < (b.Root.Position - tagPosition).Magnitude
		end)
		selected[1]:SetOrder(order, { UserId = command.UserId })
	elseif order == Orders.Follow then
		for i, s in selected do
			s:SetOrder(order, { UserId = player.UserId, Slot = i })
		end
	elseif order == Orders.Wander or order == Orders.Gather then
		for _, s in selected do
			s:SetOrder(order, { Anchor = s.Root.Position })
		end
	else
		for _, s in selected do
			s:SetOrder(order)
		end
	end
end

-- Snapshot for the tactical map ------------------------------------------------

function SquadService:BroadcastSnapshot()
	if #Players:GetPlayers() == 0 then
		return
	end
	local eyes: { Vector3 } = {}
	local soldierList = {}
	for _, s in soldiers do
		if s.Alive then
			local p = s.Root.Position
			table.insert(eyes, p)
			table.insert(soldierList, {
				s.Id,
				math.round(p.X),
				math.round(p.Z),
				s.Order,
				math.round(s.Humanoid.Health / s.Humanoid.MaxHealth * 100),
				s.Model:GetAttribute("Carrying") or "",
				s.DisplayName,
				s.Kind,
				if s.Grabbed then 1 else 0,
			})
		end
	end
	local playerList = {}
	for _, player in Players:GetPlayers() do
		local root = Registry.PlayerService:GetRoot(player)
		if root and Registry.PlayerService:IsAlive(player) then
			table.insert(eyes, root.Position)
			table.insert(
				playerList,
				{ player.UserId, math.round(root.Position.X), math.round(root.Position.Z), player.DisplayName }
			)
		end
	end

	-- Monsters show up only when someone is close enough to see them
	local monsterList = {}
	for _, monster in Registry.MonsterService:GetMonsters() do
		if monster.Alive then
			local p = monster.Root.Position
			for _, eye in eyes do
				if (eye - p).Magnitude < 55 then
					table.insert(monsterList, { math.round(p.X), math.round(p.Z), monster.Kind })
					break
				end
			end
		end
	end

	-- Resources stay on the map once someone has seen them
	local itemList = {}
	local tagList = {}
	for _, item in Registry.ResourceService:GetItems() do
		local handle = item.PrimaryPart
		if handle then
			local p = handle.Position
			local kind = item:GetAttribute("Kind")
			if kind == "DogTag" then
				table.insert(tagList, { item:GetAttribute("OwnerUserId"), math.round(p.X), math.round(p.Z) })
			else
				if not spotted[item] then
					for _, eye in eyes do
						if (eye - p).Magnitude < 70 then
							spotted[item] = true
							break
						end
					end
				end
				if spotted[item] then
					table.insert(itemList, { math.round(p.X), math.round(p.Z), kind })
				end
			end
		end
	end
	for item in spotted do
		if not item.Parent then
			spotted[item] = nil
		end
	end

	snapshotRemote:FireAllClients({
		S = soldierList,
		P = playerList,
		M = monsterList,
		I = itemList,
		T = tagList,
	})
end

return SquadService
