shader_type particles;

uniform vec3 box_centre = vec3(0.0);
uniform float box_half = 20.0;
uniform vec3 drift = vec3(0.0, 0.0, 1.0);
uniform float edge_fade = 0.6;

// A PCG hash: cheap, well spread random numbers from the particle's seed.
float next_random(inout uint state) {
	state = state * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	word = (word >> 22u) ^ word;
	return float(word) / 4294967295.0;
}

void start() {
	uint state = RANDOM_SEED + uint(INDEX) * 7919u + NUMBER * 104729u;
	vec3 spot = vec3(
		next_random(state), next_random(state), next_random(state)
	);
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = box_centre + (spot * 2.0 - 1.0) * box_half;
	CUSTOM.x = 0.6 + 0.8 * next_random(state);
	VELOCITY = drift * CUSTOM.x;
	COLOR = vec4(1.0, 1.0, 1.0, 0.0);
}

void process() {
	vec3 offset = TRANSFORM[3].xyz - box_centre;
	offset = mod(offset + box_half, 2.0 * box_half) - box_half;
	TRANSFORM[3].xyz = box_centre + offset;
	VELOCITY = drift * CUSTOM.x;
	float edge = max(max(abs(offset.x), abs(offset.y)), abs(offset.z));
	COLOR = vec4(1.0, 1.0, 1.0, 1.0 - smoothstep(edge_fade, 1.0, edge / box_half));
}
