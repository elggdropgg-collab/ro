-- Constraint-based placement helpers shared by all station generators.

local Placement = {}

export type Spec = {
	Kind: string,
	Radius: number,
	MinDist: number,
	MaxDist: number,
	Count: number,
}

export type Placed = {
	Kind: string,
	Position: Vector3,
	Radius: number,
	CFrame: CFrame,
}

export type ScatterOptions = {
	FieldRadius: number,
	TrackClearance: number,
	Gap: number,
	Existing: { Placed }?,
	Attempts: number?,
}

function Placement.flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function Placement.segmentDistance(p: Vector3, a: Vector3, b: Vector3): number
	local ax, az = b.X - a.X, b.Z - a.Z
	local lengthSq = ax * ax + az * az
	local t = 0
	if lengthSq > 0 then
		t = math.clamp(((p.X - a.X) * ax + (p.Z - a.Z) * az) / lengthSq, 0, 1)
	end
	local cx, cz = a.X + ax * t, a.Z + az * t
	local dx, dz = p.X - cx, p.Z - cz
	return math.sqrt(dx * dx + dz * dz)
end

-- Places points of interest so that they never overlap, keep away from the railway
-- and stay inside the playable radius. Each one faces the station with some jitter.
function Placement.scatter(rng: Random, specs: { Spec }, options: ScatterOptions): { Placed }
	local placed: { Placed } = {}
	local all: { Placed } = options.Existing and table.clone(options.Existing) or {}
	local attempts = options.Attempts or 400

	for _, spec in specs do
		for _ = 1, spec.Count do
			for _ = 1, attempts do
				local angle = rng:NextNumber(0, math.pi * 2)
				local dist = rng:NextNumber(spec.MinDist, spec.MaxDist)
				local pos = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

				local ok = math.abs(pos.Z) > spec.Radius + options.TrackClearance
					and dist + spec.Radius < options.FieldRadius
				if ok then
					for _, other in all do
						if Placement.flatDistance(pos, other.Position) < spec.Radius + other.Radius + options.Gap then
							ok = false
							break
						end
					end
				end

				if ok then
					local facing = CFrame.lookAt(pos, Vector3.new(0, 0, pos.Z * 0.15))
					local yaw = rng:NextNumber(-0.4, 0.4)
					local entry: Placed = {
						Kind = spec.Kind,
						Position = pos,
						Radius = spec.Radius,
						CFrame = facing * CFrame.Angles(0, yaw, 0),
					}
					table.insert(placed, entry)
					table.insert(all, entry)
					break
				end
			end
		end
	end

	return placed
end

-- Paints a path into the terrain and returns its segments.
function Placement.carvePath(
	rng: Random,
	from: Vector3,
	to: Vector3,
	width: number,
	material: Enum.Material
): { { Vector3 } }
	local direction = to - from
	local perpendicular = Vector3.new(-direction.Z, 0, direction.X).Unit
	local mid = from:Lerp(to, rng:NextNumber(0.4, 0.6)) + perpendicular * rng:NextNumber(-35, 35)
	local segments = { { from, mid }, { mid, to } }
	for _, segment in segments do
		local a, b = segment[1], segment[2]
		local length = Placement.flatDistance(a, b)
		if length > 0.5 then
			local center = (a + b) / 2
			local cframe = CFrame.lookAt(Vector3.new(center.X, -2, center.Z), Vector3.new(b.X, -2, b.Z))
			workspace.Terrain:FillBlock(cframe, Vector3.new(width, 4, length + width), material)
		end
	end
	return segments
end

return Placement
