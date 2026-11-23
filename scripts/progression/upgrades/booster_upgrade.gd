class_name BoosterUpgrade
extends Upgrade


func _apply(player: Player, by: float) -> void:
	player.thruster.back_thrust_force *= by
