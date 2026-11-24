class_name BounceEffect
extends Node

@export_group("Components")
@export var target: Control

@export_group("Bounce")
@export_range(0.05, 10.0, 0.05, "or_greater") var hz := 1.4:
	set(value):
		if not Contract.require(value > 0.0, "hz must be positive"):
			return
		hz = value
@export_range(0.0, 100.0, 0.5, "or_greater") var distance := 8.0:
	set(value):
		if not Contract.require(value >= 0.0, "distance must not be negative"):
			return
		distance = value
@export var direction := Vector2.UP:
	set(value):
		if not Contract.require(
			not value.is_zero_approx(),
			"direction must not be zero",
		):
			return
		direction = value.normalized()
@export var active := true:
	set(value):
		active = value
		_time = 0.0
		if not active and target != null:
			target.position = base_position

var base_position := Vector2.ZERO

var _time := 0.0


func _process(delta: float) -> void:
	advance(delta)


func offset() -> Vector2:
	return direction * distance * absf(sin(PI * hz * _time))


func advance(delta: float) -> void:
	if not active:
		return
	_time += delta
	if target != null:
		target.position = base_position + offset()
