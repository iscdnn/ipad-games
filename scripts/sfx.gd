class_name Sfx
extends RefCounted
## Placeholder sound effects synthesised in code (no audio files needed).
## Replace with real .wav/.ogg files by loading them instead of calling these.

const RATE := 22050

static var _cache: Dictionary = {}


## Scissor "snip snip" plus a little rising blip.
static func shear() -> AudioStreamWAV:
	if not _cache.has("shear"):
		_cache["shear"] = _build(_shear_samples())
	return _cache["shear"]


## Short rising arpeggio for the end of a round.
static func finish() -> AudioStreamWAV:
	if not _cache.has("finish"):
		_cache["finish"] = _build(_finish_samples())
	return _cache["finish"]


static func _shear_samples() -> PackedFloat32Array:
	var n := int(RATE * 0.28)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var prev := 0.0
	var snip_starts := [0.0, 0.08]
	for i in n:
		var t := float(i) / float(RATE)
		var noise := rng.randf_range(-1.0, 1.0)
		var hp := noise - prev # crude high-pass => metallic hiss
		prev = noise
		var v := 0.0
		for s in snip_starts:
			var dt: float = t - float(s)
			if dt >= 0.0 and dt < 0.06:
				var env := exp(-dt * 90.0)
				v += (hp * 0.35 + sin(TAU * 2400.0 * dt) * 0.25) * env
		var bt := t - 0.15
		if bt >= 0.0 and bt < 0.12:
			var benv := 1.0 - bt / 0.12
			v += sin(TAU * (500.0 * bt + 2000.0 * bt * bt)) * 0.35 * benv
		out[i] = clampf(v, -1.0, 1.0)
	return out


static func _finish_samples() -> PackedFloat32Array:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var note_len := 0.11
	var n := int(RATE * (note_len * notes.size() + 0.35))
	var out := PackedFloat32Array()
	out.resize(n)
	var last := notes.size() - 1
	for i in n:
		var t := float(i) / float(RATE)
		var idx := mini(int(t / note_len), last)
		var local := t - float(idx) * note_len
		var freq: float = notes[idx]
		var env := exp(-local * (4.0 if idx == last else 9.0))
		var v := (sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.0 * t) * 0.2) * env * 0.6
		out[i] = clampf(v, -1.0, 1.0)
	return out


static func _build(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
