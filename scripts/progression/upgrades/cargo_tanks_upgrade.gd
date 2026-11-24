class_name CargoTanksUpgrade
extends Upgrade


func _apply(player: Player, by: float) -> void:
	if not Contract.require(player.cargo != null, "player must have a cargo"):
		return
	player.cargo.tanks += roundi(by - 1.0)
