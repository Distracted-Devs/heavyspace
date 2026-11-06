
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

// Size of each "big pixel" in screen pixels. 1 = no effect.
uniform float pixel_size : hint_range(1.0, 32.0, 1.0) = 4.0;

void fragment() {
	
	// SCREEN_PIXEL_SIZE = 1 / screen resolution, so this is one block's size in UV space.
	vec2 block = pixel_size * SCREEN_PIXEL_SIZE;

	vec2 uv = (floor(SCREEN_UV / block) + 0.5) * block;
	COLOR = texture(screen_tex, uv);
}
