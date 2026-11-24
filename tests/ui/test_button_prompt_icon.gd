extends GutTest

const ICON_SET := preload("res://resources/ui/input_icon_set.tres")

var _was_enabled: bool
var _devices: DeviceTracker
var _button: Button
var _prompt_icon: ButtonPromptIcon


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_devices = add_child_autofree(DeviceTracker.new())
	_button = add_child_autofree(Button.new())
	_prompt_icon = ButtonPromptIcon.new()
	_prompt_icon.button = _button
	_prompt_icon.actions = [&"warp_out"]
	_prompt_icon.devices = _devices


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_the_button_shows_the_actions_icon() -> void:
	add_child_autofree(_prompt_icon)
	var path := ICON_SET.path("space", DeviceTracker.Device.KEYBOARD_MOUSE)
	assert_eq(_button.icon, InputIcons.texture(path))


func test_the_icon_follows_the_device() -> void:
	add_child_autofree(_prompt_icon)
	_devices.device = DeviceTracker.Device.CONTROLLER
	var path := ICON_SET.path("x_color", DeviceTracker.Device.CONTROLLER)
	assert_eq(_button.icon, InputIcons.texture(path))


func test_no_binding_clears_the_icon() -> void:
	_prompt_icon.actions = [&"look_up"]
	_button.icon = PlaceholderTexture2D.new()
	add_child_autofree(_prompt_icon)
	assert_null(_button.icon)


func test_missing_button_is_reported() -> void:
	_prompt_icon.button = null
	add_child_autofree(_prompt_icon)
	assert_push_error("[Contract] Pre-condition broken: button must be set")
