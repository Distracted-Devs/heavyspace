class_name MissingFuelBoostEffect
extends SkillEffect


func _apply(player: Player, amount: float) -> void:
	if not Contract.require(
		player.missing_fuel_boost != null,
		"player must have a missing fuel boost",
	):
		return
	player.missing_fuel_boost.bonus_per_missing += amount
