@tool
class_name MassBody
extends AnimatableBody3D

const UNIT_SPHERE := preload("res://resources/meshes/unit_sphere.tres")
const GROUP := &"mass_bodies"
const SEED_PARAMETER := &"seed"

@export_range(0.01, 1000.0, 0.01, "or_greater") var radius := 50.0:
	set(value):
		if not Contract.require(value > 0.0, "radius must be positive"):
			return
		radius = value
		if is_node_ready():
			_apply_size()
@export_range(0.01, 1000.0, 0.01, "or_greater") var mass := 10000.0:
	set(value):
		if not Contract.require(value > 0.0, "mass must be positive"):
			return
		mass = value
		if is_node_ready():
			_apply_size()

@export_range(0.0, 0.999, 0.001) var look_seed := 0.0:
	set(value):
		if not Contract.require(
			value >= 0.0 and value < 1.0,
			"look_seed must be within [0, 1)",
		):
			return
		look_seed = value
		if is_node_ready():
			_apply_look()

@export_group("Components")
@export var mesh: MeshInstance3D
@export var collider: CollisionShape3D
@export var gravity: GravityComponent

var _shape: SphereShape3D


func _enter_tree() -> void:
	add_to_group(GROUP)


func set_material_override(material: Material) -> void:
	mesh.material_override = material


func _ready() -> void:
	_shape = SphereShape3D.new()
	collider.shape = _shape
	mesh.mesh = UNIT_SPHERE
	_apply_size()
	_apply_look()


func _apply_look() -> void:
	mesh.set_instance_shader_parameter(SEED_PARAMETER, look_seed)
	Contract.ensure(
		is_equal_approx(
			mesh.get_instance_shader_parameter(SEED_PARAMETER),
			look_seed,
		),
		"the mesh's seed must match look_seed",
	)


func _apply_size() -> void:
	mesh.scale = Vector3.ONE * radius
	_shape.radius = radius
	gravity.radius = radius
	gravity.mass = mass
	Contract.ensure(
		(
			mesh.mesh == UNIT_SPHERE
			and mesh.scale.is_equal_approx(Vector3.ONE * radius)
			and collider.shape == _shape
			and is_equal_approx(_shape.radius, radius)
			and is_equal_approx(gravity.radius, radius)
			and is_equal_approx(gravity.mass, mass)
		),
		"mesh, own collider sphere and gravity must match radius and mass",
	)
