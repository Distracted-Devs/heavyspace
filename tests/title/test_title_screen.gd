extends GutTest

const TITLE_SCENE := preload("res://scenes/title/title_screen.tscn")

var _was_enabled: bool
var _title: TitleScreen
var _events: GameEvents
var _sessions_started := 0


func before_all() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_events = GameEvents.new()
	add_child(_events)
	_events.session_started.connect(
		func() -> void:
			_sessions_started += 1,
	)
	_title = TITLE_SCENE.instantiate()
	_title.events = _events
	add_child(_title)
	await wait_physics_frames(2)


func after_all() -> void:
	_title.free()
	_events.free()
	Engine.time_scale = 1.0
	Contract.enabled = _was_enabled


func test_loading_starts_one_session() -> void:
	assert_eq(_sessions_started, 1)


func test_the_level_behind_uses_the_title_seed() -> void:
	assert_eq(_title.streamer.resolved_seed, _title.title_seed)


func test_the_orbits_run_fast() -> void:
	var clock: Clock = _title.level.get_node("Clock")
	assert_eq(clock.speed, _title.time_speed)


func test_the_player_is_stopped_and_hidden() -> void:
	var player: Player = _title.level.get_node("Player")
	assert_false(player.visible)
	assert_true(player.freeze)


func test_gameplay_doesnt_run() -> void:
	for quiet in TitleScreen.QUIET_NODES:
		var node := _title.level.get_node(NodePath(quiet))
		assert_eq(node.process_mode, Node.PROCESS_MODE_DISABLED, quiet)


func test_the_hud_is_hidden() -> void:
	var layers := _title.level.get_children().filter(
		func(child: Node) -> bool:
			return child is CanvasLayer,
	)
	assert_false(layers.is_empty())
	assert_true(
		layers.all(
			func(layer: CanvasLayer) -> bool:
				return not layer.visible,
		)
	)


func test_its_own_camera_frames_the_root_body() -> void:
	assert_true(_title.camera.current)
	var root := _title.streamer.renderer_for(PackedInt32Array())
	var to_root := root.global_position - _title.camera.global_position
	var distance := _title.streamer.root_radius * _title.framing.distance_radii
	assert_almost_eq(to_root.length(), distance, distance * 1e-3)


func test_the_menu_is_up_and_wired() -> void:
	assert_not_null(_title.menu)
	assert_true(_title.menu.main_page.visible)
	assert_true(_title.menu.start_pressed.is_connected(_title.start))
