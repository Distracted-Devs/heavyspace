extends GutTest

var _devices: DeviceTracker
var _layer: CanvasLayer
var _view: ControlsView


func before_each() -> void:
	_devices = add_child_autofree(DeviceTracker.new())
	_layer = CanvasLayer.new()
	_layer.visible = false
	_view = ControlsView.new()
	_view.devices = _devices
	_layer.add_child(_view)
	add_child_autofree(_layer)


func test_a_hidden_view_waits_until_it_is_shown() -> void:
	assert_eq(_view.get_child_count(), 0)
	_layer.visible = true
	assert_true(_view.has_node("Key_%d" % KEY_W))


func test_a_device_change_while_hidden_rebuilds_on_showing() -> void:
	_layer.visible = true
	_layer.visible = false
	_devices.device = DeviceTracker.Device.CONTROLLER
	assert_true(
		_view.has_node("Key_%d" % KEY_W),
		"nothing rebuilt while hidden",
	)
	_layer.visible = true
	assert_false(_view.has_node("Key_%d" % KEY_W))
	assert_true(_view.has_node("Slot_rt"))


func test_showing_again_without_a_change_keeps_the_view() -> void:
	_layer.visible = true
	var picture := _view.get_node("Picture")
	_layer.visible = false
	_layer.visible = true
	assert_same(_view.get_node("Picture"), picture)
