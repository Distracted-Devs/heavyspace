class_name GravityEffect
extends Node

@export var body: RigidBody3D

@export_group("Gravity")
@export var gravitational_constant := 10.0
@export var softening := 0.5


func _physics_process(_delta: float) -> void:
	var total_force := Vector3()
	for node in get_tree().get_nodes_in_group("gravity"):
		if node == self or not node is Node3D:
			continue
		var gravity_component := get_node_or_null("GravityComponent") as GravityComponent
		if gravity_component:
			var offset: Vector3 = node.global_position - body.global_position
			var dist_sq := offset.length_squared() + softening * softening

			var this_mass := body.mass
			var other_mass := gravity_component.mass

			var magnitude := gravitational_constant * this_mass * other_mass / dist_sq
			total_force += offset.normalized() * magnitude

	body.apply_central_force(total_force)
