extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const OVERLAY_SCENE := preload("res://scenes/ui/lose_overlay.tscn")

var _player: Player
var _overlay: LoseOverlay


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.flight_input.capture_mouse = false
	add_child_autofree(_player)
	var lose := LoseController.new()
	lose.player = _player
	add_child_autofree(lose)
	_overlay = OVERLAY_SCENE.instantiate()
	_overlay.lose_controller = lose
	add_child_autofree(_overlay)


func test_message_is_hidden_until_the_player_loses() -> void:
	assert_false(_overlay.visible)
	_player.contact_component.heavier_contact.emit(_player, 100.0)
	assert_true(_overlay.visible)


func test_it_prompts_a_restart_with_a_pulse() -> void:
	var prompt: InputPrompt = _overlay.get_node("Centre/Panel/Rows/Restart")
	assert_eq(Array(prompt.actions), [&"restart"])
	var pulse: PulseEffect = _overlay.get_node("RestartPulse")
	assert_eq(pulse.target, prompt)
	assert_true(pulse.active)


func test_the_backdrop_lets_the_mouse_through() -> void:
	for part_name in ["Backdrop", "Scanlines", "Centre"]:
		var part: Control = _overlay.get_node(part_name)
		assert_eq(part.mouse_filter, Control.MOUSE_FILTER_IGNORE, part_name)


func test_with_slow_motion_it_waits_for_it_to_finish() -> void:
	var slow := TimeScaleEffect.new()
	slow.set_process(false)
	add_child_autofree(slow)
	_overlay.time_scale_effect = slow
	_overlay.popup_delay = 0.05
	_player.contact_component.heavier_contact.emit(_player, 100.0)
	assert_false(_overlay.visible)
	slow.finished.emit()
	assert_false(_overlay.visible, "it holds back for the pop-up delay")
	await wait_seconds(0.15)
	assert_true(_overlay.visible)
