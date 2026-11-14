class_name Goblin
extends Node2D
## The goblin builder. Sprite sheet: 4 frames [idle0, idle1, walk0, walk1],
## drawn facing right, feet at the bottom.

@export var speed := 120.0

var _walking := false
var _anim_t := 0.0
var _frame_flip := false

@onready var sprite: Sprite2D = $Sprite


func walk_to(x: float) -> void:
	var dist := absf(x - position.x)
	if dist < 4.0:
		return
	sprite.flip_h = x < position.x
	_walking = true
	var tw := create_tween()
	tw.tween_property(self, "position:x", x, dist / speed)
	await tw.finished
	_walking = false


func face(x: float) -> void:
	sprite.flip_h = x < position.x


func cheer(times := 1) -> void:
	for i in times:
		var tw := create_tween()
		tw.tween_property(sprite, "position:y", -6.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(sprite, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		await tw.finished


func _process(delta: float) -> void:
	_anim_t += delta
	var period := 0.12 if _walking else 0.5
	if _anim_t >= period:
		_anim_t = 0.0
		_frame_flip = not _frame_flip
		if _walking:
			Sfx.play(&"step", 1.0, -10.0)
	var base := 2 if _walking else 0
	sprite.frame = base + (1 if _frame_flip else 0)
