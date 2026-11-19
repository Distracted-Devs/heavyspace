class_name GravityComponent
extends Node

@export var radius := 1.0:
	set(value):
		if not Contract.require(value > 0.0, "radius must be positive"):
			return
		radius = value
		_push_to_registry()
@export var mass := 1.0:
	set(value):
		if not Contract.require(value > 0.0, "mass must be positive"):
			return
		mass = value
		_push_to_registry()

var source_node: Node3D:
	get:
		return get_parent() as Node3D

var _registered := false


func _enter_tree() -> void:
	if not Contract.require(source_node != null, "parent must be a Node3D"):
		return
	GravityRegistry.register(self)
	_registered = true


func _exit_tree() -> void:
	if _registered:
		GravityRegistry.unregister(self)
		_registered = false


func _push_to_registry() -> void:
	if _registered:
		GravityRegistry.update(self)
