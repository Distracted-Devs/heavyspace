class_name BoosterEffect
extends SkillEffect


func _apply(player: Player, amount: float) -> void:
	player.thruster.back_thrust_force *= 1.0 + amount
