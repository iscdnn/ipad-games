extends Node2D
## The 60-second shearing round. Everything is built in code so the scene file
## stays trivial. Sheep enter from random points on the left/right edges at
## random speeds; tapping an unsheared sheep shears it.

const GAME_SECONDS := 60.0
const HUD_TOP_MARGIN := 120.0 # keep sheep below the score/timer row
const BOTTOM_MARGIN := 80.0
# Tap target is a bit bigger than the 128x96 on-screen sheep (fingers are fat).
const HIT_HALF_SIZE := Vector2(80.0, 64.0)

enum State { PLAYING, OVER }

var state: State = State.PLAYING
var time_left := GAME_SECONDS
var score := 0
var spawn_cooldown := 0.3

var sheep_layer: Node2D
var fx_layer: Node2D
var score_label: Label
var time_label: Label
var best_label: Label
var overlay: Control
var overlay_title: Label
var overlay_detail: Label
var shear_player: AudioStreamPlayer
var finish_player: AudioStreamPlayer
var _urgent := false


func _ready() -> void:
	_build_background()

	sheep_layer = Node2D.new()
	add_child(sheep_layer)
	fx_layer = Node2D.new()
	add_child(fx_layer)

	_build_hud()
	_build_overlay()

	shear_player = AudioStreamPlayer.new()
	shear_player.stream = Sfx.shear()
	shear_player.max_polyphony = 8 # let quick successive shears overlap
	add_child(shear_player)

	finish_player = AudioStreamPlayer.new()
	finish_player.stream = Sfx.finish()
	add_child(finish_player)

	_update_hud()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return

	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_end_game()
		return
	_update_hud()

	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		_spawn_sheep()
		# Spawns get ~2x more frequent over the round.
		var ramp := lerpf(1.0, 0.5, 1.0 - time_left / GAME_SECONDS)
		spawn_cooldown = randf_range(0.5, 1.1) * ramp


func _input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	# Touches arrive as emulated left-clicks (Input Devices > Pointing setting).
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := make_input_local(mb) as InputEventMouseButton
	_try_shear_at(local.position)


# --- Gameplay -------------------------------------------------------------

func _spawn_sheep() -> void:
	var view := get_viewport_rect().size
	var from_left := randi() % 2 == 0
	var speed := randf_range(140.0, 460.0)
	var y := randf_range(HUD_TOP_MARGIN, maxf(view.y - BOTTOM_MARGIN, HUD_TOP_MARGIN + 1.0))

	var s := Sheep.new()
	s.position = Vector2(-90.0 if from_left else view.x + 90.0, y)
	s.z_index = int(y) # lower on screen = in front
	s.setup(Vector2(speed if from_left else -speed, randf_range(-25.0, 25.0)))
	sheep_layer.add_child(s)


func _try_shear_at(p: Vector2) -> void:
	var best: Sheep = null
	var best_dist := INF
	for child in sheep_layer.get_children():
		var s := child as Sheep
		if s == null or s.sheared:
			continue
		var d := p - s.position
		if absf(d.x) <= HIT_HALF_SIZE.x and absf(d.y) <= HIT_HALF_SIZE.y:
			var dist := d.length_squared()
			if dist < best_dist:
				best_dist = dist
				best = s
	if best != null:
		_shear(best)


func _shear(s: Sheep) -> void:
	s.shear()
	score += 1
	_update_hud()
	shear_player.pitch_scale = randf_range(0.92, 1.15)
	shear_player.play()
	_spawn_wool_burst(s.position)
	_spawn_popup(s.position + Vector2(0.0, -70.0), "+1")


func _end_game() -> void:
	state = State.OVER
	var is_new_best := Save.submit_score(score)
	overlay_title.text = "New best!" if is_new_best else "Time's up!"
	overlay_detail.text = "You sheared %d sheep\nBest: %d" % [score, Save.high_score]
	overlay.visible = true
	finish_player.play()
	_update_hud()


# --- Effects --------------------------------------------------------------

func _spawn_wool_burst(pos: Vector2) -> void:
	var p := CPUParticles2D.new() # CPU particles: most reliable on web/Compatibility
	p.position = pos
	p.texture = SheepArt.wool_texture()
	p.one_shot = true
	p.amount = 20
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0.0, 380.0)
	p.damping_min = 40.0
	p.damping_max = 80.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	p.color_ramp = ramp

	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


func _spawn_popup(pos: Vector2, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("2b2b3a"))
	l.add_theme_constant_override("outline_size", 10)
	l.position = pos - Vector2(30.0, 30.0)
	l.z_index = 4000
	fx_layer.add_child(l)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 80.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.finished.connect(l.queue_free)


# --- UI -------------------------------------------------------------------

func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var field := ColorRect.new()
	field.color = Color("8fd36b")
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(field)
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	layer.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	score_label = _hud_label(44, HORIZONTAL_ALIGNMENT_LEFT)
	time_label = _hud_label(72, HORIZONTAL_ALIGNMENT_CENTER)
	best_label = _hud_label(44, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(score_label)
	row.add_child(time_label)
	row.add_child(best_label)


func _hud_label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("2b2b3a"))
	l.add_theme_constant_override("outline_size", maxi(size / 6, 4))
	return l


func _update_hud() -> void:
	score_label.text = "Sheared: %d" % score
	time_label.text = str(int(ceil(time_left)))
	best_label.text = "Best: %d" % maxi(Save.high_score, score)

	var urgent := state == State.PLAYING and time_left <= 10.0
	if urgent != _urgent:
		_urgent = urgent
		time_label.add_theme_color_override("font_color", Color("ff5a4d") if urgent else Color.WHITE)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)

	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0, 0, 0, 0.55)
	overlay.visible = false
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	overlay_title = _overlay_label(96)
	overlay_detail = _overlay_label(48)
	vbox.add_child(overlay_title)
	vbox.add_child(overlay_detail)

	var again := _overlay_button("Play Again")
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	vbox.add_child(again)

	var menu := _overlay_button("Menu")
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	vbox.add_child(menu)


func _overlay_label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("2b2b3a"))
	l.add_theme_constant_override("outline_size", maxi(size / 8, 4))
	return l


func _overlay_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 100)
	b.add_theme_font_size_override("font_size", 48)
	return b
