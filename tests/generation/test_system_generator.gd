extends GutTest

const SEED := 1234

var _settings: SystemSettings
var _generator: SystemGenerator


func before_each() -> void:
	_settings = SystemSettings.new()
	_settings.level_seed = SEED
	_generator = SystemGenerator.new(_settings)


func _all_bodies() -> Array[BodySpec]:
	var bodies: Array[BodySpec] = [_generator.root()]
	var index := 0
	while index < bodies.size():
		var spec := bodies[index]
		if not spec.is_pickup:
			bodies.append_array(_generator.contents_of(spec))
		index += 1
	return bodies


func _same_spec(a: BodySpec, b: BodySpec) -> bool:
	return (
		a.path == b.path and a.radius == b.radius and a.mass == b.mass
		and a.orbit_radius == b.orbit_radius and a.phase == b.phase
		and a.orbit_u == b.orbit_u and a.angular_speed == b.angular_speed
		and a.child_count == b.child_count
	)


func test_bad_angles_are_reported() -> void:
	_settings.max_inclination_degrees = 120.0
	_generator = SystemGenerator.new(_settings)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "tilt and inclination angles must be within [0, 90]"
	)
	assert_null(_generator.root())


func test_same_seed_gives_the_same_system() -> void:
	var first := _all_bodies()
	_generator = SystemGenerator.new(_settings)
	var second := _all_bodies()
	assert_eq(first.size(), second.size())
	for index in first.size():
		if not _same_spec(first[index], second[index]):
			fail_test("spec %s differs" % first[index].key())
			return
	pass_test("identical")


func test_different_seeds_give_different_systems() -> void:
	var first := _generator.contents_of(_generator.root())
	_settings.level_seed = SEED + 1
	_generator = SystemGenerator.new(_settings)
	var second := _generator.contents_of(_generator.root())
	assert_ne(first[0].radius, second[0].radius)


func test_seed_zero_picks_a_random_non_zero_seed() -> void:
	_settings.level_seed = 0
	_generator = SystemGenerator.new(_settings)
	assert_ne(_generator.level_seed, 0)


func test_a_body_does_not_depend_on_generating_its_siblings() -> void:
	var root := _generator.root()
	var direct := _generator.contents_of(root)[1]
	var fresh := SystemGenerator.new(_settings)
	var again := fresh.contents_of(fresh.root())[1]
	assert_true(_same_spec(direct, again))


func test_hierarchy_respects_depth_counts_and_ratios() -> void:
	for spec in _all_bodies():
		assert_lte(spec.depth, _settings.max_depth + 1)
		if spec.is_pickup:
			assert_eq(spec.child_count, 0)
			continue
		if spec.depth < _settings.max_depth:
			assert_between(
				spec.child_count,
				_settings.children_min,
				_settings.children_max,
			)
		else:
			assert_eq(spec.child_count, 0)


func test_child_radius_is_within_the_ratio_of_its_parent() -> void:
	var root := _generator.root()
	for child in _generator.contents_of(root):
		if child.is_pickup:
			continue
		var ratio := child.radius / root.radius
		assert_between(ratio, _settings.ratio_min, _settings.ratio_max)


func test_mass_follows_the_mass_law() -> void:
	for spec in _all_bodies():
		assert_almost_eq(
			spec.mass,
			_settings.mass_law.mass_for_radius(spec.radius),
			spec.mass * 1e-9,
		)


func test_bodies_with_belts_have_pickups_per_body_pickups() -> void:
	var root := _generator.root()
	var pickups := _generator.contents_of(root).filter(
		func(spec: BodySpec) -> bool:
			return spec.is_pickup,
	)
	assert_eq(root.pickup_count, _settings.pickups_per_body)
	assert_eq(pickups.size(), _settings.pickups_per_body)


func test_pickups_are_never_smaller_than_the_minimum() -> void:
	for spec in _all_bodies():
		if spec.is_pickup:
			assert_gte(spec.radius, _settings.min_pickup_radius)


func test_belts_are_skipped_when_pickups_would_be_too_small() -> void:
	for spec in _all_bodies():
		if spec.is_pickup:
			continue
		var big_enough := (
			spec.radius * _settings.pickup_ratio_max
			>= _settings.min_pickup_radius
		)
		assert_eq(spec.pickup_count > 0, big_enough, spec.key())


func test_every_expansion_fits_without_broken_contracts() -> void:
	var bodies := _all_bodies()
	assert_gt(bodies.size(), 1000)
	assert_push_error_count(0)


func test_system_fits_within_float_friendly_bounds() -> void:
	assert_lt(_generator.root().system_radius, 20000.0)


func test_system_is_packed_tightly() -> void:
	var root := _generator.root()
	gut.p("root system radius: %.1f" % root.system_radius)
	assert_lt(root.system_radius, 5000.0)


func test_root_system_is_a_horizontal_ring() -> void:
	var root := _generator.root()
	assert_eq(root.system_normal, Vector3.UP)
	for spec in _generator.contents_of(root):
		var inclination := rad_to_deg(spec.orbit_normal().angle_to(Vector3.UP))
		var limit := (
			_settings.belt_inclination_degrees
			if spec.is_pickup
			else _settings.max_inclination_degrees
		)
		assert_lte(inclination, limit + 1e-3)


func test_children_orbit_near_their_parent_system_plane() -> void:
	for parent in _all_bodies():
		if parent.is_pickup:
			continue
		for spec in _generator.contents_of(parent):
			if spec.is_pickup:
				continue
			var inclination := rad_to_deg(
				spec.orbit_normal().angle_to(parent.system_normal)
			)
			assert_lte(inclination, _settings.max_inclination_degrees + 1e-3)


func test_child_systems_tilt_by_at_most_system_tilt() -> void:
	for parent in _all_bodies():
		if parent.is_pickup:
			continue
		for spec in _generator.contents_of(parent):
			if spec.is_pickup:
				continue
			var tilt := rad_to_deg(
				spec.system_normal.angle_to(spec.orbit_normal())
			)
			assert_lte(tilt, _settings.system_tilt_degrees + 1e-3)


func test_child_orbits_are_spaced_by_their_exact_systems() -> void:
	var root := _generator.root()
	var children := _generator.contents_of(root).filter(
		func(spec: BodySpec) -> bool:
			return not spec.is_pickup,
	)
	var first: BodySpec = children[0]
	var expected := root.radius + first.system_radius * (
		1.0 + _settings.shell_gap
	)
	assert_almost_eq(first.orbit_radius, expected, 1e-6)


func test_depth_two_pickups_are_lighter_than_a_fresh_player() -> void:
	var root := _generator.root()
	var planet := _generator.contents_of(root)[0]
	var moon := _generator.contents_of(planet)[0]
	var lighter := _generator.contents_of(moon).filter(
		func(spec: BodySpec) -> bool:
			return spec.is_pickup and spec.mass < 1.0,
	)
	assert_gt(lighter.size(), 0)


func test_invalid_settings_are_reported_and_give_no_bodies() -> void:
	_settings.ratio_max = 0.6
	_generator = SystemGenerator.new(_settings)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "size ratios must satisfy 0 < min <= max < 0.5"
	)
	assert_null(_generator.root())


func test_pickups_have_no_contents() -> void:
	var root := _generator.root()
	var pickup: BodySpec = _generator.contents_of(root).back()
	assert_true(pickup.is_pickup)
	assert_eq(_generator.contents_of(pickup).size(), 0)
	assert_push_error(
		"[Contract] Pre-condition broken: parent must be a body, not a pickup"
	)
