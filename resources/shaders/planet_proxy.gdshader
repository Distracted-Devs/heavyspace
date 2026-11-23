shader_type spatial;

// Each instance's transform holds only its radius (as scale), and its
// INSTANCE_CUSTOM is (orbit radius, height, phase, angular speed) in the
// node's frame. This must match Orbit.position, and the seed must match
// PlanetSeed.of. COLOR.rgb tints the body, and COLOR.a < 0.5 hides it.

#include "res://resources/shaders/planet_surface.gdshaderinc"

global uniform float clock_time;

void vertex() {
	sphere_position = normalize(VERTEX);
	vec4 orbit = INSTANCE_CUSTOM;
	body_seed = fract(orbit.x * 0.0137 + orbit.z * 0.6180339);
	tint = COLOR.rgb;
	float angle = orbit.z + orbit.w * clock_time;
	vec3 offset = vec3(cos(angle) * orbit.x, orbit.y, sin(angle) * orbit.x);
	float radius = length(MODEL_MATRIX[0].xyz);
	VERTEX = COLOR.a < 0.5
		? vec3(0.0)
		: raised_vertex(VERTEX, body_seed) + offset / radius;
}

void fragment() {
	planet_fragment(NORMAL, VIEW, ALBEDO, EMISSION);
}
