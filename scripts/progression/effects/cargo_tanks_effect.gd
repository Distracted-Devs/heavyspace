class_name CargoTanksEffect
extends SkillEffect


func _apply(player: Player, amount: float) -> void:
	if not Contract.require(player.cargo != null, "player must have a cargo"):
		return
	player.cargo.tanks += roundi(amount)
