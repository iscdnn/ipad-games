class_name Goblin
extends Node2D
## The goblin builder. AnimatedSprite2D with assets/anim/goblin_frames.tres.
## Animations used:
##   idle   - default, loops
##   walk   - loops while walking
##   do     - default action, loops while a pop-up step runs
##   hammer - loops during the nail step
##   carry  - loops during place/nail steps (box on head = board/nail source)
##   jump   - one-shot cheer (loop off)
## walk_to_point() moves the goblin to each step's spot.

@export var speed := 120.0
## Centre of the box on the goblin's head in the "carry" animation, in art px
## relative to the goblin's origin. Boards and nails are dragged from here.
@export var carry_box_offset := Vector2(0, -14)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.play(&"idle")


func idle() -> void:
	sprite.play(&"idle")


## Loops an action animation (e.g. "do", "hammer") until idle() or cheer().
func play_action(anim: StringName) -> void:
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	else:
		push_warning("Goblin: no animation '%s', using do" % anim)
		sprite.play(&"do")


func walk_to(x: float) -> void:
	var dist := absf(x - position.x)
	if dist < 1.0:
		return
	face(x)
	sprite.play(&"walk")
	var tw := create_tween()
	tw.tween_property(self, "position:x", x, dist / speed)
	await tw.finished
	sprite.play(&"idle")


func walk_to_point(p: Vector2) -> void:
	var dist := position.distance_to(p)
	if dist < 1.0:
		return
	face(p.x)
	sprite.play(&"walk")
	var tw := create_tween()
	tw.tween_property(self, "position", p, dist / speed)
	await tw.finished
	sprite.play(&"idle")


## Bounds of the visible pixels of the current frame, relative to the
## goblin's origin (art px).
func visual_rect() -> Rect2:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return Rect2()
	var used := tex.get_image().get_used_rect()
	var top_left := sprite.position + sprite.offset - tex.get_size() / 2.0
	return Rect2(top_left + Vector2(used.position), Vector2(used.size))


## Feet point relative to the goblin's origin (bottom of the sprite frame).
func feet_offset() -> Vector2:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	var h := tex.get_height() if tex else 0
	return sprite.position + sprite.offset + Vector2(0, h / 2.0)


func face(x: float) -> void:
	sprite.flip_h = x < position.x

func hammer_windup() -> void:
	sprite.play(&"hammer_windup")
	
func hammer_strike() -> void:
	sprite.play(&"hammer_strike")
	await sprite.animation_finished
	sprite.play(&"idle")

## Plays the jump animation `times` times, then returns to idle.
func cheer(times := 1) -> void:
	for i in times:
		sprite.play(&"jump")
		await sprite.animation_finished
	sprite.play(&"idle")
