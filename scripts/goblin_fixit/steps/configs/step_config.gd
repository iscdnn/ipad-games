class_name StepConfig
extends Resource
## Settings for one step in a WorkArea's chain. Each step type has its own
## subclass (SawStepConfig, NailStepConfig, ...) that knows its scene and only
## shows the fields that step uses. Add them in WorkArea.steps, in play order.


## Where the goblin stands for this step: a Marker2D, path relative to the
## WorkArea. Empty = the area's "GoblinSpot" child, else left of the area.
@export var goblin_spot: NodePath


## The FixStep scene this config runs. Overridden by each subclass.
func scene() -> PackedScene:
	return null
