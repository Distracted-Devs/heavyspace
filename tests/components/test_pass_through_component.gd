extends GutTest

const Fixture := preload("res://tests/components/ring_pool_fixture.gd")

var _was_enabled: bool
var _streamer: HierarchyStreamer
var _pool: LiveBodyPool
var _ship: RigidBody3D
var _mass: MassComponent
var _cargo: CargoComponent
var _pass_through: PassThroughComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_streamer = Fixture.make_streamer()
	add_child_autofree(_streamer)
	_pool = Fixture.make_pool(_streamer)
	add_child_autofree(_pool)
	_ship = RigidBody3D.new()
	_ship.gravity_scale = 0.0
	_ship.freeze = true
	_mass = MassComponent.new()
	_mass.body = _ship
	_ship.add_child(_mass)
	_cargo = CargoComponent.new()
	_cargo.tank_size = 1.0
	_ship.add_child(_cargo)
	_pass_through = PassThroughComponent.new()
	_pass_through.body = _ship
	_pass_through.mass_component = _mass
	_pass_through.cargo = _cargo
	_pass_through.pool = _pool
	_pass_through.reach = 5.0
	_pass_through.process_mode = Node.PROCESS_MODE_DISABLED
	_ship.add_child(_pass_through)
	add_child_autofree(_ship)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _ring_body() -> MassBody:
	var ring := Fixture.make_ring_body_live(_streamer, _pool)
	await wait_physics_frames(1)
	var body := _pool.body_for(ring, Fixture.innermost(ring))
	assert_not_null(body, "the innermost ring body must be live")
	return body


func _park(at: Vector3, ship_mass: float) -> void:
	_ship.global_position = at
	_mass.current_mass = ship_mass


func test_a_full_cargo_passes_through_lighter_bodies_in_reach() -> void:
	var body := await _ring_body()
	_park(body.global_position + Vector3.UP * 2.0, body.mass * 2.0)
	_cargo.add(1.0)
	_pass_through.update()
	assert_true(_pass_through.passable().has(body))
	assert_true(_ship.get_collision_exceptions().has(body))


func test_a_body_of_equal_mass_is_passable() -> void:
	var body := await _ring_body()
	_park(body.global_position + Vector3.UP * 2.0, body.mass)
	_cargo.add(1.0)
	_pass_through.update()
	assert_true(_ship.get_collision_exceptions().has(body))


func test_a_heavier_body_is_never_passable() -> void:
	var body := await _ring_body()
	_park(body.global_position + Vector3.UP * 2.0, body.mass * 0.5)
	_cargo.add(1.0)
	_pass_through.update()
	assert_false(_ship.get_collision_exceptions().has(body))


func test_with_room_in_the_cargo_nothing_is_passable() -> void:
	var body := await _ring_body()
	_park(body.global_position + Vector3.UP * 2.0, body.mass * 2.0)
	_pass_through.update()
	assert_eq(_pass_through.passable().size(), 0)
	assert_false(_ship.get_collision_exceptions().has(body))


func test_emptying_the_cargo_makes_bodies_solid_again() -> void:
	var body := await _ring_body()
	_park(body.global_position + Vector3.UP * 2.0, body.mass * 2.0)
	_cargo.add(1.0)
	_pass_through.update()
	_cargo.empty()
	_pass_through.update()
	assert_false(_ship.get_collision_exceptions().has(body))


func test_a_body_out_of_reach_becomes_solid_again() -> void:
	var body := await _ring_body()
	_park(body.global_position + Vector3.UP * 2.0, body.mass * 2.0)
	_cargo.add(1.0)
	_pass_through.update()
	_ship.global_position = body.global_position + Vector3.UP * 50.0
	_pass_through.update()
	assert_false(_ship.get_collision_exceptions().has(body))


func test_without_a_pool_nothing_is_passable() -> void:
	_pass_through.pool = null
	_cargo.add(1.0)
	_pass_through.update()
	assert_eq(_pass_through.passable().size(), 0)


func test_negative_reach_is_reported_and_ignored() -> void:
	_pass_through.reach = -1.0
	assert_push_error("reach must not be negative")
	assert_eq(_pass_through.reach, 5.0)
