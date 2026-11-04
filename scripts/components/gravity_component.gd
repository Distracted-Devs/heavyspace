class_name GravityComponent
extends Node

@export var mass: float = 1000.0

func _ready() -> void:
	add_to_group(&"gravity")
