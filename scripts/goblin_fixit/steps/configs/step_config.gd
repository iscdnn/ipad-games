class_name StepConfig
extends Resource
## Settings for one step in a WorkArea's chain. Each step type has its own
## subclass (SawStepConfig, NailStepConfig, ...) that knows its scene and only
## shows the fields that step uses. Add them in WorkArea.steps, in play order.


## The FixStep scene this config runs. Overridden by each subclass.
func scene() -> PackedScene:
	return null
