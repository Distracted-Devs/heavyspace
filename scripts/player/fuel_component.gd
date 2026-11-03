class_name FuelComponent
extends Node

signal changed(current: float)

@export var player: Player
@export var starting_fuel: float = 100.0

var fuel: float = starting_fuel


func change_fuel(delta_fuel: float) -> void:
	fuel += delta_fuel
	player.fuel = fuel
	changed.emit(fuel)
