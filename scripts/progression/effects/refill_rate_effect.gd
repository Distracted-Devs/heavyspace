class_name RefillRateEffect
extends SkillEffect


func _apply(player: Player, amount: float) -> void:
	player.fuel_component.refill_time /= 1.0 + amount
