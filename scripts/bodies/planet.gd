@tool
class_name Planet
extends StaticBody3D

@export_range(0.01, 1000.0, 0.01, "or_greater") var radius := 50.0:
	set(value):
		if not Contract.require(value > 0.0, "radius must be positive"):
			return
		radius = value
		if is_node_ready():
			_apply_radius()

@export_group("Components")
@export var mesh: CSGSphere3D
@export var collider: CollisionShape3D
@export var gravity: GravityComponent

var _shape: SphereShape3D


func _ready() -> void:
	_shape = SphereShape3D.new()
	collider.shape = _shape
	_apply_radius()


func _apply_radius() -> void:
	mesh.radius = radius
	_shape.radius = radius
	gravity.radius = radius
	Contract.ensure(
		(
			is_equal_approx(mesh.radius, radius) and collider.shape == _shape
			and is_equal_approx(_shape.radius, radius)
			and is_equal_approx(gravity.radius, radius)
		),
		"mesh, own collider sphere and gravity radii must match the radius",
	)
