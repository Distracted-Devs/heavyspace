shader_type spatial;
render_mode unshaded, shadows_disabled;

// Reference colours: yellow → orange → pink.
uniform vec4 sunset_bottom : source_color =
    vec4(1.0, 0.75, 0.08, 1.0);
uniform vec4 sunset_middle : source_color =
    vec4(1.0, 0.35, 0.12, 1.0);
uniform vec4 sunset_top : source_color =
    vec4(1.0, 0.02, 0.42, 1.0);

// Brightness. Increase gradually to preserve the colours.
uniform float sun_energy : hint_range(0.0, 20.0) = 2.5;

// Gentle centre-to-edge shading.
uniform float limb_power : hint_range(0.01, 4.0) = 0.6;
uniform float edge_brightness : hint_range(0.0, 1.0) = 0.85;

// Half the mesh's height BEFORE node scaling.
uniform float half_height : hint_range(0.01, 100.0) = 0.5;
uniform float gradient_center_y = 0.0;

// Horizontal stripes.
uniform float stripe_count : hint_range(2.0, 60.0, 1.0) = 24.0;
uniform float stripe_strength : hint_range(0.0, 1.0) = 0.22;
uniform float stripe_width : hint_range(0.05, 0.9) = 0.3;

// Subtle animated waves.
// Increase wave_amount for more obvious bending.
uniform float wave_amount : hint_range(0.0, 0.1) = 0.004;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.3;
uniform float wave_frequency : hint_range(0.0, 20.0) = 5.0;

varying vec3 local_position;

void vertex() {
    local_position = VERTEX;
}

void fragment() {
    // Vertical position from bottom (0) to top (1).
    float height =
        (local_position.y - gradient_center_y)
        / (half_height * 2.0) + 0.5;

    // Animated bending of the gradient and stripes.
    float wave = sin(
        local_position.x * wave_frequency
        + local_position.z * wave_frequency * 0.667
        + TIME * wave_speed
    ) * wave_amount;

    float gradient_height = clamp(height + wave, 0.0, 1.0);

    // Smooth yellow → orange → pink gradient.
    vec3 col = mix(
        sunset_bottom.rgb,
        sunset_middle.rgb,
        smoothstep(0.0, 0.55, gradient_height)
    );

    col = mix(
        col,
        sunset_top.rgb,
        smoothstep(0.55, 1.0, gradient_height)
    );

    // Repeating darker horizontal stripes with soft edges.
    float stripe_position = (height + wave) * stripe_count;
    float stripe_distance =
        abs(fract(stripe_position) - 0.5);

    float smoothing = max(fwidth(stripe_position), 0.001);
    float stripe = 1.0 - smoothstep(
        stripe_width * 0.5 - smoothing,
        stripe_width * 0.5 + smoothing,
        stripe_distance
    );

    col *= 1.0 - stripe * stripe_strength;

    // Keep the facing logic without heavily darkening the edges.
    float facing = clamp(
        dot(normalize(NORMAL), normalize(VIEW)),
        0.0,
        1.0
    );

    float brightness = mix(
        edge_brightness,
        1.0,
        pow(facing, limb_power)
    );

    // HDR output for glow.
    ALBEDO = col * brightness * sun_energy;
}