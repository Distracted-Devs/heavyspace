extends GutTest

const SHIP_RADIUS := 0.5

var _was_enabled: bool
var _streamer: HierarchyStreamer
var _pool: LiveBodyPool
var _ship: RigidBody3D
var _mass: MassComponent
var _absorb: AbsorbEffect
var _pickup: PickupComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_streamer = HierarchyStreamer.new()
	_streamer.level_seed = 7
	_streamer.root_radius = 100.0
	_streamer.root_mass = 1.0e7
	_streamer.tiers = [_systems_tier(), _rings_tier()]
	add_child_autofree(_streamer)
	_pool = LiveBodyPool.new()
	_pool.streamer = _streamer
	add_child_autofree(_pool)
	_ship = _make_ship()
	add_child_autofree(_ship)


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


func _make_ship() -> RigidBody3D:
	var ship := RigidBody3D.new()
	ship.gravity_scale = 0.0
	ship.freeze = true
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = SHIP_RADIUS
	collider.shape = sphere
	ship.add_child(collider)
	_mass = MassComponent.new()
	_mass.body = ship
	ship.add_child(_mass)
	_absorb = AbsorbEffect.new()
	_absorb.ship = ship
	ship.add_child(_absorb)
	_pickup = PickupComponent.new()
	_pickup.body = ship
	_pickup.mass_component = _mass
	_pickup.collider = collider
	_pickup.pool = _pool
	_pickup.absorb = _absorb
	_pickup.process_mode = Node.PROCESS_MODE_DISABLED
	ship.add_child(_pickup)
	return ship


func _innermost(renderer: OrbitRenderer) -> int:
	var orbits := renderer.layout.orbit_radius
	var best := 0
	for index in orbits.size():
		if orbits[index] < orbits[best]:
			best = index
	return best


func _ring_body_live() -> MassBody:
	var systems := _streamer.renderer_for(PackedInt32Array())
	var system_centre := systems.child_position(0, 0.0)
	_streamer.update(system_centre, 0.0)
	_pool.update(system_centre, 0.0)
	var ring := _streamer.renderer_for(PackedInt32Array([0]))
	var spot := ring.child_position(_innermost(ring), 0.0)
	_streamer.update(spot, 0.0)
	_pool.update(spot, 0.0)
	await wait_physics_frames(1)
	var body := _pool.body_for(ring, _innermost(ring))
	assert_not_null(body, "the innermost ring body must be live")
	return body


func _park_ship(at: Vector3, ship_mass: float) -> void:
	_ship.global_position = at
	_mass.current_mass = ship_mass


func _finish_absorbing() -> void:
	for step in 4:
		_absorb.advance(_absorb.suck_duration)


func test_reach_is_measured_from_the_ship_surface() -> void:
	_pickup.pickup_radius = 8.0
	_pickup.size_scale = 2.0
	assert_eq(_pickup.reach(), 8.0 * 2.0 + SHIP_RADIUS)


func test_body_of_equal_mass_in_reach_is_caught() -> void:
	var body := await _ring_body_live()
	_park_ship(body.global_position + Vector3.UP * 3.0, body.mass)
	_pickup.collect()
	assert_true(_absorb.is_absorbing(body))
	assert_false(_pool.is_live(body))


func test_heavier_body_is_never_caught() -> void:
	var body := await _ring_body_live()
	_park_ship(body.global_position, body.mass * 0.99)
	_pickup.collect()
	assert_false(_absorb.is_absorbing(body))
	assert_true(_pool.is_live(body))


func test_body_beyond_reach_is_not_caught() -> void:
	var body := await _ring_body_live()
	_pickup.pickup_radius = 1.0
	var gap := body.radius + _pickup.reach() + 0.1
	_park_ship(body.global_position + Vector3.UP * gap, body.mass)
	_pickup.collect()
	assert_false(_absorb.is_absorbing(body))


func test_absorbed_mass_is_added_with_the_conversion() -> void:
	var body := await _ring_body_live()
	_pickup.pickup_radius = 0.5
	_pickup.mass_conversion = 2.5
	var eaten := body.mass
	_park_ship(body.global_position, eaten)
	_pickup.collect()
	assert_eq(_absorb.absorbing_count(), 1, "only the one body is in reach")
	_finish_absorbing()
	assert_almost_eq(_mass.current_mass, eaten + eaten * 2.5, 1.0e-9)


func test_eating_a_parent_brings_its_whole_ring() -> void:
	var body := await _ring_body_live()
	var systems := _streamer.renderer_for(PackedInt32Array())
	var system := _pool.body_for(systems, 0)
	var ring := _streamer.renderer_for(PackedInt32Array([0]))
	var expected := system.mass
	for index in ring.count():
		expected += ring.layout.mass[index]
	var start := 1.0e6
	_park_ship(body.global_position, start)
	_pickup.pickup_radius = 25.0
	_pickup.collect()
	assert_true(_absorb.is_absorbing(system))
	assert_true(_absorb.is_absorbing(body))
	assert_true(_streamer.is_removed(PackedInt32Array([0])))
	_finish_absorbing()
	assert_almost_eq(_mass.current_mass, start + expected, 1.0e-6)


func test_every_caught_body_is_held_by_the_absorb_effect() -> void:
	var body := await _ring_body_live()
	_park_ship(body.global_position, 1.0e6)
	_pickup.pickup_radius = 50.0
	_pickup.collect()
	assert_gt(_absorb.absorbing_count(), 1)
	assert_eq(_pool.live_count(), 0)


func test_physics_frames_collect_and_grow() -> void:
	var body := await _ring_body_live()
	var start := body.mass
	_park_ship(body.global_position, start)
	_pickup.pickup_radius = 0.5
	_pickup.process_mode = Node.PROCESS_MODE_INHERIT
	await wait_physics_frames(60)
	assert_gt(_mass.current_mass, start)


func _add_cargo(tank_size: float) -> CargoComponent:
	var cargo := CargoComponent.new()
	cargo.tank_size = tank_size
	_ship.add_child(cargo)
	_pickup.cargo = cargo
	return cargo


func test_with_a_cargo_absorbed_mass_fills_it_not_the_ship() -> void:
	var body := await _ring_body_live()
	var cargo := _add_cargo(100.0)
	_pickup.pickup_radius = 0.5
	_pickup.mass_conversion = 2.0
	var eaten := body.mass
	_park_ship(body.global_position, eaten)
	_pickup.collect()
	_finish_absorbing()
	assert_almost_eq(cargo.stored, eaten * 2.0, 1.0e-9)
	assert_almost_eq(_mass.current_mass, eaten, 1.0e-9)


func test_a_full_cargo_catches_nothing() -> void:
	var body := await _ring_body_live()
	var cargo := _add_cargo(1.0)
	cargo.add(1.0)
	_park_ship(body.global_position, body.mass)
	_pickup.collect()
	assert_false(_absorb.is_absorbing(body))
	assert_true(_pool.is_live(body))


func test_what_does_not_fit_in_the_cargo_is_lost() -> void:
	var cargo := _add_cargo(1.0)
	_absorb.absorbed.emit(3.0)
	assert_almost_eq(cargo.stored, 1.0, 1.0e-9)


func test_without_a_pool_collect_does_nothing() -> void:
	_pickup.pool = null
	_pickup.collect()
	assert_eq(_absorb.absorbing_count(), 0)


func test_bad_settings_are_reported_and_ignored() -> void:
	_pickup.pickup_radius = -1.0
	assert_push_error(
		"[Contract] Pre-condition broken: pickup_radius must not be negative"
	)
	_pickup.mass_conversion = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: mass_conversion must be positive"
	)
	_pickup.size_scale = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: size_scale must be positive"
	)
	assert_eq(_pickup.pickup_radius, 8.0)
	assert_eq(_pickup.mass_conversion, 1.0)
	assert_eq(_pickup.size_scale, 1.0)
