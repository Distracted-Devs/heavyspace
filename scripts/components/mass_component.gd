class_name MassComponent
extends Node

signal mass_changed(new_mass: float)

@export_group("Components")
@export var body: RigidBody3D

@export_group("Mass")
@export var starting_mass := 1.0

var current_mass := 1.0:
	set(value):
		if not Contract.require(value > 0.0, "current_mass must be positive"):
			return
		current_mass = value
		if body:
			body.mass = value
			Contract.ensure(
				is_equal_approx(body.mass, value),
				"body.mass must equal current_mass",
			)
		mass_changed.emit(value)


func _ready() -> void:
	current_mass = starting_mass
