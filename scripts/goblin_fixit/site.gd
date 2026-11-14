extends Node2D
## Goblin Fix-It: the building site. Tap a glowing part of the building,
## the goblin walks over, the fix-it window pops up, the part gets repaired.

@export var ground_tile := Vector2i(0, 0)
@export var dirt_tile := Vector2i(1, 0)

var _busy := false

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
	_layout()
	goblin.position = Vector2(building.position.x - 90.0, _ground_y())
	building.refresh_highlights()


func _ground_y() -> float:
	return get_viewport_rect().size.y - ground.tile_set.tile_size.y * ground.scale.y


func _layout() -> void:
	var vp := get_viewport_rect().size
	var gy := _ground_y()
	# fill ground across the whole width
	ground.clear()
	ground.position = Vector2(0, gy)
	var tile_w := ground.tile_set.tile_size.x * ground.scale.x
	for x in ceili(vp.x / tile_w) + 1:
		ground.set_cell(Vector2i(x, 0), 0, ground_tile)
		for y in range(1, 3):
			ground.set_cell(Vector2i(x, y), 0, dirt_tile)
	var bs := building.size_px()
	building.position = Vector2(roundf((vp.x - bs.x) / 2.0), gy - bs.y)
	goblin.position.y = gy
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
	var target := clampf(r.get_center().x, b_left - 60.0, b_right + 60.0)
	await goblin.walk_to(target)
	goblin.face(r.get_center().x)
	await window.run(area)
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
