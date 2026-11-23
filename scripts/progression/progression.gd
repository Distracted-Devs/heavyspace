class_name Progression
extends RefCounted

signal changed

var bank: float:
	get:
		return _bank
var runs: int:
	get:
		return _runs

var _bank := 0.0
var _runs := 0
var _levels: Dictionary[StringName, int] = { }


func level_of(upgrade: Upgrade) -> int:
	if not Contract.require(upgrade != null, "upgrade must be set"):
		return 0
	return _levels.get(upgrade.id, 0)


func bank_mass(amount: float) -> void:
	var message := "banked amount must not be negative"
	if not Contract.require(amount >= 0.0, message):
		return
	_bank += amount
	_changed()


func can_afford(upgrade: Upgrade) -> bool:
	if upgrade == null:
		return false
	return upgrade.cost(level_of(upgrade)) <= _bank


func buy(upgrade: Upgrade) -> bool:
	if not can_afford(upgrade):
		return false
	var level := level_of(upgrade)
	_bank -= upgrade.cost(level)
	_levels[upgrade.id] = level + 1
	_changed()
	return true


func start_run() -> void:
	_runs += 1
	_changed()


func _changed() -> void:
	Contract.invariant(
		_bank >= 0.0
		and _levels.values().all(
			func(l: int) -> bool:
				return l >= 0,
		),
		"bank and levels must not be negative",
	)
	changed.emit()
