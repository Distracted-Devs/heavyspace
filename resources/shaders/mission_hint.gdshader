shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Looping "go here" ping for mission objectives: a camera-facing quad that
// flashes the object's silhouette and sends out an expanding ring every
// `period` seconds. Driven purely by TIME, so it loops forever on its own.
//
// Distances are in quad space: 0 = center, 1 = quad edge. `start_radius` should
// match the object's silhouette (object radius / quad half-size).

uniform vec4 color : source_color = vec4(1.0, 0.82, 0.1, 1.0);
uniform float intensity = 4.0;
/// Seconds between pulses.
uniform float period = 3.0;
/// Seconds each ring takes to expand and fade (should be <= period).
uniform float pulse_duration = 1.6;
/// Ring starts here (the object's silhouette).
uniform float start_radius = 0.333;
uniform float ring_width = 0.045;
/// Second, fainter ring that trails the first one.
uniform float echo_delay = 0.25;
uniform float echo_strength = 0.5;
/// Soft fill behind the ring.
uniform float halo_strength = 0.35;
/// Always-on rim glow so the target stays visible between pulses.
uniform float idle_glow = 0.15;
/// Shifts the loop in time (e.g. to desync several hints).
uniform float time_offset = 0.0;

void vertex() {
	// Camera-facing billboard that keeps the node's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

// Expanding ring for a pulse that started `t` seconds ago (0 when inactive).
float ring_pulse(float d, float t, out float halo) {
	halo = 0.0;
	if (t < 0.0 || t > pulse_duration) {
		return 0.0;
	}
	float p = t / pulse_duration;
	float eased = 1.0 - pow(1.0 - p, 3.0); // Fast out, slow settle.
	float r = mix(start_radius, 1.0 - ring_width * 2.0, eased);
	float fade = (1.0 - p) * (1.0 - p);
	float ring = 1.0 - smoothstep(0.0, ring_width, abs(d - r));
	// Soft fill between the silhouette and the ring, brightest near the ring.
	halo = smoothstep(start_radius, r, d) * step(d, r) * fade;
	return ring * fade;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float t = mod(TIME + time_offset, period);

	float halo;
	float echo_halo;
	float ring = ring_pulse(d, t, halo);
	float echo = ring_pulse(d, t - echo_delay, echo_halo) * echo_strength;

	// Rim hugging the silhouette: faint idle glow plus a flash as each pulse fires.
	float flash = exp(-t * 5.0);
	float rim = 1.0 - smoothstep(start_radius, start_radius + 0.12, d);
	rim *= step(start_radius * 0.85, d);

	float total = ring + echo + halo * halo_strength + rim * (idle_glow + flash);
	// Never reach the quad's border.
	total *= 1.0 - smoothstep(0.92, 1.0, d);

	ALBEDO = color.rgb * intensity * total;
}
