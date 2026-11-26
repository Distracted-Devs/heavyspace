extends GutTest

var _was_enabled: bool
var _tracker: DeviceTracker


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_tracker = add_child_autofree(DeviceTracker.new())


func after_each() -> void:
	Contract.enabled = _was_enabled


func _stick(value: float) -> InputEventJoypadMotion:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = value
	return motion


func _controller_button() -> InputEventJoypadButton:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	return button


func test_device_starts_as_keyboard_and_mouse() -> void:
	assert_eq(_tracker.device, DeviceTracker.Device.KEYBOARD_MOUSE)
	assert_false(_tracker.is_controller())


func test_controller_button_switches_to_controller() -> void:
	_tracker._input(_controller_button())
	assert_eq(_tracker.device, DeviceTracker.Device.CONTROLLER)
	assert_true(_tracker.is_controller())


func test_stick_past_deadzone_switches_to_controller() -> void:
	_tracker._input(_stick(0.5))
	assert_eq(_tracker.device, DeviceTracker.Device.CONTROLLER)


func test_stick_drift_does_not_switch_device() -> void:
	_tracker._input(_stick(0.1))
	assert_eq(_tracker.device, DeviceTracker.Device.KEYBOARD_MOUSE)


func test_key_or_mouse_switches_back_to_keyboard_and_mouse() -> void:
	var events: Array[InputEvent] = [
		InputEventKey.new(),
		InputEventMouseButton.new(),
		InputEventMouseMotion.new(),
	]
	for event in events:
		_tracker._input(_controller_button())
		_tracker._input(event)
		assert_eq(_tracker.device, DeviceTracker.Device.KEYBOARD_MOUSE)


func test_other_events_leave_the_device_alone() -> void:
	_tracker._input(_controller_button())
	_tracker._input(InputEventAction.new())
	assert_eq(_tracker.device, DeviceTracker.Device.CONTROLLER)


func test_device_changed_emits_once_per_change() -> void:
	watch_signals(_tracker)
	_tracker._input(_stick(0.5))
	_tracker._input(_controller_button())
	assert_signal_emit_count(_tracker, "device_changed", 1)
	assert_signal_emitted_with_parameters(
		_tracker,
		"device_changed",
		[DeviceTracker.Device.CONTROLLER],
	)


func test_it_keeps_tracking_while_paused() -> void:
	assert_eq(_tracker.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_switch_deadzone_outside_zero_to_one_is_reported_and_ignored() -> void:
	var switch_deadzone := _tracker.switch_deadzone
	_tracker.switch_deadzone = 1.5
	assert_push_error(
		"[Contract] Pre-condition broken: switch_deadzone must be within [0, 1]"
	)
	assert_eq(_tracker.switch_deadzone, switch_deadzone)


func test_the_project_has_one_tracker_as_input_device() -> void:
	assert_true(InputDevice is DeviceTracker)
