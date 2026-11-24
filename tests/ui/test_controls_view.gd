extends GutTest

const CONTROLLER_LAYOUT := preload("res://resources/ui/controller_layout.tres")
const LABELS := preload("res://resources/ui/control_labels.tres")
const ICON_SET := preload("res://resources/ui/input_icon_set.tres")

var _devices: DeviceTracker
var _view: ControlsView


func before_each() -> void:
	_devices = add_child_autofree(DeviceTracker.new())
	_view = ControlsView.new()
	_view.devices = _devices
	add_child_autofree(_view)


func _texts(node: Node) -> Array:
	var texts := []
	for child in node.find_children("*", "Label", true, false):
		texts.append((child as Label).text)
	return texts


func _to_controller() -> void:
	_devices.device = DeviceTracker.Device.CONTROLLER


func test_keyboard_keys_are_lit_with_their_captions() -> void:
	assert_eq(_texts(_view.get_node("Key_%d" % KEY_W)), ["Pitch ↓"])
	assert_eq(_texts(_view.get_node("Key_%d" % KEY_SHIFT)), ["Boost"])
	assert_eq(_texts(_view.get_node("Key_%d" % KEY_SPACE)), ["Warp out"])
	assert_false(_view.has_node("Key_%d" % KEY_ESCAPE))


func test_a_key_sits_exactly_over_its_rectangle() -> void:
	var key: Control = _view.get_node("Key_%d" % KEY_W)
	var picture: Control = _view.get_node("Picture")
	var unit: Rect2 = _view.keyboard_layout.rect_of(KEY_W)
	var expected := Rect2(
		picture.position + unit.position * picture.size,
		unit.size * picture.size,
	)
	assert_almost_eq(key.position, expected.position, Vector2.ONE * 1e-3)
	assert_almost_eq(key.size, expected.size, Vector2.ONE * 1e-3)


func test_the_legend_lists_controls_off_the_keyboard() -> void:
	assert_eq(_texts(_view.get_node("Legend")), ["Pause", "Look"])


func test_switching_to_the_controller_labels_each_line() -> void:
	_to_controller()
	assert_false(_view.has_node("Key_%d" % KEY_W))
	assert_eq(_texts(_view.get_node("Slot_rt")), ["Boost"])
	assert_eq(_texts(_view.get_node("Slot_ls")), ["Pitch", "Yaw"])
	assert_eq(_texts(_view.get_node("Slot_rs")), ["Look"])
	assert_false(_view.has_node("Slot_lt"))


func test_slot_rows_sit_beside_the_picture_on_their_side() -> void:
	_to_controller()
	var picture: Control = _view.get_node("Picture")
	var left: Control = _view.get_node("Slot_ls")
	var right: Control = _view.get_node("Slot_rt")
	assert_lte(left.position.x + left.size.x, picture.position.x)
	assert_gte(right.position.x, picture.position.x + picture.size.x)
	var height := picture.size.y
	var ls_line := picture.position.y + 0.779 * height
	assert_almost_eq(left.position.y + left.size.y * 0.5, ls_line, 1.0)


func test_icons_share_one_size() -> void:
	_to_controller()
	for icon in _view.find_children("*", "TextureRect", true, false):
		if icon.name == "Picture":
			continue
		assert_eq(
			icon.custom_minimum_size,
			Vector2.ONE * _view.controller_icon_size,
		)


func test_the_controller_picture_leaves_out_unused_lines() -> void:
	var entries: Dictionary = CONTROLLER_LAYOUT.entries(LABELS, ICON_SET)
	var svg: String = _view.controller_svg(entries)
	assert_false(svg.contains('id="rect256"'), "the LT line is unused")
	assert_true(svg.contains('id="rect283"'), "the RT line is used")
	assert_false(svg.contains("fill:#000000"))


func test_both_devices_get_the_same_size() -> void:
	var keyboard_size := _view.custom_minimum_size
	_to_controller()
	assert_eq(_view.custom_minimum_size, keyboard_size)
	assert_gte(_view.custom_minimum_size.x, _view.view_size.x)
	assert_gte(_view.custom_minimum_size.y, _view.view_size.y)


func test_it_ignores_the_mouse() -> void:
	assert_eq(_view.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_devices_default_to_the_input_device_autoload() -> void:
	var view: ControlsView = add_child_autofree(ControlsView.new())
	assert_eq(view.devices, InputDevice)
