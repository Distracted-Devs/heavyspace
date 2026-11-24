extends GutTest

const TOLERANCE := Vector3.ONE * 1e-4

var _was_enabled: bool
var _body: RigidBody3D
var _arcade: ArcadeFlightComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = FakeBody.make()
	_arcade = ArcadeFlightComponent.new()
	_arcade.body = _body
	_arcade.set_physics_process(false)
	_body.add_child(_arcade)
	add_child_autofree(_body)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _forward() -> Vector3:
	return -_body.global_basis.z


func test_full_alignment_points_the_velocity_along_the_facing() -> void:
	_body.rotation.y = PI / 3.0
	_body.linear_velocity = Vector3(4.0, 1.0, 2.0)
	var speed := _body.linear_velocity.length()
	_arcade.align()
	assert_almost_eq(_body.linear_velocity, _forward() * speed, TOLERANCE)


func test_turning_keeps_the_speed() -> void:
	_body.rotation = Vector3(0.4, 1.1, -0.7)
	_arcade.alignment = 0.3
	_body.linear_velocity = Vector3(-2.0, 5.0, 3.0)
	var speed := _body.linear_velocity.length()
	_arcade.align()
	assert_almost_eq(_body.linear_velocity.length(), speed, 1e-4)


func test_partial_alignment_swings_part_way_to_the_facing() -> void:
	_arcade.alignment = 0.5
	_body.linear_velocity = Vector3.RIGHT * 2.0
	_arcade.align()
	var expected := Vector3(1.0, 0.0, -1.0).normalized() * 2.0
	assert_almost_eq(_body.linear_velocity, expected, TOLERANCE)


func test_zero_alignment_leaves_the_velocity_alone() -> void:
	_arcade.alignment = 0.0
	var velocity := Vector3(1.0, 2.0, 3.0)
	_body.linear_velocity = velocity
	_arcade.align()
	assert_almost_eq(_body.linear_velocity, velocity, TOLERANCE)


func test_a_body_at_rest_stays_at_rest() -> void:
	_arcade.align()
	assert_eq(_body.linear_velocity, Vector3.ZERO)


func test_flying_straight_backwards_turns_forward_at_the_same_speed() -> void:
	_arcade.alignment = 0.5
	_body.linear_velocity = -_forward() * 3.0
	_arcade.align()
	assert_almost_eq(_body.linear_velocity, _forward() * 3.0, TOLERANCE)


func test_the_velocity_follows_the_ship_as_it_turns() -> void:
	_arcade.set_physics_process(true)
	_body.linear_velocity = _forward() * 2.0
	_body.angular_velocity = Vector3.UP
	await wait_physics_frames(30)
	assert_almost_eq(
		_body.linear_velocity.normalized(),
		_forward(),
		Vector3.ONE * 2e-2,
	)
	assert_almost_eq(_body.linear_velocity.length(), 2.0, 1e-3)


func test_alignment_outside_unit_is_reported_and_ignored() -> void:
	_arcade.alignment = 1.5
	assert_push_error(
		"[Contract] Pre-condition broken: alignment must be within [0, 1]"
	)
	assert_eq(_arcade.alignment, 1.0)


func test_missing_body_is_reported_and_changes_nothing() -> void:
	var velocity := Vector3.RIGHT
	_body.linear_velocity = velocity
	_arcade.body = null
	_arcade.align()
	assert_push_error("[Contract] Pre-condition broken: body must be set")
	assert_eq(_body.linear_velocity, velocity)


func test_runs_after_the_rotation_component() -> void:
	assert_gt(
		_arcade.process_physics_priority,
		autofree(RotationComponent.new()).process_physics_priority,
	)


func _add_drift(drift: Vector3) -> GravityReceiverComponent:
	var receiver := GravityReceiverComponent.new()
	receiver.body = _body
	receiver.drift_enabled = true
	receiver.set_physics_process(false)
	_body.add_child(receiver)
	receiver.drift = drift
	_arcade.gravity_receiver = receiver
	return receiver


func test_the_gravity_drift_survives_alignment() -> void:
	var drift := Vector3(0.0, -3.0, 0.0)
	_add_drift(drift)
	_body.linear_velocity = Vector3(4.0, 0.0, 0.0) + drift
	_arcade.align()
	assert_almost_eq(_body.linear_velocity, _forward() * 4.0 + drift, TOLERANCE)


func test_a_ship_moved_only_by_drift_is_not_steered() -> void:
	var drift := Vector3(2.0, 0.0, 0.0)
	_add_drift(drift)
	_body.linear_velocity = drift
	_arcade.align()
	assert_almost_eq(_body.linear_velocity, drift, TOLERANCE)


func test_a_disabled_drift_is_steered_like_any_velocity() -> void:
	var receiver := _add_drift(Vector3(2.0, 0.0, 0.0))
	receiver.drift_enabled = false
	_body.linear_velocity = Vector3(2.0, 0.0, 0.0)
	_arcade.align()
	assert_almost_eq(_body.linear_velocity, _forward() * 2.0, TOLERANCE)
