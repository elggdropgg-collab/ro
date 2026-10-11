-- Server-side locomotion animations for NPC humanoids (idle / walk / run by speed).
-- An optional Hold animation plays on top of everything, e.g. to keep a weapon raised.

local NpcAnimator = {}

function NpcAnimator.attach(
	humanoid: Humanoid,
	ids: { Idle: string, Walk: string, Run: string, Hold: string? },
	runThreshold: number
)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid

	local tracks: { [string]: AnimationTrack } = {}
	for name, id in ids :: any do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = true
			if name == "Hold" then
				track.Priority = Enum.AnimationPriority.Action
				track:Play(0)
			else
				track.Priority = Enum.AnimationPriority.Core
				tracks[name] = track
			end
		end
	end

	local current: AnimationTrack? = nil
	local function play(name: string, speed: number)
		local track = tracks[name]
		if not track then
			return
		end
		if current ~= track then
			if current then
				current:Stop(0.25)
			end
			track:Play(0.25)
			current = track
		end
		track:AdjustSpeed(speed)
	end

	play("Idle", 1)
	humanoid.Running:Connect(function(speed)
		if speed < 0.5 then
			play("Idle", 1)
		elseif speed < runThreshold then
			play("Walk", speed / 12)
		else
			play("Run", speed / 18)
		end
	end)
end

return NpcAnimator
