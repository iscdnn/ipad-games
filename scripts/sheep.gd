class_name Sheep
extends Node2D
## One sheep running across the screen. Created and driven by game.gd.

const SPRITE_SCALE := 4.0

var velocity := Vector2.ZERO
var sheared := false

var _sprite := Sprite2D.new()
var _frame := 0
var _anim_timer := 0.0
var _frame_time := 0.15


func _init() -> void:
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(_sprite)
	_refresh_texture()


func setup(vel: Vector2) -> void:
	velocity = vel
	_sprite.flip_h = vel.x < 0.0
	# Faster sheep animate their legs faster.
	_frame_time = clampf(26.0 / maxf(absf(vel.x), 60.0), 0.05, 0.22)


func shear() -> void:
	if sheared:
		return
	sheared = true
	velocity *= 1.3 # startled!
	_frame_time /= 1.3
	_refresh_texture()
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE) * 1.4
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	position += velocity * delta

	_anim_timer += delta
	if _anim_timer >= _frame_time:
		_anim_timer = 0.0
		_frame = 1 - _frame
		_refresh_texture()

	# Free once fully off the far side of the screen.
	var width := get_viewport_rect().size.x
	if (velocity.x > 0.0 and position.x > width + 140.0) or (velocity.x < 0.0 and position.x < -140.0):
		queue_free()


func _refresh_texture() -> void:
	_sprite.texture = SheepArt.frames(sheared)[_frame]
