extends GutTest

const FRAMES := 30

var _was_enabled: bool
var _body: RigidBody3D
var _input: InputComponent
var _thruster: ThrusterComponent


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
	_thruster.apply_thrust(Vector3(0.0, 0.0, -2.0))
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "thrust intent axes must be within [-1, 1]"
	)
	await wait_physics_frames(1)
	assert_eq(_body.linear_velocity, Vector3.ZERO)


func test_negative_force_is_reported_and_not_applied() -> void:
	_thruster.set_physics_process(false)
	_thruster.back_thrust_force = -1.0
	_thruster.apply_thrust(Vector3.FORWARD)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "back_thrust_force must not be negative"
	)
	await wait_physics_frames(1)
	assert_eq(_body.linear_velocity, Vector3.ZERO)
