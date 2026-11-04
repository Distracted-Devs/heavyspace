class_name GravityBody
extends Node3D

@export var diameter: float = 1.0


func _ready() -> void:
	add_to_group("bodies")
	self.transform = self.transform.scaled(Vector3(diameter, diameter, diameter))
