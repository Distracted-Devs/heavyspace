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


func test_promoted_body_takes_the_seed_of_its_orbit() -> void:
	var renderer := _root_renderer()
	_step(renderer.child_position(0, 0.0), 0.0)
	var body := _pool.body_for(renderer, 0)
	var expected := PlanetSeed.of(
		renderer.layout.orbit_radius[0],
		renderer.layout.phase[0],
	)
	assert_almost_eq(body.look_seed, expected, 1.0e-6)


func test_promoted_body_draws_its_surface_in_its_rings_frame() -> void:
	var renderer := _root_renderer()
	renderer.basis = Basis(Vector3(0.3, 1.0, 0.2).normalized(), 0.8)
	_step(renderer.child_position(0, 0.0), 0.0)
	var body := _pool.body_for(renderer, 0)
	assert_true(
		body
		.surface_frame
		.is_equal_approx(renderer.global_basis.orthonormalized())
	)


func test_live_depths_follow_the_hierarchy() -> void:
	var system_spot := _root_renderer().child_position(0, 0.0)
	_step(system_spot, 0.0)
	var system := _pool.body_for(_root_renderer(), 0)
	var ring := _streamer.renderer_for(PackedInt32Array([0]))
	_step(ring.child_position(0, 0.0), 0.0)
	var moon := _pool.body_for(ring, 0)
	assert_not_null(moon)
	var bodies := _pool.live_bodies()
	assert_eq(_pool.live_depths()[bodies.find(system)], 1)
	assert_eq(_pool.live_depths()[bodies.find(moon)], 2)


func test_live_depths_match_live_bodies_one_to_one() -> void:
	var renderer := _root_renderer()
	_step(renderer.child_position(0, 0.0), 0.0)
	assert_eq(_pool.live_depths().size(), _pool.live_count())
	_step(renderer.child_position(0, 0.0) + Vector3(1.0e7, 0.0, 0.0), 0.0)
	assert_eq(_pool.live_depths().size(), _pool.live_count())


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


func _innermost(renderer: OrbitRenderer) -> int:
	var orbits := renderer.layout.orbit_radius
	var best := 0
	for index in orbits.size():
		if orbits[index] < orbits[best]:
			best = index
	return best


func _system_and_ring_body_live() -> Array:
	_step(_root_renderer().child_position(0, 0.0), 0.0)
	var ring := _streamer.renderer_for(PackedInt32Array([0]))
	var index := _innermost(ring)
	_step(ring.child_position(index, 0.0), 0.0)
	var system := _pool.body_for(_root_renderer(), 0)
	var ring_body := _pool.body_for(ring, index)
	assert_not_null(system, "the system must be live")
	assert_not_null(ring_body, "the innermost ring body must be live")
	return [system, ring, index, ring_body]


func _assert_hidden_are_live_or_removed() -> void:
	for path in _streamer.expanded_paths():
		var renderer := _streamer.renderer_for(path)
		for index in renderer.count():
			var child := path.duplicate()
			child.append(index)
			var live := _pool.body_for(renderer, index) != null
			var removed := _streamer.is_removed(child)
			assert_false(live and removed, "%s is live and removed" % child)
			assert_eq(renderer.is_hidden(index), live or removed, str(child))


func test_taken_ring_body_is_handed_over_without_being_freed() -> void:
	var live := _system_and_ring_body_live()
	var ring: OrbitRenderer = live[1]
	var index: int = live[2]
	var body: MassBody = live[3]
	var count := _pool.live_count()
	var taken := _pool.take(body)
	assert_eq(taken.bodies, [body] as Array[MassBody])
	assert_eq(taken.drawn_mass, 0.0)
	assert_eq(_pool.live_count(), count - 1)
	assert_null(_pool.body_for(ring, index))
	assert_true(ring.is_hidden(index))
	assert_true(body.is_inside_tree())
	assert_false(body.is_queued_for_deletion())


func test_taken_body_is_no_longer_moved_or_freed_by_the_pool() -> void:
	var live := _system_and_ring_body_live()
	var ring: OrbitRenderer = live[1]
	var index: int = live[2]
	var body: MassBody = live[3]
	_pool.take(body)
	await _settle()
	var held := body.global_position
	_step(ring.child_position(index, 5.0), 5.0)
	await _settle()
	assert_almost_eq(body.global_position.distance_to(held), 0.0, 1.0e-4)
	_step(FAR_AWAY, 5.0)
	assert_false(body.is_queued_for_deletion())


func test_taken_child_is_never_promoted_again() -> void:
	var live := _system_and_ring_body_live()
	var ring: OrbitRenderer = live[1]
	var index: int = live[2]
	_pool.take(live[3])
	_step(ring.child_position(index, 0.0), 0.0)
	assert_null(_pool.body_for(ring, index))
	assert_true(ring.is_hidden(index))
	_assert_hidden_are_live_or_removed()


func test_taken_child_stays_hidden_after_its_parent_re_expands() -> void:
	var live := _system_and_ring_body_live()
	var index: int = live[2]
	_pool.take(live[3])
	_step(FAR_AWAY, 0.0)
	assert_null(_streamer.renderer_for(PackedInt32Array([0])))
	_step(_root_renderer().child_position(0, 0.0), 0.0)
	var ring := _streamer.renderer_for(PackedInt32Array([0]))
	assert_true(ring.is_hidden(index))
	_step(ring.child_position(index, 0.0), 0.0)
	assert_null(_pool.body_for(ring, index))
	_assert_hidden_are_live_or_removed()


func test_taking_a_parent_takes_its_live_descendants_too() -> void:
	var live := _system_and_ring_body_live()
	var system: MassBody = live[0]
	var ring: OrbitRenderer = live[1]
	var live_ring: Array[MassBody] = []
	var drawn_mass := 0.0
	for index in ring.count():
		var body := _pool.body_for(ring, index)
		if body:
			live_ring.append(body)
		else:
			drawn_mass += ring.layout.mass[index]
	var count := _pool.live_count()
	var taken := _pool.take(system)
	assert_eq(taken.bodies[0], system)
	assert_eq(taken.bodies.size(), 1 + live_ring.size())
	for body in live_ring:
		assert_has(taken.bodies, body)
	assert_almost_eq(taken.drawn_mass, drawn_mass, 1.0e-6)
	assert_eq(_pool.live_count(), count - taken.bodies.size())
	for body in taken.bodies:
		assert_false(body.is_queued_for_deletion())


func test_taking_a_parent_removes_its_path() -> void:
	var live := _system_and_ring_body_live()
	_pool.take(live[0])
	assert_true(_streamer.is_removed(PackedInt32Array([0])))
	assert_null(_streamer.renderer_for(PackedInt32Array([0])))
	assert_true(_root_renderer().is_hidden(0))
	_step(_root_renderer().child_position(0, 0.0), 0.0)
	assert_null(_streamer.renderer_for(PackedInt32Array([0])))
	assert_null(_pool.body_for(_root_renderer(), 0))
	_assert_hidden_are_live_or_removed()


func test_previously_taken_children_add_no_drawn_mass() -> void:
	var live := _system_and_ring_body_live()
	var system: MassBody = live[0]
	var ring: OrbitRenderer = live[1]
	var ring_body: MassBody = live[3]
	var drawn_mass := 0.0
	for index in ring.count():
		if _pool.body_for(ring, index) == null:
			drawn_mass += ring.layout.mass[index]
	_pool.take(ring_body)
	var taken := _pool.take(system)
	assert_false(taken.bodies.has(ring_body))
	assert_almost_eq(taken.drawn_mass, drawn_mass, 1.0e-6)


func test_taking_the_root_is_rejected() -> void:
	var taken := _pool.take(_pool.root_body)
	assert_push_error(
		"[Contract] Pre-condition broken: body must be a live body"
	)
	assert_true(taken.bodies.is_empty())
	assert_eq(taken.drawn_mass, 0.0)


func test_taking_a_body_the_pool_does_not_own_is_rejected() -> void:
	var stranger: MassBody = add_child_autofree(
		preload("res://scenes/bodies/mass_body.tscn").instantiate()
	)
	var taken := _pool.take(stranger)
	assert_push_error("body must be a live body")
	assert_true(taken.bodies.is_empty())


func test_bodies_within_finds_live_bodies_by_surface_distance() -> void:
	var live := _system_and_ring_body_live()
	var ring_body: MassBody = live[3]
	await _settle()
	var outward := Vector3.UP * (ring_body.radius + 2.0)
	var centre := ring_body.global_position + outward
	assert_has(_pool.bodies_within(centre, 2.01, INF), ring_body)
	assert_does_not_have(_pool.bodies_within(centre, 1.99, INF), ring_body)


func test_bodies_within_leaves_out_heavier_bodies() -> void:
	var live := _system_and_ring_body_live()
	var ring_body: MassBody = live[3]
	await _settle()
	var centre := ring_body.global_position
	assert_has(_pool.bodies_within(centre, 0.0, ring_body.mass), ring_body)
	assert_does_not_have(
		_pool.bodies_within(centre, 0.0, ring_body.mass * 0.99),
		ring_body,
	)


func test_bodies_within_never_returns_the_root() -> void:
	var found := _pool.bodies_within(_streamer.global_position, 1.0e6, INF)
	assert_does_not_have(found, _pool.root_body)


func test_bodies_within_only_returns_live_bodies() -> void:
	_system_and_ring_body_live()
	await _settle()
	for body in _pool.bodies_within(Vector3.ZERO, 1.0e6, INF):
		assert_true(_pool.is_live(body))


func test_negative_reach_is_rejected() -> void:
	var found := _pool.bodies_within(Vector3.ZERO, -1.0, INF)
	assert_push_error(
		"[Contract] Pre-condition broken: reach must not be negative"
	)
	assert_true(found.is_empty())


func test_taken_body_is_no_longer_live() -> void:
	var live := _system_and_ring_body_live()
	var ring_body: MassBody = live[3]
	assert_true(_pool.is_live(ring_body))
	_pool.take(ring_body)
	assert_false(_pool.is_live(ring_body))
	assert_false(_pool.is_live(_pool.root_body))
