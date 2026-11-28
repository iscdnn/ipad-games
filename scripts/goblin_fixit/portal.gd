class_name Portal
extends Node2D
## Magic portal: spinning inner swirl plus an outer spinning ring
## (assets/anim/portal_frames.tres). The ring is split into left and right
## halves so things can pass "through" it: this node draws the swirl and the
## ring's right half; add `front` (the ring's left half) above whatever comes
## out of the portal. Use place() to move both together.

const FRAMES := preload("res://assets/anim/portal_frames.tres")

## Ring left half; add to the tree above the object passing through.
var front := Node2D.new()


func _init() -> void:
	add_child(_sprite(&"inner", Vector2.ZERO))
	add_child(_sprite(&"ring_right", Vector2(64, 0)))
	front.add_child(_sprite(&"ring_left", Vector2(-64, 0)))


func _sprite(anim: StringName, offset: Vector2) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = FRAMES
	s.animation = anim
	s.offset = offset
	s.play()
	return s


func place(pos: Vector2) -> void:
	position = pos
	front.position = pos


## Scales in from nothing. Placeholder until the real appear animation.
func open(size := 1.0, time := 0.5) -> void:
	_set_scale(0.0)
	var tw := create_tween()
	tw.tween_method(_set_scale, 0.0, size, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


## Scales out to nothing. Placeholder until the real disappear animation.
func close(time := 0.5) -> void:
	var tw := create_tween()
	tw.tween_method(_set_scale, scale.x, 0.0, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished


func _set_scale(v: float) -> void:
	scale = Vector2.ONE * v
	front.scale = scale
