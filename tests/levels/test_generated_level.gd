extends GutTest

const LEVEL_PATH := "res://scenes/levels/generated_level.tscn"
const FRAMES := 30

const UPGRADES := "res://resources/progression/upgrades/"

var _level: Node3D
var _progression: Progression


func before_each() -> void:
	_progression = Progression.new()
	_level = _build(_progression)


func after_each() -> void:
	get_tree().paused = false


func _build(progression: Progression) -> Node3D:
	var scene: PackedScene = load(LEVEL_PATH)
	var level: Node3D = scene.instantiate()
	var player: Player = level.get_node("Player")
	player.flight_input.capture_mouse = false
	(level.get_node("RunStarter") as RunStarter).progression = progression
	(level.get_node("WarpController") as WarpController).progression = (
		progression
	)
	var shop: ShopOverlay = level.get_node("ShopOverlay")
	shop.progression = progression
	shop.reload_on_launch = false
	return add_child_autofree(level)


func _rebuild_with(progression: Progression) -> void:
	_level.free()
	_progression = progression
	_level = _build(progression)


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


func test_home_ring_bodies_start_no_heavier_than_the_player() -> void:
	var ring := _streamer().renderer_for(PackedInt32Array([0]))
	var player_mass := _player().mass_component.current_mass
	for index in ring.count():
		assert_lte(ring.layout.mass[index], player_mass)


func test_level_wires_the_pickup_to_the_pool_and_sets_gravity() -> void:
	var pickup: PickupComponent = _player().get_node("PickupComponent")
	assert_eq(pickup.pool, _pool(), "the pickup must use the level's pool")
	assert_eq(_player().gravity_receiver.gravity_constant, 10.0)
	assert_eq(_streamer().focus_mass, _player().mass_component)


func test_level_wires_the_game_loop() -> void:
	var starter: RunStarter = _level.get_node("RunStarter")
	var warp: WarpController = _level.get_node("WarpController")
	var effect: WarpEffect = _level.get_node("WarpEffect")
	var shop: ShopOverlay = _level.get_node("ShopOverlay")
	assert_eq(starter.player, _player())
	assert_eq(warp.player, _player())
	assert_eq(warp.lose_controller, _level.get_node("LoseController"))
	assert_eq(warp.warp_effect, effect)
	assert_eq(warp.warp_cost, 10.0)
	assert_true(warp.warp_spends_cost)
	assert_eq(effect.camera, _player().camera_component.camera)
	assert_eq(effect.mesh, _player().get_node("Mesh"))
	assert_eq(effect.fade, _level.get_node("WarpFade/Fade"))
	assert_eq(shop.warp_controller, warp)
	assert_eq(shop.run_starter, starter)


func test_the_run_starter_holds_all_six_upgrades() -> void:
	var starter: RunStarter = _level.get_node("RunStarter")
	var ids := { }
	for upgrade in starter.upgrades:
		ids[upgrade.id] = true
	assert_eq(starter.upgrades.size(), 6)
	assert_eq(ids.size(), 6)
	assert_true(starter.started)
	assert_eq(_progression.runs, 1)


func test_the_run_starts_upgraded_and_the_home_ring_follows() -> void:
	var booster: Upgrade = load(UPGRADES + "booster_upgrade.tres")
	var size: Upgrade = load(UPGRADES + "starting_size_upgrade.tres")
	var base: Player = load("res://scenes/player/player.tscn").instantiate()
	var base_thrust := base.thruster.back_thrust_force
	var base_mass := base.mass_component.starting_mass
	base.free()
	var progression := Progression.new()
	progression.bank_mass(1000.0)
	progression.buy(booster)
	progression.buy(size)
	progression.buy(size)
	_rebuild_with(progression)
	var player := _player()
	assert_almost_eq(
		player.thruster.back_thrust_force,
		base_thrust * booster.multiplier(1),
		1e-4,
	)
	var start_mass := base_mass * size.multiplier(2)
	assert_almost_eq(player.mass_component.current_mass, start_mass, 1e-6)
	var ring := _streamer().renderer_for(PackedInt32Array([0]))
	var heaviest := 0.0
	for index in ring.count():
		assert_lte(ring.layout.mass[index], start_mass)
		heaviest = maxf(heaviest, ring.layout.mass[index])
	assert_gt(heaviest, base_mass, "the ring must follow the upgraded mass")


func test_warping_banks_and_opens_the_shop_then_launch_unpauses() -> void:
	var warp: WarpController = _level.get_node("WarpController")
	var effect: WarpEffect = _level.get_node("WarpEffect")
	var shop: ShopOverlay = _level.get_node("ShopOverlay")
	_player().mass_component.current_mass += 14.0
	assert_true(warp.warp_out())
	assert_almost_eq(_progression.bank, 4.0, 1e-4)
	assert_false(shop.is_open)
	effect.advance(effect.warp_duration)
	assert_true(shop.is_open)
	assert_true(get_tree().paused)
	shop.launch()
	assert_false(get_tree().paused)
