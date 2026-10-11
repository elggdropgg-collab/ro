-- Sends localized notifications. Kinds: "info", "warn", "radio", "death", "good".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Notify = {}

local remote: any = nil

local function get(): any
	if not remote then
		remote = Net.event("Notify")
	end
	return remote
end

function Notify.all(key: string, args: { any }?, kind: string?)
	get():FireAllClients(key, args, kind or "info")
end

function Notify.player(player: Player, key: string, args: { any }?, kind: string?)
	get():FireClient(player, key, args, kind or "info")
end

return Notify
