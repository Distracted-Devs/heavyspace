class_name PlayerShip
extends Node3D

@export var roll_impulse := 2.0
@export var pitch_impulse := 2.0
@export var yaw_impulse := 2.0

@export var thrust_force := 20.0

@export var gravitational_constant := 10.0
@export var softening := 0.5 # stops the force blowing up at tiny distances
@export var mass_change_rate := 10.0 # units per second
@export var min_mass := 0.1
@export var max_mass := 1000.0

@onready var ship: RigidBody3D = $Ship


func _physics_process(delta: float) -> void:
	_apply_rotation(delta)
	_adjust_mass(delta)
	_apply_thrust()
	_apply_gravity()


func _apply_rotation(delta: float) -> void:
	var roll := int(Input.is_physical_key_pressed(KEY_A)) - int(
		Input.is_physical_key_pressed(KEY_D)
	)
	var pitch := int(Input.is_physical_key_pressed(KEY_S)) - int(
		Input.is_physical_key_pressed(KEY_W)
	)
	var yaw := int(Input.is_physical_key_pressed(KEY_Q)) - int(Input.is_physical_key_pressed(KEY_E))

	var torque := ship.global_basis.z * roll * roll_impulse \
			+ ship.global_basis.x * pitch * pitch_impulse \
			+ ship.global_basis.y * yaw * yaw_impulse

	if torque != Vector3.ZERO:
		ship.apply_torque_impulse(torque * delta)


func _apply_thrust() -> void:
	if Input.is_physical_key_pressed(KEY_SPACE):
		ship.apply_central_force(-ship.global_basis.z * thrust_force)


func _apply_gravity() -> void:
	var total_force := Vector3.ZERO

	for node in get_tree().get_nodes_in_group("bodies"):
		if node == ship or node == self or not node is Node3D:
			continue

		var offset: Vector3 = node.global_position - ship.global_position
		var dist_sq := offset.length_squared() + softening * softening
		var other_mass := _get_mass(node)

		var magnitude := gravitational_constant * ship.mass * other_mass / dist_sq
		total_force += offset.normalized() * magnitude

	ship.apply_central_force(total_force)


func _get_mass(node: Node) -> float:
	if node is RigidBody3D:
		return node.mass
	return node.get_meta("mass", 1.0)


func _adjust_mass(delta: float) -> void:
	var change := int(Input.is_physical_key_pressed(KEY_X)) - int(
		Input.is_physical_key_pressed(KEY_Z)
	)

	if change != 0:
		ship.mass = clamp(ship.mass + change * mass_change_rate * delta, min_mass, max_mass)
