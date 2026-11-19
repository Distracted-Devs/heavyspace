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


func _spawn_source(source_mass: float) -> GravityComponent:
	var parent: Node3D = add_child_autofree(Node3D.new())
	parent.position = SOURCE_POSITION
	var gravity := GravityComponent.new()
	gravity.mass = source_mass
	parent.add_child(gravity)
	return gravity


func _velocity_after_one_pull() -> Vector3:
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
	assert_eq(_receiver.gravity_sources, [])
	assert_eq(await _velocity_after_one_pull(), Vector3.ZERO)


func test_negative_gravity_constant_is_reported_and_applies_no_force() -> void:
	_spawn_source(100.0)
	_receiver.gravity_constant = -1.0
	var velocity := await _velocity_after_one_pull()
	assert_push_error(
		"[Contract] Pre-condition broken: gravity_constant must not be negative"
	)
	assert_eq(velocity, Vector3.ZERO)
