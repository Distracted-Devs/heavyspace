class_name PulseEffect
extends Node

@export_group("Components")
@export var target: CanvasItem

@export_group("Pulse")
@export_range(0.05, 10.0, 0.05, "or_greater") var hz := 1.4:
	set(value):
		if not Contract.require(value > 0.0, "hz must be positive"):
			return
		hz = value
@export_range(1.0, 4.0, 0.05, "or_greater") var brightness := 1.5:
	set(value):
		if not Contract.require(value >= 1.0, "brightness must be at least 1"):
			return
		brightness = value
@export var active := true:
	set(value):
		active = value
		_time = 0.0
		if not active:
			_light(1.0)

var _time := 0.0


func _process(delta: float) -> void:
	advance(delta)


func level() -> float:
	return 0.5 - 0.5 * cos(TAU * hz * _time)


func advance(delta: float) -> void:
	if not active:
		return
	_time += delta
	_light(lerpf(1.0, brightness, level()))


func _light(amount: float) -> void:
	if target == null:
		return
	target.modulate = Color(amount, amount, amount, target.modulate.a)
