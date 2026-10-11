# One-off helper: runs find-sounds.ps1 for every sound slot and writes candidates to a file.
param([string]$Out = "$env:TEMP\fodder-sound-candidates.txt")

$queries = [ordered]@{
	ScreamAgony = @("male screams in pain", "agony scream", "screams of torture")
	ScreamPanic = @("male scream short", "terrified scream male", "panic yell")
	ScreamChoked = @("choking", "strangled scream", "gargled scream")
	Gurgle = @("gurgle", "blood gurgle", "drowning gurgle")
	DyingBreath = @("dying breath", "death gasp", "last breath")
	Whimper = @("whimper", "man crying", "sobbing")
	BoneCrunch = @("bone break", "bone crack", "bone snap")
	BoneGrind = @("bone twist", "bone grind", "joint twist")
	FleshTear = @("flesh tear", "flesh rip", "gore rip")
	WetSquelch = @("gore squish", "squelch", "guts")
	BloodSplatter = @("blood splatter", "gore splat", "liquid splat")
	BloodDrip = @("blood drip", "dripping")
	BodyDrop = @("body fall", "bodyfall", "body drop")
	ClothRip = @("cloth rip", "fabric tear")
	ScarecrowCreak = @("wood creak", "creaking wood")
	ScarecrowBreath = @("monster breathing", "creature breath", "heavy breathing")
	ScarecrowLurch = @("straw rustle", "hay rustle", "brush movement")
	HuskClick = @("creature clicks", "insect clicks", "clicking creature")
	HuskShriek = @("creature screech", "monster shriek", "creature scream")
	MonsterChew = @("chewing", "eating gore", "monster eating")
	MonsterGrowlLow = @("monster growl", "creature growl low")
	RadioKeyUp = @("radio click", "walkie talkie", "radio squelch")
	RadioStatic = @("radio static", "static burst")
	RadioVoiceContact = @("soldier yell", "military shout", "man yelling")
	RifleShot = @("assault rifle shot", "rifle gunshot", "automatic rifle")
	PistolShot = @("pistol shot", "handgun shot", "9mm")
	PistolDry = @("dry fire", "gun empty click")
	PistolReload = @("pistol reload", "magazine insert", "pistol slide")
	Heartbeat = @("heartbeat")
	Tinnitus = @("tinnitus", "ear ringing")
	ScareStinger = @("horror stinger", "jump scare", "horror hit")
	Whisper = @("whisper", "ghost whisper", "whispering")
	FootstepWheat = @("footsteps grass", "footstep tall grass", "footsteps leaves")
	FootstepHeavy = @("footsteps dirt", "running footsteps", "heavy footsteps")
	AmbientFieldWind = @("wind field", "wind ambience", "wind howling")
	AmbientFieldCrickets = @("crickets", "night insects")
	AmbientNight = @("night ambience", "night forest")
	AmbientTrainInterior = @("train interior", "inside train")
	TrainRolling = @("train passing", "train rolling", "train clack")
	TrainHorn = @("train horn", "train whistle")
	TrainBrakes = @("train brakes", "train screech")
	PortalHum = @("portal", "sci fi hum", "energy hum")
}

Set-Content -Encoding UTF8 $Out ""
foreach ($slot in $queries.Keys) {
	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("### $slot")
	$seen = @{}
	foreach ($q in $queries[$slot]) {
		try {
			$results = & "$PSScriptRoot\find-sounds.ps1" -Query $q -Pages 1
		} catch {
			$lines.Add("  ! $q failed: $_")
			continue
		}
		foreach ($r in $results) {
			if ($seen.ContainsKey($r.Id)) { continue }
			$seen[$r.Id] = $true
			$lines.Add(("  {0}  {1,3}s  {2}  [{3}]" -f $r.Id, $r.Sec, $r.Title, $r.Category))
		}
	}
	$lines | Add-Content -Encoding UTF8 $Out
}
"Wrote $Out"
