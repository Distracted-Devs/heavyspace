#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D depth_texture;
layout(rgba16f, set = 0, binding = 2) uniform restrict image2D source_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float pixel_size;
	float copy_pass;
} params;

bool is_geometry(ivec2 p) {
	return texelFetch(depth_texture, p, 0).r > 0.0;
}

void main() {
	ivec2 size = ivec2(params.raster_size);
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	if (params.copy_pass > 0.5) {
		imageStore(source_image, uv, imageLoad(color_image, uv));
		return;
	}

	int block = max(int(params.pixel_size), 1);
	ivec2 origin = (uv / block) * block;
	ivec2 max_p = size - 1;
	int half_block = block / 2;
	int quarter = max(block / 4, 0);

	ivec2 samples[5] = ivec2[](
		origin + ivec2(half_block),
		origin + ivec2(quarter, quarter),
		origin + ivec2(block - 1 - quarter, quarter),
		origin + ivec2(quarter, block - 1 - quarter),
		origin + ivec2(block - 1 - quarter, block - 1 - quarter)
	);

	for (int i = 0; i < 5; i++) {
		ivec2 p = min(samples[i], max_p);
		if (is_geometry(p)) {
			imageStore(color_image, uv, imageLoad(source_image, p));
			return;
		}
	}

	if (is_geometry(uv)) {
		imageStore(color_image, uv, imageLoad(source_image, uv));
	}
}
