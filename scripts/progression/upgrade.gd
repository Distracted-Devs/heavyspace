@abstract
class_name Upgrade
extends Resource

@export var id: StringName
@export var display_name := ""
@export_range(0.0, 10.0, 0.01, "or_greater") var step := 0.2:
	set(value):
		if not Contract.require(value >= 0.0, "step must not be negative"):
			return
		step = value
@export_range(0.01, 1000.0, 0.01, "or_greater") var base_cost := 5.0:
	set(value):
		if not Contract.require(value > 0.0, "base_cost must be positive"):
			return
		base_cost = value
@export_range(1.0, 10.0, 0.01, "or_greater") var cost_growth := 1.6:
	set(value):
		if not Contract.require(value >= 1.0, "cost_growth must be at least 1"):
			return
		cost_growth = value
@export_range(-1, 100, 1, "or_greater") var max_level := -1:
	set(value):
		var message := "max_level must be at least -1"
		if not Contract.require(value >= -1, message):
			return
		max_level = value


func multiplier(level: int) -> float:
	if not Contract.require(level >= 0, "level must not be negative"):
		return 1.0
	return 1.0 + step * level


func cost(level: int) -> float:
	if not _require_id():
		return INF
	if not Contract.require(level >= 0, "level must not be negative"):
		return INF
	if is_maxed(level):
		return INF
	return roundf(base_cost * pow(cost_growth, level))


func is_maxed(level: int) -> bool:
	return max_level >= 0 and level >= max_level


func apply(player: Player, level: int) -> void:
	if not Contract.require(player != null, "player must be set"):
		return
	if not _require_id():
		return
	if not Contract.require(level >= 0, "level must not be negative"):
		return
	_apply(player, multiplier(level))


@abstract func _apply(player: Player, by: float) -> void


func _require_id() -> bool:
	return Contract.require(id != &"", "upgrade id must be set")
