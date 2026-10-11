-- Procedural animation and voices of monsters, entirely on the client for smooth motion.
-- The server only sets the "State" attribute; joints are animated by offsetting Motor6D.C0.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Registry = require(script.Parent.Parent.Registry)

local MonsterController = {}

type Entry = {
	Model: Model,
	Kind: string,
	Motors: { [string]: { Motor: Motor6D, Base: CFrame } },
	Phase: number,
	LastState: string?,
	Voice: Sound?,
	Seed: number,
}

local entries: { [Model]: Entry } = {}

local function track(model: Instance)
	if not model:IsA("Model") or entries[model] then
		return
	end
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = { Motor = d, Base = d.C0 }
		end
	end
	local entry: Entry = {
		Model = model,
		Kind = model:GetAttribute("Kind") or model.Name,
		Motors = motors,
		Phase = math.random() * 10,
		LastState = nil,
		Voice = nil,
		Seed = math.random() * 100,
	}
	entries[model] = entry

	-- Idle voice loop
	local root = model.PrimaryPart
	if root then
		local slot = if entry.Kind == "Scarecrow" then "ScarecrowBreath" else "HuskClick"
		local sound = Registry.AudioController:Loop(
			slot,
			root,
			if entry.Kind == "Scarecrow" then 0.5 else 0.7,
			math.random(90, 110) / 100
		)
		if sound then
			sound.RollOffMaxDistance = 90
			entry.Voice = sound
		end
	end
end

local function untrack(model: Instance)
	local entry = entries[model :: Model]
	if entry then
		if entry.Voice then
			entry.Voice:Destroy()
		end
		entries[model :: Model] = nil
	end
end

local function set(entry: Entry, name: string, offset: CFrame)
	local m = entry.Motors[name]
	if m and m.Motor.Parent then
		m.Motor.C0 = m.Base * offset
	end
end

local function onStateChanged(entry: Entry, state: string)
	local root = entry.Model.PrimaryPart
	if not root then
		return
	end
	if state == "Hunt" then
		if entry.Kind == "Husk" then
			Registry.AudioController:PlayAt("HuskShriek", root, 1, math.random(90, 115) / 100)
		else
			Registry.AudioController:PlayAt("ScarecrowLurch", root, 1)
		end
	elseif state == "Stunned" and entry.Kind == "Scarecrow" then
		Registry.AudioController:PlayAt("ScarecrowCreak", root, 1, 0.8)
	end
end

local function animateScarecrow(entry: Entry, state: string, t: number)
	local s = entry.Seed
	if state == "Frozen" then
		-- Perfectly still, except the head that tilts very slowly
		set(entry, "Neck", CFrame.Angles(0, 0, 0.22 + math.sin(t * 0.25 + s) * 0.08))
		set(entry, "LeftHand", CFrame.new())
		set(entry, "RightHand", CFrame.new())
	elseif state == "Hunt" then
		local jitter = math.noise(t * 9, s) * 0.5
		set(entry, "Neck", CFrame.Angles(jitter * 0.4, jitter, math.noise(t * 7, s, 1) * 0.6))
		set(entry, "LeftHand", CFrame.Angles(math.noise(t * 12, s, 2) * 0.8, 0, math.noise(t * 10, s, 3) * 0.6))
		set(entry, "RightHand", CFrame.Angles(math.noise(t * 12, s, 4) * 0.8, 0, math.noise(t * 10, s, 5) * 0.6))
	elseif state == "Feeding" then
		local bite = math.abs(math.sin(t * 7)) * 0.5
		set(entry, "Neck", CFrame.Angles(bite + 0.3, math.noise(t * 4, s) * 0.4, math.noise(t * 5, s, 6) * 0.3))
		set(entry, "LeftHand", CFrame.Angles(0.6 + math.sin(t * 9) * 0.3, 0, 0))
		set(entry, "RightHand", CFrame.Angles(0.6 + math.sin(t * 9 + 1) * 0.3, 0, 0))
	elseif state == "Stunned" then
		set(entry, "Neck", CFrame.Angles(0.7, 0, 0.4))
		set(entry, "LeftHand", CFrame.Angles(0, 0, 0.8))
		set(entry, "RightHand", CFrame.Angles(0, 0, -0.8))
	else
		set(entry, "Neck", CFrame.Angles(math.sin(t * 0.6 + s) * 0.08, math.sin(t * 0.4 + s) * 0.35, 0.1))
		set(entry, "LeftHand", CFrame.Angles(math.sin(t * 1.3) * 0.1, 0, 0))
		set(entry, "RightHand", CFrame.Angles(math.sin(t * 1.1 + 2) * 0.1, 0, 0))
	end
end

local function animateHusk(entry: Entry, state: string, t: number, dt: number)
	local root = entry.Model.PrimaryPart
	local speed = if root
		then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		else 0
	entry.Phase += dt * (2 + speed * 0.9)
	local stride = math.clamp(speed / 12, 0, 1) * 0.55
	local p = entry.Phase
	set(entry, "LegFL", CFrame.Angles(math.sin(p) * stride, 0, math.cos(p) * stride * 0.3))
	set(entry, "LegBR", CFrame.Angles(math.sin(p) * stride, 0, -math.cos(p) * stride * 0.3))
	set(entry, "LegFR", CFrame.Angles(math.sin(p + math.pi) * stride, 0, math.cos(p + math.pi) * stride * 0.3))
	set(entry, "LegBL", CFrame.Angles(math.sin(p + math.pi) * stride, 0, -math.cos(p + math.pi) * stride * 0.3))

	local s = entry.Seed
	if state == "Feeding" then
		set(entry, "Jaw", CFrame.Angles(math.abs(math.sin(t * 9)) * 0.7, 0, 0))
		set(
			entry,
			"Neck",
			CFrame.Angles(
				0.35 + math.noise(t * 6, s) * 0.5,
				math.noise(t * 5, s, 1) * 0.7,
				math.noise(t * 8, s, 2) * 0.5
			)
		)
	elseif state == "Hunt" then
		set(entry, "Jaw", CFrame.Angles(0.45 + math.sin(t * 25) * 0.08, 0, 0))
		set(entry, "Neck", CFrame.Angles(math.noise(t * 4, s) * 0.2, math.noise(t * 3, s, 3) * 0.3, 0))
	elseif state == "Investigate" then
		-- Blind: sweeping its head, listening
		set(entry, "Jaw", CFrame.Angles(0.12, 0, 0))
		set(entry, "Neck", CFrame.Angles(-0.15, math.sin(t * 1.8 + s) * 0.8, math.sin(t * 1.1) * 0.3))
	elseif state == "Stunned" then
		set(entry, "Jaw", CFrame.Angles(0.5, 0, 0))
		set(entry, "Neck", CFrame.Angles(0.6, 0, 0.5))
	else
		set(entry, "Jaw", CFrame.Angles(0.06 + math.max(0, math.sin(t * 0.7 + s)) * 0.12, 0, 0))
		set(entry, "Neck", CFrame.Angles(0, math.sin(t * 0.5 + s) * 0.4, 0))
	end
end

function MonsterController:Start()
	for _, model in CollectionService:GetTagged("Monster") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("Monster"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Monster"):Connect(untrack)

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		for model, entry in entries do
			if not model.Parent then
				untrack(model)
				continue
			end
			local state = model:GetAttribute("State") or "Roam"
			if state ~= entry.LastState then
				entry.LastState = state
				onStateChanged(entry, state)
			end
			if entry.Kind == "Scarecrow" then
				animateScarecrow(entry, state, t)
			else
				animateHusk(entry, state, t, dt)
			end
		end
	end)
end

return MonsterController
