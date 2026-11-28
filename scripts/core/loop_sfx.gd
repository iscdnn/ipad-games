class_name LoopSfx
extends AudioStreamPlayer
## Looping sound driven by continuous input (e.g. a saw stroke).
##
## start(pitch)       play from the top (attack), then the sample's loop body.
## keep_alive(pitch)  call while the input keeps going; restarts if silent.
## release()          fade out, then stop. Never hard-stops mid-sound.
## If keep_alive() is not called for idle_time, it releases on its own.
##
## The stream must be imported with Loop Mode = Forward and loop_begin set
## just after the attack (see the .wav.import file).

## Seconds without keep_alive() before it fades out by itself.
@export var idle_time := 0.08
## Fade-out length in seconds.
@export var fade_out := 0.06
## How fast pitch_scale follows the requested pitch (higher = snappier).
@export var pitch_follow := 14.0

var _idle := 0.0
var _target_pitch := 1.0
var _fading := false
var _base_volume := 1.0
var _tween: Tween


func _ready() -> void:
	_base_volume = volume_linear


func start(pitch := 1.0) -> void:
	if _tween:
		_tween.kill()
	_fading = false
	_idle = 0.0
	_target_pitch = pitch
	pitch_scale = pitch
	volume_linear = _base_volume
	play()


func keep_alive(pitch := 1.0) -> void:
	if not playing or _fading:
		start(pitch)
		return
	_target_pitch = pitch
	_idle = 0.0


func release(time := fade_out) -> void:
	if not playing or _fading:
		return
	_fading = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "volume_linear", 0.0, time)
	_tween.tween_callback(_stop_faded)


func _stop_faded() -> void:
	stop()
	_fading = false
	volume_linear = _base_volume


func _process(delta: float) -> void:
	if not playing or _fading:
		return
	pitch_scale = lerpf(pitch_scale, _target_pitch, 1.0 - exp(-pitch_follow * delta))
	_idle += delta
	if _idle > idle_time:
		release()
