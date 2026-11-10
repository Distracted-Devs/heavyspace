class_name Planet
extends Node3D

@export var radius := 100000.0
@export var mass := 1E9


func _ready() -> void:
	self.scale *= radius * 2
