class_name FuelComponent
extends Node

signal changed(new_fuel: float, delta_fuel: float)

@export var starting_fuel: float = 200.0
## Full tank. Values below starting_fuel are raised to it, so by default the
## tank starts full. Pickups can't fill past this.
@export var max_fuel: float = 0.0

@onready var fuel: float = starting_fuel


func _ready() -> void:
	max_fuel = maxf(max_fuel, starting_fuel)


func add_fuel(delta_fuel: float) -> void:
	var old_fuel := fuel
	fuel = clampf(fuel + delta_fuel, 0.0, max_fuel)
	changed.emit(fuel, fuel - old_fuel)


## 0 = empty, 1 = full tank.
func get_fraction() -> float:
	return fuel / max_fuel if max_fuel > 0.0 else 0.0
