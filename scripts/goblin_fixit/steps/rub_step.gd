class_name RubStep
extends FixStep
## Base for rub-to-cover steps (sand, paint). Press anywhere and rub: the tool
## follows the finger and changes the look of every RubSurface it passes over.
## Settings come from a RubStepConfig (surface type, brush size, passes...).
## Subclasses set the tool art, sound, particles and _style_surface().

## Tool art and the point on it (texture px) that touches the surface.
@export var tool_texture: Texture2D
@export var tool_tip := Vector2.ZERO
## Sound played every `sound_every` px of rubbing.
@export var rub_sound := &"sand"
@export var sound_every := 70.0

var surfaces: Array[RubSurface] = []
var _slots: Array[Rect2] = []
var _tool: Sprite2D
var _tool_home := Vector2.ZERO
var _particles: CPUParticles2D
var _rubbing := false
var _last := Vector2.ZERO
var _since_sound := 0.0
var _moved_t := 1.0
var _busy := false
var _t := 0.0


func rub_config() -> RubStepConfig:
	return config as RubStepConfig


## How much one pass over a pixel covers it (1 = fully in one swipe).
func rub_amount() -> float:
	return 1.0


## Set the shader's before/after look on a new surface.
func _style_surface(_s: RubSurface) -> void:
	pass


## Particles that spray from the tool while rubbing.
func _make_particles() -> CPUParticles2D:
	return CPUParticles2D.new()


func begin() -> void:
	super.begin()
	var cfg := rub_config()
	var use_panel := cfg != null and cfg.surface == RubStepConfig.Surface.PANEL
	var center := pr(0.45, 0.55)
	if use_panel:
		var s := RubSurface.new()
		s.setup(cfg.panel_texture)
		var tex_size := s.texture.get_size()
		var fit := minf(panel_rect.size.x * 0.7 / tex_size.x, panel_rect.size.y * 0.7 / tex_size.y)
		s.scale = Vector2.ONE * maxf(floorf(fit), art_scale)
		s.position = center.round()
		_add_surface(s)
	else:
		_slots = slot_rects(center)
		for r in _slots:
			var s := RubSurface.new()
			s.setup(board_texture, Rect2i(0, 0, board_keep_px, board_texture.get_height()))
			s.scale = Vector2.ONE * art_scale
			s.position = r.get_center().round()
			_add_surface(s)

	_particles = _make_particles()
	_particles.emitting = false
	add_child(_particles)

	_tool = Sprite2D.new()
	_tool.texture = tool_texture
	_tool.centered = false
	_tool.offset = -tool_tip
	_tool.scale = Vector2.ONE * art_scale
	_tool_home = pr(0.9, 0.85)
	_tool.position = _tool_home
	add_child(_tool)
	move_child(top, -1)


func _add_surface(s: RubSurface) -> void:
	add_child(s)
	_style_surface(s)
	surfaces.append(s)


func progress() -> float:
	var done := 0
	var total := 0
	for s in surfaces:
		done += s.done_count()
		total += s.opaque_count()
	return float(done) / maxf(total, 1.0)


func _gui_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_rubbing = event.pressed
		_last = event.position
		if _rubbing:
			_tool.position = event.position
			move_child(_tool, -1)
			move_child(top, -1)
		else:
			_tool_back()
	elif event is InputEventMouseMotion and _rubbing:
		var p: Vector2 = event.position
		var cfg := rub_config()
		var radius := cfg.brush_radius if cfg else 34.0
		var touched := false
		for s in surfaces:
			if s.hits(p, radius) or s.hits(_last, radius):
				s.rub(_last, p, radius, rub_amount())
				touched = true
		var d := _last.distance_to(p)
		_tool.position = p
		_last = p
		if touched and d > 0.0:
			_moved_t = 0.0
			_particles.position = p
			_since_sound += d
			if _since_sound >= sound_every:
				_since_sound = 0.0
				Sfx.play(rub_sound, randf_range(0.9, 1.15), -4.0)


func _tool_back() -> void:
	var tw := create_tween()
	tw.tween_property(_tool, "position", _tool_home, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	_moved_t += delta
	if _particles:
		_particles.emitting = _moved_t < 0.1 and not _busy
	if not _busy and surfaces.size() > 0:
		var cfg := rub_config()
		var target := cfg.complete_at if cfg else 0.9
		if progress() >= target:
			_complete()


func _complete() -> void:
	_busy = true
	_rubbing = false
	_tool_back()
	var tw: Tween
	for s in surfaces:
		tw = s.fill_rest(0.4)
	Sfx.play(&"nail_done", 1.2, -2.0)
	await tw.finished
	finish(0.5)


func _draw_under() -> void:
	if not _slots.is_empty():
		draw_frame(under, _slots)


func _draw_top() -> void:
	# back-and-forth hint until rubbing has started
	if _busy or surfaces.is_empty() or progress() > 0.03:
		return
	var s := surfaces[0]
	var bob := sin(_t * 5.0) * 40.0
	var c := s.position + Vector2(bob, -s.texture.get_height() * s.scale.y / 2.0 - 70.0)
	draw_arrow(top, c - Vector2(90, 0), c + Vector2(90, 0), Color(1, 1, 1, 0.85), 10.0, true)
