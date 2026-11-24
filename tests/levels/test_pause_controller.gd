extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const FRAMES := 30

var _was_enabled: bool
var _pause: PauseController


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_pause = add_child_autofree(PauseController.new())


func after_each() -> void:
	get_tree().paused = false
	Contract.enabled = _was_enabled


func _spawn_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	player.linear_damp = 0.0
	return add_child_autofree(player)


func _pause_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	return event


func test_set_paused_pauses_and_unpauses_the_tree() -> void:
	_pause.set_paused(true)
	assert_true(get_tree().paused)
	_pause.set_paused(false)
	assert_false(get_tree().paused)


func test_pause_action_toggles_pause() -> void:
	_pause._unhandled_input(_pause_event())
	assert_true(_pause.paused)
	_pause._unhandled_input(_pause_event())
	assert_false(_pause.paused)


func test_paused_changed_emits_once_per_real_change() -> void:
	watch_signals(_pause)
	_pause.set_paused(true)
	_pause.set_paused(true)
	assert_signal_emit_count(_pause, "paused_changed", 1)
	assert_signal_emitted_with_parameters(_pause, "paused_changed", [true])
	_pause.set_paused(false)
	_pause.set_paused(false)
	assert_signal_emit_count(_pause, "paused_changed", 2)


func test_controller_keeps_running_while_paused() -> void:
	_pause.set_paused(true)
	assert_true(_pause.can_process())


func test_pausing_freezes_a_moving_ship_and_its_fuel() -> void:
	var player := _spawn_player()
	player.linear_velocity = Vector3(0.0, 0.0, -3.0)
	player.fuel_component.draw(0.5)
	await wait_physics_frames(1)
	_pause.set_paused(true)
	var frozen_position := player.global_position
	var frozen_fuel := player.fuel_component.fuel
	await wait_physics_frames(FRAMES)
	assert_eq(player.global_position, frozen_position)
	assert_eq(player.fuel_component.fuel, frozen_fuel)


func test_unpausing_resumes_at_the_same_velocity() -> void:
	var player := _spawn_player()
	var velocity := Vector3(0.0, 0.0, -3.0)
	player.linear_velocity = velocity
	await wait_physics_frames(1)
	_pause.set_paused(true)
	await wait_physics_frames(FRAMES)
	_pause.set_paused(false)
	var resumed_position := player.global_position
	await wait_physics_frames(FRAMES)
	assert_almost_eq(player.linear_velocity, velocity, Vector3.ONE * 1e-4)
	assert_ne(player.global_position, resumed_position)
