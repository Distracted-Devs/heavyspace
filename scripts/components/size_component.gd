class_name SizeComponent
extends Node

@export_group("Components")
@export var mass_component: MassComponent
@export var collider: CollisionShape3D
@export var mesh: Node3D
@export var camera_component: CameraComponent

@export_group("Size")
@export var mass_law := MassLaw.new()
@export var base_radius := 0.5

var radius: float:
	get:
		return _shape.radius

var _shape: SphereShape3D
var _base_camera_distance: float


func _ready() -> void:
	_shape = SphereShape3D.new()
	collider.shape = _shape
	_base_camera_distance = camera_component.distance
	mass_component.mass_changed.connect(apply_mass)
	apply_mass(mass_component.current_mass)


func apply_mass(mass: float) -> void:
	var new_radius := mass_law.radius_for_mass(mass)
	if is_nan(new_radius):
		return
	var scale_factor := new_radius / base_radius
	_shape.radius = new_radius
	mesh.scale = Vector3.ONE * scale_factor
	camera_component.distance = _base_camera_distance * scale_factor
	Contract.ensure(
		(
			collider.shape == _shape
			and is_equal_approx(_shape.radius, new_radius)
			and mesh.scale.is_equal_approx(Vector3.ONE * scale_factor)
			and is_equal_approx(
				camera_component.distance,
				_base_camera_distance * scale_factor,
			)
		),
		"collider, mesh and camera must follow the mass",
	)
