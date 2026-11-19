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
@export var source_position := Vector3.ZERO

var _source: Node3D
var _registered := false


func _enter_tree() -> void:
	_source = get_parent() as Node3D
	if not Contract.require(_source != null, "parent must be a Node3D"):
		return
	source_position = _source.global_position
	GravityRegistry.register(self)
	_registered = true


# TODO - is there a better way? Fragile
func _process(_delta: float) -> void:
	if _source:
		source_position = _source.global_position


func _exit_tree() -> void:
	if _registered:
		GravityRegistry.unregister(self)
		_registered = false


func _push_to_registry() -> void:
	if _registered:
		GravityRegistry.update(self)
