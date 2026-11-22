shader_type spatial;

// Each instance's transform holds only its radius (as scale), and its
// INSTANCE_CUSTOM is (orbit radius, height, phase, angular speed) in the
// node's frame. This must match Orbit.position.
// COLOR.rgb tints the body, and COLOR.a < 0.5 hides it.

global uniform float clock_time;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;

varying vec3 tint;

void vertex() {
	vec4 orbit = INSTANCE_CUSTOM;
	float angle = orbit.z + orbit.w * clock_time;
	vec3 offset = vec3(cos(angle) * orbit.x, orbit.y, sin(angle) * orbit.x);
	float radius = length(MODEL_MATRIX[0].xyz);
	VERTEX = COLOR.a < 0.5 ? vec3(0.0) : VERTEX + offset / radius;
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * tint;
	ROUGHNESS = 1.0;
}
