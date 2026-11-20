class_name ThrusterComponent
extends Node

@export_group("Components")
@export var body: RigidBody3D
@export var flight_input: InputComponent
@export var fuel: FuelComponent

@export_group("Thrust")
@export var back_thrust_force := 1.0


func _physics_process(delta: float) -> void:
	apply_thrust(flight_input.thrust_intent, delta)


func apply_thrust(intent: Vector3, delta: float) -> void:
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

	var local_force := Vector3(
		0.0,
		0.0,
		intent.z * back_thrust_force * _fuel_fraction(intent, delta),
	)
	body.apply_central_force(body.global_basis * local_force)


func _fuel_fraction(intent: Vector3, delta: float) -> float:
	if not fuel:
		return 1.0
	var requested := fuel.burn_rate * absf(intent.z) * delta
	if requested <= 0.0:
		return 1.0
	return fuel.draw(requested) / requested
