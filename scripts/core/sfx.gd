extends Node
## Autoload "Sfx": shared sound player for every minigame.
##
## Usage:  Sfx.play(&"hammer_hit")            random pitch variation
##         Sfx.play(&"hammer_hit", 0.8)       base pitch 0.8, still varied
##         Sfx.play(&"tap", 1.0, -6.0, false) quieter, no variation
##
## Pitch variation uses Godot's built-in AudioStreamRandomizer (random_pitch),
## which also picks randomly between variant files when a sound lists several.
##
## To replace a placeholder: drop new files in res://assets/sfx/ and update
## SOUNDS below. List several files for one name to get random variants.

const SOUNDS := {
	# saw_push / saw_pull: one-shot per saw stroke. saw_grind: looping (LoopSfx,
	# fetched with Sfx.stream()) while the saw is dragged slowly.
	&"saw_grind": ["res://assets/sfx/saw_grind.wav"],
	&"saw_push": ["res://assets/sfx/fix/saw_fwd_1.wav", "res://assets/sfx/fix/saw_fwd_2.wav"],
	&"saw_pull": ["res://assets/sfx/fix/saw_bk_1.wav", "res://assets/sfx/fix/saw_bk_2.wav"],
	&"cut_done": ["res://assets/sfx/cut_done.wav"],
	&"pickup": ["res://assets/sfx/pickup.wav"],
	&"drop": ["res://assets/sfx/drop.wav"],
	&"place": ["res://assets/sfx/place.wav"],
	&"hammer_hit": ["res://assets/sfx/hammer_hit.wav"],
	&"nail_done": ["res://assets/sfx/nail_done.wav"],
	&"charge": ["res://assets/sfx/charge.wav"],
	&"tap": ["res://assets/sfx/tap.wav"],
	&"step": ["res://assets/sfx/step.wav"],
	&"whoosh": ["res://assets/sfx/whoosh.wav"],
	&"area_done": ["res://assets/sfx/area_done.wav"],
	&"building_done": ["res://assets/sfx/building_done.wav"],
	&"sand": ["res://assets/sfx/sand.wav"],
	&"paint": ["res://assets/sfx/paint.wav"],
}

## Pitch spread for varied sounds. 1.12 = up to ~12% higher or lower.
const RANDOM_PITCH := 1.12
const POOL_SIZE := 12

var _varied: Dictionary = {} # name -> AudioStreamRandomizer (random pitch)
var _plain: Dictionary = {} # name -> AudioStreamRandomizer (no random pitch)
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for sound_name in SOUNDS:
		_varied[sound_name] = _make(SOUNDS[sound_name], RANDOM_PITCH)
		_plain[sound_name] = _make(SOUNDS[sound_name], 1.0)


## Plays a sound by name. Returns the player (e.g. to stop a long sound).
func play(sound_name: StringName, pitch := 1.0, volume_db := 0.0, vary := true) -> AudioStreamPlayer:
	var table := _varied if vary else _plain
	if not table.has(sound_name):
		push_warning("Sfx: unknown sound '%s'" % sound_name)
		return null
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = table[sound_name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
	return p


## Raw stream of a sound's first file, for dedicated players such as LoopSfx.
func stream(sound_name: StringName) -> AudioStream:
	if not SOUNDS.has(sound_name):
		push_warning("Sfx: unknown sound '%s'" % sound_name)
		return null
	return load(SOUNDS[sound_name][0])


func _make(paths: Array, random_pitch: float) -> AudioStreamRandomizer:
	var r := AudioStreamRandomizer.new()
	r.random_pitch = random_pitch
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS if paths.size() > 2 else AudioStreamRandomizer.PLAYBACK_RANDOM
	for path in paths:
		var s: AudioStream = load(path)
		if s:
			r.add_stream(-1, s)
		else:
			push_warning("Sfx: missing file %s" % path)
	return r
