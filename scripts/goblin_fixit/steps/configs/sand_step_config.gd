class_name SandStepConfig
extends RubStepConfig
## Rub the sanding block over the surface until it's clean.

## Back-and-forth passes over a spot to sand it fully.
@export_range(1.0, 8.0) var passes := 3.0


func scene() -> PackedScene:
	return load("res://scenes/goblin_fixit/steps/sand_step.tscn")
