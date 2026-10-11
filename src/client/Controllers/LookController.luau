-- Tells the server where this player is looking, for monsters that react to the gaze.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer

local LookController = {}

local INTERVAL = 0.2

function LookController:Start()
	local remote = Net.event("LookReport")
	while true do
		task.wait(INTERVAL)
		local camera = workspace.CurrentCamera
		if camera and player:GetAttribute("Alive") then
			local cf = camera.CFrame
			remote:FireServer(cf.Position, cf.LookVector)
		end
	end
end

return LookController
