class_name CargoComponent
extends Node

signal changed(stored: float)

const FULL_EPSILON := 1.0e-6

@export_group("Cargo")
@export_range(0.01, 1000.0, 0.01, "or_greater") var tank_size := 5.0:
	set(value):
		if not Contract.require(value > 0.0, "tank_size must be positive"):
			return
		tank_size = value
		_clamp_stored()
@export_range(1, 10, 1, "or_greater") var tanks := 1:
	set(value):
		if not Contract.require(value >= 1, "tanks must be at least 1"):
			return
		tanks = value
		_clamp_stored()

var stored: float:
	get:
		return _stored

var _stored := 0.0


func capacity() -> float:
	return tanks * tank_size


func full_tanks() -> int:
	return mini(floori(_stored / tank_size + FULL_EPSILON), tanks)


func is_full() -> bool:
	return _stored >= capacity() - FULL_EPSILON


func fill_of(tank: int) -> float:
	if not Contract.require(
		tank >= 0 and tank < tanks,
		"tank must be within [0, tanks)",
	):
		return 0.0
	return clampf((_stored - tank * tank_size) / tank_size, 0.0, 1.0)


func add(amount: float) -> float:
	if not Contract.require(amount >= 0.0, "amount must not be negative"):
		return 0.0
	var accepted := minf(amount, capacity() - _stored)
	_set_stored(_stored + accepted)
	return accepted


func empty() -> void:
	_set_stored(0.0)


func _clamp_stored() -> void:
	_set_stored(minf(_stored, capacity()))


func _set_stored(value: float) -> void:
	var before := _stored
	_stored = value
	Contract.invariant(
		_stored >= 0.0 and _stored <= capacity() + FULL_EPSILON,
		"stored must be within [0, capacity]",
	)
	if not is_equal_approx(before, _stored):
		changed.emit(_stored)
