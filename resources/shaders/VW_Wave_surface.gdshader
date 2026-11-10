shader_type spatial;
render_mode unshaded;

uniform vec4 bottom_color : source_color =
    vec4(0.12, 0.02, 0.35, 1.0);
uniform vec4 middle_color : source_color =
    vec4(1.0, 0.08, 0.55, 1.0);
uniform vec4 top_color : source_color =
    vec4(0.1, 0.9, 1.0, 1.0);
uniform vec4 rim_color : source_color =
    vec4(0.2, 0.8, 1.0, 1.0);

// Half the mesh's height before node scaling.
uniform float half_height : hint_range(0.01, 10.0) = 0.5;

uniform float band_count : hint_range(2.0, 20.0, 1.0) = 7.0;
uniform float wave_amount : hint_range(0.0, 0.3) = 0.06;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.3;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.7;

varying vec3 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    // Convert vertical position into a value between 0 and 1.
    float height = local_position.y / (half_height * 2.0) + 0.5;

    // Bend the colour bands around the planet.
    height += sin(
        local_position.x * 9.0
        + local_position.z * 6.0
        + TIME * wave_speed
    ) * wave_amount;

    height = clamp(height, 0.0, 1.0);

    // Turn the smooth gradient into distinct colour bands.
    float stepped = floor(height * band_count) / band_count;

    vec3 col = mix(
        bottom_color.rgb,
        middle_color.rgb,
        smoothstep(0.0, 0.5, stepped)
    );

    col = mix(
        col,
        top_color.rgb,
        smoothstep(0.5, 1.0, stepped)
    );

    // Bright colour around the visible silhouette.
    float rim = pow(
        1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0),
        3.0
    );

    ALBEDO = col + rim_color.rgb * rim * rim_strength;
}