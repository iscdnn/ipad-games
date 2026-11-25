class_name CleanStepConfig
extends RubStepConfig
## Clean a big surface (window, wall...): tap to splash water, which cleans
## rings and sends drips running down; then scrub from any wet spot.
## Sizes are in texture pixels (texels).

@export var splashes := 3
## Splash ring radii: x = fully clean, y = 66%, z = 33%.
@export var ring_radii := Vector3(10, 20, 35)
## Chance per pixel that each ring cleans it at all (x = inner ... z = outer).
@export var clean_chances := Vector3(1.0, 1.0, 0.33)
## Drip chance per pixel in each ring (x = inner ... z = outer).
@export var drip_chances := Vector3(0.3, 0.15, 0.1)
## Drip length range (dirty pixels it can clean before drying up).
@export var drip_length := Vector2i(5, 30)
## Drip speed in texels per second.
@export var drip_speed := 60.0
## Chance per step down that a drip also shifts one pixel sideways.
@export_range(0.0, 1.0) var drip_shift := 0.15
## Scrub passes (and drip hits) to clean a fully dirty pixel.
@export_range(1, 6) var clean_passes := 3


func _init() -> void:
	surface = Surface.PANEL
	panel_texture = load("res://assets/sprites/window.png")


func scene() -> PackedScene:
	return load("res://scenes/goblin_fixit/steps/clean_step.tscn")
