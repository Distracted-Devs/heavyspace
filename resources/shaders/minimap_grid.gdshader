shader_type canvas_item;

uniform vec4 line_colour : source_color = vec4(0.3, 0.9, 1.0, 0.0627451);
uniform vec4 fill_colour : source_color = vec4(0.0, 0.04, 0.07, 0.35);
uniform float cells = 12.0;
uniform float line_px = 1.0;
uniform vec2 size = vec2(256.0);

void fragment() {
	vec2 cell = fract(UV * cells);
	vec2 to_line = min(cell, 1.0 - cell) * size / cells;
	float line = 1.0 - step(line_px, min(to_line.x, to_line.y));
	COLOR = mix(fill_colour, line_colour, line);
}
