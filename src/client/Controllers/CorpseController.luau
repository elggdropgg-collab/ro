-- What the player sees of the remains:
--   * a tape-glitch censor (shifting dark and red blocks) through which the ribs, the spine
--     and the blood can still be made out;
--   * the camera refusing to focus on a body you look at (depth of field);
--   * on a fresh body (first minute): the open chest pulsing and limbs twitching.
-- The censor level comes from the server and can only be raised by the player.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Visuals = require(ReplicatedStorage.Shared.Config.Visuals)
local State = require(ReplicatedStorage.Shared.State)
local Settings = require(script.Parent.Parent.Settings)
local Theme = require(script.Parent.Parent.UI.Theme)

local CorpseController = {}

type Entry = {
	Model: Model,
	Gui: BillboardGui?,
	Blocks: { Frame },
	Pulse: { { Part: BasePart, Size: Vector3 } },
	Twitch: { { Part: BasePart, CFrame: CFrame, NextAt: number, Until: number } },
	Level: number,
}

local entries: { [Model]: Entry } = {}
local dof: DepthOfFieldEffect
local VIEW_DISTANCE = 160

local function censorLevel(): number
	local base = State.get("CensorLevel") or GameConfig.Censor.Level
	return math.clamp(base + Settings.ExtraCensor, GameConfig.Censor.MinLevel, GameConfig.Censor.MaxLevel)
end

local function buildGui(entry: Entry)
	if entry.Gui then
		entry.Gui:Destroy()
	end
	entry.Blocks = {}
	local level = censorLevel()
	entry.Level = level
	local spec = Visuals.Censor[level]
	local root = entry.Model.PrimaryPart
	if not root then
		return
	end
	local gui = Theme.new("BillboardGui", {
		Name = "Censor",
		Adornee = root,
		Size = UDim2.new(7.5, 0, 4.5, 0),
		StudsOffsetWorldSpace = Vector3.new(0, 0.9, 0),
		AlwaysOnTop = false,
		LightInfluence = 0.4,
		MaxDistance = VIEW_DISTANCE,
		Parent = root,
	})
	local columns = spec.Blocks
	local rows = math.max(3, math.floor(columns * 0.6))
	for x = 1, columns do
		for y = 1, rows do
			table.insert(
				entry.Blocks,
				Theme.new("Frame", {
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1 / columns + 0.01, 1 / rows + 0.01),
					Position = UDim2.fromScale((x - 1) / columns, (y - 1) / rows),
					BackgroundColor3 = Color3.new(0, 0, 0),
					BackgroundTransparency = spec.BlockTransparency,
					Parent = gui,
				})
			)
		end
	end
	entry.Gui = gui
end

local function track(model: Instance)
	if not model:IsA("Model") or entries[model] then
		return
	end
	local entry: Entry = { Model = model, Gui = nil, Blocks = {}, Pulse = {}, Twitch = {}, Level = 0 }
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Pulse" then
				table.insert(entry.Pulse, { Part = d, Size = d.Size })
			elseif d.Name == "Twitch" then
				table.insert(
					entry.Twitch,
					{ Part = d, CFrame = d.CFrame, NextAt = os.clock() + math.random(), Until = 0 }
				)
			end
		end
	end
	entries[model] = entry
	buildGui(entry)
end

local function untrack(model: Instance)
	local entry = entries[model :: Model]
	if entry then
		if entry.Gui then
			entry.Gui:Destroy()
		end
		entries[model :: Model] = nil
	end
end

function CorpseController:Init()
	dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "CorpseFocus"
	dof.FarIntensity = 0
	dof.NearIntensity = 0
	dof.FocusDistance = 0
	dof.InFocusRadius = 50
	dof.Parent = Lighting
end

function CorpseController:Start()
	for _, model in CollectionService:GetTagged("Corpse") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("Corpse"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Corpse"):Connect(untrack)

	local function rebuildAll()
		for _, entry in entries do
			buildGui(entry)
		end
	end
	State.changed("CensorLevel"):Connect(rebuildAll)
	Settings.Changed:Connect(function(key)
		if key == "ExtraCensor" then
			rebuildAll()
		end
	end)

	local lastShuffle = 0
	local focusWeight = 0
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = os.clock()
		local serverNow = State.now()
		local shuffle = now - lastShuffle > 1 / 12
		if shuffle then
			lastShuffle = now
		end
		local camPos = camera.CFrame.Position
		local look = camera.CFrame.LookVector
		local bestFocus, bestDist = 0, 0

		for model, entry in entries do
			local root = model.PrimaryPart
			if not model.Parent or not root then
				untrack(model)
				continue
			end
			local toBody = root.Position - camPos
			local dist = toBody.Magnitude
			if dist > VIEW_DISTANCE then
				continue
			end
			local freshUntil = model:GetAttribute("FreshUntil") or 0
			local freshness = math.clamp((freshUntil - serverNow) / GameConfig.Corpses.FreshSeconds, 0, 1)

			-- Censor blocks shift like a damaged tape
			if shuffle then
				local spec = Visuals.Censor[entry.Level]
				for _, block in entry.Blocks do
					local red = math.random() < 0.3
					local v = math.random(4, 22) / 255
					block.BackgroundColor3 = if red then Color3.new(v * 3.2, v * 0.3, v * 0.3) else Color3.new(v, v, v)
					block.BackgroundTransparency =
						math.clamp(spec.BlockTransparency + math.random() * 0.22 - freshness * 0.05, 0, 1)
				end
			end

			-- Fresh: the chest pulses, limbs twitch
			if freshness > 0 then
				local beat = math.max(0, math.sin(now * 5.2)) ^ 3 + math.max(0, math.sin(now * 5.2 - 0.9)) ^ 6 * 0.6
				for _, p in entry.Pulse do
					p.Part.Size = p.Size * (1 + beat * 0.14 * freshness)
				end
				for _, tw in entry.Twitch do
					if now > tw.NextAt then
						tw.Until = now + math.random(4, 12) / 100
						tw.NextAt = now + math.random(4, 25) / 10 / math.max(freshness, 0.15)
					end
					if now < tw.Until then
						local a = 0.18 * freshness
						tw.Part.CFrame = tw.CFrame
							* CFrame.Angles(
								math.random() * a - a / 2,
								math.random() * a - a / 2,
								math.random() * a - a / 2
							)
					else
						tw.Part.CFrame = tw.CFrame
					end
				end
			end

			-- Is the player looking right at it?
			if dist < 50 then
				local alignment = look:Dot(toBody.Unit)
				if alignment > 0.9 then
					local focus = (alignment - 0.9) / 0.1
					if focus > bestFocus then
						bestFocus, bestDist = focus, dist
					end
				end
			end
		end

		focusWeight += (bestFocus - focusWeight) * math.min(1, dt * 4)
		local level = censorLevel()
		dof.FarIntensity = Visuals.Censor[level].DepthOfField * focusWeight
		if bestFocus > 0 then
			dof.InFocusRadius = math.max(2, bestDist - 3)
		end
	end)
end

return CorpseController
