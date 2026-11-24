class_name MiningEffect
extends SkillEffect


func _apply(player: Player, amount: float) -> void:
	if not Contract.require(
		player.pickup_component != null,
		"player must have a pickup component",
	):
		return
	player.pickup_component.mass_conversion *= 1.0 + amount
