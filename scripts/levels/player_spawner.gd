class_name PlayerSpawner
extends Node

@export_group("Components")
@export var streamer: SystemStreamer
@export var player: Player

@export_group("Spawn")
@export var spawn_depth := 2
@export var spawn_margin := 1.2

var spawn_spec: BodySpec


func spawn() -> void:
	var generator := streamer.generator
	if not Contract.require(generator != null, "streamer must be started"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([generator.level_seed, "spawn"])
	var time := streamer.orbit_system.time
	var spec := generator.root()
	var spawn_position := Vector3.ZERO
	var spawn_velocity := Vector3.ZERO
	while spec.depth < spawn_depth:
		var bodies := generator.contents_of(spec).filter(
			func(content: BodySpec) -> bool:
				return not content.is_pickup,
		)
		if bodies.is_empty():
			break
		spec = bodies[rng.randi_range(0, bodies.size() - 1)]
		spawn_position += spec.orbit_offset(time)
		spawn_velocity += spec.orbit_velocity(time)
	spawn_spec = spec
	var normal := spec.orbit_u.cross(spec.orbit_v)
	player.global_position = (
		spawn_position + normal * spec.system_radius * spawn_margin
	)
	player.linear_velocity = spawn_velocity
	streamer.update_streaming()
	Contract.ensure(_is_clear_of_bodies(), "player must not overlap any body")
	Contract.ensure(
		_has_lighter_body(),
		"a body lighter than the player must be live",
	)


func _is_clear_of_bodies() -> bool:
	var player_radius := player.size_component.radius
	for slot in streamer.live_slots():
		var spec := streamer.spec_of(slot)
		var distance := player.global_position.distance_to(
			streamer.orbit_system.position_of(slot)
		)
		if distance < spec.radius + player_radius:
			return false
	return true


func _has_lighter_body() -> bool:
	var player_mass := player.mass_component.current_mass
	for slot in streamer.live_slots():
		if streamer.spec_of(slot).mass <= player_mass:
			return true
	return false
