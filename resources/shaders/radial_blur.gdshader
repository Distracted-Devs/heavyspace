shader_type canvas_item;

const int TAPS = 12;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
uniform vec2 centre = vec2(0.5);
uniform float clear_radius = 0.05;
uniform float falloff = 0.35;
uniform float reach = 0.12;
uniform float aberration = 0.0;

void fragment() {
	vec2 away = SCREEN_UV - centre;
	float ramp = smoothstep(clear_radius, clear_radius + falloff, length(away));
	vec2 streak = away * ramp * strength * reach;
	vec2 split = away * ramp * aberration;
	vec3 sum = vec3(0.0);
	for (int tap = 0; tap < TAPS; tap++) {
		vec2 at = SCREEN_UV - streak * float(tap) / float(TAPS - 1);
		sum.r += texture(screen_texture, at + split).r;
		sum.g += texture(screen_texture, at).g;
		sum.b += texture(screen_texture, at - split).b;
	}
	COLOR = vec4(sum / float(TAPS), 1.0);
}
