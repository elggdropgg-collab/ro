--!strict
-- Remote events. The server creates them, clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RELIABLE = {
	-- server -> client
	"Notify", -- (key: string, args: {any}?, kind: string?)
	"AudioCue", -- (recipe: string, position: Vector3, payload: {any})
	"VoteStart", -- (candidates: {{UserId, Name}}, endsAt: number)
	"VoteResult", -- (commanderUserId: number)
	"MapLayout", -- (layout: {any})
	"KillCam", -- (monster: Model, duration: number)
	"Scare", -- (fromName: string, paranoiaSeconds: number)
	"RunSummary", -- (summary: {any})
	"Death", -- (info: {any})
	"SquadSnapshot", -- (snapshot: {any}), 4 times per second; too large for unreliable events
	-- client -> server
	"ReadyUp",
	"CastVote", -- (userId: number)
	"SquadCommand", -- (command: {any})
	"TransferCommand", -- (userId: number?)
	"Fire", -- (aimPoint: Vector3)
	"Reload",
	"ToggleFlashlight",
	"RequestPurchase", -- (productKey: string)
	"UpgradeWeapon",
	"Sprinting", -- (isSprinting: boolean)
}

local UNRELIABLE = {
	"Tracer", -- server -> client
	"LookReport", -- client -> server, camera direction for gaze-based monsters
}

local Net = {}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	local f: Folder
	if RunService:IsServer() then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		for _, name in RELIABLE do
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = f
		end
		for _, name in UNRELIABLE do
			local e = Instance.new("UnreliableRemoteEvent")
			e.Name = name
			e.Parent = f
		end
		f.Parent = ReplicatedStorage
	else
		f = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	folder = f
	return f
end

-- Returns a RemoteEvent or UnreliableRemoteEvent. Typed as any because both share the same API.
function Net.event(name: string): any
	local f = getFolder()
	local remote = if RunService:IsServer() then f:FindFirstChild(name) else f:WaitForChild(name, 15)
	assert(remote, "Unknown remote: " .. name)
	return remote
end

return Net
