shader_type canvas_item;
// Soft outline glow around a sprite's opaque pixels.
// The quad is grown by `radius` texels in vertex() so the glow has room even
// when the art fills its whole texture. Full-texture sprites only (no regions).

uniform vec4 glow_color : source_color = vec4(1.0);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;
// Glow reach in texture pixels.
uniform float radius = 3.0;
// 0 = steady, 1 = full breathing pulse.
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed = 3.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
	vec2 dir = UV * 2.0 - 1.0; // -1 / +1 at the quad corners
	VERTEX += dir * radius;
	UV += dir * radius * TEXTURE_PIXEL_SIZE;
}

float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	bool inside = UV.x >= 0.0 && UV.y >= 0.0 && UV.x <= 1.0 && UV.y <= 1.0;
	vec4 base = inside ? texture(TEXTURE, UV) : vec4(0.0);
	float g = 0.0;
	if (glow_strength > 0.0) {
		int steps = int(ceil(radius));
		for (int r = 1; r <= steps; r++) {
			float fr = float(r);
			float fall = 1.0 - (fr - 1.0) / max(radius, 1.0);
			for (int i = 0; i < 16; i++) {
				float ang = float(i) * 0.392699; // TAU / 16
				vec2 o = vec2(cos(ang), sin(ang)) * fr * TEXTURE_PIXEL_SIZE;
				g = max(g, alpha_at(TEXTURE, UV + o) * fall);
			}
		}
	}
	float pulse = mix(1.0, 0.55 + 0.45 * sin(TIME * pulse_speed), pulse_amount);
	float ga = glow_color.a * g * glow_strength * pulse * (1.0 - base.a);
	vec4 outc = vec4(base.rgb * base.a + glow_color.rgb * ga, base.a + ga);
	outc.rgb /= max(outc.a, 0.0001);
	COLOR = outc * v_modulate;
}
