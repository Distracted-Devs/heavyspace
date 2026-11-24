extends GutTest

const SOURCE_POSITION := Vector3(0.0, 0.0, -10.0)

var _was_enabled: bool
var _body: RigidBody3D
var _receiver: GravityReceiverComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = add_child_autofree(FakeBody.make())
	_body.mass = 2.0
	_receiver = GravityReceiverComponent.new()
	_receiver.body = _body
	_receiver.gravity_constant = 1.0
	_body.add_child(_receiver)
	_receiver.set_physics_process(false)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _spawn_source(
	source_mass: float,
	at := SOURCE_POSITION,
	source_radius := 1.0,
) -> GravityComponent:
	var parent: Node3D = add_child_autofree(Node3D.new())
	parent.position = at
	var gravity := GravityComponent.new()
	gravity.mass = source_mass
	gravity.radius = source_radius
	parent.add_child(gravity)
	return gravity


func _velocity_after_one_pull() -> Vector3:
	_body.global_position = Vector3.ZERO
	_body.linear_velocity = Vector3.ZERO
	_receiver.apply_gravity()
	await wait_physics_frames(1)
	return _body.linear_velocity


func test_heavier_source_pulls_body_towards_it() -> void:
	_spawn_source(100.0)
	var velocity := await _velocity_after_one_pull()
	assert_gt(velocity.length(), 0.0)
	assert_almost_eq(
		velocity.normalized(),
		SOURCE_POSITION.normalized(),
		Vector3.ONE * 1e-3,
	)


func test_source_of_equal_mass_does_not_pull() -> void:
	_spawn_source(2.0)
	assert_eq(await _velocity_after_one_pull(), Vector3.ZERO)


func test_lighter_source_does_not_pull() -> void:
	_spawn_source(1.0)
	assert_eq(await _velocity_after_one_pull(), Vector3.ZERO)


func test_freed_source_no_longer_pulls() -> void:
	var gravity := _spawn_source(100.0)
	gravity.get_parent().free()
	assert_eq(await _velocity_after_one_pull(), Vector3.ZERO)


func test_source_added_before_receiver_still_pulls() -> void:
	_receiver.free()
	_spawn_source(100.0)
	_receiver = GravityReceiverComponent.new()
	_receiver.body = _body
	_receiver.gravity_constant = 1.0
	_body.add_child(_receiver)
	_receiver.set_physics_process(false)
	var velocity := await _velocity_after_one_pull()
	assert_gt(velocity.length(), 0.0)


func test_negative_gravity_constant_is_reported_and_applies_no_force() -> void:
	_spawn_source(100.0)
	_receiver.gravity_constant = -1.0
	var velocity := await _velocity_after_one_pull()
	assert_push_error(
		"[Contract] Pre-condition broken: gravity_constant must not be negative"
	)
	assert_eq(velocity, Vector3.ZERO)


func test_acceleration_does_not_depend_on_body_mass() -> void:
	_spawn_source(1000.0)
	_body.mass = 1.0
	var light := await _velocity_after_one_pull()
	_body.mass = 100.0
	var heavy := await _velocity_after_one_pull()
	assert_gt(light.length(), 0.0)
	assert_almost_eq(light, heavy, Vector3.ONE * 1e-6)


func test_force_follows_inverse_square_outside_radius() -> void:
	_body.mass = 1.0
	var gravity := _spawn_source(1000.0, Vector3(0.0, 0.0, -10.0))
	var near := await _velocity_after_one_pull()
	gravity.source_node.position = Vector3(0.0, 0.0, -20.0)
	await wait_physics_frames(1)
	var far := await _velocity_after_one_pull()
	assert_almost_eq(near.length(), far.length() * 4.0, 1e-6)


func test_distance_is_clamped_to_source_radius() -> void:
	var gravity := _spawn_source(100.0, Vector3(0.0, 0.0, -1.0), 5.0)
	var at_one := await _velocity_after_one_pull()
	gravity.source_node.position = Vector3(0.0, 0.0, -4.0)
	await wait_physics_frames(1)
	var at_four := await _velocity_after_one_pull()
	assert_almost_eq(at_one.length(), at_four.length(), 1e-6)


func test_force_at_distance_zero_is_finite() -> void:
	_spawn_source(100.0, Vector3.ZERO)
	var velocity := await _velocity_after_one_pull()
	assert_true(velocity.is_finite())
	assert_eq(velocity, Vector3.ZERO)


func test_falloff_exponent_sets_how_fast_the_pull_drops() -> void:
	_body.mass = 1.0
	_receiver.falloff_exponent = 3.0
	var gravity := _spawn_source(1000.0, Vector3(0.0, 0.0, -10.0))
	var near := await _velocity_after_one_pull()
	gravity.source_node.position = Vector3(0.0, 0.0, -20.0)
	await wait_physics_frames(1)
	var far := await _velocity_after_one_pull()
	assert_almost_eq(near.length(), far.length() * 8.0, 1e-6)


func test_acceleration_at_matches_g_m_over_r_to_the_exponent() -> void:
	var acceleration := GravityReceiverComponent.acceleration_at(
		Vector3.ZERO,
		PackedInt32Array([0]),
		PackedVector3Array([Vector3(0.0, 0.0, -10.0)]),
		PackedFloat64Array([1000.0]),
		PackedFloat64Array([1.0]),
		2.0,
		3.5,
	)
	assert_almost_eq(acceleration.length(), 2.0 * 1000.0 / pow(10.0, 3.5), 1e-6)
	assert_almost_eq(
		acceleration.normalized(),
		Vector3.FORWARD,
		Vector3.ONE * 1e-9,
	)


func test_the_core_mass_decides_what_is_heavier() -> void:
	var mass := MassComponent.new()
	_body.add_child(mass)
	mass.current_mass = 1.0
	_receiver.mass_component = mass
	_body.mass = 50.0
	_spawn_source(10.0)
	var velocity := await _velocity_after_one_pull()
	assert_gt(velocity.length(), 0.0, "cargo weight must not stop the pull")


func test_with_drift_the_pull_builds_up_a_drift_velocity() -> void:
	_receiver.drift_enabled = true
	_spawn_source(100.0)
	_body.global_position = Vector3.ZERO
	_body.linear_velocity = Vector3.ZERO
	_receiver.apply_gravity()
	assert_gt(_receiver.drift.length(), 0.0)
	assert_almost_eq(_body.linear_velocity, _receiver.drift, Vector3.ONE * 1e-6)
	assert_almost_eq(
		_receiver.drift.normalized(),
		SOURCE_POSITION.normalized(),
		Vector3.ONE * 1e-6,
	)


func test_drift_is_damped_like_the_body() -> void:
	_receiver.drift_enabled = true
	_body.linear_damp = 0.5
	_receiver.drift = Vector3(10.0, 0.0, 0.0)
	_receiver.apply_gravity()
	var delta := _receiver.get_physics_process_delta_time()
	assert_almost_eq(_receiver.drift.x, 10.0 * (1.0 - 0.5 * delta), 1e-6)


func test_reset_drift_clears_it() -> void:
	_receiver.drift = Vector3.ONE
	_receiver.reset_drift()
	assert_eq(_receiver.drift, Vector3.ZERO)


func test_non_positive_exponent_is_reported_and_ignored() -> void:
	_receiver.falloff_exponent = 0.0
	assert_push_error("falloff_exponent must be positive")
	assert_eq(_receiver.falloff_exponent, 2.0)
