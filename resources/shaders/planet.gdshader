shader_type spatial;

#include "res://resources/shaders/planet_surface.gdshaderinc"

instance uniform float seed = 0.0;

void vertex() {
	sphere_position = normalize(VERTEX);
	body_seed = seed;
	tint = vec3(1.0);
	VERTEX = raised_vertex(VERTEX, body_seed);
}

void fragment() {
	planet_fragment(NORMAL, VIEW, ALBEDO, EMISSION);
}
