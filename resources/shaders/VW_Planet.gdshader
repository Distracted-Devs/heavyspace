shader_type spatial;
render_mode unshaded, shadows_disabled;

// Purple oceans.
uniform vec4 deep_water : source_color =
    vec4(0.07, 0.005, 0.22, 1.0);
uniform vec4 shallow_water : source_color =
    vec4(0.42, 0.04, 0.72, 1.0);

// Colourful land regions.
uniform vec4 beach_color : source_color =
    vec4(1.0, 0.08, 0.55, 1.0);
uniform vec4 lowland_color : source_color =
    vec4(0.01, 0.65, 0.57, 1.0);
uniform vec4 highland_color : source_color =
    vec4(0.15, 0.95, 0.68, 1.0);
uniform vec4 peak_color : source_color =
    vec4(1.0, 0.72, 0.25, 1.0);

// Glowing contours and atmosphere.
uniform vec4 contour_color : source_color =
    vec4(0.02, 0.65, 1.0, 1.0);
uniform vec4 rim_color : source_color =
    vec4(0.55, 0.08, 1.0, 1.0);

// Shape and continent controls.
uniform float planet_radius : hint_range(0.01, 100.0) = 0.5;
uniform float continent_scale : hint_range(0.5, 8.0) = 2.6;
uniform float sea_level : hint_range(0.2, 0.8) = 0.48;
uniform float bump_height : hint_range(0.0, 0.3) = 0.12;
uniform float mountain_detail : hint_range(0.0, 1.0) = 0.55;
uniform vec3 pattern_offset = vec3(3.2, 7.1, 1.8);

// Contour controls.
uniform float contour_count : hint_range(2.0, 50.0, 1.0) = 18.0;
uniform float contour_width : hint_range(0.01, 0.3) = 0.045;
uniform float contour_energy : hint_range(0.0, 5.0) = 1.5;

// Brightness controls.
uniform float surface_brightness : hint_range(0.0, 3.0) = 1.0;
uniform float edge_brightness : hint_range(0.0, 1.0) = 0.45;
uniform float rim_energy : hint_range(0.0, 5.0) = 1.0;

varying vec3 sphere_position;

// Repeatable random values.
float hash3(vec3 p) {
    return fract(
        sin(dot(p, vec3(127.1, 311.7, 74.7)))
        * 43758.5453
    );
}

// Smooth 3D noise.
float noise3(vec3 p) {
    vec3 cell = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);

    float a = hash3(cell);
    float b = hash3(cell + vec3(1.0, 0.0, 0.0));
    float c = hash3(cell + vec3(0.0, 1.0, 0.0));
    float d = hash3(cell + vec3(1.0, 1.0, 0.0));
    float e = hash3(cell + vec3(0.0, 0.0, 1.0));
    float f1 = hash3(cell + vec3(1.0, 0.0, 1.0));
    float g = hash3(cell + vec3(0.0, 1.0, 1.0));
    float h = hash3(cell + vec3(1.0, 1.0, 1.0));

    return mix(
        mix(mix(a, b, u.x), mix(c, d, u.x), u.y),
        mix(mix(e, f1, u.x), mix(g, h, u.x), u.y),
        u.z
    );
}

float terrain_height(vec3 direction) {
    vec3 p = direction * continent_scale + pattern_offset;

    // Distort the noise to make irregular coastlines.
    vec3 warp = vec3(
        noise3(p + vec3(4.1, 1.7, 8.3)),
        noise3(p + vec3(9.2, 5.4, 2.1)),
        noise3(p + vec3(2.8, 8.6, 6.4))
    );

    p += (warp - vec3(0.5)) * 1.3;

    float broad = noise3(p);
    float detail = noise3(p * 2.7 + vec3(5.2));

    return mix(broad, detail, mountain_detail * 0.35);
}

void vertex() {
    // Assumes a sphere centred on its local origin.
    vec3 direction = normalize(VERTEX);
    sphere_position = direction;

    float terrain = terrain_height(direction);

    float elevation = max(
        (terrain - sea_level) / (1.0 - sea_level),
        0.0
    );

    // Physically raise the land above the ocean.
    VERTEX += direction
        * elevation
        * bump_height
        * planet_radius;
}

void fragment() {
    vec3 direction = normalize(sphere_position);
    float terrain = terrain_height(direction);

    // A narrow transition creates defined coastlines.
    float land_mask = smoothstep(
        sea_level - 0.005,
        sea_level + 0.005,
        terrain
    );

    float elevation = clamp(
        (terrain - sea_level) / (1.0 - sea_level),
        0.0,
        1.0
    );

    // Dark purple ocean becoming violet near shore.
    float shallows = smoothstep(
        sea_level - 0.18,
        sea_level,
        terrain
    );

    vec3 water = mix(
        deep_water.rgb,
        shallow_water.rgb,
        shallows
    );

    // Pink coastline → turquoise land → mint → gold peaks.
    vec3 land = mix(
        beach_color.rgb,
        lowland_color.rgb,
        smoothstep(0.0, 0.045, elevation)
    );

    land = mix(
        land,
        highland_color.rgb,
        smoothstep(0.06, 0.25, elevation)
    );

    land = mix(
        land,
        peak_color.rgb,
        smoothstep(0.25, 0.5, elevation)
    );

    vec3 col = mix(water, land, land_mask);

    // Topographic lines follow the land's elevation.
    float contour_position = elevation * contour_count;
    float distance_to_line =
        abs(fract(contour_position + 0.5) - 0.5);

    float smoothing = max(fwidth(contour_position), 0.001);

    float contours = 1.0 - smoothstep(
        contour_width,
        contour_width + smoothing,
        distance_to_line
    );

    contours *= land_mask * smoothstep(0.01, 0.035, elevation);

    // Facing-based shading keeps the spherical appearance.
    float facing = clamp(
        dot(normalize(NORMAL), normalize(VIEW)),
        0.0,
        1.0
    );

    float shading = mix(
        edge_brightness,
        1.0,
        pow(facing, 0.7)
    );

    float rim = pow(1.0 - facing, 4.0);

    ALBEDO = col * surface_brightness * shading;

    EMISSION =
        contour_color.rgb * contours * contour_energy
        + rim_color.rgb * rim * rim_energy;
}