class_name Clock
extends Node

const SHADER_TIME := &"clock_time"

var time: float:
	get:
		return _time

var _time := 0.0


func _init() -> void:
	process_physics_priority = -5


func _enter_tree() -> void:
	_publish()


func _physics_process(delta: float) -> void:
	var before := _time
	_time += maxf(delta, 0.0)
	_publish()
	Contract.invariant(
		_time >= 0.0 and _time >= before,
		"time must never be negative or go backwards",
	)


func _publish() -> void:
	RenderingServer.global_shader_parameter_set(SHADER_TIME, _time)
