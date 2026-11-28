extends Node2D
## Goblin Fix-It: the building site. Tap a highlighted part of the building,
## the fix-it window pops up, the part gets repaired.
##
## Top-down view: flat green background, building centred on screen.
## World is authored in art pixels (16px tiles, scale 1). The Camera2D zoom
## sets how big art pixels appear. Pop-up art has its own `ui_art_scale`.

## Screen pixels per art pixel for the world (sets the camera zoom).
@export var pixel_zoom := 3.0
## Scale of the pop-up step art (UI layer, independent of the world zoom).
## Use 0.5 for hi-res sprites drawn at 2x for the iPad screen.
@export var ui_art_scale := 2.0
## Goblin distance from the left screen edge, in art pixels.
@export var goblin_margin := 24.0
## Camera zoom while a pop-up is open (close-up on the goblin).
@export var closeup_zoom := 8.0
## Goblin point (art px, relative to the goblin) kept centred in the close-up.
@export var closeup_focus := Vector2(0, -6)
## Steps without a panel: goblin's screen x as a fraction of the width
## (the step's props sit to its right).
@export var no_panel_goblin_x := 0.2
## Default goblin spot when an area/step has no marker: this far left of the
## area's left edge (art px), level with its middle.
@export var default_spot_gap := 10.0
@export var camera_move_time := 0.5

var _busy := false
var _closeup := false
var _closeup_panel := true

@onready var camera: Camera2D = $Camera
@onready var building: Building = $Building
@onready var goblin: Goblin = $Goblin
@onready var window: InteractionWindow = $InteractionWindow
@onready var done_label: Label = $UI/DoneLabel
@onready var again_button: Button = $UI/AgainButton
@onready var confetti: CPUParticles2D = $UI/Confetti


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	again_button.pressed.connect(_on_again)
	window.step_started.connect(_on_step_started)
	window.prepare_step = _prepare_step
	done_label.visible = false
	again_button.visible = false
	# building centred on world origin; camera looks at the origin
	var bs := building.size_px()
	building.position = (-bs / 2.0).round()
	_layout()
	building.refresh_highlights()


func _layout() -> void:
	var view := get_viewport_rect().size / pixel_zoom
	# goblin stands at the left edge for now (no walking yet)
	if not _busy:
		goblin.position = Vector2(-view.x / 2.0 + goblin_margin, 0.0).round()
	var vp := get_viewport_rect().size
	confetti.position = Vector2(vp.x / 2.0, -20.0)
	confetti.emission_rect_extents = Vector2(vp.x / 2.0, 10.0)
	if _closeup:
		camera.zoom = Vector2.ONE * closeup_zoom
		camera.position = _closeup_position(_closeup_panel)
	else:
		camera.zoom = Vector2.ONE * pixel_zoom
		camera.position = Vector2.ZERO


## Camera position for the goblin close-up. With the pop-up panel, the goblin
## sits in the middle of the space left of it; without, at no_panel_goblin_x.
func _closeup_position(with_panel := true) -> Vector2:
	var vp := get_viewport_rect().size
	var goblin_x := vp.x * (1.0 - window.panel_width) / 2.0 if with_panel else vp.x * no_panel_goblin_x
	var shift := (vp.x / 2.0 - goblin_x) / closeup_zoom
	return goblin.position + closeup_focus + Vector2(shift, 0)


## Where the goblin stands for a step (world position).
func _goblin_spot(area: WorkArea, config: StepConfig) -> Vector2:
	var marker: Node2D = null
	if config and not config.goblin_spot.is_empty():
		marker = area.get_node_or_null(config.goblin_spot) as Node2D
	if marker == null:
		marker = area.get_node_or_null(^"GoblinSpot") as Node2D
	var world: Vector2
	if marker:
		world = marker.global_position
	else:
		var r := area.global_rect()
		world = Vector2(r.position.x - default_spot_gap, r.get_center().y)
	# goblin's feet go on the spot
	return to_local(world) - goblin.feet_offset()


## Before each step: walk the goblin to its spot, frame the camera, and tell
## the step where the goblin's box and feet are on screen.
func _prepare_step(area: WorkArea, config: StepConfig, step: FixStep) -> Dictionary:
	await goblin.walk_to_point(_goblin_spot(area, config).round())
	_closeup = true
	_closeup_panel = step.uses_panel
	await _move_camera(closeup_zoom, _closeup_position(step.uses_panel))
	await get_tree().process_frame
	var xf := get_viewport().get_canvas_transform()
	return {
		source = xf * goblin.to_global(goblin.carry_box_offset),
		feet = xf * goblin.to_global(goblin.feet_offset()),
	}


func _move_camera(zoom: float, pos: Vector2) -> void:
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "zoom", Vector2.ONE * zoom, camera_move_time)
	tw.tween_property(camera, "position", pos, camera_move_time)
	await tw.finished


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var area := building.area_at(get_global_mouse_position())
		if area:
			get_viewport().set_input_as_handled()
			_fix(area)


func _fix(area: WorkArea) -> void:
	_busy = true
	Sfx.play(&"tap")
	building.clear_highlights()
	# per step: walk to the spot + close-up (see _prepare_step), run the
	# steps, then zoom back out
	await window.run(area, ui_art_scale)
	goblin.idle()
	_closeup = false
	await _move_camera(pixel_zoom, Vector2.ZERO)
	area.complete()
	Sfx.play(&"area_done")
	await goblin.cheer()
	if building.is_complete():
		await _celebrate()
	else:
		building.refresh_highlights()
	_busy = false


func _celebrate() -> void:
	Sfx.play(&"building_done")
	confetti.restart()
	confetti.emitting = true
	done_label.visible = true
	done_label.pivot_offset = done_label.size / 2.0
	done_label.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(done_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await goblin.cheer(3)
	again_button.visible = true


func _on_again() -> void:
	Sfx.play(&"tap")
	done_label.visible = false
	again_button.visible = false
	building.reset()

func _on_step_started(step: FixStep) -> void:
	goblin.play_action(step.goblin_animation) ## may remove at some point, just have steps drive the animation
	step.animate_goblin.connect(goblin.play_action)
