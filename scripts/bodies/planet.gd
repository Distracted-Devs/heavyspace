class_name Planet
extends Node3D

@export var radius := 1000.0


func _ready() -> void:
	self.scale *= radius * 2.0
