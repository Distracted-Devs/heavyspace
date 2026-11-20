class_name RotationComponent
extends Node

@export_group("Components")
@export var body: RigidBody3D
@export var flight_input: InputComponent

@export_group("Rotation")
@export var pitch_torque := 0.05
@export var turn_torque := 0.05
@export var roll_torque := 0.05


func _physics_process(_delta: float) -> void:
	apply_rotation(flight_input.rotation_intent)


func apply_rotation(intent: Vector3) -> void:
	if not Contract.require(
		Intent.is_within_unit(intent),
		"rotation intent axes must be within [-1, 1]",
	):
		return
	if not Contract.require(
		(pitch_torque >= 0.0 and turn_torque >= 0.0 and roll_torque >= 0.0),
		"rotation torques must not be negative",
	):
		return

	var local_torque := Vector3(
		intent.x * pitch_torque,
		intent.y * turn_torque,
		intent.z * roll_torque,
	)
	body.apply_torque(body.global_basis * local_torque)
