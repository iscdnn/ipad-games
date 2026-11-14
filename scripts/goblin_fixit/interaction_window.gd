class_name InteractionWindow
extends CanvasLayer
## Pop-up that plays a WorkArea's steps one after another.
## Usage:  await window.run(area)

const PANEL_SIZE := Vector2(1100, 620)
const TITLE_H := 90.0

var _dim: ColorRect
var _panel: Panel
var _title: Label
var _holder: Control


func _ready() -> void:
	layer = 10
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.9, 0.72)
	sb.border_color = Color(0.55, 0.36, 0.18)
	sb.set_border_width_all(8)
	sb.set_corner_radius_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.size = PANEL_SIZE
	_panel.pivot_offset = PANEL_SIZE / 2.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.position = Vector2.ZERO
	_title.size = Vector2(PANEL_SIZE.x, TITLE_H)
	_title.add_theme_font_size_override("font_size", 48)
	_title.add_theme_color_override("font_color", Color(0.35, 0.2, 0.08))
	_panel.add_child(_title)

	_holder = Control.new()
	_holder.position = Vector2(40, TITLE_H)
	_holder.size = PANEL_SIZE - Vector2(80, TITLE_H + 30)
	_holder.clip_contents = false
	_panel.add_child(_holder)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_panel.position = (vp - PANEL_SIZE) / 2.0


func run(area: WorkArea) -> void:
	await _open()
	for scene in area.steps:
		var step := scene.instantiate() as FixStep
		step.area = area
		step.size = _holder.size
		step.modulate.a = 0.0
		_holder.add_child(step)
		step.begin()
		_title.text = step.title
		create_tween().tween_property(step, "modulate:a", 1.0, 0.2)
		await step.completed
		Sfx.play(&"area_done", 1.4, -8.0)
		var tw := create_tween()
		tw.tween_property(step, "modulate:a", 0.0, 0.2)
		await tw.finished
		step.queue_free()
	await _close()


func _open() -> void:
	_title.text = ""
	visible = true
	_dim.modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.7
	_panel.modulate.a = 0.0
	Sfx.play(&"whoosh")
	var tw := create_tween().set_parallel()
	tw.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


func _close() -> void:
	Sfx.play(&"whoosh", 1.2)
	var tw := create_tween().set_parallel()
	tw.tween_property(_dim, "modulate:a", 0.0, 0.2)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE * 0.8, 0.2)
	await tw.finished
	visible = false
