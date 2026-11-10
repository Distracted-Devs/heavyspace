class_name GravityComponent
extends Node

@export var radius: float = 1.0
@export var mass: float = 1.0
@export var source_position := Vector3.ZERO


func _ready() -> void:
	var gravity_group := get_tree().get_nodes_in_group("gravity_affected")
	for node in gravity_group:
		node.add_gravity_source(self)

# TODO - is there a better way? Fragile
func _process(delta: float) -> void:
	self.source_position = get_parent().global_position

func _exit_tree() -> void:
	var gravity_group := get_tree().get_nodes_in_group("gravity_affected")
	for node in gravity_group:
		node.remove_gravity_source(self)
