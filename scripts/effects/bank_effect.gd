class_name BankEffect
extends Node

const TOLERANCE := 1e-4

@export_group("Components")
@export var ship: RigidBody3D
@export var mesh: Node3D

@export_group("Bank")
@export_range(0.0, 200.0, 1.0, "or_greater") var bank_per_yaw_rate := 60.0:
	set(value):
		var message := "bank_per_yaw_rate must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		bank_per_yaw_rate = value
@export_range(0.0, 90.0, 1.0) var max_bank_degrees := 60.0:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 90.0,
			"max_bank_degrees must be within [0, 90]",
		):
			return
		max_bank_degrees = value
@export_range(0.1, 100.0, 0.1, "or_greater") var bank_speed := 50.0:
	set(value):
		if not Contract.require(value > 0.0, "bank_speed must be positive"):
			return
		bank_speed = value

var bank := 0.0


func _physics_process(delta: float) -> void:
	update(delta)


func update(delta: float) -> void:
	if not Contract.require(
		ship != null and mesh != null,
		"ship and mesh must be set",
	):
		return
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	if ship.freeze:
		return
	var spin := ship.global_basis.orthonormalized().inverse() * (
		ship.angular_velocity
	)
	var limit := deg_to_rad(max_bank_degrees)
	var target := clampf(spin.y * deg_to_rad(bank_per_yaw_rate), -limit, limit)
	bank = lerpf(bank, target, 1.0 - exp(-bank_speed * delta))
	mesh.rotation = Vector3(0.0, 0.0, bank)
	Contract.invariant(
		absf(bank) <= limit + TOLERANCE,
		"bank must be within max_bank_degrees",
	)
