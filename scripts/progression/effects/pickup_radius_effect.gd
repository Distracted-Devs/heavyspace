class_name PickupRadiusEffect
extends SkillEffect


func _apply(player: Player, amount: float) -> void:
	if not Contract.require(
		player.pickup_component != null,
		"player must have a pickup component",
	):
		return
	player.pickup_component.pickup_radius *= 1.0 + amount
