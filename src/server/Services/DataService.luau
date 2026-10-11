-- Persistent player profiles with a soft session lock, autosave and safe shutdown.
-- In Studio without API access the game runs on temporary offline profiles.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local STORE_NAME = "FodderProfiles_v1"
local AUTOSAVE_SECONDS = 90
local LOCK_EXPIRE_SECONDS = 300
local MAX_RECEIPTS = 60

local TEMPLATE = {
	Coins = 0,
	WeaponLevel = 1,
	Receipts = {}, -- [purchaseId] = os.time()
	Credits = {}, -- [productKey] = count, purchases that could not be applied immediately
	Stats = { Runs = 0, Escapes = 0, SoldiersLost = 0, Deaths = 0 },
}

local DataService = {}

type Profile = { Data: any, Key: string, Offline: boolean, Loaded: boolean }

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function reconcile(data: any, template: any)
	for k, v in template do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v)
		end
	end
end

local function trimReceipts(receipts: { [string]: number })
	local list = {}
	for id, time in receipts do
		table.insert(list, { id = id, time = time })
	end
	if #list <= MAX_RECEIPTS then
		return
	end
	table.sort(list, function(a, b)
		return a.time > b.time
	end)
	for i = MAX_RECEIPTS + 1, #list do
		receipts[list[i].id] = nil
	end
end

local function withRetries<T>(fn: () -> T, attempts: number): (boolean, T | string)
	local lastError: any = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(attempt * 1.5)
	end
	return false, tostring(lastError)
end

local function loadProfile(player: Player)
	local key = "player_" .. player.UserId
	local profile: Profile = { Data = deepCopy(TEMPLATE), Key = key, Offline = store == nil, Loaded = false }
	profiles[player] = profile

	if store then
		local jobId = game.JobId
		local ok, result = withRetries(function()
			return (store :: DataStore):UpdateAsync(key, function(saved)
				saved = saved or deepCopy(TEMPLATE)
				local lock = saved._lock
				if lock and lock.job ~= jobId and os.time() - lock.time < LOCK_EXPIRE_SECONDS then
					-- Another server still holds the profile. Take it over: it was probably left
					-- by a crashed server, and refusing would lock the player out.
					warn(`[Data] taking over profile lock of {player.Name} from {lock.job}`)
				end
				saved._lock = { job = jobId, time = os.time() }
				return saved
			end)
		end, 4)
		if ok and type(result) == "table" then
			profile.Data = result
		else
			warn(`[Data] could not load {player.Name}, using a temporary profile: {result}`)
			profile.Offline = true
		end
	end

	reconcile(profile.Data, TEMPLATE)
	profile.Loaded = true
	player:SetAttribute("Coins", profile.Data.Coins)
	player:SetAttribute("WeaponLevel", profile.Data.WeaponLevel)
end

local function saveProfile(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile or not profile.Loaded then
		return false
	end
	if profile.Offline or not store then
		return true
	end
	trimReceipts(profile.Data.Receipts)
	local data = profile.Data
	local jobId = game.JobId
	local ok, err = withRetries(function()
		return (store :: DataStore):UpdateAsync(profile.Key, function(saved)
			if saved and saved._lock and saved._lock.job ~= jobId then
				-- Someone else owns the profile now; never overwrite their data.
				return nil
			end
			data._lock = if release then nil else { job = jobId, time = os.time() }
			return data
		end)
	end, 3)
	if not ok then
		warn(`[Data] save failed for {player.Name}: {err}`)
	end
	return ok
end

function DataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStores unavailable (enable Studio API access). Profiles will not be saved.")
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player, true)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in profiles do
				task.spawn(saveProfile, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

function DataService:GetProfile(player: Player): Profile?
	local profile = profiles[player]
	if profile and profile.Loaded then
		return profile
	end
	return nil
end

function DataService:WaitForProfile(player: Player, timeout: number?): Profile?
	local deadline = os.clock() + (timeout or 15)
	while os.clock() < deadline and player.Parent do
		local profile = self:GetProfile(player)
		if profile then
			return profile
		end
		task.wait(0.1)
	end
	return nil
end

function DataService:SaveNow(player: Player): boolean
	return saveProfile(player, false)
end

function DataService:AddCoins(player: Player, amount: number)
	local profile = self:GetProfile(player)
	if not profile then
		return
	end
	profile.Data.Coins = math.max(0, profile.Data.Coins + amount)
	player:SetAttribute("Coins", profile.Data.Coins)
end

function DataService:AddStat(player: Player, stat: string, amount: number)
	local profile = self:GetProfile(player)
	if profile then
		profile.Data.Stats[stat] = (profile.Data.Stats[stat] or 0) + amount
	end
end

return DataService
