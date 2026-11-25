extends RubStep
## Clean a big surface: tap to splash water (limited splashes); each splash
## cleans in rings and sends drips running down. Then press on any spot that
## isn't fully dirty and scrub; each pass cleans another third.

## Finger travel (px) before a press counts as a scrub instead of a tap.
@export var tap_slop := 14.0

var _splashes_left := 3
var _pressed := false
var _moved := false
var _press_pos := Vector2.ZERO
var _can_scrub := false


func _init() -> void:
	super._init()
	title = "Wash it clean!"
	tool_texture = preload("res://assets/sprites/sponge.png")
	tool_tip = Vector2(24, 16)
	rub_sound = &"scrub"
	sound_every = 60.0


func clean_config() -> CleanStepConfig:
	return config as CleanStepConfig


func begin() -> void:
	if config == null:
		config = CleanStepConfig.new()
	super.begin()
	_splashes_left = clean_config().splashes


func rub_amount() -> float:
	return 1.0 / clean_config().clean_passes


func _style_surface(s: RubSurface) -> void:
	s.mat.set_shader_parameter(&"before_tint", Color(0.72, 0.64, 0.48))
	s.mat.set_shader_parameter(&"before_grime", 0.8)


## Soapy bubbles while scrubbing.
func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 18
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 20.0
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, -30)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 9.0
	p.color = Color(1, 1, 1, 0.75)
	return p


func _gui_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_moved = false
			_press_pos = event.position
			_last = event.position
			_can_scrub = _wet_at(event.position)
		else:
			_pressed = false
			if not _moved:
				_splash(_press_pos)
			elif _rubbing:
				_rubbing = false
				_tool_back()
	elif event is InputEventMouseMotion and _pressed:
		var p: Vector2 = event.position
		if not _moved and p.distance_to(_press_pos) > tap_slop:
			_moved = true
			if _can_scrub:
				_rubbing = true
				_last = _press_pos
				move_child(_tool, -1)
				move_child(top, -1)
		if _rubbing:
			_rub_to(p)


## Not fully dirty under the finger (a scrub can start here).
func _wet_at(p: Vector2) -> bool:
	for s in surfaces:
		if s.value_at(p) > 0.0:
			return true
	return false


func _splash(p: Vector2) -> void:
	if _splashes_left <= 0:
		return
	var target: RubSurface = null
	for s in surfaces:
		if s.value_at(p) >= 0.0:
			target = s
	if target == null:
		return
	_splashes_left -= 1
	var c := clean_config()
	var third := 1.0 / c.clean_passes
	target.splash(p, c.ring_radii, Vector3(1.0, 1.0 - third, third), c.drip_chances,
			c.drip_length, third, c.drip_shift)
	Sfx.play(&"splash")
	_splash_fx(p, c.ring_radii.z * target.scale.x)


func _splash_fx(p: Vector2, radius: float) -> void:
	var fx := CPUParticles2D.new()
	fx.one_shot = true
	fx.explosiveness = 0.95
	fx.amount = 28
	fx.lifetime = 0.6
	fx.position = p
	fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fx.emission_sphere_radius = radius * 0.5
	fx.direction = Vector2(0, -1)
	fx.spread = 180.0
	fx.initial_velocity_min = 60.0
	fx.initial_velocity_max = 200.0
	fx.gravity = Vector2(0, 600)
	fx.scale_amount_min = 3.0
	fx.scale_amount_max = 7.0
	fx.color = Color(0.6, 0.85, 1.0, 0.9)
	add_child(fx)
	fx.emitting = true
	fx.finished.connect(fx.queue_free)


func _draw_top() -> void:
	if _busy or surfaces.is_empty():
		return
	var s := surfaces[0]
	var half := s.texture.get_size() * s.scale / 2.0
	# water drops left
	var total := clean_config().splashes
	for i in total:
		var c := s.position + Vector2(-half.x + 14.0 + i * 34.0, -half.y - 26.0)
		var col := Color(0.35, 0.65, 1.0) if i < _splashes_left else Color(0.35, 0.65, 1.0, 0.25)
		top.draw_circle(c, 12.0, col)
		top.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -5), c + Vector2(10, -5), c + Vector2(0, -24)]), col)
	# hint: pulsing tap ring until the first splash, then the scrub arrow
	if _splashes_left == total:
		var r := 30.0 + 12.0 * sin(_t * 5.0)
		top.draw_arc(s.position, r, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 6.0)
	elif not _rubbing and progress() < 0.05:
		super._draw_top()
