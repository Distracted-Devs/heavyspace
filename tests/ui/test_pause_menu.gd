extends GutTest

const MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const LEVEL_PATH := "res://scenes/levels/generated_level.tscn"

var _was_enabled: bool
var _pause: PauseController
var _devices: DeviceTracker
var _menu: PauseMenu


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_pause = add_child_autofree(PauseController.new())
	_pause.reload_on_restart = false
	_devices = add_child_autofree(DeviceTracker.new())
	_menu = MENU_SCENE.instantiate()
	_menu.pause_controller = _pause
	_menu.devices = _devices
	_menu.quit_on_request = false
	add_child_autofree(_menu)


func after_each() -> void:
	get_tree().paused = false
	Contract.enabled = _was_enabled


func _press_b() -> void:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_B
	button.pressed = true
	_menu._unhandled_input(button)


func test_it_shows_only_while_paused() -> void:
	assert_false(_menu.visible)
	_pause.set_paused(true)
	assert_true(_menu.visible)
	_pause.set_paused(false)
	assert_false(_menu.visible)


func test_resume_has_focus_each_time_it_opens() -> void:
	_pause.set_paused(true)
	assert_true(_menu.resume_button.has_focus())
	_menu.quit_button.grab_focus()
	_pause.set_paused(false)
	_pause.set_paused(true)
	assert_true(_menu.resume_button.has_focus())


func test_resume_unpauses() -> void:
	_pause.set_paused(true)
	_menu.resume_button.pressed.emit()
	assert_false(get_tree().paused)
	assert_false(_menu.visible)


func test_restart_restarts_through_the_controller() -> void:
	watch_signals(_pause)
	_pause.set_paused(true)
	_menu.restart_button.pressed.emit()
	assert_signal_emit_count(_pause, "restarting", 1)
	assert_false(get_tree().paused)


func test_quit_asks_to_quit() -> void:
	watch_signals(_menu)
	_menu.quit_button.pressed.emit()
	assert_signal_emit_count(_menu, "quit_requested", 1)


func test_pad_b_resumes_while_shown() -> void:
	_pause.set_paused(true)
	_press_b()
	assert_false(get_tree().paused)


func test_pad_b_does_nothing_while_hidden() -> void:
	watch_signals(_pause)
	_press_b()
	assert_signal_not_emitted(_pause, "paused_changed")


func test_header_follows_the_active_device() -> void:
	var keyboard := _menu.header.text
	_devices.device = DeviceTracker.Device.CONTROLLER
	assert_ne(_menu.header.text, keyboard)


func test_its_view_follows_the_same_devices() -> void:
	assert_eq(_menu.view.devices, _devices)


func test_it_runs_while_paused_above_the_game() -> void:
	assert_eq(_menu.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(_menu.layer, 20)


func test_missing_controller_is_reported() -> void:
	var menu: PauseMenu = MENU_SCENE.instantiate()
	menu.devices = _devices
	add_child_autofree(menu)
	assert_push_error(
		"[Contract] Pre-condition broken: pause_controller must be set"
	)


func test_the_level_uses_the_pause_menu() -> void:
	var level: Node = autofree(load(LEVEL_PATH).instantiate())
	var menu := level.get_node("PauseMenu") as PauseMenu
	assert_not_null(menu)
	assert_eq(menu.pause_controller, level.get_node("PauseController"))
	assert_false(level.has_node("PauseOverlay"))
