class_name Clock
extends Node

const SHADER_TIME := &"clock_time"

@export var running := true
@export_range(0.0, 1000.0, 0.1, "or_greater") var speed := 1.0:
	set(value):
		if not Contract.require(value >= 0.0, "speed must not be negative"):
			return
		speed = value

var time: float:
	get:
		return _time

var _time := 0.0


func _init() -> void:
	process_physics_priority = -5


func _enter_tree() -> void:
	_publish()


func _physics_process(delta: float) -> void:
	if not running:
		return
	var before := _time
	_time += maxf(delta, 0.0) * speed
	_publish()
	Contract.invariant(
		_time >= 0.0 and _time >= before,
		"time must never be negative or go backwards",
	)


func _publish() -> void:
	RenderingServer.global_shader_parameter_set(SHADER_TIME, _time)
