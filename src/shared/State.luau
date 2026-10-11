--!strict
-- Replicated match state, stored as attributes so clients get changes for free.
--
-- Keys used across the game:
--   Phase, PhaseEndsAt, LocationIndex, LocationCount, LocationName, StationKey,
--   DieselPool, ScrapPool, SuppliesPool, DieselNeeded, CommanderUserId, Night,
--   TrainMoving, FusesInserted, FusesNeeded, PortalCharging, PortalOpen,
--   CleanupActive, SquadDamageBoost, CensorLevel, SquadAlive, Seed

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local State = {}

local holder: Instance? = nil

local function getHolder(): Instance
	if holder then
		return holder
	end
	local h: Instance
	if RunService:IsServer() then
		h = Instance.new("Configuration")
		h.Name = "MatchState"
		h.Parent = ReplicatedStorage
	else
		h = ReplicatedStorage:WaitForChild("MatchState")
	end
	holder = h
	return h
end

function State.set(key: string, value: any)
	getHolder():SetAttribute(key, value)
end

function State.get(key: string): any
	return getHolder():GetAttribute(key)
end

function State.changed(key: string): RBXScriptSignal
	return getHolder():GetAttributeChangedSignal(key)
end

-- Calls fn now and on every change.
function State.observe(key: string, fn: (any) -> ()): RBXScriptConnection
	task.spawn(fn, State.get(key))
	return State.changed(key):Connect(function()
		fn(State.get(key))
	end)
end

function State.now(): number
	return workspace:GetServerTimeNow()
end

return State
