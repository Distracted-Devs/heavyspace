class_name GravityReceiverComponent
extends Node

@export_group("Components")
@export var body: RigidBody3D

@export_group("Gravity")
@export var gravity_constant := 0.001

var gravity_sources: Array[GravityComponent] = []


func _ready() -> void:
	add_to_group("gravity_affected")


func _physics_process(_delta: float) -> void:
	apply_gravity()


func apply_gravity() -> void:
	if not Contract.require(
		gravity_constant >= 0.0,
		"gravity_constant must not be negative",
	):
		return
	for gravity_source: GravityComponent in gravity_sources.duplicate():
		if not is_instance_valid(gravity_source):
			remove_gravity_source(gravity_source)
			continue
		if gravity_source.mass <= body.mass:
			continue

		var source_dir := gravity_source.source_position - body.global_position
		var distance_to_source := source_dir.length()
		source_dir = source_dir.normalized()
		var gravity_force: Vector3 = (
			source_dir * body.mass * gravity_source.mass * gravity_constant
			/ (distance_to_source * distance_to_source)
		)
		body.apply_force(gravity_force)


func add_gravity_source(source: GravityComponent) -> void:
	gravity_sources.append(source)


func remove_gravity_source(source: GravityComponent) -> void:
	gravity_sources.erase(source)
