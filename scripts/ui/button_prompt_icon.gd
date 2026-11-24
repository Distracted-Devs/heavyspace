class_name ButtonPromptIcon
extends Node

@export var button: Button
@export var actions: Array[StringName] = []
@export var icon_set: InputIconSet = preload(
	"res://resources/ui/input_icon_set.tres"
)

var devices: DeviceTracker


func _enter_tree() -> void:
	if devices == null:
		devices = InputDevice
	if not devices.device_changed.is_connected(_on_device_changed):
		devices.device_changed.connect(_on_device_changed)


func _exit_tree() -> void:
	if (
		is_instance_valid(devices)
		and devices.device_changed.is_connected(_on_device_changed)
	):
		devices.device_changed.disconnect(_on_device_changed)


func _ready() -> void:
	if not Contract.require(button != null, "button must be set"):
		return
	refresh()


func refresh() -> void:
	var paths := InputIcons.paths(actions, devices.device, icon_set)
	button.icon = null if paths.is_empty() else InputIcons.texture(paths[0])


func _on_device_changed(_device: DeviceTracker.Device) -> void:
	if button != null:
		refresh()
