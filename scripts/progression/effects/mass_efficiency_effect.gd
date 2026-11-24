class_name MassEfficiencyEffect
extends SkillEffect


func _apply(player: Player, amount: float) -> void:
	if not Contract.require(
		player.cargo_weight != null,
		"player must have a cargo weight component",
	):
		return
	player.cargo_weight.cargo_weight *= maxf(0.0, 1.0 - amount)
