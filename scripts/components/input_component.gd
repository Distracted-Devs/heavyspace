class_name InputComponent
extends Node

var thrust_intent := Vector3.ZERO
var rotation_intent := Vector3.ZERO


func _init() -> void:
	process_physics_priority = -1


func _physics_process(delta: float) -> void:
	_update_intent(delta)
	Contract.ensure(
		(
			Intent.is_within_unit(thrust_intent)
			and Intent.is_within_unit(rotation_intent)
		),
		"intent axes must be within [-1, 1]",
	)


func _update_intent(_delta: float) -> void:
	pass
