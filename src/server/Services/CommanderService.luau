-- Commander vote at the start of a run, succession on death or inactivity, and manual hand-over.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Server = ServerScriptService.Server
local Notify = require(Server.Util.Notify)
local Registry = require(Server.Registry)

local CommanderService = {}

local commander: Player? = nil
local ranking: { number } = {} -- user ids, best voted first
local votes: { [Player]: number } = {}
local voting = false
local lastActivity = 0
local lastPosition: Vector3? = nil

local function setCommander(player: Player?)
	if commander then
		commander:SetAttribute("IsCommander", nil)
	end
	commander = player
	lastActivity = os.clock()
	lastPosition = nil
	if player then
		player:SetAttribute("IsCommander", true)
		State.set("CommanderUserId", player.UserId)
	else
		State.set("CommanderUserId", 0)
	end
end

function CommanderService:Init()
	State.set("CommanderUserId", 0)
	Net.event("CastVote").OnServerEvent:Connect(function(player, userId)
		if voting and type(userId) == "number" and Players:GetPlayerByUserId(userId) then
			votes[player] = userId
		end
	end)
	Net.event("TransferCommand").OnServerEvent:Connect(function(player, userId)
		if player ~= commander then
			return
		end
		local target = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		if target and target ~= player and Registry.PlayerService:IsAlive(target) then
			setCommander(target)
			Notify.all("Commander_Transferred", { target.DisplayName }, "info")
		end
	end)
end

function CommanderService:Start()
	Players.PlayerRemoving:Connect(function(player)
		votes[player] = nil
		if player == commander then
			self:Succeed()
		end
	end)
	Registry.PlayerService.Died:Connect(function(player)
		if player == commander then
			Notify.all("Notify_CommanderDown", nil, "death")
			self:Succeed()
		end
	end)

	-- Inactive commanders lose command so one AFK player cannot ruin the run
	task.spawn(function()
		while true do
			task.wait(5)
			local phase = State.get("Phase")
			if commander and (phase == "Location" or phase == "Finale") then
				local root = Registry.PlayerService:GetRoot(commander)
				if root then
					if lastPosition and (root.Position - lastPosition).Magnitude > 4 then
						lastActivity = os.clock()
					end
					lastPosition = root.Position
				end
				if os.clock() - lastActivity > GameConfig.CommanderAfkSeconds then
					self:Succeed()
				end
			end
		end
	end)
end

function CommanderService:NoteActivity(player: Player)
	if player == commander then
		lastActivity = os.clock()
	end
end

-- Runs the vote. Yields until it ends.
function CommanderService:RunVote(participants: { Player })
	votes = {}
	ranking = {}
	local candidates = {}
	for _, player in participants do
		table.insert(candidates, { UserId = player.UserId, Name = player.DisplayName })
	end
	if #participants <= 1 then
		ranking = { if participants[1] then participants[1].UserId else 0 }
		setCommander(participants[1])
		return
	end

	voting = true
	local endsAt = State.now() + GameConfig.VoteDuration
	State.set("PhaseEndsAt", endsAt)
	Net.event("VoteStart"):FireAllClients(candidates, endsAt)
	local started = os.clock()
	while os.clock() - started < GameConfig.VoteDuration do
		task.wait(0.25)
		local cast = 0
		for _ in votes do
			cast += 1
		end
		if cast >= #participants then
			break
		end
	end
	voting = false

	local tally: { [number]: number } = {}
	for _, userId in votes do
		tally[userId] = (tally[userId] or 0) + 1
	end
	local order = {}
	for _, player in participants do
		if player.Parent then
			table.insert(order, { UserId = player.UserId, Votes = tally[player.UserId] or 0, Tie = math.random() })
		end
	end
	table.sort(order, function(a, b)
		if a.Votes ~= b.Votes then
			return a.Votes > b.Votes
		end
		return a.Tie > b.Tie
	end)
	for _, entry in order do
		table.insert(ranking, entry.UserId)
	end
	local winner = order[1] and Players:GetPlayerByUserId(order[1].UserId)
	setCommander(winner)
	Net.event("VoteResult"):FireAllClients(if winner then winner.UserId else 0)
	if winner then
		Notify.all("Vote_Result", { winner.DisplayName }, "info")
	end
end

-- Passes command to the next living player by vote ranking.
function CommanderService:Succeed()
	local previous = commander
	for _, userId in ranking do
		local player = Players:GetPlayerByUserId(userId)
		if player and player ~= previous and Registry.PlayerService:IsAlive(player) then
			setCommander(player)
			Notify.all("Commander_Transferred", { player.DisplayName }, "info")
			return
		end
	end
	for _, player in Registry.PlayerService:GetAlivePlayers() do
		if player ~= previous then
			setCommander(player)
			Notify.all("Commander_Transferred", { player.DisplayName }, "info")
			return
		end
	end
	-- Nobody else alive: keep the title so the squad still follows the last orders
	if previous and not previous.Parent then
		setCommander(nil)
	end
end

-- Called when a player comes back to life: if nobody can command, they take over.
function CommanderService:OnPlayerAvailable(player: Player)
	if not commander or not commander.Parent or not Registry.PlayerService:IsAlive(commander) then
		setCommander(player)
		Notify.all("Commander_Transferred", { player.DisplayName }, "info")
	end
end

function CommanderService:IsCommander(player: Player): boolean
	return player == commander
end

function CommanderService:GetCommander(): Player?
	return commander
end

function CommanderService:Reset()
	setCommander(nil)
	ranking = {}
	votes = {}
end

return CommanderService
