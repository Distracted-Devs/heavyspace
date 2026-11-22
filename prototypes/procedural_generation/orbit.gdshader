shader_type spatial;
// Draws MultiMesh instances on circular orbits, computed from time on the GPU.
// INSTANCE_CUSTOM = (orbit radius, height off the plane, phase, angular speed),
// in the MultiMeshInstance3D's local frame. The instance transform holds only
// the body's scale (its radius). COLOR.rgb is the tint, and COLOR.a < 0.5
// hides the instance (while a real body stands in for it).

uniform float orbit_time;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;

varying vec3 tint;

void vertex() {
	vec4 orbit = INSTANCE_CUSTOM;
	float a = orbit.z + orbit.w * orbit_time;
	vec3 offset = vec3(cos(a) * orbit.x, orbit.y, sin(a) * orbit.x);
	float r = length(MODEL_MATRIX[0].xyz);
	VERTEX = COLOR.a < 0.5 ? vec3(0.0) : VERTEX + offset / r;
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * tint;
	ROUGHNESS = 1.0;
}
