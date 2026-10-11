-- Builds and tears down stations, owns lighting and answers spatial questions
-- such as "is this point hidden in the wheat?".

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Net)
local State = require(ReplicatedStorage.Shared.State)
local Visuals = require(ReplicatedStorage.Shared.Config.Visuals)

local Server = ServerScriptService.Server
local Generators = {
	Lobby = require(Server.World.Locations.Lobby),
	Field = require(Server.World.Locations.Field),
	Finale = require(Server.World.Locations.Finale),
}

local LocationService = {}

local folder: Folder
local atmosphere: Atmosphere
local current: any = nil
local mapRemote

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function LocationService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Location"
	folder.Parent = workspace

	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.06
	sunRays.Spread = 0.8
	sunRays.Parent = Lighting

	mapRemote = Net.event("MapLayout")
end

function LocationService:Clear()
	folder:ClearAllChildren()
	workspace.Terrain:Clear()
	current = nil
end

function LocationService:ApplyLighting(presetName: string, night: number)
	local preset = Visuals.Presets[presetName]
	if not preset then
		return
	end
	local t = math.clamp(night, 0, 1)
	Lighting.ClockTime = lerp(preset.ClockStart, preset.ClockEnd, t)
	Lighting.Brightness = lerp(preset.BrightnessStart, preset.BrightnessEnd, t)
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = lerpColor(preset.OutdoorAmbientStart, preset.OutdoorAmbientEnd, t)
	Lighting.ExposureCompensation = preset.ExposureCompensation
	atmosphere.Density = lerp(preset.AtmosphereDensityStart, preset.AtmosphereDensityEnd, t)
	atmosphere.Color = lerpColor(preset.AtmosphereColorStart, preset.AtmosphereColorEnd, t)
	atmosphere.Decay = preset.AtmosphereDecay
	atmosphere.Haze = preset.Haze
	atmosphere.Glare = preset.Glare
	atmosphere.Offset = 0.1
	State.set("Night", t)
end

local function buildBoundary(radius: number)
	local ring = Instance.new("Folder")
	ring.Name = "Boundary"
	local segments = 36
	local width = 2 * math.pi * radius / segments + 4
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local wall = Instance.new("Part")
		wall.Anchored = true
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CastShadow = false
		wall.Size = Vector3.new(width, 80, 2)
		wall.CFrame =
			CFrame.lookAt(Vector3.new(math.cos(angle) * radius, 40, math.sin(angle) * radius), Vector3.new(0, 40, 0))
		wall.Parent = ring
	end
	ring.Parent = folder
end

function LocationService:Generate(name: string, seed: number, extra: { [string]: any }?): any
	self:Clear()
	local generator = Generators[name]
	assert(generator, "Unknown location " .. name)

	local ctx = {
		Folder = folder,
		Random = Random.new(seed),
		Seed = seed,
	}
	if extra then
		for k, v in extra do
			ctx[k] = v
		end
	end

	local layout = generator.generate(ctx)
	-- Railway bed through every station
	workspace.Terrain:FillBlock(CFrame.new(0, -2, 0), Vector3.new(1400, 4, 16), Enum.Material.Slate)
	buildBoundary(layout.Radius + 25)

	current = layout
	State.set("Seed", seed)
	self:ApplyLighting(name, 0)
	self:BroadcastLayout()
	return layout
end

function LocationService:GetLayout(): any
	return current
end

function LocationService:GetFolder(): Folder
	return folder
end

-- Compact description of the station for the tactical map.
function LocationService:SerializeForMap(): any
	if not current then
		return nil
	end
	local wheat = table.create(#current.WheatCells * 2)
	for _, cell in current.WheatCells do
		table.insert(wheat, cell.X)
		table.insert(wheat, cell.Z)
	end
	local pois = {}
	for _, poi in current.POIs do
		table.insert(pois, { poi.Kind, poi.Position.X, poi.Position.Z, poi.Radius })
	end
	local paths = {}
	for _, segment in current.Paths do
		table.insert(paths, { segment[1].X, segment[1].Z, segment[2].X, segment[2].Z })
	end
	local reanimators = {}
	for _, cf in current.Reanimators do
		table.insert(reanimators, { cf.Position.X, cf.Position.Z })
	end
	return {
		Name = current.Name,
		Radius = current.Radius,
		CellSize = current.CellSize,
		Wheat = wheat,
		POIs = pois,
		Paths = paths,
		Reanimators = reanimators,
	}
end

function LocationService:BroadcastLayout()
	mapRemote:FireAllClients(self:SerializeForMap())
end

function LocationService:SendLayout(player: Player)
	mapRemote:FireClient(player, self:SerializeForMap())
end

function LocationService:IsConcealed(position: Vector3): boolean
	if not current or position.Y > 7 then
		return false
	end
	local size = current.CellSize
	local key = math.round(position.X / size) .. "," .. math.round(position.Z / size)
	return current.Concealed[key] == true
end

function LocationService:InBounds(position: Vector3): boolean
	if not current then
		return true
	end
	return Vector2.new(position.X, position.Z).Magnitude < current.Radius
end

-- A random point on open ground near `center`, inside the station.
function LocationService:RandomPointNear(center: Vector3, radius: number, rng: Random?): Vector3
	local r = rng or Random.new()
	for _ = 1, 12 do
		local angle = r:NextNumber(0, math.pi * 2)
		local dist = r:NextNumber(radius * 0.3, radius)
		local p = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		if self:InBounds(p) then
			return Vector3.new(p.X, center.Y, p.Z)
		end
	end
	return center
end

return LocationService
