extends GutTest

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func _spawn_source(parent: Node) -> GravityComponent:
	var gravity := GravityComponent.new()
	parent.add_child(gravity)
	add_child_autofree(parent)
	return gravity


func test_source_registers_at_parent_position_on_entering_tree() -> void:
	var parent := Node3D.new()
	parent.position = Vector3(1.0, 2.0, 3.0)
	var gravity := _spawn_source(parent)
	var index := GravityRegistry.index_of(gravity)
	assert_gte(index, 0)
	assert_eq(GravityRegistry.positions[index], Vector3(1.0, 2.0, 3.0))


func test_source_unregisters_on_leaving_tree() -> void:
	var parent := Node3D.new()
	var gravity := _spawn_source(parent)
	parent.remove_child(gravity)
	assert_eq(GravityRegistry.index_of(gravity), -1)
	gravity.free()


func test_mass_and_radius_changes_reach_the_registry() -> void:
	var gravity := _spawn_source(Node3D.new())
	gravity.mass = 7.0
	gravity.radius = 3.0
	var index := GravityRegistry.index_of(gravity)
	assert_eq(GravityRegistry.masses[index], 7.0)
	assert_eq(GravityRegistry.radii[index], 3.0)


func test_non_node3d_parent_is_reported_and_does_not_register() -> void:
	var gravity := _spawn_source(Node.new())
	assert_push_error(
		"[Contract] Pre-condition broken: parent must be a Node3D"
	)
	assert_eq(GravityRegistry.index_of(gravity), -1)


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
