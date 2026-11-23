extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _was_enabled: bool
var _player: Player
var _lose: LoseController
var _warp: WarpController
var _progression: Progression


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_progression = Progression.new()
	_player = PLAYER_SCENE.instantiate()
	_player.flight_input.capture_mouse = false
	add_child_autofree(_player)
	_lose = LoseController.new()
	_lose.player = _player
	add_child_autofree(_lose)
	_warp = WarpController.new()
	_warp.player = _player
	_warp.lose_controller = _lose
	_warp.progression = _progression
	_warp.warp_cost = 10.0
	add_child_autofree(_warp)
	watch_signals(_warp)


func after_each() -> void:
	Input.action_release("warp_out")
	Contract.enabled = _was_enabled


func _collect(amount: float) -> void:
	_player.mass_component.current_mass += amount


func _crash() -> void:
	_player.contact_component.heavier_contact.emit(
		add_child_autofree(Node3D.new()),
		1000.0,
	)


func test_collected_counts_from_the_run_start_mass() -> void:
	assert_eq(_warp.collected(), 0.0)
	_collect(4.0)
	assert_almost_eq(_warp.collected(), 4.0, 1e-6)


func test_the_run_start_mass_includes_the_starting_upgrade() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	player.mass_component.start_multiplier = 2.0
	add_child_autofree(player)
	var warp := WarpController.new()
	warp.player = player
	warp.lose_controller = _lose
	warp.progression = _progression
	add_child_autofree(warp)
	assert_eq(warp.run_start_mass, player.mass_component.starting_mass * 2.0)
	assert_eq(warp.collected(), 0.0)


func test_cannot_warp_below_the_cost() -> void:
	_collect(9.0)
	assert_false(_warp.can_warp())
	assert_false(_warp.warp_out())
	assert_false(_warp.warping)
	assert_eq(_progression.bank, 0.0)
	assert_signal_not_emitted(_warp, "warp_started")


func test_warping_banks_what_is_left_after_the_cost() -> void:
	_collect(14.0)
	assert_true(_warp.can_warp())
	assert_true(_warp.warp_out())
	assert_almost_eq(_progression.bank, 4.0, 1e-5)
	assert_true(_warp.warping)
	assert_signal_emitted_with_parameters(_warp, "warp_started", [4.0])
	assert_signal_emit_count(_warp, "warp_finished", 1)


func test_without_spending_the_cost_it_banks_everything() -> void:
	_warp.warp_spends_cost = false
	_collect(14.0)
	_warp.warp_out()
	assert_almost_eq(_progression.bank, 14.0, 1e-5)


func test_a_free_warp_with_nothing_collected_banks_nothing() -> void:
	_warp.warp_cost = 0.0
	assert_true(_warp.warp_out())
	assert_eq(_progression.bank, 0.0)


func test_mass_is_banked_only_once() -> void:
	_collect(30.0)
	_warp.warp_out()
	assert_false(_warp.warp_out())
	assert_almost_eq(_progression.bank, 20.0, 1e-5)
	assert_signal_emit_count(_warp, "warp_started", 1)


func test_warping_stops_flight() -> void:
	_collect(10.0)
	_warp.warp_out()
	await wait_physics_frames(1)
	assert_true(_player.freeze)


func test_no_warp_after_losing() -> void:
	_collect(20.0)
	_crash()
	assert_false(_warp.can_warp())
	assert_false(_warp.warp_out())
	assert_eq(_progression.bank, 0.0)


func test_a_crash_while_warping_does_not_lose() -> void:
	_collect(10.0)
	_warp.warp_out()
	_crash()
	assert_false(_lose.lost)


func test_the_warp_out_action_warps() -> void:
	_collect(10.0)
	var press := InputEventAction.new()
	press.action = "warp_out"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_process_frames(2)
	assert_true(_warp.warping)


func test_negative_warp_cost_is_reported_and_ignored() -> void:
	_warp.warp_cost = -1.0
	assert_push_error("warp_cost must not be negative")
	assert_eq(_warp.warp_cost, 10.0)


func test_with_an_effect_the_warp_finishes_when_the_effect_does() -> void:
	var camera := Camera3D.new()
	var mesh := Node3D.new()
	add_child_autofree(camera)
	add_child_autofree(mesh)
	var effect := WarpEffect.new()
	effect.camera = camera
	effect.mesh = mesh
	effect.set_process(false)
	add_child_autofree(effect)
	_warp.warp_effect = effect
	_collect(10.0)
	_warp.warp_out()
	assert_true(effect.playing)
	assert_signal_not_emitted(_warp, "warp_finished")
	effect.advance(effect.warp_duration)
	assert_signal_emit_count(_warp, "warp_finished", 1)
