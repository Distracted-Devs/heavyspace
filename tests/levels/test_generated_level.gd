extends GutTest

const LEVEL_PATH := "res://scenes/levels/generated_level.tscn"
const FRAMES := 30

var _level: Node3D


func before_each() -> void:
	var scene: PackedScene = load(LEVEL_PATH)
	_level = scene.instantiate()
	var player: Player = _level.get_node("Player")
	player.flight_input.capture_mouse = false
	add_child_autofree(_level)


func _player() -> Player:
	return _level.get_node("Player")


func _streamer() -> HierarchyStreamer:
	return _level.get_node("HierarchyStreamer")


func _pool() -> LiveBodyPool:
	return _level.get_node("LiveBodyPool")


func _home_centre() -> Vector3:
	var clock: Clock = _level.get_node("Clock")
	var systems := _streamer().renderer_for(PackedInt32Array())
	return systems.child_position(0, clock.time)


func test_generated_level_is_the_main_scene() -> void:
	var main_scene: String = ProjectSettings.get_setting(
		"application/run/main_scene"
	)
	assert_eq(ResourceLoader.load(main_scene).resource_path, LEVEL_PATH)


func test_level_starts_with_the_giant_and_its_systems() -> void:
	var streamer := _streamer()
	assert_ne(streamer.resolved_seed, 0)
	assert_almost_eq(
		float(streamer.renderer_for(PackedInt32Array()).count()),
		1980.0,
		300.0,
	)
	assert_eq(_pool().root_body.radius, streamer.root_radius)
	assert_eq(_pool().root_body.mass, streamer.root_mass)


func test_player_starts_in_orbit_around_its_home_system() -> void:
	var distance := _player().global_position.distance_to(_home_centre())
	assert_almost_eq(distance, 300.0, 1.0e-2)
	assert_true(_streamer().is_expanded(PackedInt32Array([0])))


func test_home_system_is_a_real_body_once_physics_runs() -> void:
	await wait_physics_frames(2)
	var systems := _streamer().renderer_for(PackedInt32Array())
	assert_not_null(_pool().body_for(systems, 0))
	assert_true(systems.is_hidden(0))


func test_player_stays_near_its_home_system_without_input() -> void:
	await wait_physics_frames(FRAMES)
	var distance := _player().global_position.distance_to(_home_centre())
	assert_between(distance, 250.0, 350.0)
	var lose: LoseController = _level.get_node("LoseController")
	assert_false(lose.lost)


func _innermost(renderer: OrbitRenderer) -> int:
	var orbits := renderer.layout.orbit_radius
	var best := 0
	for index in orbits.size():
		if orbits[index] < orbits[best]:
			best = index
	return best


func test_home_ring_bodies_start_no_heavier_than_the_player() -> void:
	var ring := _streamer().renderer_for(PackedInt32Array([0]))
	var player_mass := _player().mass_component.current_mass
	for index in ring.count():
		assert_lte(ring.layout.mass[index], player_mass)


func test_flying_into_the_home_ring_grows_the_player_without_losing() -> void:
	var clock: Clock = _level.get_node("Clock")
	var systems := _streamer().renderer_for(PackedInt32Array())
	var ring := _streamer().renderer_for(PackedInt32Array([0]))
	var index := _innermost(ring)
	var player := _player()
	var start_mass := player.mass_component.current_mass
	var start_radius := (
		(player.get_node("Collider") as CollisionShape3D).shape as SphereShape3D
	).radius
	player.global_position = ring.child_position(index, clock.time)
	player.linear_velocity = systems.child_velocity(0, clock.time)
	await wait_physics_frames(FRAMES * 3)
	var lose: LoseController = _level.get_node("LoseController")
	assert_false(lose.lost, "eating the ring must not lose")
	assert_gt(player.mass_component.current_mass, start_mass)
	var grown_radius := (
		(player.get_node("Collider") as CollisionShape3D).shape as SphereShape3D
	).radius
	assert_gt(grown_radius, start_radius)
	assert_true(_streamer().is_removed(PackedInt32Array([0, index])))


func test_level_wires_the_pickup_to_the_pool_and_sets_gravity() -> void:
	var pickup: PickupComponent = _player().get_node("PickupComponent")
	assert_eq(pickup.pool, _pool(), "the pickup must use the level's pool")
	assert_eq(_player().gravity_receiver.gravity_constant, 10.0)
	assert_eq(_streamer().focus_mass, _player().mass_component)
