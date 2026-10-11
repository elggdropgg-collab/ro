-- Server side of the audio system: decides what happens, clients decide how it sounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)

local AudioService = {}

local cueRemote

export type CuePayload = {
	Seed: number?,
	Follow: Instance?, -- the sound follows this part while it exists
	VictimName: string?,
	VictimKind: string?, -- "Soldier" | "Player"
	VictimUserId: number?,
	Radio: boolean?, -- far listeners hear it through the squad radio
}

function AudioService:Init()
	cueRemote = Net.event("AudioCue")
end

function AudioService:Cue(recipe: string, position: Vector3, payload: CuePayload?)
	local data: any = payload or {}
	data.Seed = data.Seed or math.random(1, 2 ^ 30)
	data.StartedAt = State.now()
	cueRemote:FireAllClients(recipe, position, data)
end

function AudioService:CueFor(player: Player, recipe: string, position: Vector3, payload: CuePayload?)
	local data: any = payload or {}
	data.Seed = data.Seed or math.random(1, 2 ^ 30)
	data.StartedAt = State.now()
	cueRemote:FireClient(player, recipe, position, data)
end

function AudioService:CueExcept(except: Player, recipe: string, position: Vector3, payload: CuePayload?)
	local data: any = payload or {}
	data.Seed = data.Seed or math.random(1, 2 ^ 30)
	data.StartedAt = State.now()
	for _, player in Players:GetPlayers() do
		if player ~= except then
			cueRemote:FireClient(player, recipe, position, data)
		end
	end
end

-- Ambient loops are chosen on the client from this preset name.
function AudioService:SetAmbient(preset: string)
	State.set("AmbientPreset", preset)
end

return AudioService
