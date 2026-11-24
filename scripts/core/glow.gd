class_name Glow
## Outline glow for usable objects (any Sprite2D / CanvasItem with a full texture).
##
##   Glow.set_state(saw, Glow.IDLE)    faint white pulse: "you can use this"
##   Glow.set_state(saw, Glow.ACTIVE)  bright purple: "you're holding it"
##   Glow.set_state(saw, Glow.OFF)     no glow
##
## Each item gets its own ShaderMaterial on first use, so states don't leak
## between items. Changes fade over `time` seconds.

enum { OFF, IDLE, ACTIVE }

const SHADER := preload("res://shaders/outline_glow.gdshader")

## [color, strength, pulse_amount] per state. Tweak to taste.
static var styles := {
	OFF: [Color(1, 1, 1), 0.0, 0.0],
	IDLE: [Color(1, 1, 1, 0.9), 0.45, 1.0],
	ACTIVE: [Color(0.72, 0.35, 1.0), 1.0, 0.0],
}
## Glow reach in texture pixels.
static var radius := 3.0


static func set_state(item: CanvasItem, state: int, time := 0.15) -> void:
	var mat := _material(item)
	var style: Array = styles[state]
	if item.has_meta(&"glow_tween"):
		var old: Tween = item.get_meta(&"glow_tween")
		if old and old.is_valid():
			old.kill()
	var tw := item.create_tween().set_parallel()
	tw.tween_property(mat, "shader_parameter/glow_strength", style[1], time)
	tw.tween_property(mat, "shader_parameter/pulse_amount", style[2], time)
	# keep the old colour while fading out, so OFF doesn't flash white
	if style[1] > 0.0:
		tw.tween_property(mat, "shader_parameter/glow_color", style[0], time)
	item.set_meta(&"glow_tween", tw)


static func _material(item: CanvasItem) -> ShaderMaterial:
	var mat := item.material as ShaderMaterial
	if mat == null or mat.shader != SHADER:
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter(&"radius", radius)
		mat.set_shader_parameter(&"glow_strength", 0.0)
		mat.set_shader_parameter(&"pulse_amount", 0.0)
		mat.set_shader_parameter(&"glow_color", styles[IDLE][0])
		item.material = mat
	return mat
