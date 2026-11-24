extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SYSTEMS_TIER := preload("res://resources/generation/systems_tier.tres")
const RINGS_TIER := preload("res://resources/generation/rings_tier.tres")
const GRAVITY := 10.0

var _was_enabled: bool
var _streamer: HierarchyStreamer
var _player: Player
var _spawn: PlayerSpawn


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_player = PLAYER_SCENE.instantiate()
	_player.flight_input.capture_mouse = false
	_player.gravity_receiver.gravity_constant = GRAVITY
	add_child_autofree(_player)
	_player.freeze = true
	_streamer = HierarchyStreamer.new()
	_streamer.level_seed = 11
	_streamer.root_radius = 5000.0
	_streamer.root_mass = 1.0e7
	_streamer.tiers = [SYSTEMS_TIER, RINGS_TIER]
	_streamer.focus_mass = _player.mass_component
	add_child_autofree(_streamer)
	_spawn = PlayerSpawn.new()
	_spawn.streamer = _streamer
	_spawn.player = _player


func after_each() -> void:
	Contract.enabled = _was_enabled


func _systems() -> OrbitRenderer:
	return _streamer.renderer_for(PackedInt32Array())


func _ring() -> OrbitRenderer:
	return _streamer.renderer_for(PackedInt32Array([_spawn.home_index]))


func _home_centre() -> Vector3:
	return _systems().child_position(_spawn.home_index, 0.0)


func test_player_starts_in_the_home_ring_plane_at_spawn_distance() -> void:
	add_child_autofree(_spawn)
	var offset := _player.global_position - _home_centre()
	assert_almost_eq(offset.length(), _spawn.spawn_distance, 1.0e-2)
	assert_almost_eq(offset.dot(_ring().global_basis.y), 0.0, 1.0e-2)


func test_player_has_home_velocity_plus_circular_orbit_speed() -> void:
	add_child_autofree(_spawn)
	var home_velocity := _systems().child_velocity(_spawn.home_index, 0.0)
	var relative := _player.linear_velocity - home_velocity
	var home_mass := _systems().layout.mass[_spawn.home_index]
	var expected := sqrt(GRAVITY * home_mass / _spawn.spawn_distance)
	assert_almost_eq(relative.length(), expected, 1.0e-3)
	var offset := (_player.global_position - _home_centre()).normalized()
	assert_almost_eq(relative.normalized().dot(offset), 0.0, 1.0e-3)


func test_stopped_clock_leaves_out_the_home_velocity() -> void:
	var clock: Clock = add_child_autofree(Clock.new())
	clock.running = false
	_streamer.clock = clock
	add_child_autofree(_spawn)
	var home_mass := _systems().layout.mass[_spawn.home_index]
	var expected := sqrt(GRAVITY * home_mass / _spawn.spawn_distance)
	assert_almost_eq(_player.linear_velocity.length(), expected, 1.0e-3)


func test_player_orbits_the_way_the_ring_turns() -> void:
	add_child_autofree(_spawn)
	var home_velocity := _systems().child_velocity(_spawn.home_index, 0.0)
	var relative := _player.linear_velocity - home_velocity
	var offset := _player.global_position - _home_centre()
	var spin := offset.cross(relative)
	var ring := _ring()
	var body_offset := ring.child_position(0, 0.0) - ring.global_position
	var ring_spin := body_offset.cross(ring.child_velocity(0, 0.0))
	assert_gt(spin.dot(ring_spin), 0.0)


func test_player_faces_along_its_orbit_with_up_out_of_the_plane() -> void:
	add_child_autofree(_spawn)
	var home_velocity := _systems().child_velocity(_spawn.home_index, 0.0)
	var direction := (_player.linear_velocity - home_velocity).normalized()
	var forward := -_player.global_basis.z
	assert_almost_eq(forward.dot(direction), 1.0, 1.0e-4)
	assert_almost_eq(
		_player.global_basis.y.dot(_ring().global_basis.y),
		1.0,
		1.0e-4,
	)


func test_spawn_angle_moves_the_start_around_the_home() -> void:
	_spawn.spawn_angle_degrees = 90.0
	add_child_autofree(_spawn)
	var ring := _ring().global_basis
	var offset := (_player.global_position - _home_centre()).normalized()
	assert_almost_eq(offset.dot(ring.z), 1.0, 1.0e-4)


func test_camera_far_plane_covers_the_system() -> void:
	add_child_autofree(_spawn)
	assert_eq(_player.camera_component.camera.far, _spawn.camera_far)


func test_spawn_inside_the_home_ring_is_reported() -> void:
	_spawn.spawn_distance = 100.0
	var start := _player.global_position
	add_child_autofree(_spawn)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "spawn_distance must clear the home ring"
	)
	assert_eq(_player.global_position, start)


func test_missing_home_system_is_reported() -> void:
	_spawn.home_index = 100000
	add_child_autofree(_spawn)
	assert_push_error("[Contract] Pre-condition broken: home system must exist")


func test_missing_streamer_is_reported() -> void:
	_spawn.streamer = null
	add_child_autofree(_spawn)
	assert_push_error(
		"[Contract] Pre-condition broken: streamer and player must be set"
	)


func test_starting_at_rest_leaves_the_player_still() -> void:
	_spawn.start_at_rest = true
	_player.gravity_receiver.drift = Vector3.ONE
	add_child_autofree(_spawn)
	assert_eq(_player.linear_velocity, Vector3.ZERO)
	assert_eq(_player.angular_velocity, Vector3.ZERO)
	assert_eq(_player.gravity_receiver.drift, Vector3.ZERO)


func _nearest_root_child() -> Vector3:
	var positions := _systems().child_positions(0.0)
	var nearest := positions[0]
	for centre in positions:
		if (
			_player.global_position.distance_to(centre)
			< _player.global_position.distance_to(nearest)
		):
			nearest = centre
	return nearest


func test_facing_the_nearest_planet_points_at_the_closest_root_child() -> void:
	_spawn.face_nearest_planet = true
	add_child_autofree(_spawn)
	var to_planet := (
		_nearest_root_child() - _player.global_position
	).normalized()
	assert_almost_eq(-_player.global_basis.z.dot(to_planet), 1.0, 1.0e-4)


func test_facing_the_nearest_planet_keeps_the_ring_normal_as_up() -> void:
	_spawn.face_nearest_planet = true
	add_child_autofree(_spawn)
	var forward := -_player.global_basis.z
	var normal := _ring().global_basis.y
	var up := (normal - forward * normal.dot(forward)).normalized()
	assert_almost_eq(_player.global_basis.y.dot(up), 1.0, 1.0e-4)


func test_facing_the_nearest_planet_leaves_position_and_velocity() -> void:
	_spawn.face_nearest_planet = true
	add_child_autofree(_spawn)
	var position := _player.global_position
	var velocity := _player.linear_velocity
	var facing := -_player.global_basis.z
	_spawn.face_nearest_planet = false
	_spawn.spawn()
	assert_almost_eq(_player.global_position, position, Vector3.ONE * 1.0e-3)
	assert_almost_eq(_player.linear_velocity, velocity, Vector3.ONE * 1.0e-3)
	assert_lt(-_player.global_basis.z.dot(facing), 0.999)


func test_starting_at_rest_still_faces_along_the_ring() -> void:
	_spawn.start_at_rest = true
	add_child_autofree(_spawn)
	var outward := (_player.global_position - _home_centre()).normalized()
	var forward := -_player.global_basis.z
	assert_almost_eq(forward.dot(outward), 0.0, 1.0e-4)
	assert_almost_eq(forward.dot(_ring().global_basis.y), 0.0, 1.0e-4)
