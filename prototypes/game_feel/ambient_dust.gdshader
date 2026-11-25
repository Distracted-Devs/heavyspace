shader_type particles;

// Space dust: motes live in a box around the ship and wrap round its edges,
// so there are always the same number nearby, however fast the ship goes.
// They drift lazily along `drift` and fade out near the box's edges so the
// wrap doesn't pop.

uniform vec3 box_centre = vec3(0.0);
uniform float box_half = 20.0;
uniform vec3 drift = vec3(0.0, 0.0, -1.0);
uniform float edge_fade = 0.6;

float rand(inout uint s) {
	s = s * 747796405u + 2891336453u;
	uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
	w = (w >> 22u) ^ w;
	return float(w) / 4294967295.0;
}

void start() {
	uint s = RANDOM_SEED + uint(INDEX) * 7919u + NUMBER * 104729u;
	vec3 r = vec3(rand(s), rand(s), rand(s)) * 2.0 - 1.0;
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = box_centre + r * box_half;
	CUSTOM.x = 0.6 + 0.8 * rand(s);
	VELOCITY = drift * CUSTOM.x;
	COLOR = vec4(1.0, 1.0, 1.0, 0.0);
}

void process() {
	vec3 rel = TRANSFORM[3].xyz - box_centre;
	rel = mod(rel + box_half, 2.0 * box_half) - box_half;
	TRANSFORM[3].xyz = box_centre + rel;
	VELOCITY = drift * CUSTOM.x;
	float edge = max(max(abs(rel.x), abs(rel.y)), abs(rel.z)) / box_half;
	COLOR = vec4(1.0, 1.0, 1.0, 1.0 - smoothstep(edge_fade, 1.0, edge));
}
