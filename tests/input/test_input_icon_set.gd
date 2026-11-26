extends GutTest

const ICON_SET := preload("res://resources/ui/input_icon_set.tres")
const KEYBOARD := DeviceTracker.Device.KEYBOARD_MOUSE
const CONTROLLER := DeviceTracker.Device.CONTROLLER


func test_path_is_the_icon_in_the_devices_folder() -> void:
	var icon_set := InputIconSet.new()
	icon_set.controller_folder = "res://pad"
	icon_set.keyboard_folder = "res://keys/"
	assert_eq(icon_set.path("rt", CONTROLLER), "res://pad/rt.png")
	assert_eq(icon_set.path("shift", KEYBOARD), "res://keys/shift.png")


func test_face_buttons_use_the_coloured_icons() -> void:
	assert_eq(ICON_SET.buttons[JOY_BUTTON_A], "a_color")
	assert_eq(ICON_SET.buttons[JOY_BUTTON_B], "b_color")
	assert_eq(ICON_SET.buttons[JOY_BUTTON_X], "x_color")
	assert_eq(ICON_SET.buttons[JOY_BUTTON_Y], "y_color")


func test_every_named_button_and_axis_icon_exists() -> void:
	var names := PackedStringArray(ICON_SET.buttons.values())
	for stick in [ICON_SET.left_stick, ICON_SET.right_stick]:
		for suffix in ["_x", "_y", "_2d"]:
			names.append(stick + suffix)
	names.append_array([ICON_SET.left_trigger, ICON_SET.right_trigger, "dpad"])
	for icon in names:
		var path: String = ICON_SET.path(icon, CONTROLLER)
		assert_true(ResourceLoader.exists(path), path)
