shader_type canvas_item;

void fragment() {
	float line = step(0.5, fract(FRAGCOORD.y / 3.0));
	COLOR = vec4(0.0, 0.0, 0.0, 0.18 * line);
}
