class_name RefillRateUpgrade
extends Upgrade


func _apply(player: Player, by: float) -> void:
	player.fuel_component.refill_time /= by
