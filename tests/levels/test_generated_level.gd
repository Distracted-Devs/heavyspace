extends GutTest

const LEVEL_SCENE := preload("res://scenes/levels/generated_level.tscn")
const SEEDS: Array[int] = [1, 42, 2026, 99999]

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func _spawn_level(level_seed: int) -> GeneratedLevel:
	var level: GeneratedLevel = LEVEL_SCENE.instantiate()
	var settings: SystemSettings = level.streamer.settings.duplicate(true)
	settings.level_seed = level_seed
	level.streamer.settings = settings
	level.player.flight_input.capture_mouse = false
	return add_child_autofree(level)


func test_player_spawns_clear_of_bodies_for_several_seeds() -> void:
	for level_seed in SEEDS:
		var level := _spawn_level(level_seed)
		var player_radius := level.player.size_component.radius
		for slot in level.streamer.live_slots():
			var spec := level.streamer.spec_of(slot)
			var distance := level.player.global_position.distance_to(
				level.streamer.orbit_system.position_of(slot)
			)
			assert_gt(distance, spec.radius + player_radius, str(level_seed))
		level.free()


func test_player_spawns_next_to_a_depth_two_body() -> void:
	var level := _spawn_level(42)
	assert_eq(level.spawner.spawn_spec.depth, 2)


func test_player_starts_at_rest_relative_to_its_spawn_body() -> void:
	var level := _spawn_level(42)
	var spawn_key := level.spawner.spawn_spec.key()
	for slot in level.streamer.live_slots():
		if level.streamer.spec_of(slot).key() == spawn_key:
			assert_almost_eq(
				level.player.linear_velocity,
				level.streamer.orbit_system.velocity_of(slot),
				Vector3.ONE * 1e-4,
			)
			return
	fail_test("spawn body is not live")


func test_spawn_body_and_its_ancestors_are_expanded() -> void:
	var level := _spawn_level(42)
	var spawn_key := level.spawner.spawn_spec.key()
	for slot in level.streamer.live_slots():
		if level.streamer.spec_of(slot).key() == spawn_key:
			var current := slot
			while current != OrbitSystem.NO_PARENT:
				assert_true(level.streamer.is_expanded(current))
				current = level.streamer.orbit_system.parent_of(current)
			return
	fail_test("spawn body is not live")


func test_lighter_bodies_are_live_at_spawn() -> void:
	var level := _spawn_level(42)
	var lighter := 0
	for slot in level.streamer.live_slots():
		if level.streamer.spec_of(slot).mass <= 1.0:
			lighter += 1
	assert_gt(lighter, 10)


func test_level_runs_for_ten_seconds_without_broken_contracts() -> void:
	var level := _spawn_level(42)
	await wait_physics_frames(600)
	assert_gt(level.streamer.live_slots().size(), 100)


func test_player_mass_law_matches_the_system() -> void:
	var level := _spawn_level(42)
	assert_eq(
		level.player.size_component.mass_law,
		level.streamer.settings.mass_law,
	)
