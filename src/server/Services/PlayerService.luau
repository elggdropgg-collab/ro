-- Player characters: spawning, death, flashlight, ammo, weapon upgrades and invulnerability.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Resources = require(ReplicatedStorage.Shared.Config.Resources)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Server = ServerScriptService.Server
local Notify = require(Server.Util.Notify)
local GunModels = require(Server.Weapons.GunModels)
local Registry = require(Server.Registry)

local PlayerService = {}

PlayerService.Died = Signal.new() -- (player, position, cause)
PlayerService.Spawned = Signal.new() -- (player, character)

local alive: { [Player]: boolean } = {}
local silentDeath: { [Player]: boolean } = {}

local function weaponLevel(player: Player): any
	local level = player:GetAttribute("WeaponLevel") or 1
	return Weapons.Levels[math.clamp(level, 1, #Weapons.Levels)]
end

function PlayerService:Init()
	Net.event("ToggleFlashlight").OnServerEvent:Connect(function(player)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local light = head and head:FindFirstChild("Flashlight") :: SpotLight?
		if light then
			light.Enabled = not light.Enabled
		end
	end)
	Net.event("Sprinting").OnServerEvent:Connect(function(player, sprinting)
		if type(sprinting) == "boolean" then
			player:SetAttribute("Sprinting", sprinting)
		end
	end)
	Net.event("UpgradeWeapon").OnServerEvent:Connect(function(player)
		self:UpgradeWeapon(player)
	end)
end

function PlayerService:Start()
	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character then
			Registry.ResourceService:Drop(character)
			Registry.ResourceService:ForgetCarrier(character)
		end
		alive[player] = nil
		silentDeath[player] = nil
	end)
end

function PlayerService:ResetAmmo(player: Player)
	local level = weaponLevel(player)
	player:SetAttribute("Ammo", level.Magazine)
	player:SetAttribute("Reserve", level.Reserve)
end

local function setupCharacter(player: Player, character: Model, invulnerable: number)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local head = character:WaitForChild("Head") :: BasePart
	humanoid.MaxHealth = GameConfig.Player.MaxHealth
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = GameConfig.Player.WalkSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Face = Enum.NormalId.Front
	light.Angle = 42
	light.Range = 62
	light.Brightness = 3.2
	light.Shadows = true
	light.Color = Color3.fromRGB(255, 244, 222)
	light.Enabled = State.get("Night") ~= nil and (State.get("Night") :: number) > 0.4
	light.Parent = head

	-- Parenting the tool to the character equips it; the backpack bar is hidden on the client
	GunModels.pistol().Parent = character

	character:SetAttribute("IsPlayer", true)
	character:SetAttribute("UserId", player.UserId)
	player:SetAttribute("InvulnerableUntil", State.now() + invulnerable)
	if player:GetAttribute("Ammo") == nil then
		PlayerService:ResetAmmo(player)
	end

	humanoid.Died:Connect(function()
		if not alive[player] then
			return
		end
		alive[player] = false
		player:SetAttribute("Alive", false)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local position = if root then root.Position else head.Position
		Registry.ResourceService:Drop(character)
		Registry.ResourceService:ForgetCarrier(character)

		local silent = silentDeath[player]
		silentDeath[player] = nil
		if not silent then
			Registry.CorpseService:Create(position, Registry.CorpseService:PaletteOf(character))
		end
		Registry.DataService:AddStat(player, "Deaths", 1)
		PlayerService.Died:Fire(player, position, if silent then "LeftBehind" else "Killed")
		task.delay(0.1, function()
			if player.Character == character then
				player.Character = nil
			end
			character:Destroy()
		end)
	end)
end

-- Spawns (or respawns) a player's character at `cframe`.
function PlayerService:Spawn(player: Player, cframe: CFrame, invulnerable: number?)
	if not player.Parent then
		return
	end
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		warn(`[Player] LoadCharacter failed for {player.Name}: {err}`)
		return
	end
	local character = player.Character
	if not character then
		return
	end
	setupCharacter(player, character, invulnerable or 0)
	character:PivotTo(cframe)
	alive[player] = true
	player:SetAttribute("Alive", true)
	player:SetAttribute("Escaped", nil)
	PlayerService.Spawned:Fire(player, character)
end

function PlayerService:Despawn(player: Player)
	local character = player.Character
	alive[player] = false
	player:SetAttribute("Alive", false)
	if character then
		Registry.ResourceService:Drop(character)
		Registry.ResourceService:ForgetCarrier(character)
		player.Character = nil
		character:Destroy()
	end
end

-- Kills a player without leaving a body (left behind at a station, happens off-screen).
function PlayerService:KillSilently(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and alive[player] then
		silentDeath[player] = true
		humanoid.Health = 0
	end
end

function PlayerService:IsAlive(player: Player): boolean
	return alive[player] == true and player.Character ~= nil
end

function PlayerService:GetAlivePlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if self:IsAlive(player) then
			table.insert(list, player)
		end
	end
	return list
end

function PlayerService:IsInvulnerable(player: Player): boolean
	return (player:GetAttribute("InvulnerableUntil") or 0) > State.now()
end

function PlayerService:GetRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function PlayerService:RefillAmmo(player: Player)
	if not self:IsAlive(player) then
		return
	end
	local level = weaponLevel(player)
	local ammo, reserve = player:GetAttribute("Ammo") or 0, player:GetAttribute("Reserve") or 0
	if ammo >= level.Magazine and reserve >= level.Reserve then
		Notify.player(player, "Notify_AmmoRefilled", nil, "info")
		return
	end
	if not Registry.ResourceService:SpendPool("Supplies", 1) then
		Notify.player(player, "Notify_NoSupplies", nil, "warn")
		return
	end
	player:SetAttribute("Ammo", level.Magazine)
	player:SetAttribute("Reserve", level.Reserve)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Resources.SuppliesHeal)
	end
	Notify.player(player, "Notify_AmmoRefilled", nil, "good")
end

function PlayerService:UpgradeWeapon(player: Player)
	local profile = Registry.DataService:GetProfile(player)
	if not profile then
		return
	end
	local current = profile.Data.WeaponLevel
	local nextLevel = Weapons.Levels[current + 1]
	if not nextLevel then
		Notify.player(player, "Notify_MaxLevel", nil, "info")
		return
	end
	if profile.Data.Coins < nextLevel.Cost then
		Notify.player(player, "Notify_NotEnoughCoins", { nextLevel.Cost }, "warn")
		return
	end
	Registry.DataService:AddCoins(player, -nextLevel.Cost)
	profile.Data.WeaponLevel = current + 1
	player:SetAttribute("WeaponLevel", current + 1)
	Notify.player(player, "Notify_Upgraded", { current + 1 }, "good")
end

return PlayerService
