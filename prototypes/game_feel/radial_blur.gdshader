shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
uniform vec2 centre = vec2(0.5);
uniform float clear_radius = 0.12;
uniform float falloff = 0.35;
uniform float reach = 0.12;
// Chromatic aberration: red pushed out, blue pulled in, away from the centre.
uniform float aberration = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - centre;
	float ramp = smoothstep(clear_radius, clear_radius + falloff, length(d));
	float m = ramp * strength;
	vec2 split = d * aberration * ramp;
	vec3 c = vec3(0.0);
	for (int i = 0; i < 12; i++) {
		float t = float(i) / 11.0;
		vec2 at = uv - d * m * reach * t;
		c.r += texture(screen_tex, at + split).r;
		c.g += texture(screen_tex, at).g;
		c.b += texture(screen_tex, at - split).b;
	}
	COLOR = vec4(c / 12.0, 1.0);
}
