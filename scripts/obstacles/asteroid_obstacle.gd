class_name AsteroidObstacle
extends AnimatableBody3D


@export var planet: Node3D

@export var planet_radius: float = 2000.0
@export var orbit_radius: float = 1.1
@export var orbit_speed: float = 10.0
@export var clockwise: bool = false

@export var orbit_axis: Vector3 = Vector3.UP

## Starting position along the orbit, in degrees.
@export_range(0.0, 360.0) var start_angle: float = 0.0

## 0 = no spin
@export var spin_speed: float = 20.0

var _angle: float


func _ready() -> void:
	add_to_group(&"deadly")
	_angle = deg_to_rad(start_angle)
	global_position = _orbit_position()


func _physics_process(delta: float) -> void:
	var direction := -1.0 if clockwise else 1.0
	_angle = fposmod(_angle + deg_to_rad(orbit_speed) * direction * delta, TAU)
	global_position = _orbit_position()
	if spin_speed != 0.0:
		rotate_object_local(Vector3.UP, deg_to_rad(spin_speed) * delta)


func _orbit_position() -> Vector3:
	var center := Vector3.ZERO
	if is_instance_valid(planet):
		center = planet.global_position
	elif get_parent() is Node3D:
		center = (get_parent() as Node3D).global_position

	var axis := orbit_axis.normalized() if orbit_axis.length_squared() > 0.0 else Vector3.UP
	# Any vector perpendicular to the axis gives the angle-0 point on the orbit.
	var reference := Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD
	var start := (reference - axis * reference.dot(axis)).normalized()
	return center + start.rotated(axis, _angle) * orbit_radius * planet_radius
