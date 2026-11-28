class_name InteractionWindow
extends CanvasLayer
## Pop-up that plays a WorkArea's steps one after another.
## The panel sits on the right of the screen; the left is left clear so the
## goblin close-up shows. Steps cover the whole screen for input (so drags can
## start on the goblin), but lay out their content inside `panel_rect`.
## Usage:  await window.run(area, ui_art_scale, source_point)

signal step_started(step: FixStep)

## Fraction of the screen width the panel takes, from the right edge.
@export_range(0.3, 0.9) var panel_width := 0.6
@export var margin := 20.0
@export var title_height := 90.0

## Called before each step begins: await prepare_step.call(area, config, step)
## must return {source = Vector2, feet = Vector2} (screen points). The site
## walks the goblin to the step's spot and frames the camera here. Optional
## `rect` = goblin's visible sprite on screen.
var prepare_step: Callable
var _panel_shown := false
var _blocker: Control
var _panel: Panel
var _title: Label
var _holder: Control


func _ready() -> void:
	layer = 10
	visible = false
	# invisible full-screen catcher so taps never reach the world underneath
	_blocker = Control.new()
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_blocker)

	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.9, 0.72)
	sb.border_color = Color(0.55, 0.36, 0.18)
	sb.set_border_width_all(8)
	sb.set_corner_radius_all(28)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 48)
	_title.add_theme_color_override("font_color", Color(0.35, 0.2, 0.08))
	_panel.add_child(_title)

	# steps live here: full screen, above the panel
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x * panel_width
	_panel.position = Vector2(vp.x - w, margin)
	_panel.size = Vector2(w - margin, vp.y - margin * 2.0)
	_title.size = Vector2(_panel.size.x, title_height)


## Step content area in screen coordinates (inside the panel, below the title).
func panel_rect() -> Rect2:
	var r := Rect2(_panel.position, _panel.size)
	return Rect2(r.position + Vector2(30, title_height), r.size - Vector2(60, title_height + 30))


## `source_point`: screen position boards/nails come from (box on the goblin's head).
func run(area: WorkArea, art_scale := 2.0, source_point := Vector2.ZERO) -> void:
	await _open()
	for config in area.steps:
		if config == null or config.scene() == null:
			push_warning("%s: empty step config, skipped" % area.name)
			continue
		var step := config.scene().instantiate() as FixStep
		step.area = area
		step.config = config
		step.art_scale = art_scale
		step.panel_rect = panel_rect()
		step.source_point = source_point
		if prepare_step.is_valid():
			var ctx: Dictionary = await prepare_step.call(area, config, step)
			step.source_point = ctx.get("source", source_point)
			step.goblin_feet = ctx.get("feet", Vector2.ZERO)
			step.goblin_rect = ctx.get("rect", Rect2(step.goblin_feet, Vector2.ZERO))
		await _show_panel(step.uses_panel)
		step.position = Vector2.ZERO
		step.size = get_viewport().get_visible_rect().size
		step.modulate.a = 0.0
		_holder.add_child(step)
		step.begin()
		step_started.emit(step)
		_title.text = step.title if step.uses_panel else ""
		create_tween().tween_property(step, "modulate:a", 1.0, 0.2)
		await step.completed
		Sfx.play(&"area_done", 1.4, -8.0)
		var tw := create_tween()
		tw.tween_property(step, "modulate:a", 0.0, 0.2)
		await tw.finished
		step.queue_free()
	await _close()


func _open() -> void:
	_layout()
	_title.text = ""
	visible = true
	_panel_shown = false
	_panel.position.x = get_viewport().get_visible_rect().size.x


## Slides the panel in or out (steps with uses_panel = false have none).
func _show_panel(show: bool) -> void:
	if show == _panel_shown:
		return
	_panel_shown = show
	if not show:
		_title.text = ""
		Sfx.play(&"whoosh", 1.2)
		var out := create_tween()
		out.tween_property(_panel, "position:x", get_viewport().get_visible_rect().size.x, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await out.finished
		return
	_layout()
	var vp := get_viewport().get_visible_rect().size
	var x := _panel.position.x
	_panel.position.x = vp.x
	Sfx.play(&"whoosh")
	var tw := create_tween()
	tw.tween_property(_panel, "position:x", x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


func _close() -> void:
	if not _panel_shown:
		visible = false
		return
	_panel_shown = false
	Sfx.play(&"whoosh", 1.2)
	var vp := get_viewport().get_visible_rect().size
	var tw := create_tween()
	tw.tween_property(_panel, "position:x", vp.x, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	visible = false
