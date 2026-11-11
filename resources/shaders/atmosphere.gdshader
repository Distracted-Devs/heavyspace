shader_type spatial;
render_mode blend_add, depth_draw_never, cull_front, shadows_disabled, ambient_light_disabled, specular_disabled;

// Atmosphere shell drawn around a planet. Put it on a sphere slightly bigger
// than the planet. Only the inside (back faces) of the shell is drawn, so the
// planet covers the middle and the glow shows up as a halo around its edge.
//
// The glow strength comes from how close the view ray passes to the planet:
// densest right at the planet's surface, fading out at the edge of the shell.
// The sun side glows and the night side fades through a sunset tint.

// Main sky color on the lit side.
uniform vec4 atmosphere_color : source_color = vec4(0.35, 0.65, 1.0, 1.0);
// Tint near the day/night line.
uniform vec4 sunset_color : source_color = vec4(1.0, 0.45, 0.2, 1.0);
// Overall brightness of the lit glow.
uniform float intensity : hint_range(0.0, 10.0, 0.01) = 1.5;
// Higher = glow hugs the planet more tightly.
uniform float falloff : hint_range(0.1, 8.0, 0.01) = 2.0;
// Planet radius / atmosphere radius (0.5 / 0.55 for the default meshes).
uniform float planet_ratio : hint_range(0.5, 0.999, 0.001) = 0.909;
// How wide the day/night transition is.
uniform float terminator_softness : hint_range(0.01, 1.0, 0.01) = 0.35;
// How wide the sunset band is.
uniform float sunset_width : hint_range(0.0, 1.0, 0.01) = 0.35;
// Faint glow that stays visible on the night side.
uniform float night_glow : hint_range(0.0, 1.0, 0.01) = 0.05;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 center = NODE_POSITION_WORLD;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 dir = normalize(world_pos - cam);

	// Point on the view ray closest to the planet center.
	vec3 closest = cam + dir * dot(center - cam, dir);
	vec3 to_closest = closest - center;
	float h = length(to_closest);

	// The fragment sits on the shell, so its distance to the center is the
	// atmosphere radius (works for any scale).
	float r_atmo = length(world_pos - center);
	float r_planet = r_atmo * planet_ratio;

	float t = clamp((r_atmo - h) / max(r_atmo - r_planet, 1e-4), 0.0, 1.0);
	float glow = pow(t, falloff);

	// Use the limb direction as the normal so lighting decides day vs night.
	vec3 n_world = h > 1e-4 ? to_closest / h : -dir;
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	ALBEDO = vec3(glow * intensity);
	EMISSION = atmosphere_color.rgb * glow * night_glow;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// Wraps a bit past the terminator so the glow fades instead of cutting off.
	float day = smoothstep(-terminator_softness, terminator_softness, ndl);
	float sunset = 1.0 - smoothstep(0.0, max(sunset_width, 1e-3), ndl);
	vec3 tint = mix(atmosphere_color.rgb, sunset_color.rgb, sunset);
	// LIGHT_COLOR already includes PI; divide it out so intensity stays intuitive.
	DIFFUSE_LIGHT += tint * day * LIGHT_COLOR * ATTENUATION / PI;
}
