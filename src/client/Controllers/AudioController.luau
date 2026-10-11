-- Plays layered sound recipes sent by the server.
--
-- Mixing rules:
--   * Near the victim you hear the world layers in 3D, with reverb.
--   * Far away, a squad death reaches you through the radio: band-limited, distorted,
--     compressed, with static and key clicks. The world layers are routed there too,
--     so you hear the bones break through a cheap speaker. That is the point.
--   * Ambience ducks while somebody is dying so nothing masks it.
--   * Every layer picks a random variant and pitch: no two deaths sound the same.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Settings = require(script.Parent.Parent.Settings)
local Registry = require(script.Parent.Parent.Registry)

local player = Players.LocalPlayer

local AudioController = {}

local groups: { [string]: SoundGroup } = {}
local ambient: { Sound } = {}
local heartbeat: Sound? = nil
local duckUntil = 0
local paranoiaUntil = 0

local AMBIENT_PRESETS: { [string]: { { string | number } } } = {
	Lobby = { { "AmbientNight", 0.4 }, { "AmbientFieldWind", 0.25 } },
	Travel = { { "TrainRolling", 0.9 }, { "AmbientTrainInterior", 0.5 } },
	Field = { { "AmbientFieldWind", 0.55 }, { "AmbientFieldCrickets", 0.35 } },
	Finale = { { "AmbientNight", 0.6 }, { "AmbientFieldWind", 0.3 } },
}

local function group(name: string, parent: Instance, volume: number): SoundGroup
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = volume
	g.Parent = parent
	groups[name] = g
	return g
end

function AudioController:Pick(slot: string, rng: Random?): string?
	local list = Sounds.Library[slot]
	if not list or #list == 0 then
		return nil
	end
	local r = rng or Random.new()
	return list[r:NextInteger(1, #list)]
end

local function makeSound(id: string, volume: number, pitch: number, groupName: string): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.SoundGroup = groups[groupName]
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = Sounds.WorldMaxDistance
	return sound
end

local function cleanupWhenDone(sound: Sound, holder: Instance?)
	sound.Ended:Once(function()
		if holder then
			holder:Destroy()
		else
			sound:Destroy()
		end
	end)
	task.delay(30, function()
		if holder and holder.Parent then
			holder:Destroy()
		elseif sound.Parent then
			sound:Destroy()
		end
	end)
end

-- 3D sound at a point or following a part.
function AudioController:PlayAt(
	slot: string,
	where: Vector3 | BasePart,
	volume: number?,
	pitch: number?,
	rng: Random?
): Sound?
	local id = self:Pick(slot, rng)
	if not id then
		return nil
	end
	local attachment = Instance.new("Attachment")
	if typeof(where) == "Instance" and where.Parent then
		attachment.Parent = where
	else
		attachment.WorldPosition = if typeof(where) == "Vector3" then where else (where :: BasePart).Position
		attachment.Parent = workspace.Terrain
	end
	local sound = makeSound(id, volume or 1, pitch or 1, "World")
	sound.Parent = attachment
	sound:Play()
	cleanupWhenDone(sound, attachment)
	return sound
end

-- Looped 3D sound attached to a part; lives until the caller (or the part) destroys it.
function AudioController:Loop(slot: string, parent: BasePart, volume: number?, pitch: number?): Sound?
	local id = self:Pick(slot)
	if not id then
		return nil
	end
	local sound = makeSound(id, volume or 1, pitch or 1, "World")
	sound.Looped = true
	sound.Parent = parent
	sound.TimePosition = math.random() * 2
	sound:Play()
	return sound
end

-- Non-positional sound on a channel ("Radio", "Self", "Ui").
function AudioController:Play2D(slot: string, groupName: string, volume: number?, pitch: number?, rng: Random?): Sound?
	local id = self:Pick(slot, rng)
	if not id then
		return nil
	end
	local sound = makeSound(id, volume or 1, pitch or 1, groupName)
	sound.Parent = SoundService
	sound:Play()
	cleanupWhenDone(sound)
	return sound
end

function AudioController:Duck(seconds: number)
	duckUntil = math.max(duckUntil, os.clock() + seconds)
	TweenService:Create(groups.Ambient, TweenInfo.new(0.4), { Volume = 0.18 }):Play()
end

local function listenerPosition(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.Focus.Position else Vector3.zero
end

local function rangeValue(value: number | { number }, rng: Random): number
	if type(value) == "table" then
		return rng:NextNumber(value[1], value[2])
	end
	return value :: number
end

local VOICE_SLOTS = {
	ScreamAgony = true,
	ScreamPanic = true,
	ScreamChoked = true,
	Gurgle = true,
	BoneCrunch = true,
	FleshTear = true,
	WetSquelch = true,
	MonsterChew = true,
}

function AudioController:PlayRecipe(name: string, position: Vector3, payload: any)
	local recipe = Sounds.Recipes[name]
	if not recipe then
		return
	end
	payload = payload or {}
	local rng = Random.new(payload.Seed or 1)
	local follow: BasePart? = if typeof(payload.Follow) == "Instance" and payload.Follow:IsA("BasePart")
		then payload.Follow
		else nil
	local isMe = payload.VictimUserId ~= nil and payload.VictimUserId == player.UserId
	local distance = (position - listenerPosition()).Magnitude
	local radioOnly = payload.RadioOnly == true
	local radio = payload.Radio == true and not isMe and (radioOnly or distance > Sounds.RadioDistance)
	local world = not radioOnly and distance < Sounds.WorldMaxDistance

	if recipe.DuckAmbient and (radio or (world and distance < 140)) then
		self:Duck(recipe.Duration)
	end
	if radio then
		-- Static bed under the whole transmission
		local bed = self:Play2D("RadioStatic", "Radio", 0.25, rng:NextNumber(0.95, 1.05), rng)
		if bed then
			bed.Looped = true
			task.delay(recipe.Duration, function()
				TweenService:Create(bed, TweenInfo.new(0.3), { Volume = 0 }):Play()
				task.delay(0.35, function()
					bed:Destroy()
				end)
			end)
		end
		Registry.TapeController:RadioGlitch(recipe.Duration)
	end

	for _, layer in recipe.Layers do
		local channel = layer.Channel or "World"
		local count = layer.Repeat or 1
		local start = rangeValue(layer.At, rng)
		local time = start
		for _ = 1, count do
			local pitch = if layer.Pitch then rng:NextNumber(layer.Pitch[1], layer.Pitch[2]) else 1
			local volume = layer.Volume or 1
			local delay = time
			-- Each layer gets its own generator so the variants stay in sync between players
			local layerRng = Random.new(rng:NextInteger(1, 2 ^ 30))
			if channel == "World" then
				if world then
					task.delay(delay, function()
						local where: Vector3 | BasePart = if follow and follow.Parent then follow else position
						self:PlayAt(layer.Slot, where, volume, pitch, layerRng)
					end)
				end
				if radio and VOICE_SLOTS[layer.Slot] then
					task.delay(delay, function()
						self:Play2D(
							layer.Slot,
							"Radio",
							volume * 0.85,
							pitch,
							Random.new(layerRng:NextInteger(1, 2 ^ 30))
						)
					end)
				end
			elseif channel == "Radio" then
				if radio then
					task.delay(delay, function()
						self:Play2D(layer.Slot, "Radio", volume, pitch, layerRng)
					end)
				end
			elseif channel == "Self" then
				if isMe or name == "Scare" then
					task.delay(delay, function()
						self:Play2D(layer.Slot, "Self", volume, pitch, layerRng)
					end)
				end
			end
			if layer.Gap then
				time += rng:NextNumber(layer.Gap[1], layer.Gap[2])
			end
		end
	end
end

-- Ambience ------------------------------------------------------------------

function AudioController:SetAmbient(preset: string?)
	for _, sound in ambient do
		TweenService:Create(sound, TweenInfo.new(2), { Volume = 0 }):Play()
		task.delay(2.1, function()
			sound:Destroy()
		end)
	end
	ambient = {}
	local list = preset and AMBIENT_PRESETS[preset]
	if not list then
		return
	end
	for _, entry in list do
		local slot, volume = entry[1] :: string, entry[2] :: number
		local id = self:Pick(slot)
		if id then
			local sound = makeSound(id, 0, 1, "Ambient")
			sound.Looped = true
			sound.Parent = SoundService
			sound:Play()
			TweenService:Create(sound, TweenInfo.new(3), { Volume = volume }):Play()
			table.insert(ambient, sound)
		end
	end
end

-- Paranoia: after a paid scare the victim keeps hearing things that may or may not be there.

local function phantomFootsteps()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not root then
		return
	end
	local origin = root.Position
	local back = -Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
	local side = Vector3.new(-back.Z, 0, back.X) * (if math.random() < 0.5 then -1 else 1)
	local from = origin + back * 48 + side * 4
	local passBy = origin + side * 6
	local to = origin - back * 30 + side * 9

	local ghost = Instance.new("Part")
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.Transparency = 1
	ghost.Size = Vector3.new(1, 1, 1)
	ghost.Position = from
	ghost.Parent = workspace.Terrain

	local slot = if State.get("LocationName") == "Field" or (State.get("StationKey") == "Station_Field")
		then "FootstepWheat"
		else "FootstepHeavy"
	local duration = 5.5
	local started = os.clock()
	local lastStep = 0
	while os.clock() - started < duration and ghost.Parent do
		local t = (os.clock() - started) / duration
		local p = if t < 0.6 then from:Lerp(passBy, t / 0.6) else passBy:Lerp(to, (t - 0.6) / 0.4)
		ghost.Position = p
		if os.clock() - lastStep > 0.32 then
			lastStep = os.clock()
			AudioController:PlayAt(slot, ghost, 0.9, math.random(90, 110) / 100)
		end
		RunService.Heartbeat:Wait()
	end
	ghost:Destroy()
end

local function whisper()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local angle = math.random() * math.pi * 2
	local p = root.Position + Vector3.new(math.cos(angle) * 7, 1.5, math.sin(angle) * 7)
	AudioController:PlayAt("Whisper", p, 0.55, math.random(88, 108) / 100)
end

function AudioController:StartParanoia(seconds: number)
	local already = os.clock() < paranoiaUntil
	paranoiaUntil = math.max(paranoiaUntil, os.clock() + seconds)
	if already then
		return
	end
	task.spawn(function()
		task.wait(math.random(8, 15))
		while os.clock() < paranoiaUntil do
			if math.random() < 0.45 then
				phantomFootsteps()
			else
				whisper()
			end
			task.wait(math.random(10, 26))
		end
	end)
end

-- Lifecycle -------------------------------------------------------------------

function AudioController:Init()
	local master = group("Master", SoundService, Settings.Volume)
	local worldGroup = group("World", master, 1)
	group("Ambient", master, 1)
	group("Self", master, 1)
	group("Ui", master, 0.7)
	local radio = group("Radio", master, 1)

	-- Outdoor space for everything in the world
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 1.6
	reverb.Density = 0.8
	reverb.Diffusion = 0.9
	reverb.DryLevel = 0
	reverb.WetLevel = -12
	reverb.Parent = worldGroup

	-- Squad radio: telephone band, overdriven, squashed
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = -40
	eq.MidGain = 6
	eq.HighGain = -30
	eq.Priority = 3
	eq.Parent = radio
	local distortion = Instance.new("DistortionSoundEffect")
	distortion.Level = 0.55
	distortion.Priority = 2
	distortion.Parent = radio
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Threshold = -20
	compressor.Ratio = 8
	compressor.Attack = 0.005
	compressor.Release = 0.12
	compressor.GainMakeup = 6
	compressor.Priority = 1
	compressor.Parent = radio

	Settings.Changed:Connect(function(key, value)
		if key == "Volume" then
			master.Volume = value
		end
	end)
end

function AudioController:Start()
	Net.event("AudioCue").OnClientEvent:Connect(function(recipe, position, payload)
		self:PlayRecipe(recipe, position, payload)
	end)
	State.observe("AmbientPreset", function(preset)
		self:SetAmbient(preset)
	end)

	RunService.Heartbeat:Connect(function()
		if duckUntil > 0 and os.clock() > duckUntil then
			duckUntil = 0
			TweenService:Create(groups.Ambient, TweenInfo.new(2.5), { Volume = 1 }):Play()
		end
		-- Heartbeat grows with fear
		local fear = Registry.TapeController and Registry.TapeController.Fear or 0
		if fear > 0.35 then
			if not heartbeat then
				local id = self:Pick("Heartbeat")
				if id then
					local sound = makeSound(id, 0, 1, "Self")
					sound.Looped = true
					sound.Parent = SoundService
					sound:Play()
					heartbeat = sound
				end
			end
			if heartbeat then
				heartbeat.Volume = (fear - 0.35) * 1.4
				heartbeat.PlaybackSpeed = 0.9 + fear * 0.45
			end
		elseif heartbeat then
			heartbeat:Destroy()
			heartbeat = nil
		end
	end)
end

return AudioController
