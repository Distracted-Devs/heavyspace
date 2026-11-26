extends GutTest

const FRAMES := 30
const SPEED_TOLERANCE := 0.05
const FUEL_TOLERANCE := 0.02

var _was_enabled: bool
var _body: RigidBody3D
var _input: InputComponent
var _thruster: ThrusterComponent
var _fuel: FuelComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = FakeBody.make()
	_input = InputComponent.new()
	_thruster = ThrusterComponent.new()
	_thruster.body = _body
	_thruster.flight_input = _input
	_body.add_child(_input)
	_body.add_child(_thruster)
	add_child_autofree(_body)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _expected_speed(force: float) -> float:
	return force / _body.mass * FRAMES / Engine.physics_ticks_per_second


func test_forward_intent_pushes_along_global_forward() -> void:
	_body.rotation.y = PI / 2.0
	_input.thrust_intent = Vector3.FORWARD
	await wait_physics_frames(FRAMES)
	assert_almost_eq(
		_body.linear_velocity.normalized(),
		Vector3.LEFT,
		Vector3.ONE * 1e-3,
	)


func test_forward_intent_accelerates_by_back_force_over_mass() -> void:
	_thruster.back_thrust_force = 3.0
	_input.thrust_intent = Vector3.FORWARD
	await wait_physics_frames(FRAMES)
	assert_almost_eq(_body.linear_velocity.length(), _expected_speed(3.0), 1e-2)


func test_forward_intent_is_the_only_thrust() -> void:
	_input.thrust_intent = Vector3(0.0, 0.0, -1.0)
	await wait_physics_frames(FRAMES)
	assert_almost_eq(_body.linear_velocity.x, 0.0, 1e-6)
	assert_almost_eq(_body.linear_velocity.y, 0.0, 1e-6)


func test_intent_outside_unit_is_reported_and_not_applied() -> void:
	_thruster.set_physics_process(false)
	_thruster.apply_thrust(Vector3(0.0, 0.0, -2.0), 1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "thrust intent axes must be within [-1, 1]"
	)
	await wait_physics_frames(1)
	assert_eq(_body.linear_velocity, Vector3.ZERO)


func test_negative_force_is_reported_and_not_applied() -> void:
	_thruster.set_physics_process(false)
	_thruster.back_thrust_force = -1.0
	_thruster.apply_thrust(Vector3.FORWARD, 1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "back_thrust_force must not be negative"
	)
	await wait_physics_frames(1)
	assert_eq(_body.linear_velocity, Vector3.ZERO)


func _add_fuel() -> void:
	_fuel = FuelComponent.new()
	_thruster.fuel = _fuel
	_body.add_child(_fuel)


func _seconds(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func test_rejected_thrust_draws_no_fuel() -> void:
	_add_fuel()
	_thruster.set_physics_process(false)
	_thruster.apply_thrust(Vector3(0.0, 0.0, -2.0), 1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "thrust intent axes must be within [-1, 1]"
	)
	assert_eq(_fuel.fuel, _fuel.tank_size)


func test_full_boost_from_full_lasts_one_second_then_stops() -> void:
	_add_fuel()
	_input.thrust_intent = Vector3.FORWARD
	await wait_physics_frames(_seconds(1.5))
	assert_almost_eq(_fuel.fuel, 0.0, FUEL_TOLERANCE)
	assert_almost_eq(
		_body.linear_velocity.length(),
		_thruster.back_thrust_force / _body.mass,
		SPEED_TOLERANCE,
	)


func test_releasing_boost_refills_in_five_seconds() -> void:
	_add_fuel()
	_input.thrust_intent = Vector3.FORWARD
	await wait_physics_frames(_seconds(1.5))
	_input.thrust_intent = Vector3.ZERO
	await wait_physics_frames(_seconds(2.5))
	assert_almost_eq(_fuel.fuel, _fuel.tank_size / 2.0, FUEL_TOLERANCE)
	await wait_physics_frames(_seconds(2.6))
	assert_eq(_fuel.fuel, _fuel.tank_size)


func test_half_boost_lasts_twice_as_long() -> void:
	_add_fuel()
	_input.thrust_intent = Vector3.FORWARD / 2.0
	await wait_physics_frames(_seconds(1.5))
	assert_almost_eq(_fuel.fuel, 0.25, FUEL_TOLERANCE)
	await wait_physics_frames(_seconds(1.0))
	assert_almost_eq(_fuel.fuel, 0.0, FUEL_TOLERANCE)
	assert_almost_eq(
		_body.linear_velocity.length(),
		_thruster.back_thrust_force / _body.mass,
		SPEED_TOLERANCE,
	)


func test_thruster_without_fuel_never_runs_out() -> void:
	_input.thrust_intent = Vector3.FORWARD
	await wait_physics_frames(_seconds(2.0))
	assert_almost_eq(
		_body.linear_velocity.length(),
		2.0 * _thruster.back_thrust_force / _body.mass,
		SPEED_TOLERANCE,
	)


func test_the_thrust_multiplier_scales_the_force() -> void:
	_thruster.back_thrust_force = 3.0
	_thruster.thrust_multiplier = 2.0
	_input.thrust_intent = Vector3.FORWARD
	await wait_physics_frames(FRAMES)
	assert_almost_eq(_body.linear_velocity.length(), _expected_speed(6.0), 1e-2)


func test_a_negative_thrust_multiplier_is_reported_and_ignored() -> void:
	var thrust_multiplier := _thruster.thrust_multiplier
	_thruster.thrust_multiplier = -1.0
	assert_push_error(
		"Pre-condition broken: thrust_multiplier must not be negative"
	)
	assert_eq(_thruster.thrust_multiplier, thrust_multiplier)
