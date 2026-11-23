class_name PickupRadiusUpgrade
extends Upgrade


func _apply(player: Player, by: float) -> void:
	if not Contract.require(
		player.pickup_component != null,
		"player must have a pickup component",
	):
		return
	player.pickup_component.pickup_radius *= by
