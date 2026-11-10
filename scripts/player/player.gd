class_name Player
extends Node3D

@export_group("Components")
@export var body: RigidBody3D

@export_group("Movement")
@export var roll_amount := 2.0 * PI / 4.0
@export var turn_amount := 2.0 * PI / 4.0
@export var bottom_thrust_scaling := 0.1
@export var back_thrust_scaling := 0.1
@export var gravity_constant := 0.001

@export_group("Properties")
@export var starting_mass := 1.0
@export var thrust_mass := 1.0
@export var thrust_rate := 1.0

@onready var current_mass: float = starting_mass

var gravity_sources: Array[GravityComponent] = []


func _ready() -> void:
	add_to_group("gravity_affected")


func _process(_delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	if Input.is_action_pressed("turn_right"):
		body.angular_velocity -= turn_amount * body.basis.y * _delta

	if Input.is_action_pressed("turn_left"):
		body.angular_velocity += turn_amount * body.basis.y * _delta

	if Input.is_action_pressed("roll_right"):
		body.angular_velocity -= roll_amount * body.basis.z * _delta

	if Input.is_action_pressed("roll_left"):
		body.angular_velocity += roll_amount * body.basis.z * _delta

	if Input.is_action_pressed("bottom_thruster"):
		apply_linear_velocity(_delta, body.basis.y, bottom_thrust_scaling)

	if Input.is_action_pressed("top_thruster"):
		apply_linear_velocity(_delta, -body.basis.y, bottom_thrust_scaling)

	if Input.is_action_pressed("back_thruster"):
		apply_linear_velocity(_delta, -body.basis.z, back_thrust_scaling)

	if Input.is_action_just_pressed("stop_motion"):
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO

	apply_gravity(_delta)


func apply_linear_velocity(delta: float, direction: Vector3, scaling: float):
	body.linear_velocity += direction * sqrt(thrust_mass / current_mass) * thrust_rate * scaling * delta


func apply_gravity(_delta: float):
	for gravity_source in gravity_sources:
		if gravity_source:
			if not is_instance_valid(gravity_source):
				remove_gravity_source(gravity_source)
				continue
			if self.current_mass > gravity_source.mass:
				continue

			var source_dir: Vector3 = gravity_source.source_position - body.global_position
			var distance_to_source := source_dir.length()
			source_dir = source_dir.normalized()
			var gravity_force: Vector3 = (
				source_dir * self.current_mass * gravity_source.mass * gravity_constant
				/ (distance_to_source * distance_to_source)
			)
			print(gravity_force.length())
			body.apply_force(gravity_force)


func add_gravity_source(source: GravityComponent):
	gravity_sources.append(source)


func remove_gravity_source(source: GravityComponent):
	gravity_sources.append(source)
