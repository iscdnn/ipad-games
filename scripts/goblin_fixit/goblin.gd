class_name Goblin
extends Node2D
## The goblin builder. AnimatedSprite2D with assets/anim/goblin_frames.tres.
## Animations used:
##   idle   - default, loops
##   walk   - loops while walking
##   do     - default action, loops while a pop-up step runs
##   hammer - loops during the nail step
##   jump   - one-shot cheer (loop off)
## walk_to() is unused for now (goblin stands at the screen edge).

@export var speed := 120.0

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


func face(x: float) -> void:
	sprite.flip_h = x < position.x


## Plays the jump animation `times` times, then returns to idle.
func cheer(times := 1) -> void:
	for i in times:
		sprite.play(&"jump")
		await sprite.animation_finished
	sprite.play(&"idle")
