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
