class_name PlayerSpawn
extends Node

@export_group("Components")
@export var streamer: HierarchyStreamer
@export var player: Player

@export_group("Spawn")
@export var home_index := 0
@export_range(0.0, 10000.0, 0.1, "or_greater") var spawn_distance := 300.0
@export_range(-180.0, 180.0, 0.1) var spawn_angle_degrees := 0.0
@export_range(1.0, 1.0e6, 1.0, "or_greater") var camera_far := 60000.0
@export var start_at_rest := false


func _ready() -> void:
	spawn()


func spawn() -> void:
	if not Contract.require(
		streamer != null and player != null,
		"streamer and player must be set",
	):
		return
	var systems := streamer.renderer_for(PackedInt32Array())
	if not Contract.require(
		systems != null and home_index >= 0 and home_index < systems.count(),
		"home system must exist",
	):
		return
	var time := streamer.clock.time if streamer.clock != null else 0.0
	var home_path := PackedInt32Array([home_index])
	var home_centre := systems.child_position(home_index, time)
	var home_radius := systems.layout.radius[home_index]
	var ring_tier := streamer.tier_of(home_path)
	if ring_tier == null:
		streamer.update(home_centre, time)
		ring_tier = streamer.tier_of(home_path)
	var ring := streamer.renderer_for(home_path)
	if not Contract.require(
		ring != null and spawn_distance > _ring_reach(ring_tier, home_radius),
		"spawn_distance must clear the home ring",
	):
		return

	var plane := ring.global_basis
	var angle := deg_to_rad(spawn_angle_degrees)
	var outward := plane * Vector3(cos(angle), 0.0, sin(angle))
	var prograde := plane * Vector3(-sin(angle), 0.0, cos(angle))
	var orbit_speed := sqrt(
		player.gravity_receiver.gravity_constant
		* systems.layout.mass[home_index]
		/ spawn_distance,
	)
	player.global_position = home_centre + outward * spawn_distance
	player.global_basis = Basis.looking_at(prograde, plane.y)
	var home_velocity := Vector3.ZERO
	if streamer.clock == null or streamer.clock.running:
		home_velocity = systems.child_velocity(home_index, time)
	player.linear_velocity = home_velocity + prograde * orbit_speed
	if start_at_rest:
		_stop(player)
	player.camera_component.camera.far = camera_far
	Contract.ensure(
		(
			is_equal_approx(
				player.global_position.distance_to(home_centre),
				spawn_distance,
			)
			and absf((player.global_position - home_centre).dot(plane.y))
			< 1.0e-3 * spawn_distance
		),
		"player must start in the home ring's plane at spawn_distance",
	)


func _stop(ship: Player) -> void:
	ship.linear_velocity = Vector3.ZERO
	ship.angular_velocity = Vector3.ZERO
	if ship.gravity_receiver != null:
		ship.gravity_receiver.reset_drift()
	Contract.ensure(
		ship.linear_velocity == Vector3.ZERO
		and ship.angular_velocity == Vector3.ZERO,
		"a player started at rest must not move",
	)


func _ring_reach(ring_tier: Tier, home_radius: float) -> float:
	return (
		ring_tier.orbit_outer * home_radius
		+ ring_tier.thickness + ring_tier.radius_max
	)
