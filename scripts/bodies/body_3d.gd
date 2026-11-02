class_name Body3D
extends Area3D

const MIN_MASS := 800
const MASS_PER_UNIT_OF_RADIUS := 1000.0
const RESTITUTION := 0.8
const POSITIVE_COLOUR := Color.ORANGE_RED
const NEGATIVE_COLOUR := Color.DODGER_BLUE

@export var mass: float = 1E5:
	set(new_mass):
		var old_mass: float = mass
		mass = max(new_mass, MIN_MASS)
		conserve_momentum(old_mass, mass)
		update_radius()
@export var is_static: bool = false
@export var colour: Color = Color.WHITE:
	set(value):
		colour = value
		update_material()
@export var initial_velocity: Vector3 = Vector3.ZERO
@export var collider: CollisionShape3D
@export var is_orbit_locked: bool = false:
	set(value):
		is_orbit_locked = value
		if not value:
			orbit_parent = null
@export var lock_rest_length := -1.0
@export var spring_stiffness := 20.0
@export var spring_damping := 2.0

var radius: float = 1.0
var velocity: Vector3 = Vector3.ZERO
var gravity_acceleration: Vector3 = Vector3.ZERO
var orbit_parent: Body3D

var _mesh_instance: MeshInstance3D
var _sphere_mesh: SphereMesh
var _material: StandardMaterial3D


func _ready() -> void:
	velocity = initial_velocity
	add_to_group("bodies")

	# Give each body its own shape so resizing one doesn't resize all
	# bodies sharing the same scene resource.
	var sphere_shape := SphereShape3D.new()
	collider.shape = sphere_shape

	_sphere_mesh = SphereMesh.new()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sphere_mesh.material = _material
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _sphere_mesh
	add_child(_mesh_instance)

	update_material()
	update_radius()


func resolve_overlap(other: Body3D) -> void:
	if is_static and other.is_static:
		return

	var offset_to_other := other.global_position - global_position
	var distance_between_centres := offset_to_other.length()
	var touching_distance := radius + other.radius

	if distance_between_centres >= touching_distance:
		return

	var push_direction := Vector3.RIGHT
	if distance_between_centres > 0.0:
		push_direction = offset_to_other / distance_between_centres

	var my_inverse_mass := 0.0 if is_static else 1.0 / mass
	var other_inverse_mass := 0.0 if other.is_static else 1.0 / other.mass
	var total_inverse_mass := my_inverse_mass + other_inverse_mass

	var overlap_amount := touching_distance - distance_between_centres
	var my_share := my_inverse_mass / total_inverse_mass
	var other_share := other_inverse_mass / total_inverse_mass
	global_position -= push_direction * overlap_amount * my_share
	other.global_position += push_direction * overlap_amount * other_share

	var relative_velocity := velocity - other.velocity
	var are_moving_closer := relative_velocity.dot(push_direction) > 0.0
	if are_moving_closer:
		if not is_static:
			velocity -= push_direction * velocity.dot(push_direction)
		if not other.is_static:
			other.velocity -= push_direction * other.velocity.dot(push_direction)


func update_radius() -> void:
	radius = mass / MASS_PER_UNIT_OF_RADIUS
	if is_node_ready():
		(collider.shape as SphereShape3D).radius = radius
		_sphere_mesh.radius = radius
		_sphere_mesh.height = radius * 2.0


func update_material() -> void:
	if is_node_ready():
		_material.albedo_color = colour


func conserve_momentum(old_mass: float, new_mass: float) -> void:
	velocity = old_mass / new_mass * velocity
