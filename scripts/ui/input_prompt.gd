class_name InputPrompt
extends HBoxContainer

const DEFAULT_ICON_SET := preload("res://resources/ui/input_icon_set.tres")

@export var actions: Array[StringName] = []:
	set(value):
		actions = value
		_rebuild_if_ready()
@export var text := "":
	set(value):
		text = value
		_rebuild_if_ready()
@export_range(1.0, 256.0, 1.0, "or_greater") var icon_size := 32.0:
	set(value):
		if not Contract.require(value > 0.0, "icon_size must be positive"):
			return
		icon_size = value
		_rebuild_if_ready()
@export var icon_set: InputIconSet = DEFAULT_ICON_SET:
	set(value):
		if not Contract.require(value != null, "icon_set must be set"):
			return
		icon_set = value
		_rebuild_if_ready()
@export var keyboard_fallback := "":
	set(value):
		keyboard_fallback = value
		_rebuild_if_ready()
@export var controller_fallback := "":
	set(value):
		controller_fallback = value
		_rebuild_if_ready()
@export var label_type := &"":
	set(value):
		label_type = value
		_rebuild_if_ready()

var devices: DeviceTracker

var _paths := PackedStringArray()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	rebuild()


func icon_paths() -> PackedStringArray:
	return _paths


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	var device := devices.device
	_paths = InputIcons.paths(actions, device, icon_set)
	var fallback := (
		controller_fallback
		if device == DeviceTracker.Device.CONTROLLER
		else keyboard_fallback
	)
	if _paths.is_empty() and fallback != "":
		_paths.append(icon_set.path(fallback, device))
	for path in _paths:
		add_child(_icon(path))
	if text != "":
		add_child(_label(text))


func _rebuild_if_ready() -> void:
	if is_node_ready():
		rebuild()


func _on_device_changed(_device: DeviceTracker.Device) -> void:
	rebuild()


func _icon(path: String) -> Control:
	var texture := InputIcons.texture(path)
	if texture == null:
		return _label(path.get_file().get_basename().to_upper())
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.custom_minimum_size = Vector2.ONE * icon_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _label(shown: String) -> Label:
	var label := Label.new()
	label.text = shown
	label.theme_type_variation = label_type
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
