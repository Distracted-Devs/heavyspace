extends GutTest

const ROOT_RADIUS := 100.0
const SEED := 7
const FAR_AWAY := Vector3(1.0e5, 0.0, 0.0)

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func _tier(
	radius: float,
	thickness: float,
	separation: float,
	cell: float,
	density: float,
	period: float,
	expand: float,
	collapse: float,
) -> Tier:
	var tier := Tier.new()
	tier.orbit_inner = 1.5 if radius >= 10.0 else 2.0
	tier.orbit_outer = 3.0 if radius >= 10.0 else 4.0
	tier.radius_min = radius
	tier.radius_max = radius
	tier.thickness = thickness
	tier.min_separation = separation
	tier.cell_size = cell
	tier.spawn_density = density
	tier.inner_period_min = period
	tier.inner_period_max = period
	tier.expand_distance = expand
	tier.collapse_distance = collapse
	return tier


func _tiers(depth: int) -> Array[Tier]:
	var all: Array[Tier] = [
		_tier(10.0, 5.0, 40.0, 50.0, 5.0e-6, 3000.0, 60.0, 90.0),
		_tier(2.0, 1.0, 4.0, 5.0, 0.006, 600.0, 60.0, 90.0),
		_tier(0.4, 0.2, 0.8, 1.0, 0.75, 300.0, 12.0, 18.0),
		_tier(0.05, 0.05, 0.1, 0.15, 60.0, 150.0, 2.0, 3.0),
	]
	return all.slice(0, depth)


func _streamer(depth: int, level_seed := SEED) -> HierarchyStreamer:
	var streamer := HierarchyStreamer.new()
	streamer.level_seed = level_seed
	streamer.root_radius = ROOT_RADIUS
	streamer.tiers = _tiers(depth)
	return add_child_autofree(streamer)


func _path(indices: Array) -> PackedInt32Array:
	return PackedInt32Array(indices)


func _parent_of(path: PackedInt32Array) -> PackedInt32Array:
	return path.slice(0, path.size() - 1)


func _centre(
	streamer: HierarchyStreamer,
	path: PackedInt32Array,
	time: float,
) -> Vector3:
	var parent := streamer.renderer_for(_parent_of(path))
	return parent.child_position(path[path.size() - 1], time)


func _expand_down_to(
	streamer: HierarchyStreamer,
	path: PackedInt32Array,
	time: float,
) -> Vector3:
	var centre := Vector3.ZERO
	for depth in range(1, path.size() + 1):
		var step := path.slice(0, depth)
		centre = _centre(streamer, step, time)
		streamer.update(centre, time)
	return centre


func _orbits_of(renderer: OrbitRenderer) -> Array[Vector4]:
	var orbits: Array[Vector4] = []
	for index in renderer.count():
		orbits.append(renderer.instance_orbit(index))
	return orbits


func _expanded_keys(streamer: HierarchyStreamer) -> Dictionary:
	var keys := { }
	for path in streamer.expanded_paths():
		keys[str(path)] = true
	return keys


func _assert_streaming_rules(
	streamer: HierarchyStreamer,
	focus: Vector3,
	time: float,
	before: Dictionary,
) -> void:
	assert_true(streamer.is_expanded(PackedInt32Array()))
	for path in streamer.expanded_paths():
		if path.is_empty():
			continue
		assert_true(streamer.is_expanded(_parent_of(path)))
		var placed := streamer.renderer_for(path).global_position
		assert_almost_eq(
			placed.distance_to(_centre(streamer, path, time)),
			0.0,
			1.0e-3,
		)
	for path in streamer.expanded_paths():
		var child_depth := path.size() + 1
		if child_depth >= streamer.tiers.size():
			continue
		var tier := streamer.tiers[child_depth]
		var renderer := streamer.renderer_for(path)
		for index in renderer.count():
			var child := path.duplicate()
			child.append(index)
			var distance := focus.distance_to(
				renderer.child_position(index, time)
			)
			var now := streamer.is_expanded(child)
			if distance < tier.expand_distance:
				assert_true(now, "near child %s must be expanded" % child)
			elif distance > tier.collapse_distance:
				assert_false(now, "far child %s must be collapsed" % child)
			else:
				assert_eq(now, before.has(str(child)), "band keeps %s" % child)


func test_root_is_expanded_when_the_streamer_starts() -> void:
	var streamer := _streamer(1)
	assert_eq(streamer.expanded_paths(), [PackedInt32Array()])
	assert_gt(streamer.renderer_for(PackedInt32Array()).count(), 0)


func test_one_tier_never_expands_below_the_root() -> void:
	var streamer := _streamer(1)
	var centre := _centre(streamer, _path([0]), 0.0)
	streamer.update(centre, 0.0)
	assert_eq(streamer.expanded_paths().size(), 1)
	assert_false(streamer.is_expanded(_path([0])))


func test_seed_zero_picks_a_random_seed() -> void:
	var streamer := _streamer(1, 0)
	assert_ne(streamer.resolved_seed, 0)


func test_non_zero_seed_is_kept() -> void:
	assert_eq(_streamer(1).resolved_seed, SEED)


func test_near_child_expands() -> void:
	var streamer := _streamer(2)
	streamer.update(_centre(streamer, _path([0]), 0.0), 0.0)
	assert_true(streamer.is_expanded(_path([0])))
	assert_gt(streamer.renderer_for(_path([0])).count(), 0)


func test_far_child_collapses() -> void:
	var streamer := _streamer(2)
	streamer.update(_centre(streamer, _path([0]), 0.0), 0.0)
	streamer.update(FAR_AWAY, 0.0)
	assert_false(streamer.is_expanded(_path([0])))
	assert_eq(streamer.expanded_paths().size(), 1)


func test_band_between_expand_and_collapse_keeps_the_state() -> void:
	var streamer := _streamer(2)
	var centre := _centre(streamer, _path([0]), 0.0)
	var outward := centre.normalized()
	var in_band := centre + outward * 75.0
	streamer.update(in_band, 0.0)
	assert_false(streamer.is_expanded(_path([0])), "collapsed stays collapsed")
	streamer.update(centre + outward * 50.0, 0.0)
	assert_true(streamer.is_expanded(_path([0])))
	streamer.update(in_band, 0.0)
	assert_true(streamer.is_expanded(_path([0])), "expanded stays expanded")
	streamer.update(centre + outward * 100.0, 0.0)
	assert_false(streamer.is_expanded(_path([0])))


func test_re_expanding_gives_the_same_layout() -> void:
	var streamer := _streamer(2)
	var centre := _centre(streamer, _path([0]), 0.0)
	streamer.update(centre, 0.0)
	var first := _orbits_of(streamer.renderer_for(_path([0])))
	streamer.update(FAR_AWAY, 0.0)
	streamer.update(centre, 0.0)
	var second := _orbits_of(streamer.renderer_for(_path([0])))
	assert_gt(first.size(), 0)
	assert_eq(second, first)


func test_renderers_sit_on_their_parent_at_the_given_time() -> void:
	var streamer := _streamer(2)
	var centre := _centre(streamer, _path([0]), 0.0)
	streamer.update(centre, 0.0)
	streamer.update(centre, 20.0)
	var placed := streamer.renderer_for(_path([0])).global_position
	var expected := _centre(streamer, _path([0]), 20.0)
	assert_almost_eq(placed.distance_to(expected), 0.0, 1.0e-3)


func test_renderers_keep_their_own_ring_tilt() -> void:
	var streamer := _streamer(2)
	streamer.update(_centre(streamer, _path([0]), 0.0), 0.0)
	var renderer := streamer.renderer_for(_path([0]))
	assert_eq(renderer.get_parent(), streamer)


func test_whole_chain_of_ancestors_expands_in_one_update() -> void:
	var streamer := _streamer(4)
	var deep := _path([0, 0, 0])
	var spot := _expand_down_to(streamer, deep, 0.0)
	streamer.update(FAR_AWAY, 0.0)
	assert_eq(streamer.expanded_paths().size(), 1)
	streamer.update(spot, 0.0)
	assert_true(streamer.is_expanded(_path([0])))
	assert_true(streamer.is_expanded(_path([0, 0])))
	assert_true(streamer.is_expanded(deep))


func test_parents_come_before_their_children() -> void:
	var streamer := _streamer(4)
	_expand_down_to(streamer, _path([0, 0, 0]), 0.0)
	var seen := { }
	for path in streamer.expanded_paths():
		if not path.is_empty():
			assert_true(seen.has(str(_parent_of(path))))
		seen[str(path)] = true


func test_moving_far_collapses_the_whole_subtree() -> void:
	var streamer := _streamer(4)
	_expand_down_to(streamer, _path([0, 0, 0]), 0.0)
	var deep_renderer := streamer.renderer_for(_path([0, 0, 0]))
	streamer.update(FAR_AWAY, 0.0)
	assert_eq(streamer.expanded_paths().size(), 1)
	assert_true(deep_renderer.is_queued_for_deletion())


func test_moving_away_collapses_the_deepest_level_first() -> void:
	var streamer := _streamer(4)
	var spot := _expand_down_to(streamer, _path([0, 0, 0]), 0.0)
	var outward := (spot - _centre(streamer, _path([0, 0]), 0.0)).normalized()
	streamer.update(spot + outward * 5.0, 0.0)
	assert_false(streamer.is_expanded(_path([0, 0, 0])))
	assert_true(streamer.is_expanded(_path([0, 0])))
	assert_true(streamer.is_expanded(_path([0])))


func test_deep_renderers_follow_their_parents_over_time() -> void:
	var streamer := _streamer(4)
	var deep := _path([0, 0, 0])
	_expand_down_to(streamer, deep, 0.0)
	var time := 0.0
	for step in 20:
		time += 0.05
		streamer.update(_centre(streamer, deep, time), time)
		assert_true(streamer.is_expanded(deep))
		var placed := streamer.renderer_for(deep).global_position
		assert_almost_eq(
			placed.distance_to(_centre(streamer, deep, time)),
			0.0,
			1.0e-3,
		)


func test_expanded_is_emitted_with_the_path_and_renderer() -> void:
	var streamer := _streamer(2)
	watch_signals(streamer)
	streamer.update(_centre(streamer, _path([0]), 0.0), 0.0)
	assert_signal_emitted_with_parameters(
		streamer,
		"expanded",
		[_path([0]), streamer.renderer_for(_path([0]))],
	)


func test_collapsing_is_emitted_before_the_renderer_is_freed() -> void:
	var streamer := _streamer(2)
	streamer.update(_centre(streamer, _path([0]), 0.0), 0.0)
	var report := { }
	streamer.collapsing.connect(
		func(path: PackedInt32Array, renderer: OrbitRenderer) -> void:
			report[str(path)] = not renderer.is_queued_for_deletion(),
	)
	streamer.update(FAR_AWAY, 0.0)
	assert_eq(report, { str(_path([0])): true })


func test_streaming_rules_hold_along_a_flight_path() -> void:
	var streamer := _streamer(3)
	var first := _centre(streamer, _path([0]), 0.0)
	var second := _centre(streamer, _path([1]), 0.0)
	var start := first - first.normalized() * 150.0
	var finish := second + second.normalized() * 150.0
	var waypoints := [start, first, second, finish]
	var steps := 300
	var time := 0.0
	var visited_deeper := false
	for step in steps + 1:
		var progress := float(step) / steps * (waypoints.size() - 1)
		var leg := mini(floori(progress), waypoints.size() - 2)
		var focus: Vector3 = waypoints[leg].lerp(
			waypoints[leg + 1],
			progress - leg,
		)
		var before := _expanded_keys(streamer)
		streamer.update(focus, time)
		_assert_streaming_rules(streamer, focus, time, before)
		visited_deeper = visited_deeper or streamer.expanded_paths().size() > 2
		time += 0.05
	assert_true(visited_deeper, "the path must expand below the first level")


func test_empty_tiers_are_reported() -> void:
	var streamer := HierarchyStreamer.new()
	add_child_autofree(streamer)
	assert_push_error(
		"[Contract] Pre-condition broken: tiers must not be empty"
	)
	assert_eq(streamer.expanded_paths().size(), 0)


func test_null_tier_is_reported() -> void:
	var streamer := HierarchyStreamer.new()
	streamer.tiers = [null]
	add_child_autofree(streamer)
	assert_push_error(
		"[Contract] Pre-condition broken: tiers must not contain null"
	)


func test_tier_invalid_for_its_parent_radius_is_reported() -> void:
	var streamer := HierarchyStreamer.new()
	streamer.root_radius = ROOT_RADIUS
	streamer.tiers = _tiers(2)
	streamer.tiers[1].orbit_inner = 1.1
	add_child_autofree(streamer)
	assert_push_error_count(2)
	assert_eq(streamer.expanded_paths().size(), 0)


func test_update_before_a_valid_start_does_nothing() -> void:
	var streamer := HierarchyStreamer.new()
	add_child_autofree(streamer)
	assert_push_error("tiers must not be empty")
	streamer.update(Vector3.ZERO, 0.0)
	assert_eq(streamer.expanded_paths().size(), 0)
