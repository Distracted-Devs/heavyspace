class_name FuelComponent
extends Node

signal changed(new_fuel: float, delta_fuel: float)

@export var player: Player
@export var starting_fuel: float = 200.0

var fuel: float = starting_fuel


func add_fuel(delta_fuel: float) -> void:
	fuel += delta_fuel
	fuel = maxf(fuel, 0.0)
	changed.emit(fuel, delta_fuel)
