shader_type spatial;
render_mode unshaded, shadows_disabled;

// HDR colours (> 1.0) so the glow post-process blooms the sun.
uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float energy = 12.0;
uniform float limb_power = 0.6;

void fragment() {
	// Limb darkening: centre is white-hot, edges fall off to orange.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = mix(edge_color.rgb, core_color.rgb, pow(facing, limb_power));
	ALBEDO = col * energy;
}
