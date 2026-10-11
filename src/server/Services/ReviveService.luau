-- Death and revival. A fallen player drops a dog tag; carrying it to a reanimator brings
-- them back. Soldiers can do it on orders, or on their own when no player is left.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Server = ServerScriptService.Server
local Builder = require(Server.World.Builder)
local Notify = require(Server.Util.Notify)
local Registry = require(Server.Registry)

local P = Builder.Palette

local ReviveService = {}

local folder: Folder
local reanimators: { BasePart } = {}
local deathPositions: { [number]: Vector3 } = {}
local deathRemote

function ReviveService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Reanimators"
	folder.Parent = workspace
	deathRemote = Net.event("Death")
end

function ReviveService:Start()
	Registry.PlayerService.Died:Connect(function(player, position, cause)
		self:OnPlayerDied(player, position, cause)
	end)
	Players.PlayerRemoving:Connect(function(player)
		Registry.ResourceService:RemoveTag(player.UserId)
		deathPositions[player.UserId] = nil
	end)
end

local function buildReanimator(cframe: CFrame): BasePart
	local model = Builder.model(folder, "Reanimator")
	Builder.part(model, cframe * CFrame.new(0, 0.3, 0), Vector3.new(6, 0.6, 6), Enum.Material.DiamondPlate, P.MetalDark)
	local body = Builder.part(
		model,
		cframe * CFrame.new(0, 3, 1.6),
		Vector3.new(3.2, 5, 1.6),
		Enum.Material.Metal,
		Color3.fromRGB(190, 192, 186)
	)
	body.Name = "Core"
	Builder.detail(
		model,
		body.CFrame * CFrame.new(0, 1.4, -0.81),
		Vector3.new(2.4, 1.2, 0.05),
		Enum.Material.Neon,
		Color3.fromRGB(70, 255, 150)
	)
	-- Medical cross that glows through the fog
	local crossV = Builder.detail(
		model,
		cframe * CFrame.new(0, 7.2, 1.6),
		Vector3.new(0.6, 2, 0.3),
		Enum.Material.Neon,
		Color3.fromRGB(70, 255, 150)
	)
	Builder.detail(
		model,
		cframe * CFrame.new(0, 7.2, 1.6),
		Vector3.new(2, 0.6, 0.3),
		Enum.Material.Neon,
		Color3.fromRGB(70, 255, 150)
	)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(80, 255, 160)
	light.Range = 18
	light.Brightness = 1.4
	light.Parent = crossV
	Builder.part(model, cframe * CFrame.new(0, 3.6, 1.6), Vector3.new(0.4, 7, 0.4), Enum.Material.Metal, P.MetalDark)
	-- Gurney
	Builder.part(
		model,
		cframe * CFrame.new(0, 1.6, -1.2),
		Vector3.new(2.2, 0.3, 4.4),
		Enum.Material.Fabric,
		Color3.fromRGB(150, 160, 150)
	)

	local prompt = Builder.prompt(body, "Prompt_Revive", "Prompt_Reanimator", GameConfig.ReviveHoldSeconds, 9)
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		if not character or not Registry.PlayerService:IsAlive(player) then
			return
		end
		local item = Registry.ResourceService:GetCarried(character)
		if not item or item:GetAttribute("Kind") ~= "DogTag" then
			Notify.player(player, "Notify_NeedTag", nil, "warn")
			return
		end
		ReviveService:CompleteRevive(item:GetAttribute("OwnerUserId"), body, character)
	end)
	table.insert(reanimators, body)
	return body
end

function ReviveService:BuildFromLayout(layout: any)
	self:Clear()
	for _, cframe in layout.Reanimators or {} do
		buildReanimator(cframe)
	end
end

function ReviveService:Clear()
	folder:ClearAllChildren()
	reanimators = {}
end

function ReviveService:NearestReanimator(position: Vector3): BasePart?
	local best, bestDist = nil, math.huge
	for _, part in reanimators do
		local d = (part.Position - position).Magnitude
		if d < bestDist then
			best, bestDist = part, d
		end
	end
	return best
end

function ReviveService:OnPlayerDied(player: Player, position: Vector3, cause: string)
	deathPositions[player.UserId] = position
	local phase = State.get("Phase")
	local inRun = phase == "Location" or phase == "Departing" or phase == "Finale"
	if inRun and cause ~= "LeftBehind" then
		Registry.ResourceService:RemoveTag(player.UserId)
		Registry.ResourceService:SpawnItem("DogTag", position, {
			OwnerUserId = player.UserId,
			OwnerName = player.DisplayName,
		})
	end
	if cause ~= "LeftBehind" then
		Notify.all("Notify_PlayerDown", { player.DisplayName }, "death")
	end
	deathRemote:FireClient(player, { Cause = cause, InRun = inRun })
	Registry.MatchService:OnPlayerDied(player)
end

function ReviveService:CompleteRevive(userId: number, reanimator: BasePart, byModel: Model?)
	local player = Players:GetPlayerByUserId(userId)
	if byModel then
		Registry.ResourceService:Consume(byModel)
	end
	Registry.ResourceService:RemoveTag(userId)
	if not player or Registry.PlayerService:IsAlive(player) then
		return
	end
	local spawn = reanimator.CFrame * CFrame.new(0, 1, -4)
	Registry.PlayerService:Spawn(player, spawn, GameConfig.ReviveInvulnerability)
	Notify.all("Notify_Revived", { player.DisplayName }, "good")
	Registry.MatchService:OnPlayerRevived(player)
end

function ReviveService:SelfRevive(player: Player): boolean
	if Registry.PlayerService:IsAlive(player) then
		return false
	end
	local position = deathPositions[player.UserId]
	if not position then
		return false
	end
	Registry.ResourceService:RemoveTag(player.UserId)
	Registry.PlayerService:Spawn(
		player,
		CFrame.new(position + Vector3.new(0, 3, 0)),
		GameConfig.SelfReviveInvulnerability
	)
	player:SetAttribute("InfiniteSprintUntil", State.now() + GameConfig.SelfReviveInvulnerability)
	Notify.all("Notify_Revived", { player.DisplayName }, "good")
	Registry.MatchService:OnPlayerRevived(player)
	return true
end

function ReviveService:CanSelfRevive(player: Player): boolean
	local phase = State.get("Phase")
	return not Registry.PlayerService:IsAlive(player)
		and deathPositions[player.UserId] ~= nil
		and (phase == "Location" or phase == "Departing" or phase == "Finale" or phase == "LastChance")
		and not player:GetAttribute("Escaped")
end

-- Everyone who died at a station comes back aboard when the train leaves.
function ReviveService:RespawnDeadOnTrain(participants: { Player })
	local index = 0
	for _, player in participants do
		if player.Parent and not Registry.PlayerService:IsAlive(player) and not player:GetAttribute("Escaped") then
			index += 1
			Registry.ResourceService:RemoveTag(player.UserId)
			Registry.PlayerService:Spawn(player, Registry.TrainService:GetPlayerSpawn(index), 3)
		end
	end
	deathPositions = {}
end

function ReviveService:GetDeadUserIds(participants: { Player }): { number }
	local list = {}
	for _, player in participants do
		if player.Parent and not Registry.PlayerService:IsAlive(player) and not player:GetAttribute("Escaped") then
			table.insert(list, player.UserId)
		end
	end
	return list
end

function ReviveService:Reset()
	deathPositions = {}
	self:Clear()
end

return ReviveService
