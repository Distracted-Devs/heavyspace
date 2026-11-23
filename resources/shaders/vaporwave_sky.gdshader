shader_type sky;

uniform vec4 space_color : source_color = vec4(0.025, 0.012, 0.065, 1.0);
uniform vec4 violet : source_color = vec4(0.62, 0.20, 0.92, 1.0);
uniform vec4 magenta : source_color = vec4(0.95, 0.22, 0.57, 1.0);
uniform vec4 cyan : source_color = vec4(0.10, 0.76, 0.94, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.84, 0.72, 1.0);

uniform float violet_size : hint_range(0.25, 4.0, 0.05) = 2.2;
uniform float magenta_size : hint_range(0.25, 4.0, 0.05) = 1.1;
uniform float cyan_size : hint_range(0.25, 4.0, 0.05) = 0.5;

uniform float band_width : hint_range(0.08, 0.55, 0.01) = 0.18;
uniform float core_strength : hint_range(0.0, 3.0, 0.05) = 1.1;
uniform float dust_strength : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float cloud_strength : hint_range(0.0, 2.0, 0.01) = 0.85;
uniform float drift_speed : hint_range(0.0, 0.15, 0.001) = 0.012;

uniform float line_density : hint_range(4.0, 60.0, 1.0) = 26.0;
uniform float line_strength : hint_range(0.0, 1.0, 0.01) = 0.10;
uniform float line_coverage : hint_range(0.0, 1.0, 0.01) = 1.0;

uniform float star_strength : hint_range(0.0, 2.0, 0.01) = 0.85;
uniform float twinkle_amount : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float twinkle_speed : hint_range(0.0, 4.0, 0.05) = 1.0;

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

float star_layer(vec3 dir, float scale, float threshold, float time) {
    vec3 grid = dir * scale;
    vec3 cell = floor(grid);
    float seed = hash3(cell);
    float distance_to_center = length(fract(grid) - 0.5);
    float shape = 1.0 - smoothstep(0.08, 0.36, distance_to_center);

    // Each star has its own phase and twinkle rate.
    float phase = hash3(cell + vec3(13.0, 7.0, 19.0)) * 6.283185;
    float rate = mix(1.4, 4.0, hash3(cell + vec3(5.0, 31.0, 11.0)));
    float pulse = 0.5 + 0.5 * sin(time * twinkle_speed * rate + phase);
    float brightness = mix(1.0, mix(0.25, 1.4, pulse), twinkle_amount);

    return step(threshold, seed) * shape * brightness;
}

void sky() {
    vec3 dir = EYEDIR;
    float t = TIME * drift_speed;

    vec3 band_normal = normalize(vec3(0.30, 1.0, 0.20));
    vec3 core_direction = normalize(cross(vec3(1.0, 0.0, 0.0), band_normal));
    float core_facing = max(dot(dir, core_direction), 0.0);

    float warp = noise3(dir * 4.0 + vec3(2.0, 8.0, 1.0)) - 0.5;
    float latitude = dot(dir, band_normal) + warp * 0.13;
    float width = band_width * (0.75 + 0.5 * pow(core_facing, 4.0));
    float band_distance = latitude / width;
    float core_distance = latitude / (width * 0.65);
    float band = exp(-band_distance * band_distance);
    float core = pow(core_facing, 18.0) * exp(-core_distance * core_distance);

    float violet_patches = smoothstep(0.32, 0.76,
        noise3(dir * (6.0 / violet_size) + vec3(t, 3.0, 2.0)));
    float magenta_patches = smoothstep(0.38, 0.78,
        noise3(dir * (6.0 / magenta_size) + vec3(8.0, -t * 1.3, 5.0)));
    float cyan_patches = smoothstep(0.43, 0.80,
        noise3(dir * (6.0 / cyan_size) + vec3(2.0, 7.0, t * 1.7)));

    float wisps = noise3(dir * 13.0 + vec3(t * 0.6, 4.0, 0.0));
    float grain = noise3(dir * 32.0 + vec3(0.0, 1.0, -t));
    float cloud_texture = 0.25 + 0.75 * smoothstep(
        0.30, 0.76, wisps * 0.72 + grain * 0.28
    );

    vec3 clouds = (
        violet.rgb * violet_patches * 0.55
        + magenta.rgb * magenta_patches * 0.42
        + cyan.rgb * cyan_patches * 0.35
    ) * cloud_texture * band * cloud_strength;

    float dust_noise = noise3(dir * 11.0 + vec3(9.0, 2.0, 6.0));
    float dust_distance = (latitude + (dust_noise - 0.5) * 0.12)
        / (width * 0.22);
    float dust = exp(-dust_distance * dust_distance);
    float transmission = 1.0 - dust * dust_strength * mix(0.5, 1.0, grain);

    // Widen the filament region independently of the galaxy band.
    float line_width = mix(width, 1.1, line_coverage);
    float line_distance = latitude / line_width;
    float line_mask = mix(
        exp(-line_distance * line_distance), 1.0, line_coverage
    );

    float line_phase = (latitude * 0.9 + warp * 0.26 + wisps * 0.05)
        * line_density;
    float contour = abs(fract(line_phase) - 0.5);
    float filaments = (1.0 - smoothstep(0.015, 0.11, contour))
        * mix(0.25, 1.0, smoothstep(0.33, 0.72, wisps))
        * line_mask;

    float foreground_stars = star_layer(dir, 105.0, 0.97, TIME);
    float galactic_stars = star_layer(dir, 210.0, mix(0.995, 0.83, band), TIME)
        * band;
    vec3 star_color = vec3(0.82, 0.89, 1.0);

    COLOR = space_color.rgb
        + transmission * (
            clouds
            + core_color.rgb * core * core_strength
            + cyan.rgb * filaments * line_strength
            + star_color * galactic_stars * star_strength
        )
        + star_color * foreground_stars * star_strength;
}