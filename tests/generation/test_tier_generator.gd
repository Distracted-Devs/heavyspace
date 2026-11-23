extends GutTest

const PARENT_RADIUS := 50.0
const PATH_INDEX := 3

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func _ring_tier() -> Tier:
	return Tier.new()


func _generate(
	tier: Tier,
	level_seed := 1,
	path := PackedInt32Array([PATH_INDEX]),
) -> TierLayout:
	return TierGenerator.generate(level_seed, path, PARENT_RADIUS, tier)


func _path() -> PackedInt32Array:
	return PackedInt32Array([PATH_INDEX])


func _child_position(layout: TierLayout, index: int) -> Vector3:
	return Orbit.position(
		layout.orbit_radius[index],
		layout.height[index],
		layout.phase[index],
		layout.angular_speed[index],
		0.0,
	)


func _assert_rejected(tier: Tier, message: String) -> void:
	var layout := _generate(tier)
	assert_push_error("[Contract] Pre-condition broken: " + message)
	assert_eq(layout.size(), 0)


func test_same_inputs_give_an_identical_layout() -> void:
	var first := _generate(_ring_tier())
	var second := _generate(_ring_tier())
	assert_gt(first.size(), 0)
	assert_eq(first.radius, second.radius)
	assert_eq(first.mass, second.mass)
	assert_eq(first.orbit_radius, second.orbit_radius)
	assert_eq(first.height, second.height)
	assert_eq(first.phase, second.phase)
	assert_eq(first.angular_speed, second.angular_speed)
	assert_eq(first.plane, second.plane)


func test_different_paths_give_different_layouts() -> void:
	var first := _generate(_ring_tier(), 1, PackedInt32Array([3]))
	var second := _generate(_ring_tier(), 1, PackedInt32Array([4]))
	assert_ne(first.orbit_radius, second.orbit_radius)


func test_different_seeds_give_different_layouts() -> void:
	var first := _generate(_ring_tier(), 1)
	var second := _generate(_ring_tier(), 2)
	assert_ne(first.orbit_radius, second.orbit_radius)


func test_every_array_has_the_layout_size() -> void:
	var layout := _generate(_ring_tier())
	var size := layout.size()
	assert_eq(layout.mass.size(), size)
	assert_eq(layout.orbit_radius.size(), size)
	assert_eq(layout.height.size(), size)
	assert_eq(layout.phase.size(), size)
	assert_eq(layout.angular_speed.size(), size)


func test_every_child_is_within_its_tier_ranges() -> void:
	var tier := _ring_tier()
	var layout := _generate(tier)
	var inner := tier.orbit_inner * PARENT_RADIUS
	var outer := tier.orbit_outer * PARENT_RADIUS
	for index in layout.size():
		assert_between(layout.radius[index], tier.radius_min, tier.radius_max)
		assert_between(layout.orbit_radius[index], inner, outer)
		assert_lte(absf(layout.height[index]), tier.thickness)
		assert_gte(layout.phase[index], 0.0)
		assert_lt(layout.phase[index], TAU)


func test_mass_is_density_times_radius_cubed() -> void:
	var tier := _ring_tier()
	var layout := _generate(tier)
	for index in layout.size():
		var expected := tier.mass_density * pow(layout.radius[index], 3.0)
		assert_almost_eq(layout.mass[index], expected, expected * 1.0e-9)


func test_siblings_start_at_least_min_separation_apart() -> void:
	var tier := _ring_tier()
	var layout := _generate(tier)
	var closest := INF
	for first in layout.size():
		var at := _child_position(layout, first)
		for second in range(first + 1, layout.size()):
			var distance := at.distance_to(_child_position(layout, second))
			closest = minf(closest, distance)
	assert_gte(closest, tier.min_separation)


func test_fixed_period_gives_kepler_speeds() -> void:
	var tier := _ring_tier()
	var layout := _generate(tier)
	var inner := tier.orbit_inner * PARENT_RADIUS
	for index in layout.size():
		var expected := (
			TAU / tier.inner_period_min
			* pow(inner / layout.orbit_radius[index], 1.5)
		)
		assert_almost_eq(layout.angular_speed[index], expected, 1.0e-9)


func test_random_period_keeps_speeds_within_the_period_range() -> void:
	var tier := _ring_tier()
	tier.inner_period_min = 40.0
	tier.inner_period_max = 80.0
	var layout := _generate(tier)
	var inner := tier.orbit_inner * PARENT_RADIUS
	var periods := { }
	for index in layout.size():
		var falloff := pow(inner / layout.orbit_radius[index], 1.5)
		var period := TAU * falloff / layout.angular_speed[index]
		assert_between(period, 40.0 - 1.0e-6, 80.0 + 1.0e-6)
		periods[snappedf(period, 1.0)] = true
	assert_gt(periods.size(), 1)


func test_no_retrograde_chance_orbits_all_one_way() -> void:
	var layout := _generate(_ring_tier())
	for speed in layout.angular_speed:
		assert_gt(speed, 0.0)


func test_full_retrograde_chance_orbits_all_backwards() -> void:
	var tier := _ring_tier()
	tier.retrograde_chance = 1.0
	var layout := _generate(tier)
	for speed in layout.angular_speed:
		assert_lt(speed, 0.0)


func test_plane_is_a_rotation_within_the_tilt_limit() -> void:
	var tier := _ring_tier()
	tier.plane_tilt_max_degrees = 30.0
	for index in 20:
		var path := PackedInt32Array([index])
		var plane := _generate(tier, 1, path).plane
		assert_true(plane.is_conformal())
		assert_almost_eq(plane.determinant(), 1.0, 1.0e-6)
		var tilt := rad_to_deg(plane.y.angle_to(Vector3.UP))
		assert_lte(tilt, 30.0 + 1.0e-3)


func test_zero_tilt_keeps_the_ring_flat() -> void:
	var tier := _ring_tier()
	tier.plane_tilt_max_degrees = 0.0
	var plane := _generate(tier).plane
	assert_almost_eq(plane.y.angle_to(Vector3.UP), 0.0, 1.0e-6)


func test_count_averages_close_to_the_expected_count() -> void:
	var tier := _ring_tier()
	var total := 0
	var runs := 8
	for level_seed in runs:
		total += _generate(tier, level_seed).size()
	var expected := tier.expected_count(PARENT_RADIUS)
	assert_almost_eq(float(total) / runs, expected, expected * 0.1)


func test_non_positive_parent_radius_is_reported() -> void:
	var layout := TierGenerator.generate(1, _path(), 0.0, _ring_tier())
	assert_push_error(
		"[Contract] Pre-condition broken: parent_radius must be positive"
	)
	assert_eq(layout.size(), 0)


func test_missing_tier_is_reported() -> void:
	var layout := TierGenerator.generate(1, _path(), PARENT_RADIUS, null)
	assert_push_error("[Contract] Pre-condition broken: tier must not be null")
	assert_eq(layout.size(), 0)


func test_children_touching_the_parent_are_rejected() -> void:
	var tier := _ring_tier()
	tier.orbit_inner = 1.01
	_assert_rejected(tier, "children must not touch the parent")


func test_overlapping_siblings_are_rejected() -> void:
	var tier := _ring_tier()
	tier.min_separation = 5.0
	_assert_rejected(tier, "min_separation must be at least twice radius_max")


func test_separation_wider_than_a_cell_is_rejected() -> void:
	var tier := _ring_tier()
	tier.min_separation = 9.0
	_assert_rejected(tier, "min_separation must be at most cell_size")


func test_cell_spawn_chance_over_one_is_rejected() -> void:
	var tier := _ring_tier()
	tier.spawn_density = 1.0
	_assert_rejected(tier, "cell spawn chance must be at most 1")


func test_too_many_grid_cells_are_rejected() -> void:
	var tier := _ring_tier()
	tier.orbit_outer = 200.0
	tier.spawn_density = 1.0e-6
	_assert_rejected(tier, "grid must have at most 1000000 cells")


func test_bad_ranges_are_rejected() -> void:
	var tier := _ring_tier()
	tier.radius_min = 4.0
	_assert_rejected(tier, "radius_min must be positive and at most radius_max")
	tier = _ring_tier()
	tier.orbit_outer = 1.5
	_assert_rejected(tier, "orbit_inner must be at most orbit_outer")
	tier = _ring_tier()
	tier.inner_period_max = 30.0
	_assert_rejected(tier, "inner periods must be positive and ordered")
	tier = _ring_tier()
	tier.retrograde_chance = 1.5
	_assert_rejected(tier, "retrograde_chance must be in [0, 1]")
	tier = _ring_tier()
	tier.plane_tilt_max_degrees = 200.0
	_assert_rejected(tier, "plane_tilt_max_degrees must be in [0, 180]")


func test_non_positive_tuning_is_rejected() -> void:
	var tier := _ring_tier()
	tier.thickness = 0.0
	_assert_rejected(tier, "thickness must be positive")
	tier = _ring_tier()
	tier.size_bias = 0.0
	_assert_rejected(tier, "size_bias must be positive")
	tier = _ring_tier()
	tier.mass_density = 0.0
	_assert_rejected(tier, "mass_density must be positive")
	tier = _ring_tier()
	tier.spawn_density = 0.0
	_assert_rejected(tier, "spawn_density must be positive")


func _capped_tier(fraction := 1.0) -> Tier:
	var tier := _ring_tier()
	tier.mass_ceiling_fraction = fraction
	return tier


func _generate_with_focus(tier: Tier, focus_mass: float) -> TierLayout:
	return TierGenerator.generate(1, _path(), PARENT_RADIUS, tier, focus_mass)


func test_capped_masses_lie_between_mass_min_and_the_ceiling() -> void:
	var tier := _capped_tier(0.5)
	var layout := _generate_with_focus(tier, 8.0)
	assert_gt(layout.size(), 0)
	for index in layout.size():
		assert_between(layout.mass[index], tier.mass_min, 4.0)


func test_capped_mass_follows_the_radius_fraction() -> void:
	var tier := _capped_tier()
	var layout := _generate_with_focus(tier, 3.0)
	var span := tier.radius_max - tier.radius_min
	for index in layout.size():
		var t := (layout.radius[index] - tier.radius_min) / span
		var expected := lerpf(tier.mass_min, 3.0, pow(t, tier.mass_bias))
		assert_almost_eq(layout.mass[index], expected, 1.0e-9)


func test_capped_mass_never_falls_as_radius_grows() -> void:
	var layout := _generate_with_focus(_capped_tier(), 5.0)
	var order := range(layout.size())
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return layout.radius[a] < layout.radius[b],
	)
	for step in range(1, order.size()):
		assert_gte(layout.mass[order[step]], layout.mass[order[step - 1]])


func test_capped_bodies_are_never_heavier_than_the_focus() -> void:
	for focus_mass in [0.1, 1.0, 37.5]:
		var layout := _generate_with_focus(_capped_tier(), focus_mass)
		for index in layout.size():
			assert_lte(layout.mass[index], focus_mass)


func test_equal_radius_range_gives_the_ceiling() -> void:
	var tier := _capped_tier(0.5)
	tier.radius_min = 2.0
	tier.radius_max = 2.0
	var layout := _generate_with_focus(tier, 6.0)
	assert_gt(layout.size(), 0)
	for index in layout.size():
		assert_eq(layout.mass[index], 3.0)


func test_ceiling_never_drops_below_mass_min() -> void:
	var tier := _capped_tier()
	tier.mass_min = 2.0
	var layout := _generate_with_focus(tier, 0.5)
	for index in layout.size():
		assert_eq(layout.mass[index], 2.0)


func test_cap_leaves_every_other_field_unchanged() -> void:
	var uncapped := _generate(_ring_tier())
	var capped := _generate_with_focus(_capped_tier(), 2.0)
	assert_eq(capped.radius, uncapped.radius)
	assert_eq(capped.orbit_radius, uncapped.orbit_radius)
	assert_eq(capped.height, uncapped.height)
	assert_eq(capped.phase, uncapped.phase)
	assert_eq(capped.angular_speed, uncapped.angular_speed)
	assert_eq(capped.plane, uncapped.plane)
	assert_ne(capped.mass, uncapped.mass)


func test_same_focus_mass_gives_an_identical_capped_layout() -> void:
	var first := _generate_with_focus(_capped_tier(), 2.0)
	var second := _generate_with_focus(_capped_tier(), 2.0)
	assert_eq(first.mass, second.mass)


func test_uncapped_tier_ignores_the_focus_mass() -> void:
	var tier := _ring_tier()
	var layout := _generate_with_focus(tier, 2.0)
	for index in layout.size():
		assert_almost_eq(
			layout.mass[index],
			tier.mass_density * pow(layout.radius[index], 3.0),
			1.0e-9,
		)


func test_capped_tier_without_a_focus_mass_is_rejected() -> void:
	var layout := _generate(_capped_tier())
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "a capped tier needs a positive focus_mass"
	)
	assert_eq(layout.size(), 0)


func test_capped_tier_with_a_non_positive_focus_mass_is_rejected() -> void:
	var layout := _generate_with_focus(_capped_tier(), 0.0)
	assert_push_error("a capped tier needs a positive focus_mass")
	assert_eq(layout.size(), 0)
