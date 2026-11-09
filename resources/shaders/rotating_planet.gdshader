shader_type spatial;

// Spins an equirectangular texture (e.g. earth.jpg) around a sphere.
// The UV is rebuilt from the object-space direction each frame, so the
// planet truly rotates around an arbitrary (tilted) axis instead of just
// scrolling the texture.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

// Axis the planet spins around (object space, normalized internally).
uniform vec3 rotation_axis = vec3(0.0, 1.0, 0.0);
// Extra tilt of the axis in degrees (Earth's is ~23.4). Tilts toward +X around Z.
uniform float axial_tilt_degrees : hint_range(-90.0, 90.0) = 23.4;
// Spin speed in degrees per second. Negative values reverse the direction.
uniform float rotation_speed_degrees = 3.0;
// Static rotation offset in degrees (picks which side faces the camera at t=0).
uniform float start_angle_degrees = 0.0;
// Flip the texture horizontally if it appears mirrored.
uniform bool flip_horizontal = false;

varying vec3 obj_dir;

vec3 rotate_around(vec3 v, vec3 axis, float angle) {
	// Rodrigues' rotation formula.
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void vertex() {
	obj_dir = VERTEX;
}

void fragment() {
	vec3 axis = normalize(rotation_axis);
	axis = rotate_around(axis, vec3(0.0, 0.0, 1.0), -radians(axial_tilt_degrees));

	// Build a frame where the spin axis is "up", then undo the spin on the
	// sample direction so the surface appears to rotate forward.
	float angle = radians(start_angle_degrees + TIME * rotation_speed_degrees);
	vec3 d = rotate_around(normalize(obj_dir), axis, -angle);

	// Basis aligned to the axis: tangent (lon 0), bitangent, axis.
	vec3 ref = abs(axis.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec3 t = normalize(cross(axis, ref));
	vec3 b = cross(axis, t);

	float lon = atan(dot(d, b), dot(d, t)); // counter-clockwise seen from the north pole
	float lat = acos(clamp(dot(d, axis), -1.0, 1.0));

	float u = lon / TAU + 0.5;
	if (flip_horizontal) {
		u = 1.0 - u;
	}
	vec2 uv = vec2(u, lat / PI);

	// Avoid the mip seam where u wraps from 1 to 0 (Tarini's trick).
	float u_alt = fract(u + 0.5) - 0.5;
	vec2 dx = vec2(dFdx(u), dFdx(uv.y));
	vec2 dy = vec2(dFdy(u), dFdy(uv.y));
	vec2 dx_alt = vec2(dFdx(u_alt), dx.y);
	vec2 dy_alt = vec2(dFdy(u_alt), dy.y);
	if (abs(dx_alt.x) + abs(dy_alt.x) < abs(dx.x) + abs(dy.x)) {
		dx = dx_alt;
		dy = dy_alt;
	}

	vec4 tex = textureGrad(albedo_texture, uv, dx, dy);
	ALBEDO = tex.rgb * albedo_tint.rgb;
	ROUGHNESS = roughness;
}
