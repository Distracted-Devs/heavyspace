class_name TurnSpeedUpgrade
extends Upgrade


func _apply(player: Player, by: float) -> void:
	player.rotator.pitch_torque *= by
	player.rotator.turn_torque *= by
	player.rotator.roll_torque *= by
