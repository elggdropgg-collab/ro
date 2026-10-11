-- Client-only settings for this session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Visuals = require(ReplicatedStorage.Shared.Config.Visuals)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Settings = {
	Tape = Visuals.Tape.DefaultIntensity, -- 1 = off, 2 = normal, 3 = strong
	ExtraCensor = 0, -- added to the server censor level
	Volume = 1,
	Changed = Signal.new(),
}

function Settings.set(key: string, value: any)
	(Settings :: any)[key] = value
	Settings.Changed:Fire(key, value)
end

return Settings
