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
	add_child_autofree(_warp)
	watch_signals(_warp)


func after_each() -> void:
	Input.action_release("warp_out")
	Contract.enabled = _was_enabled


func _collect(amount: float) -> void:
	_player.cargo.add(amount)


func _crash() -> void:
	_player.contact_component.heavier_contact.emit(
		add_child_autofree(Node3D.new()),
		1000.0,
	)


func test_collected_is_what_the_cargo_holds() -> void:
	assert_eq(_warp.collected(), 0.0)
	_collect(4.0)
	assert_almost_eq(_warp.collected(), 4.0, 1e-6)


func test_cannot_warp_until_the_tank_is_full() -> void:
	_collect(_player.cargo.tank_size - 0.5)
	assert_false(_warp.can_warp())
	assert_false(_warp.warp_out())
	assert_false(_warp.warping)
	assert_eq(_progression.bank, 0.0)
	assert_signal_not_emitted(_warp, "warp_started")


func test_every_tank_must_be_full_to_warp() -> void:
	_player.cargo.tanks = 2
	_collect(_player.cargo.tank_size)
	assert_false(_warp.can_warp())
	_collect(_player.cargo.tank_size)
	assert_true(_warp.can_warp())


func test_without_needing_every_tank_tanks_to_warp_is_enough() -> void:
	_warp.warp_needs_all_tanks = false
	_warp.tanks_to_warp = 1
	_player.cargo.tanks = 3
	_collect(_player.cargo.tank_size)
	assert_true(_warp.can_warp())


func test_tanks_to_warp_is_capped_at_the_tanks_owned() -> void:
	_warp.warp_needs_all_tanks = false
	_warp.tanks_to_warp = 5
	_player.cargo.tanks = 2
	assert_eq(_warp.tanks_required(), 2)


func test_warping_banks_the_cargo() -> void:
	_collect(_player.cargo.tank_size)
	var stored := _player.cargo.stored
	assert_true(_warp.warp_out())
	assert_almost_eq(_progression.bank, stored, 1e-5)
	assert_true(_warp.warping)
	assert_signal_emitted_with_parameters(_warp, "warp_started", [stored])
	assert_signal_emit_count(_warp, "warp_finished", 1)


func test_warp_spend_is_taken_off_the_bank() -> void:
	_warp.warp_spend = 2.0
	_collect(_player.cargo.tank_size)
	_warp.warp_out()
	assert_almost_eq(_progression.bank, _player.cargo.tank_size - 2.0, 1e-5)


func test_warp_spend_never_banks_below_zero() -> void:
	_warp.warp_spend = 1000.0
	_collect(_player.cargo.tank_size)
	_warp.warp_out()
	assert_eq(_progression.bank, 0.0)


func test_without_partial_tanks_only_full_tanks_are_banked() -> void:
	_warp.warp_needs_all_tanks = false
	_warp.bank_partial_tank = false
	_player.cargo.tanks = 2
	var size := _player.cargo.tank_size
	_collect(size * 1.5)
	_warp.warp_out()
	assert_almost_eq(_progression.bank, size, 1e-5)


func test_mass_is_banked_only_once() -> void:
	_collect(_player.cargo.tank_size)
	_warp.warp_out()
	assert_false(_warp.warp_out())
	assert_almost_eq(_progression.bank, _player.cargo.tank_size, 1e-5)
	assert_signal_emit_count(_warp, "warp_started", 1)


func test_warping_stops_flight() -> void:
	_collect(_player.cargo.tank_size)
	_warp.warp_out()
	await wait_physics_frames(1)
	assert_true(_player.freeze)


func test_no_warp_after_losing() -> void:
	_collect(_player.cargo.tank_size)
	_crash()
	assert_false(_warp.can_warp())
	assert_false(_warp.warp_out())
	assert_eq(_progression.bank, 0.0)


func test_a_crash_while_warping_does_not_lose() -> void:
	_collect(_player.cargo.tank_size)
	_warp.warp_out()
	_crash()
	assert_false(_lose.lost)


func test_the_warp_out_action_warps() -> void:
	_collect(_player.cargo.tank_size)
	var press := InputEventAction.new()
	press.action = "warp_out"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_process_frames(2)
	assert_true(_warp.warping)


func test_bad_settings_are_reported_and_ignored() -> void:
	var warp_spend := _warp.warp_spend
	_warp.warp_spend = -1.0
	assert_push_error("warp_spend must not be negative")
	var tanks_to_warp := _warp.tanks_to_warp
	_warp.tanks_to_warp = -1
	assert_push_error("tanks_to_warp must not be negative")
	assert_eq(_warp.warp_spend, warp_spend)
	assert_eq(_warp.tanks_to_warp, tanks_to_warp)


func test_a_player_without_a_cargo_is_reported() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	player.cargo = null
	add_child_autofree(player)
	var warp := WarpController.new()
	warp.player = player
	warp.lose_controller = _lose
	warp.progression = _progression
	add_child_autofree(warp)
	assert_push_error("player with a cargo and lose_controller must be set")


func _effect() -> WarpEffect:
	var effect := WarpEffect.new()
	effect.camera = add_child_autofree(Camera3D.new())
	effect.mesh = add_child_autofree(Node3D.new())
	effect.set_process(false)
	return add_child_autofree(effect)


func test_no_warp_out_until_the_warp_in_has_finished() -> void:
	var effect := _effect()
	_warp.warp_effect = effect
	_collect(_player.cargo.tank_size)
	effect.play_in()
	assert_false(_warp.can_warp())
	assert_false(_warp.warp_out())
	effect.advance(effect.warp_duration)
	assert_true(_warp.can_warp())


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
	_collect(_player.cargo.tank_size)
	_warp.warp_out()
	assert_true(effect.playing)
	assert_signal_not_emitted(_warp, "warp_finished")
	effect.advance(effect.warp_duration)
	assert_signal_emit_count(_warp, "warp_finished", 1)
