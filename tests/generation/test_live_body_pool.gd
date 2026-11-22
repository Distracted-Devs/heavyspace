extends GutTest

const ROOT_RADIUS := 100.0
const ROOT_MASS := 5000.0
const FAR_AWAY := Vector3(1.0e5, 0.0, 0.0)

var _was_enabled: bool
var _streamer: HierarchyStreamer
var _pool: LiveBodyPool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_streamer = HierarchyStreamer.new()
	_streamer.level_seed = 7
	_streamer.root_radius = ROOT_RADIUS
	_streamer.root_mass = ROOT_MASS
	_streamer.tiers = [_systems_tier(), _rings_tier()]
	add_child_autofree(_streamer)
	_pool = LiveBodyPool.new()
	_pool.streamer = _streamer
	add_child_autofree(_pool)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _systems_tier() -> Tier:
	var tier := Tier.new()
	tier.orbit_inner = 1.5
	tier.orbit_outer = 3.0
	tier.radius_min = 10.0
	tier.radius_max = 10.0
	tier.mass_density = 0.5
	tier.thickness = 5.0
	tier.min_separation = 40.0
	tier.cell_size = 50.0
	tier.spawn_density = 5.0e-6
	tier.inner_period_min = 3000.0
	tier.inner_period_max = 3000.0
	tier.live_distance = 30.0
	tier.release_distance = 45.0
	return tier


func _rings_tier() -> Tier:
	var tier := Tier.new()
	tier.orbit_inner = 2.0
	tier.orbit_outer = 4.0
	tier.radius_min = 1.0
	tier.radius_max = 2.0
	tier.thickness = 1.0
	tier.min_separation = 4.0
	tier.cell_size = 5.0
	tier.spawn_density = 0.006
	tier.inner_period_min = 600.0
	tier.inner_period_max = 600.0
	tier.expand_distance = 60.0
	tier.collapse_distance = 90.0
	tier.live_distance = 6.0
	tier.release_distance = 9.0
	return tier


func _root_renderer() -> OrbitRenderer:
	return _streamer.renderer_for(PackedInt32Array())


func _step(focus: Vector3, time: float) -> void:
	_streamer.update(focus, time)
	_pool.update(focus, time)


func _settle() -> void:
	await wait_physics_frames(1)


func _hidden_count() -> int:
	var hidden := 0
	for path in _streamer.expanded_paths():
		var renderer := _streamer.renderer_for(path)
		for index in renderer.count():
			if renderer.is_hidden(index):
				hidden += 1
	return hidden


func _assert_one_to_one() -> void:
	assert_eq(_hidden_count(), _pool.live_count())
	for path in _streamer.expanded_paths():
		var renderer := _streamer.renderer_for(path)
		for index in renderer.count():
			var body := _pool.body_for(renderer, index)
			assert_eq(renderer.is_hidden(index), body != null)


func test_root_is_always_a_real_body_at_the_centre() -> void:
	_streamer.global_position = Vector3(5.0, 6.0, 7.0)
	_step(FAR_AWAY, 0.0)
	var root := _pool.root_body
	assert_not_null(root)
	assert_eq(root.radius, ROOT_RADIUS)
	assert_eq(root.mass, ROOT_MASS)
	await _settle()
	assert_almost_eq(
		root.global_position.distance_to(_streamer.global_position),
		0.0,
		1.0e-4,
	)


func test_near_child_becomes_a_real_body_on_its_drawn_copy() -> void:
	var renderer := _root_renderer()
	var centre := renderer.child_position(0, 0.0)
	_step(centre, 0.0)
	var body := _pool.body_for(renderer, 0)
	assert_not_null(body)
	assert_true(renderer.is_hidden(0))
	await _settle()
	assert_almost_eq(body.global_position.distance_to(centre), 0.0, 1.0e-4)
	assert_eq(body.radius, renderer.layout.radius[0])
	assert_eq(body.mass, renderer.layout.mass[0])


func test_far_child_is_released_and_shown_again() -> void:
	var renderer := _root_renderer()
	_step(renderer.child_position(0, 0.0), 0.0)
	var body := _pool.body_for(renderer, 0)
	_step(FAR_AWAY, 0.0)
	assert_null(_pool.body_for(renderer, 0))
	assert_false(renderer.is_hidden(0))
	assert_true(body.is_queued_for_deletion())


func test_band_between_live_and_release_keeps_the_state() -> void:
	var renderer := _root_renderer()
	var centre := renderer.child_position(0, 0.0)
	var outward := centre.normalized()
	_step(centre + outward * 38.0, 0.0)
	assert_null(_pool.body_for(renderer, 0), "drawn stays drawn")
	_step(centre + outward * 20.0, 0.0)
	assert_not_null(_pool.body_for(renderer, 0))
	_step(centre + outward * 38.0, 0.0)
	assert_not_null(_pool.body_for(renderer, 0), "live stays live")
	_step(centre + outward * 50.0, 0.0)
	assert_null(_pool.body_for(renderer, 0))


func test_live_body_follows_its_orbit_over_time() -> void:
	var renderer := _root_renderer()
	_step(renderer.child_position(0, 0.0), 0.0)
	var body := _pool.body_for(renderer, 0)
	for step in 10:
		var time := step * 0.5
		_step(renderer.child_position(0, time), time)
		await _settle()
		var expected := renderer.child_position(0, time)
		assert_almost_eq(
			body.global_position.distance_to(expected),
			0.0,
			1.0e-4,
		)


func test_live_ring_body_follows_its_moving_parent() -> void:
	var system := _root_renderer().child_position(0, 0.0)
	_step(system, 0.0)
	var ring := _streamer.renderer_for(PackedInt32Array([0]))
	var spot := ring.child_position(0, 0.0)
	_step(spot, 0.0)
	var body := _pool.body_for(ring, 0)
	assert_not_null(body)
	_step(ring.child_position(0, 30.0), 30.0)
	await _settle()
	var expected := ring.child_position(0, 30.0)
	assert_almost_eq(body.global_position.distance_to(expected), 0.0, 1.0e-4)


func test_collapsing_frees_the_parents_live_children() -> void:
	var system := _root_renderer().child_position(0, 0.0)
	_step(system, 0.0)
	var ring := _streamer.renderer_for(PackedInt32Array([0]))
	_step(ring.child_position(0, 0.0), 0.0)
	var body := _pool.body_for(ring, 0)
	assert_not_null(body)
	_step(FAR_AWAY, 0.0)
	assert_true(body.is_queued_for_deletion())
	assert_eq(_pool.live_count(), 0)


func test_live_bodies_and_hidden_copies_match_along_a_flight_path() -> void:
	var renderer := _root_renderer()
	var first := renderer.child_position(0, 0.0)
	var second := renderer.child_position(1, 0.0)
	var time := 0.0
	var went_live := { }
	for step in 201:
		var progress := step / 200.0
		var focus := first.lerp(second, progress)
		_step(focus, time)
		_assert_one_to_one()
		for path in _streamer.expanded_paths():
			var drawn := _streamer.renderer_for(path)
			for index in drawn.count():
				if _pool.body_for(drawn, index) != null:
					went_live["%s:%d" % [path, index]] = true
		time += 0.05
	assert_gt(went_live.size(), 1, "the path must make several bodies live")


func test_live_bodies_are_mass_bodies_with_gravity() -> void:
	_step(_root_renderer().child_position(0, 0.0), 0.0)
	var body := _pool.body_for(_root_renderer(), 0)
	assert_true(body.is_in_group(MassBody.GROUP))
	assert_gte(GravityRegistry.index_of(body.gravity), 0)


func test_physics_runs_clock_then_streamer_then_pool_then_gravity() -> void:
	var clock: Clock = autofree(Clock.new())
	assert_lt(
		clock.process_physics_priority,
		_streamer.process_physics_priority,
	)
	assert_lt(
		_streamer.process_physics_priority,
		_pool.process_physics_priority,
	)
	assert_lt(
		_pool.process_physics_priority,
		GravityRegistry.process_physics_priority,
	)


func test_missing_streamer_is_reported() -> void:
	var pool := LiveBodyPool.new()
	add_child_autofree(pool)
	assert_push_error("[Contract] Pre-condition broken: streamer must be set")
	pool.update(Vector3.ZERO, 0.0)
	assert_eq(pool.live_count(), 0)
