class_name ThrusterComponent
extends Node

@export_group("Components")
@export var body: RigidBody3D
@export var flight_input: InputComponent

@export_group("Thrust")
@export var back_thrust_force := 1.0


func _physics_process(_delta: float) -> void:
	apply_thrust(flight_input.thrust_intent)


func apply_thrust(intent: Vector3) -> void:
	if not Contract.require(
		Intent.is_within_unit(intent),
		"thrust intent axes must be within [-1, 1]",
	):
		return
	if not Contract.require(
		back_thrust_force >= 0.0,
		"back_thrust_force must not be negative",
	):
		return

	var local_force := Vector3(0.0, 0.0, intent.z * back_thrust_force)
	body.apply_central_force(body.global_basis * local_force)
