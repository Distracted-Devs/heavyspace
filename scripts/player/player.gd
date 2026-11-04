class_name Player
extends Node3D

@export_group("Movement")
@export var roll_impulse := 2.0
@export var pitch_impulse := 2.0
@export var yaw_impulse := 2.0
@export var thrust_force := 20.0
@export var rotation_correction_speed := 1.0
@export var rotation_correction_multiplier := 1.0
@export var rotation_correction_exponent := 0.01

@export_group("Fuel")
@export var fuel_drain_rate := 20.0
@export var mass_to_fuel_ratio := .01

@export_group("Components")
@export var mass_component: MassComponent
@export var fuel_component: FuelComponent
@export var gravity_effect: GravityEffect
@export var ship: RigidBody3D


func _ready() -> void:
	add_to_group("player")
	fuel_component.changed.connect(_on_fuel_changed)
	mass_component.add_mass(fuel_component.fuel * mass_to_fuel_ratio)


func _physics_process(delta: float) -> void:
	_apply_rotation_correction(delta)
	_apply_rotation(delta)
	_apply_thrust(delta)


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


func _apply_thrust(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_SPACE) and fuel_component.fuel > 0.0:
		ship.apply_central_force(-ship.global_basis.z * thrust_force)
		fuel_component.add_fuel(-fuel_drain_rate * delta)


func _get_mass(node: Node) -> float:
	if node is RigidBody3D:
		return node.mass
	return node.get_meta("mass", 1.0)


func _on_fuel_changed(_new_fuel: float, delta_fuel: float) -> void:
	mass_component.add_mass(delta_fuel * mass_to_fuel_ratio)


func _apply_rotation_correction(_delta: float) -> void:
	var closest_gravity_body: GravityBody
	var closest_gravity_body_distance: float = INF
	for node in get_tree().get_nodes_in_group(&"gravity"):
		var gravity_body := node as GravityBody
		if not gravity_body:
			continue
		var gravity_body_distance: float = (
			gravity_body.global_position - self.global_position
		).length()

		if gravity_body_distance < closest_gravity_body_distance:
			closest_gravity_body = gravity_body
			closest_gravity_body_distance = gravity_body_distance

	if not closest_gravity_body:
		return

	var up: Vector3 = ship.global_position - closest_gravity_body.global_position

	if up.is_zero_approx():
		return
	up = up.normalized()

	# Tangent: velocity minus its radial part, falling back to the current nose.
	var forward: Vector3 = ship.linear_velocity - up * ship.linear_velocity.dot(up)
	if forward.length_squared() < 0.01:
		var nose: Vector3 = -ship.global_basis.z
		forward = nose - up * nose.dot(up)
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()

	# -Z along the tangent, +Y away from the body.
	var target_basis := Basis.looking_at(forward, up)
	var current_basis: Basis = ship.global_basis.orthonormalized()

	# Rotation that takes current -> target.
	var error: Quaternion = target_basis.get_rotation_quaternion() \
			* current_basis.get_rotation_quaternion().inverse()
	if error.w < 0.0:
		error = -error # take the short way around

	# Drive the body with angular velocity (safe with the physics engine).
	var rotation_correction: float = rotation_correction_speed * rotation_correction_multiplier / (
		(closest_gravity_body_distance + 1) ** rotation_correction_exponent
	)
	ship.angular_velocity += error.get_axis() * error.get_angle() * rotation_correction
