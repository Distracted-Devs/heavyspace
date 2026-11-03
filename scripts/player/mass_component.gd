class_name MassComponent
extends Node

signal changed(current: float)

@export var body: RigidBody3D
@export var starting_mass: float = 1.0

var mass: float = starting_mass


func change_mass(delta_mass: float) -> void:
	mass += delta_mass
	body.mass = mass
	changed.emit(mass)
