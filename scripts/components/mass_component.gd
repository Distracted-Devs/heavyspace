class_name MassComponent
extends Node

signal changed(current: float)

@export var player: Player
@export var starting_mass: float = 1.0

var mass: float = starting_mass


func add_mass(delta_mass: float) -> void:
	mass += delta_mass
	mass = maxf(mass, 0.0)
	changed.emit(mass)


func set_mass(new_mass: float) -> void:
	mass = new_mass
	changed.emit(mass)
