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
	var radii := GravityRegistry.radii
	var body_mass := body.mass
	for index in GravityRegistry.sources_heavier_than(body_mass):
		var offset := positions[index] - body.global_position
		var distance := maxf(offset.length(), radii[index])
		var gravity_force := (
			offset.normalized() * gravity_constant * body_mass * masses[index]
			/ (distance * distance)
		)
		if not Contract.ensure(
			gravity_force.is_finite(),
			"gravity force must be finite",
		):
			continue
		body.apply_central_force(gravity_force)
