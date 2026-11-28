extends RubStep
## Paint the surface: brush over it until it's all coloured.


func _init() -> void:
	super._init()
	title = "Paint it!"
	tool_texture = preload("res://assets/sprites/paint_brush.png")
	tool_tip = Vector2(12, 52)
	rub_sound = &"paint"
	sound_every = 90.0


func paint_color() -> Color:
	var c := config as PaintStepConfig
	return c.color if c else Color(0.35, 0.6, 0.9)


func rub_amount() -> float:
	var c := config as PaintStepConfig
	return 1.0 / (c.passes if c else 1.0)


func _style_surface(s: RubSurface) -> void:
	s.mat.set_shader_parameter(&"paint_color", paint_color())
	s.mat.set_shader_parameter(&"paint_amount", 1.0)


func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 0.45
	p.direction = Vector2(0, 1)
	p.spread = 40.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 7.0
	p.color = paint_color()
	return p


func _draw_top() -> void:
	super._draw_top()
	# paint on the brush tip
	if _tool:
		var tip := _tool.position + Vector2(0, -3.0 * art_scale)
		top.draw_circle(tip, 6.0 * art_scale, paint_color())
