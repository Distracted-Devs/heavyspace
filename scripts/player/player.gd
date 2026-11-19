class_name Player
extends Node3D

@export_group("Components")
@export var body: RigidBody3D

@export_group("Rotation")
@export var roll_torque := 0.05
@export var turn_torque := 0.05

@export_group("Thrust")
@export var vertical_thrust_force := 1.0
@export var back_thrust_force := 1.0

@export_group("Gravity")
@export var gravity_constant := 0.001

@export_group("Properties")
@export var starting_mass := 1.0

var current_mass := 1.0:
	set(value):
		if not Contract.require(value > 0.0, "current_mass must be positive"):
			return
		current_mass = value
		if body:
			body.mass = value

var gravity_sources: Array[GravityComponent] = []


func _ready() -> void:
	current_mass = starting_mass
	add_to_group("gravity_affected")


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	var body_basis := body.global_basis

	if Input.is_action_pressed("turn_right"):
		body.apply_torque(-body_basis.y * turn_torque)

	if Input.is_action_pressed("turn_left"):
		body.apply_torque(body_basis.y * turn_torque)

	if Input.is_action_pressed("roll_right"):
		body.apply_torque(-body_basis.z * roll_torque)

	if Input.is_action_pressed("roll_left"):
		body.apply_torque(body_basis.z * roll_torque)

	if Input.is_action_pressed("bottom_thruster"):
		body.apply_central_force(body_basis.y * vertical_thrust_force)

	if Input.is_action_pressed("top_thruster"):
		body.apply_central_force(-body_basis.y * vertical_thrust_force)

	if Input.is_action_pressed("back_thruster"):
		body.apply_central_force(-body_basis.z * back_thrust_force)

	apply_gravity(delta)


func apply_gravity(_delta: float):
	for gravity_source in gravity_sources:
		if gravity_source:
			if not is_instance_valid(gravity_source):
				remove_gravity_source(gravity_source)
				continue
			if self.current_mass > gravity_source.mass:
				continue

			var source_dir: Vector3 = (
				gravity_source.source_position - body.global_position
			)
			var distance_to_source := source_dir.length()
			source_dir = source_dir.normalized()
			var gravity_force: Vector3 = (
				source_dir * self.current_mass
				* gravity_source.mass * gravity_constant
				/ (distance_to_source * distance_to_source)
			)
			body.apply_force(gravity_force)


func add_gravity_source(source: GravityComponent):
	gravity_sources.append(source)


func remove_gravity_source(source: GravityComponent):
	gravity_sources.append(source)
