class_name StartingSizeUpgrade
extends Upgrade


func _apply(player: Player, by: float) -> void:
	player.mass_component.start_multiplier *= by
