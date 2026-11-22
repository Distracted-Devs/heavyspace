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
		500.0,
		75.0,
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
