extends GutTest

const FRAMES := 30

var _was_enabled: bool
var _body: RigidBody3D
var _input: InputComponent
var _rotator: RotationComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = FakeBody.make()
	_input = InputComponent.new()
	_rotator = RotationComponent.new()
	_rotator.body = _body
	_rotator.flight_input = _input
	_body.add_child(_input)
	_body.add_child(_rotator)
	add_child_autofree(_body)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_turn_intent_spins_about_global_up() -> void:
	_body.rotation.x = PI / 2.0
	_input.rotation_intent = Vector3.UP
	await wait_physics_frames(1)
	var body_up := _body.global_basis.y
	await wait_physics_frames(FRAMES)
	assert_almost_eq(
		_body.angular_velocity.normalized(),
		body_up,
		Vector3.ONE * 1e-2,
	)


func test_roll_intent_spins_about_global_back() -> void:
	_body.rotation.y = PI / 2.0
	_input.rotation_intent = Vector3.BACK
	await wait_physics_frames(1)
	var body_back := _body.global_basis.z
	await wait_physics_frames(FRAMES)
	assert_almost_eq(
		_body.angular_velocity.normalized(),
		body_back,
		Vector3.ONE * 1e-2,
	)


func test_twice_the_torque_doubles_rotational_acceleration() -> void:
	_input.rotation_intent = Vector3.UP
	await wait_physics_frames(1)
	_body.angular_velocity = Vector3.ZERO
	await wait_physics_frames(FRAMES)
	var base_spin := _body.angular_velocity.length()
	_body.angular_velocity = Vector3.ZERO
	_rotator.turn_torque *= 2.0
	await wait_physics_frames(FRAMES)
	assert_gt(base_spin, 0.0)
	assert_almost_eq(_body.angular_velocity.length() / base_spin, 2.0, 1e-2)


func test_intent_outside_unit_is_reported_and_not_applied() -> void:
	_rotator.set_physics_process(false)
	_rotator.apply_rotation(Vector3(0.0, 0.0, -1.5))
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "rotation intent axes must be within [-1, 1]"
	)
	await wait_physics_frames(1)
	assert_eq(_body.angular_velocity, Vector3.ZERO)


func test_negative_torque_is_reported_and_not_applied() -> void:
	_rotator.set_physics_process(false)
	_rotator.turn_torque = -0.1
	_rotator.apply_rotation(Vector3.UP)
	assert_push_error(
		"[Contract] Pre-condition broken: rotation torques must not be negative"
	)
	await wait_physics_frames(1)
	assert_eq(_body.angular_velocity, Vector3.ZERO)
