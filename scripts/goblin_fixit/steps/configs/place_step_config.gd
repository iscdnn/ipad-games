class_name PlaceStepConfig
extends StepConfig
## Drag boards onto the frame. Uses the area's board_count.


func scene() -> PackedScene:
	return load("res://scenes/goblin_fixit/steps/place_step.tscn")
