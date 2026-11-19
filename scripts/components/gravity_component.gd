class_name GravityComponent
extends Node

@export var radius := 1.0:
	set(value):
		if not Contract.require(value > 0.0, "radius must be positive"):
			return
		radius = value
@export var mass := 1.0:
	set(value):
		if not Contract.require(value > 0.0, "mass must be positive"):
			return
		mass = value
@export var source_position := Vector3.ZERO

var _source: Node3D


func _ready() -> void:
	_source = get_parent() as Node3D
	if not Contract.require(_source != null, "parent must be a Node3D"):
		return
	source_position = _source.global_position
	var gravity_group := get_tree().get_nodes_in_group("gravity_affected")
	for node in gravity_group:
		node.add_gravity_source(self)


# TODO - is there a better way? Fragile
func _process(_delta: float) -> void:
	if _source:
		source_position = _source.global_position


func _exit_tree() -> void:
	var gravity_group := get_tree().get_nodes_in_group("gravity_affected")
	for node in gravity_group:
		node.remove_gravity_source(self)
