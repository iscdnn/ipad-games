class_name SawStepConfig
extends StepConfig
## Saw boards to size. Uses the area's board_count.


func scene() -> PackedScene:
	return load("res://scenes/goblin_fixit/steps/saw_step.tscn")
