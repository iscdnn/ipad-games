extends RubStep
## Sand the surface clean: rub the sanding block back and forth.


func _init() -> void:
	super._init()
	title = "Sand it smooth!"
	tool_texture = preload("res://assets/sprites/sanding_block.png")
	tool_tip = Vector2(20, 12)
	rub_sound = &"sand"


func rub_amount() -> float:
	var c := config as SandStepConfig
	return 1.0 / (c.passes if c else 3.0)


func _style_surface(s: RubSurface) -> void:
	s.mat.set_shader_parameter(&"before_tint", Color(0.82, 0.76, 0.7))
	s.mat.set_shader_parameter(&"before_grime", 0.85)


func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 24
	p.lifetime = 0.5
	p.direction = Vector2(0, 1)
	p.spread = 80.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 120.0
	p.gravity = Vector2(0, 400)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = Color(0.95, 0.88, 0.7)
	return p
