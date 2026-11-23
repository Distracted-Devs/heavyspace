class_name FuelTankUpgrade
extends Upgrade


func _apply(player: Player, by: float) -> void:
	player.fuel_component.tank_size *= by
