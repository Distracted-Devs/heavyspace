shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 violet_fog : source_color = vec4(0.55, 0.16, 0.9, 1.0);
uniform vec4 cyan_fog : source_color = vec4(0.10, 0.78, 0.95, 1.0);

uniform float patch_size : hint_range(0.25, 4.0, 0.05) = 1.8;
uniform float fog_coverage : hint_range(0.0, 1.0, 0.01) = 0.60;
uniform float fog_opacity : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float drift_speed : hint_range(0.0, 0.3, 0.005) = 0.025;

uniform float shell_roughness : hint_range(0.0, 0.4, 0.005) = 0.20;
uniform float shell_lobe_scale : hint_range(1.0, 12.0, 0.1) = 3.5;
uniform float edge_softness : hint_range(0.01, 0.8, 0.01) = 0.35;
uniform float near_fade : hint_range(0.001, 10.0, 0.001) = 0.06;

varying vec3 shell_direction;
varying flat float camera_inside;

float hash3(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
    vec3 cell = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = mix(hash3(cell),
        hash3(cell + vec3(1.0, 0.0, 0.0)), f.x);
    float b = mix(hash3(cell + vec3(0.0, 1.0, 0.0)),
        hash3(cell + vec3(1.0, 1.0, 0.0)), f.x);
    float c = mix(hash3(cell + vec3(0.0, 0.0, 1.0)),
        hash3(cell + vec3(1.0, 0.0, 1.0)), f.x);
    float d = mix(hash3(cell + vec3(0.0, 1.0, 1.0)),
        hash3(cell + vec3(1.0, 1.0, 1.0)), f.x);

    return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float shell_radius(vec3 direction, float base_radius) {
    vec3 p = direction * shell_lobe_scale;
    float broad = noise3(p + vec3(2.4, 5.1, 8.3));
    float detail = noise3(p.yzx * 2.3 + vec3(7.2, 1.6, 4.5));
    float lobes = smoothstep(0.3, 0.8, broad * 0.8 + detail * 0.2);

    // Push the fog outward from the base sphere.
    return base_radius * (1.0 + lobes * shell_roughness);
}

void vertex() {
    float base_radius = length(VERTEX);
    shell_direction = VERTEX / base_radius;
    VERTEX = shell_direction * shell_radius(shell_direction, base_radius);

    vec3 local_camera = (inverse(MODEL_MATRIX)
        * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
    float camera_distance = length(local_camera);
    vec3 camera_direction = local_camera / max(camera_distance, 0.0001);

    camera_inside = step(
        camera_distance, shell_radius(camera_direction, base_radius)
    );
}

void fragment() {
    // Use the outer face on approach and the inner face after entry.
    if (FRONT_FACING == (camera_inside > 0.5)) {
        discard;
    }

    float t = TIME * drift_speed;
    vec3 p = normalize(shell_direction) * (5.0 / patch_size);
    float broad = noise3(p + vec3(t, 0.0, 4.0));
    float wisps = noise3(p.yzx * 2.7 + vec3(3.0, -t * 1.4, 8.0));
    float grain = noise3(p.zxy * 6.1 + vec3(6.0, 1.0, t));

    float density = broad * 0.60 + wisps * 0.30 + grain * 0.10;
    float threshold = mix(0.75, 0.22, fog_coverage);
    float patches = smoothstep(threshold, threshold + 0.22, density);

    float camera_fade = smoothstep(0.0, near_fade, length(VERTEX));
    float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float edge_fade = smoothstep(0.0, edge_softness, facing);

    ALBEDO = mix(violet_fog.rgb, cyan_fog.rgb,
        smoothstep(0.35, 0.72, wisps));
    ALPHA = patches * fog_opacity * camera_fade * edge_fade;
}