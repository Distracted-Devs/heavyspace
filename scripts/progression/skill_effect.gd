@abstract
class_name SkillEffect
extends Resource


func apply(player: Player, amount: float) -> void:
	if not Contract.require(player != null, "player must be set"):
		return
	if not Contract.require(amount >= 0.0, "amount must not be negative"):
		return
	_apply(player, amount)


@abstract func _apply(player: Player, amount: float) -> void
