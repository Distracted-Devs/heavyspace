extends GutTest


func _has_key(action: StringName, key: Key) -> bool:
	return InputMap.action_get_events(action).any(
		func(event: InputEvent) -> bool:
			var pressed := event as InputEventKey
			return pressed != null and pressed.physical_keycode == key,
	)


func _has_button(action: StringName, button: JoyButton) -> bool:
	return InputMap.action_get_events(action).any(
		func(event: InputEvent) -> bool:
			var pressed := event as InputEventJoypadButton
			return (
				pressed != null and pressed.button_index == button
				and pressed.device == -1
			),
	)


func _has_axis(action: StringName, axis: JoyAxis, direction: float) -> bool:
	return InputMap.action_get_events(action).any(
		func(event: InputEvent) -> bool:
			var motion := event as InputEventJoypadMotion
			return (
				motion != null and motion.axis == axis
				and signf(motion.axis_value) == direction
			),
	)


func test_ui_accept_is_only_enter_and_joypad_a() -> void:
	assert_eq(InputMap.action_get_events(&"ui_accept").size(), 2)
	assert_true(_has_key(&"ui_accept", KEY_ENTER))
	assert_true(_has_button(&"ui_accept", JOY_BUTTON_A))


func test_space_does_not_accept() -> void:
	assert_false(_has_key(&"ui_accept", KEY_SPACE))


func test_the_dpad_and_left_stick_move_focus() -> void:
	var directions := {
		&"ui_up": [JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0],
		&"ui_down": [JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0],
		&"ui_left": [JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0],
		&"ui_right": [JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0],
	}
	for action: StringName in directions:
		var expected: Array = directions[action]
		assert_true(_has_button(action, expected[0]), action)
		assert_true(_has_axis(action, expected[1], expected[2]), action)


func _has_wheel(action: StringName, button: MouseButton) -> bool:
	return InputMap.action_get_events(action).any(
		func(event: InputEvent) -> bool:
			var wheel := event as InputEventMouseButton
			return wheel != null and wheel.button_index == button,
	)


func test_warp_out_is_only_space_and_joypad_x() -> void:
	assert_eq(InputMap.action_get_events(&"warp_out").size(), 2)
	assert_true(_has_key(&"warp_out", KEY_SPACE))
	assert_true(_has_button(&"warp_out", JOY_BUTTON_X))
	assert_false(_has_button(&"warp_out", JOY_BUTTON_A))


func test_the_arrows_and_wasd_move_focus() -> void:
	var keys := {
		&"ui_up": [KEY_UP, KEY_W],
		&"ui_down": [KEY_DOWN, KEY_S],
		&"ui_left": [KEY_LEFT, KEY_A],
		&"ui_right": [KEY_RIGHT, KEY_D],
	}
	for action: StringName in keys:
		for key: Key in keys[action]:
			assert_true(_has_key(action, key), "%s %d" % [action, key])


func test_triggers_q_e_and_the_wheel_zoom_the_shop() -> void:
	assert_true(_has_axis(&"shop_zoom_in", JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_true(_has_key(&"shop_zoom_in", KEY_E))
	assert_true(_has_wheel(&"shop_zoom_in", MOUSE_BUTTON_WHEEL_UP))
	assert_true(_has_axis(&"shop_zoom_out", JOY_AXIS_TRIGGER_LEFT, 1.0))
	assert_true(_has_key(&"shop_zoom_out", KEY_Q))
	assert_true(_has_wheel(&"shop_zoom_out", MOUSE_BUTTON_WHEEL_DOWN))
