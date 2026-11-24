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
var _buys: Dictionary[StringName, int] = { }


func buys(node: SkillNode) -> int:
	if not Contract.require(node != null, "node must be set"):
		return 0
	return _buys.get(node.id, 0)


func buys_by_id() -> Dictionary:
	return _buys.duplicate()


func player_level() -> int:
	var level := 0
	for count: int in _buys.values():
		level += count
	return level


func is_unlocked(node: SkillNode) -> bool:
	return player_level() >= node.required_level


func is_maxed(node: SkillNode) -> bool:
	return buys(node) >= node.max_buys


func can_buy(node: SkillNode) -> bool:
	if node == null or not node.is_valid():
		return false
	return is_unlocked(node) and not is_maxed(node) and node.cost <= _bank


func buy(node: SkillNode) -> bool:
	if not can_buy(node):
		return false
	_bank -= node.cost
	_buys[node.id] = buys(node) + 1
	_changed()
	return true


func bank_mass(amount: float) -> void:
	var message := "banked amount must not be negative"
	if not Contract.require(amount >= 0.0, message):
		return
	_bank += amount
	_changed()


func start_run() -> void:
	_runs += 1
	_changed()


func _changed() -> void:
	Contract.invariant(
		_bank >= 0.0 and _buys.values().all(_not_negative),
		"bank and buys must not be negative",
	)
	changed.emit()


func _not_negative(count: int) -> bool:
	return count >= 0
