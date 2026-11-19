extends GutTest

var _was_enabled: bool
var _receiver: GravityReceiverComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	var body: RigidBody3D = add_child_autofree(FakeBody.make())
	_receiver = GravityReceiverComponent.new()
	_receiver.body = body
	body.add_child(_receiver)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _spawn_source(parent: Node) -> GravityComponent:
	var gravity := GravityComponent.new()
	parent.add_child(gravity)
	add_child_autofree(parent)
	return gravity


func test_source_registers_with_receivers_at_parent_position() -> void:
	var parent := Node3D.new()
	parent.position = Vector3(1.0, 2.0, 3.0)
	var gravity := _spawn_source(parent)
	assert_eq(_receiver.gravity_sources, [gravity])
	assert_eq(gravity.source_position, Vector3(1.0, 2.0, 3.0))


func test_freed_source_unregisters_from_receivers() -> void:
	var parent := Node3D.new()
	_spawn_source(parent)
	parent.free()
	assert_eq(_receiver.gravity_sources, [])


func test_non_node3d_parent_is_reported_and_does_not_register() -> void:
	_spawn_source(Node.new())
	assert_push_error(
		"[Contract] Pre-condition broken: parent must be a Node3D"
	)
	assert_eq(_receiver.gravity_sources, [])


func test_non_positive_mass_is_reported_and_ignored() -> void:
	var gravity: GravityComponent = autofree(GravityComponent.new())
	gravity.mass = 5.0
	gravity.mass = 0.0
	assert_push_error("[Contract] Pre-condition broken: mass must be positive")
	assert_eq(gravity.mass, 5.0)


func test_non_positive_radius_is_reported_and_ignored() -> void:
	var gravity: GravityComponent = autofree(GravityComponent.new())
	gravity.radius = 5.0
	gravity.radius = -1.0
	assert_push_error(
		"[Contract] Pre-condition broken: radius must be positive"
	)
	assert_eq(gravity.radius, 5.0)
