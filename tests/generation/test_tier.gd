extends GutTest

const PARENT_RADIUS := 50.0

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_default_ring_tier_is_valid_for_its_parent() -> void:
	assert_true(Tier.new().require_valid(PARENT_RADIUS))


func test_default_ring_tier_lets_children_wander_their_whole_cell() -> void:
	var tier := Tier.new()
	assert_eq(tier.min_separation, 0.0)
	assert_eq(tier.jitter, 1.0)


func test_expected_count_is_spawn_density_times_ring_volume() -> void:
	var tier := Tier.new()
	var inner := tier.orbit_inner * PARENT_RADIUS
	var outer := tier.orbit_outer * PARENT_RADIUS
	var volume := PI * (outer * outer - inner * inner) * 2.0 * tier.thickness
	assert_almost_eq(
		tier.expected_count(PARENT_RADIUS),
		tier.spawn_density * volume,
		1.0e-9,
	)


func test_default_ring_tier_expects_about_the_prototype_count() -> void:
	assert_almost_eq(Tier.new().expected_count(PARENT_RADIUS), 500.0, 5.0)


func test_cell_spawn_chance_is_density_times_cell_volume() -> void:
	var tier := Tier.new()
	var cell_volume := tier.cell_size * tier.cell_size * 2.0 * tier.thickness
	assert_almost_eq(
		tier.cell_spawn_chance(),
		tier.spawn_density * cell_volume,
		1.0e-12,
	)


func test_cells_across_covers_the_ring_diameter() -> void:
	var tier := Tier.new()
	var across := tier.cells_across(PARENT_RADIUS)
	var diameter := 2.0 * tier.orbit_outer * PARENT_RADIUS
	assert_gte(across * tier.cell_size, diameter)
	assert_lt((across - 1) * tier.cell_size, diameter)


func test_broken_rule_is_reported_and_invalid() -> void:
	var tier := Tier.new()
	tier.thickness = 0.0
	assert_false(tier.require_valid(PARENT_RADIUS))
	assert_push_error(
		"[Contract] Pre-condition broken: thickness must be positive"
	)


func test_every_broken_rule_is_reported() -> void:
	var tier := Tier.new()
	tier.size_bias = 0.0
	tier.mass_density = 0.0
	assert_false(tier.require_valid(PARENT_RADIUS))
	assert_push_error(
		"[Contract] Pre-condition broken: size_bias must be positive"
	)
	assert_push_error(
		"[Contract] Pre-condition broken: mass_density must be positive"
	)


func test_validity_depends_on_the_parent_radius() -> void:
	var tier := Tier.new()
	assert_true(tier.require_valid(PARENT_RADIUS))
	assert_false(tier.require_valid(4.0))
	assert_push_error(
		"[Contract] Pre-condition broken: children must not touch the parent"
	)


func test_collapse_inside_expand_is_reported() -> void:
	var tier := Tier.new()
	tier.collapse_distance = tier.expand_distance
	assert_false(tier.require_valid(PARENT_RADIUS))
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "collapse_distance must be greater than expand_distance"
	)


func test_shipped_tiers_are_valid_for_the_v3_hierarchy() -> void:
	var systems: Tier = load("res://resources/generation/systems_tier.tres")
	var rings: Tier = load("res://resources/generation/rings_tier.tres")
	assert_true(systems.require_valid(5000.0))
	assert_true(rings.require_valid(systems.radius_min))
	assert_true(rings.require_valid(systems.radius_max))
	assert_almost_eq(systems.expected_count(5000.0), 1980.0, 5.0)
	assert_almost_eq(rings.expected_count(systems.radius_min), 500.0, 5.0)


func test_release_inside_live_is_reported() -> void:
	var tier := Tier.new()
	tier.release_distance = tier.live_distance
	assert_false(tier.require_valid(PARENT_RADIUS))
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "release_distance must be greater than live_distance"
	)


func test_default_tier_is_not_mass_capped() -> void:
	assert_false(Tier.new().is_mass_capped())


func test_positive_ceiling_fraction_caps_the_mass() -> void:
	var tier := Tier.new()
	tier.mass_ceiling_fraction = 1.0
	assert_true(tier.is_mass_capped())
	assert_true(tier.require_valid(PARENT_RADIUS))


func test_negative_ceiling_fraction_is_reported() -> void:
	var tier := Tier.new()
	tier.mass_ceiling_fraction = -1.0
	assert_false(tier.require_valid(PARENT_RADIUS))
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "mass_ceiling_fraction must not be negative"
	)


func test_capped_tier_needs_positive_mass_min_and_bias() -> void:
	var tier := Tier.new()
	tier.mass_ceiling_fraction = 1.0
	tier.mass_min = 0.0
	tier.mass_bias = 0.0
	assert_false(tier.require_valid(PARENT_RADIUS))
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "a capped tier's mass_min must be positive"
	)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "a capped tier's mass_bias must be positive"
	)


func test_uncapped_tier_ignores_mass_min_and_bias() -> void:
	var tier := Tier.new()
	tier.mass_min = 0.0
	tier.mass_bias = 0.0
	assert_true(tier.require_valid(PARENT_RADIUS))


func test_shipped_ring_tier_is_capped_at_the_player_mass() -> void:
	var systems: Tier = load("res://resources/generation/systems_tier.tres")
	var rings: Tier = load("res://resources/generation/rings_tier.tres")
	assert_false(systems.is_mass_capped())
	assert_true(rings.is_mass_capped())
	assert_eq(rings.mass_ceiling_fraction, 0.1)
	assert_eq(rings.mass_min, 0.01)
	assert_eq(rings.mass_bias, 1.5)
