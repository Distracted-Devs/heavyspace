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
