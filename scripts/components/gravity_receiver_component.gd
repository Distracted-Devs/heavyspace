class_name GravityReceiverComponent
extends Node

@export_group("Components")
@export var body: RigidBody3D

@export_group("Gravity")
@export var gravity_constant := 0.001


func _physics_process(_delta: float) -> void:
	apply_gravity()


func apply_gravity() -> void:
	if not Contract.require(
		gravity_constant >= 0.0,
		"gravity_constant must not be negative",
	):
		return
	var positions := GravityRegistry.positions
	var masses := GravityRegistry.masses
	for index in GravityRegistry.sources_heavier_than(body.mass):
		var source_dir := positions[index] - body.global_position
		var distance_to_source := source_dir.length()
		source_dir = source_dir.normalized()
		var gravity_force: Vector3 = (
			source_dir * body.mass * masses[index] * gravity_constant
			/ (distance_to_source * distance_to_source)
		)
		body.apply_force(gravity_force)
