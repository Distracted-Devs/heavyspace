shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.3, 0.9, 1.0, 0.05);

void fragment() {
	float line = step(0.5, fract(FRAGCOORD.y / 3.0));
	vec2 edge = abs(UV - 0.5) * 2.0;
	float vignette = smoothstep(0.6, 1.0, max(edge.x, edge.y));
	COLOR = vec4(tint.rgb, tint.a * line + vignette * 0.08);
}
