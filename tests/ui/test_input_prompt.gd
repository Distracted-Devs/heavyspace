extends GutTest

const ICON_SET := preload("res://resources/ui/input_icon_set.tres")
const THEME := preload("res://resources/ui/holo_theme.tres")
const KEYBOARD := DeviceTracker.Device.KEYBOARD_MOUSE
const CONTROLLER := DeviceTracker.Device.CONTROLLER

var _was_enabled: bool
var _devices: DeviceTracker
var _prompt: InputPrompt


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_devices = add_child_autofree(DeviceTracker.new())
	_prompt = autofree(InputPrompt.new())
	_prompt.devices = _devices
	_prompt.actions = [&"back_thruster"]
	_prompt.text = "BOOST"


func after_each() -> void:
	Contract.enabled = _was_enabled


func _shown() -> Array:
	var shown := []
	for child in _prompt.get_children():
		if child is TextureRect:
			shown.append(child.custom_minimum_size)
		elif child is Label:
			shown.append(child.text)
	return shown


func test_shows_the_keyboard_icon_then_the_text() -> void:
	add_child(_prompt)
	assert_eq(Array(_prompt.icon_paths()), [ICON_SET.path("shift", KEYBOARD)])
	assert_eq(_shown(), [Vector2.ONE * _prompt.icon_size, "BOOST"])


func test_rebuilds_when_the_device_changes() -> void:
	add_child(_prompt)
	_devices.device = CONTROLLER
	assert_eq(Array(_prompt.icon_paths()), [ICON_SET.path("rt", CONTROLLER)])
	assert_eq(_shown().size(), 2)


func test_rebuilds_when_its_actions_change() -> void:
	add_child(_prompt)
	_prompt.actions = [&"roll_left", &"roll_right"]
	assert_eq(
		Array(_prompt.icon_paths()),
		[ICON_SET.path("q", KEYBOARD), ICON_SET.path("e", KEYBOARD)],
	)
	assert_eq(_shown().size(), 3)


func test_fallback_icon_shows_when_the_device_has_no_binding() -> void:
	_prompt.actions = [&"look_up", &"look_down", &"look_left", &"look_right"]
	_prompt.keyboard_fallback = "mouse_xy"
	add_child(_prompt)
	assert_eq(
		Array(_prompt.icon_paths()),
		[ICON_SET.path("mouse_xy", KEYBOARD)],
	)
	_devices.device = CONTROLLER
	assert_eq(Array(_prompt.icon_paths()), [ICON_SET.path("r_2d", CONTROLLER)])


func test_empty_text_shows_only_icons() -> void:
	_prompt.text = ""
	add_child(_prompt)
	assert_eq(_shown(), [Vector2.ONE * _prompt.icon_size])


func test_missing_icon_shows_its_name() -> void:
	_prompt.actions = []
	_prompt.keyboard_fallback = "no_such_icon"
	add_child(_prompt)
	assert_eq(_shown(), ["NO_SUCH_ICON", "BOOST"])


func test_label_uses_its_theme_variation() -> void:
	_prompt.label_type = &"HoloGold"
	add_child(_prompt)
	var label: Label = _prompt.get_child(-1)
	assert_eq(label.theme_type_variation, &"HoloGold")


func test_it_ignores_the_mouse() -> void:
	add_child(_prompt)
	assert_eq(_prompt.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for child: Control in _prompt.get_children():
		assert_eq(child.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_devices_default_to_the_input_device_autoload() -> void:
	var prompt: InputPrompt = add_child_autofree(InputPrompt.new())
	assert_eq(prompt.devices, InputDevice)


func test_non_positive_icon_size_is_reported_and_ignored() -> void:
	var icon_size := _prompt.icon_size
	_prompt.icon_size = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: icon_size must be positive"
	)
	assert_eq(_prompt.icon_size, icon_size)


func test_the_holo_theme_has_the_hud_look() -> void:
	assert_not_null(THEME.default_font)
	assert_true(THEME.has_stylebox(&"panel", &"HoloPanel"))
	for variation: StringName in [&"HoloTitle", &"HoloText", &"HoloGold"]:
		assert_eq(THEME.get_type_variation_base(variation), &"Label")
