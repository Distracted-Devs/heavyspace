// Ayla's vaporwave planet surface, shared by planet.gdshader (live bodies)
// and planet_proxy.gdshader (drawn proxies). Each body's seed, from
// PlanetSeed, shifts its terrain and rotates its palette's hue.
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

uniform float hue_variety : hint_range(0.0, 1.0) = 0.6;

varying vec3 sphere_position;
varying float body_seed;
varying vec3 tint;

vec3 hue_shift(vec3 colour, float turns) {
    float angle = turns * TAU;
    vec3 axis = vec3(0.57735);
    return colour * cos(angle) + cross(axis, colour) * sin(angle)
        + axis * dot(axis, colour) * (1.0 - cos(angle));
}


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

float terrain_height(vec3 direction, float seed_value) {
    vec3 p = (direction + seed_value * 13.0) * continent_scale + pattern_offset;

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

vec3 raised_vertex(vec3 vertex, float seed) {
    vec3 direction = normalize(vertex);
    float elevation = max(
        (terrain_height(direction, seed) - sea_level) / (1.0 - sea_level),
        0.0
    );
    return vertex + direction * elevation * bump_height;
}

void planet_fragment(vec3 normal, vec3 view, out vec3 albedo, out vec3 emission) {
    vec3 direction = normalize(sphere_position);
    float terrain = terrain_height(direction, body_seed);

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
        dot(normalize(normal), normalize(view)),
        0.0,
        1.0
    );

    float shading = mix(
        edge_brightness,
        1.0,
        pow(facing, 0.7)
    );

    float rim = pow(1.0 - facing, 4.0);

    albedo = hue_shift(col, body_seed * hue_variety) * tint * surface_brightness * shading;

    emission =
        hue_shift(contour_color.rgb, body_seed * hue_variety) * contours * contour_energy
        + rim_color.rgb * rim * rim_energy;
}
