class_name OrbitPlanet
extends Area3D
## A planet that pulls on the test spaceship.
## Uses the same formula as the game's GravityManager3D:
##     acceleration = G * mass / (distance² + softening²)
## Any node in the "gravity_sources" group is picked up by the spaceship.

@export var gravity_constant: float = 100.0
@export var mass: float = 45000.0
@export var softening: float = 1.0

## Surface radius, read from the collision sphere so there is one source of truth.
var radius: float = 500.0


func _ready() -> void:
	add_to_group("gravity_sources")
	var shape := ($CollisionShape3D as CollisionShape3D).shape as SphereShape3D
	radius = shape.radius * global_basis.get_scale().x


func acceleration_at(point: Vector3) -> Vector3:
	var offset := global_position - point
	var dist_sq := offset.length_squared() + softening * softening
	return offset.normalized() * gravity_constant * mass / dist_sq


## Speed needed for a perfect circular orbit at this point.
func orbit_speed_at(point: Vector3) -> float:
	return sqrt(gravity_constant * mass / maxf(global_position.distance_to(point), 0.001))


## Specific orbital energy. Below zero means the ship can't escape this planet.
func orbital_energy(point: Vector3, velocity: Vector3) -> float:
	var r := maxf(global_position.distance_to(point), 0.001)
	return velocity.length_squared() * 0.5 - gravity_constant * mass / r
