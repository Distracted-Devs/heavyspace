extends GutTest

const ICON_SET := preload("res://resources/ui/input_icon_set.tres")
const KEYBOARD := DeviceTracker.Device.KEYBOARD_MOUSE
const CONTROLLER := DeviceTracker.Device.CONTROLLER
const ARROWS_ONLY := &"test_arrows_only"
const FLIGHT_ACTIONS: Array[StringName] = [
	&"back_thruster",
	&"pitch_down",
	&"pitch_up",
	&"turn_left",
	&"turn_right",
	&"roll_left",
	&"roll_right",
	&"warp_out",
	&"pause",
	&"restart",
	&"look_up",
	&"look_down",
	&"look_left",
	&"look_right",
	&"ui_up",
	&"ui_down",
	&"ui_left",
	&"ui_right",
	&"ui_accept",
	&"shop_zoom_in",
	&"shop_zoom_out",
]


func after_each() -> void:
	if InputMap.has_action(ARROWS_ONLY):
		InputMap.erase_action(ARROWS_ONLY)


func _names(actions: Array[StringName], device: int) -> Array:
	return Array(InputIcons.names(actions, device, ICON_SET))


func test_keys_are_named_by_their_physical_key() -> void:
	assert_eq(_names([&"pitch_down", &"pitch_up"], KEYBOARD), ["w", "s"])
	assert_eq(_names([&"back_thruster"], KEYBOARD), ["shift"])
	assert_eq(_names([&"warp_out"], KEYBOARD), ["space"])
	assert_eq(_names([&"pause"], KEYBOARD), ["esc"])


func test_pad_buttons_and_triggers_use_the_sets_names() -> void:
	assert_eq(_names([&"warp_out"], CONTROLLER), ["x_color"])
	assert_eq(_names([&"pause"], CONTROLLER), ["menu"])
	assert_eq(_names([&"restart"], CONTROLLER), ["view"])
	assert_eq(_names([&"roll_left", &"roll_right"], CONTROLLER), ["lb", "rb"])
	assert_eq(_names([&"back_thruster"], CONTROLLER), ["rt"])


func test_a_sticks_axes_merge() -> void:
	assert_eq(_names([&"pitch_down", &"pitch_up"], CONTROLLER), ["l_y"])
	assert_eq(_names([&"turn_left", &"turn_right"], CONTROLLER), ["l_x"])
	var look: Array[StringName] = [
		&"look_up",
		&"look_down",
		&"look_left",
		&"look_right",
	]
	assert_eq(_names(look, CONTROLLER), ["r_2d"])


func test_moving_merges_the_dpad_and_stick_and_drops_the_arrows() -> void:
	var move: Array[StringName] = [
		&"ui_up",
		&"ui_left",
		&"ui_down",
		&"ui_right",
	]
	assert_eq(_names(move, KEYBOARD), ["w", "a", "s", "d"])
	assert_eq(_names(move, CONTROLLER), ["dpad", "l_2d"])


func test_the_wheel_merges_where_it_first_appears() -> void:
	var zoom: Array[StringName] = [&"shop_zoom_out", &"shop_zoom_in"]
	assert_eq(_names(zoom, KEYBOARD), ["q", "mouse_scroll", "e"])
	assert_eq(_names(zoom, CONTROLLER), ["lt", "rt"])


func test_arrows_stay_when_nothing_else_does_the_job() -> void:
	InputMap.add_action(ARROWS_ONLY)
	for code: Key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		InputMap.action_add_event(ARROWS_ONLY, key)
	assert_eq(_names([ARROWS_ONLY], KEYBOARD), ["up", "down", "left", "right"])


func test_mouse_look_has_no_binding_and_unknown_actions_are_skipped() -> void:
	assert_eq(_names([&"look_up", &"look_left"], KEYBOARD).size(), 0)
	assert_eq(_names([&"no_such_action", &"pause"], KEYBOARD), ["esc"])


func test_key_names_follow_the_pack() -> void:
	assert_eq(InputIcons.key_name(KEY_Q), "q")
	assert_eq(InputIcons.key_name(KEY_7), "7")
	assert_eq(InputIcons.key_name(KEY_F11), "f11")
	assert_eq(InputIcons.key_name(KEY_APOSTROPHE), "quotation")
	assert_eq(InputIcons.key_name(KEY_QUOTELEFT), "tilde")
	assert_eq(InputIcons.key_name(KEY_BRACKETLEFT), "brackets_l")


func test_paths_are_in_the_devices_folder() -> void:
	assert_eq(
		Array(InputIcons.paths([&"back_thruster"], CONTROLLER, ICON_SET)),
		[ICON_SET.controller_folder.path_join("rt.png")],
	)
	assert_eq(
		Array(InputIcons.paths([&"back_thruster"], KEYBOARD, ICON_SET)),
		[ICON_SET.keyboard_folder.path_join("shift.png")],
	)


func test_every_game_binding_has_an_icon_file() -> void:
	for device in [KEYBOARD, CONTROLLER]:
		for action in FLIGHT_ACTIONS:
			for path in InputIcons.paths([action], device, ICON_SET):
				assert_true(ResourceLoader.exists(path), path)
	assert_true(ResourceLoader.exists(ICON_SET.path("mouse_xy", KEYBOARD)))


func test_whole_icons_keep_the_shared_canvas() -> void:
	var button := InputIcons.texture(ICON_SET.path("a_color", CONTROLLER))
	var bumper := InputIcons.texture(ICON_SET.path("lb", CONTROLLER))
	assert_eq(button.get_size(), Vector2(128.0, 128.0))
	assert_eq(bumper.get_size(), button.get_size())


func test_cropped_icons_are_cut_to_their_visible_pixels() -> void:
	var shift := InputIcons.texture(ICON_SET.path("shift", KEYBOARD), true)
	assert_gt(shift.get_width(), shift.get_height())
	assert_lt(shift.get_height(), 128)


func test_textures_are_cached_and_mipmapped() -> void:
	var path := ICON_SET.path("w", KEYBOARD)
	var texture := InputIcons.texture(path)
	assert_same(InputIcons.texture(path), texture)
	assert_ne(InputIcons.texture(path, true), texture)
	assert_true(texture.get_image().has_mipmaps())


func test_a_missing_icon_is_null() -> void:
	assert_null(InputIcons.texture("res://no/such/icon.png"))
