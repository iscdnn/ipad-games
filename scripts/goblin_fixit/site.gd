extends Node2D
## Goblin Fix-It: the building site. Tap a highlighted part of the building,
## the goblin walks over, the fix-it window pops up, the part gets repaired.
##
## World is authored in art pixels (16px tiles, scale 1). The Camera2D zoom
## sets how big art pixels appear; the pop-up window uses the same zoom for
## its art so both match.

## Screen pixels per art pixel, for the world camera and the pop-up art.
@export var pixel_zoom := 2.0
## Rows of ground tiles visible below the building.
@export var ground_rows_visible := 2
@export var ground_tile := Vector2i(0, 0)
@export var dirt_tile := Vector2i(1, 0)

var _busy := false

@onready var camera: Camera2D = $Camera
@onready var ground: TileMapLayer = $Ground
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
	# ground surface is world y = 0, building centred on x = 0
	var bs := building.size_px()
	building.position = Vector2(roundf(-bs.x / 2.0), -bs.y)
	goblin.position = Vector2(building.position.x - 24.0, 0.0)
	_layout()
	building.refresh_highlights()


## Camera keeps the ground at the bottom of the screen; extra screen space
## (other iPad shapes, `expand` stretch) shows more sky / more ground sideways.
func _layout() -> void:
	camera.zoom = Vector2.ONE * pixel_zoom
	var view := get_viewport_rect().size / pixel_zoom
	var tile := Vector2(ground.tile_set.tile_size)
	camera.position = Vector2(0.0, ground_rows_visible * tile.y - view.y / 2.0)
	ground.clear()
	var half_cols := ceili(view.x / 2.0 / tile.x) + 1
	for x in range(-half_cols, half_cols):
		ground.set_cell(Vector2i(x, 0), 0, ground_tile)
		for y in range(1, ground_rows_visible + 1):
			ground.set_cell(Vector2i(x, y), 0, dirt_tile)
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
	var r := area.global_rect()
	var b_left := building.position.x
	var b_right := b_left + building.size_px().x
	var target := clampf(r.get_center().x, b_left - 16.0, b_right + 16.0)
	await goblin.walk_to(target)
	goblin.face(r.get_center().x)
	await window.run(area, pixel_zoom)
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
