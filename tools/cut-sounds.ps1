# Cuts the raw recordings in "Звуки" into game-ready one-shots: assets/sounds/<Slot>/<name>.ogg
#
#   .\tools\cut-sounds.ps1
#
# Every clip is mono, peak-normalised to -1 dBFS, faded at the edges and encoded as Ogg Vorbis.
# The folder name is the slot in src/shared/Config/Sounds.luau; upload-sounds.ps1 relies on it.
# Cut points were picked from spectrograms and the RMS envelope of each source.
param([string]$OutDir = "$PSScriptRoot\..\assets\sounds")

$ErrorActionPreference = "Stop"
$src = Join-Path $PSScriptRoot "..\Звуки"
$blood = Join-Path $src "Звуки_крови.mp3"
$example = Join-Path $src "пример.mp3"
$scream1 = Join-Path $src "anguished-scream-of-terror.mp3"
$scream2 = Join-Path $src "man-screaming-screaming-man.mp3"

# Slot, file name, source, start, end, fade-out seconds, extra filter
$clips = @(
	@("BloodSplatter", "splatter_1", $blood, 0.33, 2.4, 0.6, ""),
	@("BloodSplatter", "splatter_2", $blood, 5.05, 7.2, 0.6, ""),
	@("FleshTear", "tear_1", $blood, 26.9, 28.3, 0.35, ""),
	@("FleshTear", "tear_2", $blood, 42.65, 44.8, 0.4, ""),
	@("FleshTear", "tear_3", $blood, 86.65, 88.4, 0.4, ""),
	@("WetSquelch", "squelch_1", $blood, 30.1, 31.5, 0.3, ""),
	@("WetSquelch", "squelch_2", $blood, 74.95, 76.1, 0.3, ""),
	@("WetSquelch", "squelch_3", $blood, 79.5, 80.9, 0.3, ""),
	@("WetSquelch", "squelch_4", $blood, 83.45, 84.6, 0.3, ""),
	@("WetSquelch", "squelch_5", $blood, 94.7, 95.8, 0.3, ""),
	@("MonsterChew", "chew_1", $blood, 72.1, 73.5, 0.3, ""),
	@("MonsterChew", "chew_2", $blood, 89.8, 91.2, 0.3, ""),
	@("MonsterChew", "chew_3", $blood, 91.6, 93.0, 0.3, ""),
	@("MonsterChew", "chew_4", $blood, 61.0, 62.4, 0.3, ""),
	@("ScreamAgony", "agony_1", $scream1, 1.22, 3.95, 0.45, ""),
	@("ScreamAgony", "agony_2", $scream2, 0.28, 3.85, 0.45, ""),
	@("ScreamPanic", "panic_1", $scream1, 1.22, 2.05, 0.15, ""),
	@("ScreamPanic", "panic_2", $scream2, 0.28, 1.15, 0.15, ""),
	# Cut off mid-breath: the abrupt end is the effect
	@("ScreamChoked", "choked_1", $scream1, 1.22, 2.75, 0.04, ""),
	@("ScreamChoked", "choked_2", $scream2, 0.28, 2.3, 0.04, ""),
	# The reference "squad under attack" montage: burst, scream, hit, scream, crunch
	@("RadioSquadAttacked", "attacked_1", $example, 0.0, 5.9, 0.8, "")
)

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
	throw "ffmpeg not found. Install it: winget install Gyan.FFmpeg"
}

foreach ($c in $clips) {
	$slot, $name, $file, $from, $to, $fadeOut, $extra = $c
	$dir = Join-Path $OutDir $slot
	New-Item -ItemType Directory -Force $dir | Out-Null
	$out = Join-Path $dir "$name.ogg"
	$length = $to - $from
	$fadeStart = [Math]::Max(0, $length - $fadeOut)
	$base = "aformat=channel_layouts=mono,highpass=f=35,afade=t=in:d=0.006,afade=t=out:st=${fadeStart}:d=${fadeOut}"
	if ($extra) { $base += ",$extra" }

	# Pass 1: measure the peak; pass 2: bring it to -1 dBFS
	$probe = & ffmpeg -hide_banner -nostats -ss $from -to $to -i $file -af "$base,volumedetect" -f null - 2>&1
	$peak = ($probe | Select-String "max_volume: (-?[\d\.]+) dB").Matches[0].Groups[1].Value
	$gain = -1 - [double]$peak
	& ffmpeg -v error -y -ss $from -to $to -i $file -af "$base,volume=${gain}dB" -ar 44100 -c:a libvorbis -q:a 6 $out
	"{0,-20} {1,-12} {2,5:N2}s  gain {3,6:N1} dB" -f $slot, $name, $length, $gain
}

# Synthesised: no library has a convincing version of these, and they are trivial to generate.
# Slot, file name, lavfi source, filter
$synth = @(
	@("Tinnitus", "tinnitus_1", "sine=f=6300:d=5", "tremolo=f=0.7:d=0.15,afade=t=in:d=1.2,afade=t=out:st=3:d=2,volume=-8dB"),
	@("Tinnitus", "tinnitus_2", "sine=f=4700:d=6", "tremolo=f=0.45:d=0.2,afade=t=in:d=1.6,afade=t=out:st=3.5:d=2.5,volume=-8dB"),
	# Release of the push-to-talk: short band-limited squelch tail
	@("RadioKeyDown", "squelch_1", "anoisesrc=d=0.24:c=white:a=0.6", "bandpass=f=1900:width_type=h:w=1600,afade=t=out:st=0.12:d=0.12"),
	@("RadioKeyDown", "squelch_2", "anoisesrc=d=0.32:c=pink:a=0.7", "bandpass=f=1500:width_type=h:w=1300,afade=t=out:st=0.18:d=0.14")
)

foreach ($s in $synth) {
	$slot, $name, $source, $filter = $s
	$dir = Join-Path $OutDir $slot
	New-Item -ItemType Directory -Force $dir | Out-Null
	& ffmpeg -v error -y -f lavfi -i $source -af "aformat=channel_layouts=mono,$filter" -ar 44100 -c:a libvorbis -q:a 6 (Join-Path $dir "$name.ogg")
	"{0,-20} {1,-12} synthesised" -f $slot, $name
}
