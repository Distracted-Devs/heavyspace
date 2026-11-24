class_name PassThroughComponent
extends Node

@export_group("Components")
@export var body: RigidBody3D
@export var mass_component: MassComponent
@export var cargo: CargoComponent
@export var pool: LiveBodyPool

@export_group("Pass through")
@export_range(0.0, 1000.0, 0.1, "or_greater") var reach := 100.0:
	set(value):
		if not Contract.require(value >= 0.0, "reach must not be negative"):
			return
		reach = value

var _passable: Array[MassBody] = []


func _physics_process(_delta: float) -> void:
	update()


func passable() -> Array[MassBody]:
	return _passable


func update() -> void:
	if not Contract.require(
		body != null and mass_component != null,
		"body and mass_component must be set",
	):
		return
	var wanted := _wanted()
	for other in _passable:
		if is_instance_valid(other) and not wanted.has(other):
			body.remove_collision_exception_with(other)
	for other in wanted:
		if not _passable.has(other):
			body.add_collision_exception_with(other)
	_passable = wanted
	Contract.ensure(
		_exceptions_match(),
		"the body must pass through exactly the passable bodies",
	)


func _wanted() -> Array[MassBody]:
	if cargo == null or pool == null or not cargo.is_full():
		return []
	return pool.bodies_within(
		body.global_position,
		reach,
		mass_component.current_mass,
	)


func _exceptions_match() -> bool:
	var exceptions := body.get_collision_exceptions()
	for other in _passable:
		if not exceptions.has(other):
			return false
	return true
