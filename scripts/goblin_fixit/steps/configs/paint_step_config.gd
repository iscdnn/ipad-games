class_name PaintStepConfig
extends RubStepConfig
## Brush paint over the surface.

@export var color := Color(0.35, 0.6, 0.9)
## Passes over a spot to paint it fully (1 = one swipe).
@export_range(1.0, 4.0) var passes := 1.0


func scene() -> PackedScene:
	return load("res://scenes/goblin_fixit/steps/paint_step.tscn")
