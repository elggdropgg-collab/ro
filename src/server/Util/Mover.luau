-- Moves a humanoid towards a goal: straight line when nothing is in the way,
-- pathfinding otherwise. Call MoveTo every brain tick; it recomputes only when needed.

local PathfindingService = game:GetService("PathfindingService")

local Mover = {}
Mover.__index = Mover

export type Mover = typeof(setmetatable(
	{} :: {
		Humanoid: Humanoid,
		Root: BasePart,
		Path: Path,
		Waypoints: { PathWaypoint }?,
		Index: number,
		Goal: Vector3?,
		LastCompute: number,
		LastPosition: Vector3,
		StuckSince: number?,
		Params: RaycastParams,
	},
	Mover
))

function Mover.new(humanoid: Humanoid, root: BasePart, agent: { [string]: any }?): Mover
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local self = setmetatable({
		Humanoid = humanoid,
		Root = root,
		Path = PathfindingService:CreatePath(agent or {
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 6,
		}),
		Waypoints = nil,
		Index = 0,
		Goal = nil,
		LastCompute = 0,
		LastPosition = root.Position,
		StuckSince = nil,
		Params = params,
	}, Mover)
	return self
end

function Mover.SetIgnore(self: Mover, list: { Instance })
	self.Params.FilterDescendantsInstances = list
end

function Mover.Stop(self: Mover)
	self.Goal = nil
	self.Waypoints = nil
	if self.Root.Parent then
		self.Humanoid:MoveTo(self.Root.Position)
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Mover.IsDirectClear(self: Mover, goal: Vector3): boolean
	local origin = self.Root.Position
	local delta = flat(goal - origin)
	if delta.Magnitude < 1 then
		return true
	end
	if workspace:Raycast(origin, delta, self.Params) then
		return false
	end
	return workspace:Raycast(origin - Vector3.new(0, 1.2, 0), delta, self.Params) == nil
end

function Mover.Arrived(self: Mover, goal: Vector3, tolerance: number): boolean
	return flat(goal - self.Root.Position).Magnitude <= tolerance
end

function Mover.MoveTo(self: Mover, goal: Vector3)
	local now = os.clock()
	local goalMoved = self.Goal == nil or (self.Goal :: Vector3 - goal).Magnitude > 4
	self.Goal = goal

	-- Stuck detection: jump, then force a new path
	local moved = (self.Root.Position - self.LastPosition).Magnitude
	self.LastPosition = self.Root.Position
	if moved < 0.3 and not self:Arrived(goal, 3) then
		self.StuckSince = self.StuckSince or now
		if now - (self.StuckSince :: number) > 1.2 then
			self.Humanoid.Jump = true
			self.Waypoints = nil
			self.StuckSince = nil
			goalMoved = true
		end
	else
		self.StuckSince = nil
	end

	if self:IsDirectClear(goal) then
		self.Waypoints = nil
		self.Humanoid:MoveTo(goal)
		return
	end

	if goalMoved or not self.Waypoints or now - self.LastCompute > 2.5 then
		self.LastCompute = now
		local ok = pcall(function()
			self.Path:ComputeAsync(self.Root.Position, goal)
		end)
		if ok and self.Path.Status == Enum.PathStatus.Success then
			self.Waypoints = self.Path:GetWaypoints()
			self.Index = 2
		else
			self.Waypoints = nil
			self.Humanoid:MoveTo(goal)
			return
		end
	end

	local waypoints = self.Waypoints
	if not waypoints then
		return
	end
	local waypoint = waypoints[self.Index]
	while waypoint and flat(waypoint.Position - self.Root.Position).Magnitude < 3 do
		self.Index += 1
		waypoint = waypoints[self.Index]
	end
	if waypoint then
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			self.Humanoid.Jump = true
		end
		self.Humanoid:MoveTo(waypoint.Position)
	else
		self.Humanoid:MoveTo(goal)
	end
end

return Mover
