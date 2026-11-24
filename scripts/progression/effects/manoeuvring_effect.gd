class_name ManoeuvringEffect
extends SkillEffect


func _apply(player: Player, amount: float) -> void:
	var by := 1.0 + amount
	player.rotator.pitch_torque *= by
	player.rotator.turn_torque *= by
	player.rotator.roll_torque *= by
