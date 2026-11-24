class_name NailStepConfig
extends StepConfig
## Hammer nails into the placed boards. Uses the area's board_count.

@export_range(1, 3) var nails_per_board := 2


func scene() -> PackedScene:
	return load("res://scenes/goblin_fixit/steps/nail_step.tscn")
