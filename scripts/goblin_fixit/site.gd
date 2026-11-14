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

var _busy := false

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
	done_label.visible = false
	again_button.visible = false
	# building centred on world origin; camera looks at the origin
	var bs := building.size_px()
	building.position = (-bs / 2.0).round()
	_layout()
	building.refresh_highlights()


func _layout() -> void:
	camera.zoom = Vector2.ONE * pixel_zoom
	camera.position = Vector2.ZERO
	var view := get_viewport_rect().size / pixel_zoom
	# goblin stands at the left edge for now (no walking yet)
	goblin.position = Vector2(-view.x / 2.0 + goblin_margin, 0.0).round()
	var vp := get_viewport_rect().size
	confetti.position = Vector2(vp.x / 2.0, -20.0)
	confetti.emission_rect_extents = Vector2(vp.x / 2.0, 10.0)


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
	await window.run(area, ui_art_scale)
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
