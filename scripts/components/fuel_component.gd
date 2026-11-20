class_name FuelComponent
extends Node

signal fuel_changed(new_fuel: float)

@export_group("Fuel")
@export var tank_size := 1.0:
	set(value):
		if not Contract.require(value > 0.0, "tank_size must be positive"):
			return
		tank_size = value
		_set_fuel(minf(_fuel, tank_size))
@export var burn_rate := 1.0:
	set(value):
		if not Contract.require(value > 0.0, "burn_rate must be positive"):
			return
		burn_rate = value
@export var refill_time := 5.0:
	set(value):
		if not Contract.require(value > 0.0, "refill_time must be positive"):
			return
		refill_time = value
@export var refill_delay := 0.0:
	set(value):
		if not Contract.require(
			value >= 0.0,
			"refill_delay must not be negative",
		):
			return
		refill_delay = value

var fuel: float:
	get:
		return _fuel

var _fuel := 0.0
var _boosted_this_frame := false
var _time_since_boost := INF


func _init() -> void:
	process_physics_priority = 1


func _ready() -> void:
	_set_fuel(tank_size)


func _physics_process(delta: float) -> void:
	if _boosted_this_frame:
		_boosted_this_frame = false
		_time_since_boost = 0.0
		return
	_time_since_boost += delta
	if _time_since_boost >= refill_delay:
		_set_fuel(minf(_fuel + tank_size / refill_time * delta, tank_size))


func draw(amount: float) -> float:
	if not Contract.require(amount >= 0.0, "draw amount must not be negative"):
		return 0.0
	if amount > 0.0:
		_boosted_this_frame = true
	var drawn := minf(amount, _fuel)
	_set_fuel(_fuel - drawn)
	return drawn


func _set_fuel(value: float) -> void:
	if value == _fuel:
		return
	_fuel = value
	Contract.invariant(
		_fuel >= 0.0 and _fuel <= tank_size,
		"fuel must be within [0, tank_size]",
	)
	fuel_changed.emit(_fuel)
