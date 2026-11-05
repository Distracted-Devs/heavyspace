class_name GravityBody
extends Node3D

@export var diameter: float = 1.0


func _ready() -> void:
	add_to_group("bodies")
	# Scale the children (collision shapes, meshes), not the body itself:
	# physics engines (Jolt especially) ignore scale on a RigidBody3D, so the
	# collider would stay its unscaled size while the visuals grow.
	for child in get_children():
		if child is Node3D:
			var node := child as Node3D
			node.transform = node.transform.scaled(Vector3.ONE * diameter)
