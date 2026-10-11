-- Per-kind brains. Each step runs a few times per second on the monster's own thread.

local ServerScriptService = game:GetService("ServerScriptService")

local Registry = require(ServerScriptService.Server.Registry)

local Behaviours = {}

-- The Scarecrow never moves while someone is looking at it. Unseen, it lurches forward
-- at terrifying speed. It prefers soldiers. Stunned by enough gunfire, never killed
-- (except at the terminus). If it loses everyone, it relocates out of sight.
Behaviours.Scarecrow = function(self: any)
	local observed = Registry.MonsterService:IsObserved(self)
	self.Model:SetAttribute("Observed", observed)
	local def = self.Def

	if observed then
		self.Mover:Stop()
		if self.Immortal then
			self.Humanoid.WalkSpeed = 0
			self:SetState("Frozen")
			return
		end
		-- At the terminus it can be killed, and it no longer waits politely
		self.Humanoid.WalkSpeed = def.WalkSpeed * 0.5
	end

	local target = self:FindTarget(def.DetectRange, def.ConcealedDetectRange, false, true)
	if not target and self.Target and os.clock() - self.LastHunt < 4 then
		target = self.Target -- keep chasing briefly after losing sight
	end
	if target then
		self:Hunt(target, if observed then def.WalkSpeed * 0.5 else def.HuntSpeed)
		return
	end
	self.Target = nil

	if self.Investigate and os.clock() < self.InvestigateUntil then
		self.Humanoid.WalkSpeed = def.WalkSpeed * 2
		self.Mover:MoveTo(self:SafeGoal(self.Investigate))
		self:SetState("Investigate")
		if self.Mover:Arrived(self.Investigate, 6) then
			self.Investigate = nil
		end
		return
	end

	-- Bored and unseen for a while: reappear somewhere behind the nearest victim
	if not observed and os.clock() - self.LastHunt > 30 then
		local victims = Registry.CombatService:GetTargets()
		if #victims > 0 then
			local victim = victims[math.random(1, #victims)]
			local behind = victim.Root.CFrame * CFrame.new(math.random(-30, 30), 0, math.random(55, 80))
			local p = behind.Position
			if
				Registry.LocationService:InBounds(p)
				and not Registry.TrainService:IsInSafeZone(p)
				and not Registry.MonsterService:IsPointObserved(p)
			then
				self.Model:PivotTo(CFrame.new(Vector3.new(p.X, 3, p.Z)))
				self.Home = Vector3.new(p.X, 0, p.Z)
				self.LastHunt = os.clock()
			end
		end
	end
	self:Roam(70)
end

-- Husks are blind. They hear sprinting, gunfire and screams, and are easy to slip past
-- if you walk slowly through the wheat.
Behaviours.Husk = function(self: any)
	local def = self.Def
	local target = self:FindTarget(def.DetectRange, def.ConcealedDetectRange, true, false)
	if target then
		self:Hunt(target, def.HuntSpeed)
		return
	end
	self.Target = nil
	if self.Investigate and os.clock() < self.InvestigateUntil then
		self.Humanoid.WalkSpeed = def.HuntSpeed * 0.75
		self.Mover:MoveTo(self:SafeGoal(self.Investigate))
		self:SetState("Investigate")
		if self.Mover:Arrived(self.Investigate, 5) then
			self.Investigate = nil
		end
		return
	end
	self:Roam(45)
end

return Behaviours
