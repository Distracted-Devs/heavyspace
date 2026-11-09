class_name MassCollectable
extends Node3D

@export var blow_up_speed = 0.9

var t = 0.0
@export var start_scale = Vector3.ZERO
@export var end_scale = Vector3.ZERO


func _process(delta: float) -> void:
	if t < 1.0:
		t += delta * blow_up_speed
		self.scale = start_scale.lerp(end_scale, t)
