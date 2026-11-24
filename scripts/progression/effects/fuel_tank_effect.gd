class_name FuelTankEffect
extends SkillEffect


func _apply(player: Player, amount: float) -> void:
	player.fuel_component.tank_size *= 1.0 + amount
