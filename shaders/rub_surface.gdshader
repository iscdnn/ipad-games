shader_type canvas_item;
// Blends a surface from its "before" look to its "after" look by a coverage
// mask (one mask pixel per texture pixel). Used by RubSurface.

uniform sampler2D mask_tex : filter_nearest;
// Everything at least this covered (tweened to 1 to finish the surface).
uniform float fill = 0.0;

// Before: texture * before_tint, darkened with speckled grime.
uniform vec4 before_tint : source_color = vec4(1.0);
uniform float before_grime : hint_range(0.0, 1.0) = 0.0;
// After: texture * after_tint, or paint (texture shading * paint_color).
uniform vec4 after_tint : source_color = vec4(1.0);
uniform vec4 paint_color : source_color = vec4(1.0);
uniform float paint_amount : hint_range(0.0, 1.0) = 0.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	float grime = before_grime * (0.55 + 0.45 * step(0.6, hash(floor(texel / 2.0))));
	vec3 before = tex.rgb * before_tint.rgb * (1.0 - 0.6 * grime);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 painted = paint_color.rgb * (0.7 + 0.45 * luma);
	vec3 after = mix(tex.rgb * after_tint.rgb, painted, paint_amount);
	float m = max(texture(mask_tex, UV).r, fill);
	COLOR = vec4(mix(before, after, m), tex.a) * v_modulate;
}
