extends GutTest

const OVERLAY_SCENE := preload("res://scenes/ui/debug_overlay.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _overlay: DebugOverlay
var _player: Player


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector3(1.0, 2.0, 3.0)
	add_child_autofree(_player)
	_overlay = OVERLAY_SCENE.instantiate()
	_overlay.player = _player
	add_child_autofree(_overlay)


func test_label_follows_the_player_each_frame() -> void:
	await wait_process_frames(1)
	var before := _overlay.label.text
	_player.mass_component.current_mass = 7.0
	await wait_process_frames(1)
	assert_ne(_overlay.label.text, before)
	assert_eq(_overlay.label.text, _overlay.describe(_player))


func test_the_description_follows_the_active_input_device() -> void:
	var devices: DeviceTracker = autofree(DeviceTracker.new())
	_overlay.devices = devices
	var keyboard := _overlay.describe(_player)
	devices.device = DeviceTracker.Device.CONTROLLER
	assert_ne(_overlay.describe(_player), keyboard)


func test_devices_default_to_the_input_device_autoload() -> void:
	assert_eq(_overlay.devices, InputDevice)
