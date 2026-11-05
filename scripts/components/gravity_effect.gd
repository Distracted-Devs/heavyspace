class_name GravityEffect
extends Node
@export var body: RigidBody3D

@export_group("Gravity")
@export var gravitational_constant := 10.0
@export var softening := 0.5

## Turned off while the ship is locked in orbit (the orbit moves it instead).
var enabled := true


func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	# Force = mass * acceleration. The ship's own mass cancels out, as in real
	# gravity, so heavy and light ships fall the same way.
	body.apply_central_force(acceleration_at(body.global_position) * body.mass)


## Every node that pulls on the ship.
func get_sources() -> Array[Node3D]:
	var sources: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(&"gravity"):
		if node is Node3D and node != body and source_mass(node) > 0.0:
			sources.append(node)
	return sources


## The mass gravity actually uses: the GravityComponent's, not the RigidBody's.
static func source_mass(node: Node) -> float:
	var component := node.get_node_or_null("GravityComponent") as GravityComponent
	return component.mass if component else 0.0


static func source_radius(node: Node3D) -> float:
	if node is GravityBody:
		return (node as GravityBody).diameter * 0.5
	return 1.0


## G * M of a source.
func mu_of(source: Node3D) -> float:
	return gravitational_constant * source_mass(source)


func acceleration_at(point: Vector3, sources: Array[Node3D] = []) -> Vector3:
	if sources.is_empty():
		sources = get_sources()
	var accel := Vector3.ZERO
	for source in sources:
		var offset := source.global_position - point
		var dist_sq := offset.length_squared() + softening * softening
		accel += offset.normalized() * mu_of(source) / dist_sq
	return accel


## The source pulling hardest at `point`; the one the ship orbits.
func strongest_source(point: Vector3, sources: Array[Node3D] = []) -> Node3D:
	if sources.is_empty():
		sources = get_sources()
	var best: Node3D = null
	var best_pull := 0.0
	for source in sources:
		var pull := source_mass(source) / maxf(source.global_position.distance_squared_to(point), 0.0001)
		if pull > best_pull:
			best_pull = pull
			best = source
	return best


## The ship's current Kepler orbit around `source` (if it stopped thrusting now).
func orbit_around(source: Node3D) -> Orbit:
	return Orbit.from_state(
		body.global_position - source.global_position,
		body.linear_velocity,
		mu_of(source),
	)
