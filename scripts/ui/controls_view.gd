class_name ControlsView
extends Control

const ROW_GAP := 4.0
const ENTRY_GAP := 6.0
const LEGEND_GAP := 12.0

@export_group("Data")
@export var controller_layout: ControllerLayout = preload(
	"res://resources/ui/controller_layout.tres"
)
@export var keyboard_layout: KeyboardLayout = preload(
	"res://resources/ui/keyboard_layout.tres"
)
@export var labels: ControlLabels = preload(
	"res://resources/ui/control_labels.tres"
)
@export var icon_set: InputIconSet = preload(
	"res://resources/ui/input_icon_set.tres"
)

@export_group("Controller")
@export_range(100.0, 1200.0, 1.0) var controller_width := 420.0
@export_range(50.0, 600.0, 1.0) var label_column := 220.0
@export_range(8.0, 128.0, 1.0) var controller_icon_size := 36.0

@export_group("Keyboard")
@export_range(200.0, 1600.0, 1.0) var keyboard_width := 860.0
@export_range(0.2, 1.0, 0.01) var key_icon_share := 0.6
@export_range(6, 32, 1) var key_caption_size := 11
@export_range(8.0, 128.0, 1.0) var legend_icon_size := 36.0
@export var key_glow := Color(0.3, 0.9, 1.0, 0.18)
@export var key_border := Color(1.0, 0.3, 0.8)

@export_group("Look")
@export var view_size := Vector2(860.0, 356.0)
@export_range(1.0, 4.0, 0.1) var svg_oversample := 2.0

var devices: DeviceTracker

var _stale := true

static var _pictures: Dictionary[String, Texture2D] = { }


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
	if is_visible_in_tree():
		rebuild()


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_VISIBILITY_CHANGED and _stale
		and is_node_ready() and is_visible_in_tree()
	):
		rebuild()


func rebuild() -> void:
	_stale = false
	for child in get_children():
		remove_child(child)
		child.free()
	var content := (
		_build_controller() if devices.is_controller() else _build_keyboard()
	)
	var room := view_size.max(content)
	var shift := ((room - content) * 0.5).floor()
	for child: Control in get_children():
		child.position += shift
	custom_minimum_size = room


func controller_svg(entries: Dictionary) -> String:
	var text := FileAccess.get_file_as_string(controller_layout.picture)
	text = text.replace(
		controller_layout.line_colour,
		controller_layout.shown_line_colour,
	)
	for id in controller_layout.unused_lines(entries.keys()):
		var shape := RegEx.create_from_string(
			'<rect\\b[^>]*\\bid="%s"[^>]*/>' % id
		)
		text = shape.sub(text, "")
	return text


func keyboard_svg() -> String:
	return FileAccess.get_file_as_string(keyboard_layout.picture).replace(
		keyboard_layout.outline_colour,
		keyboard_layout.shown_outline_colour,
	)


func _on_device_changed(_device: DeviceTracker.Device) -> void:
	if is_visible_in_tree():
		rebuild()
	else:
		_stale = true


func _build_controller() -> Vector2:
	var entries := controller_layout.entries(labels, icon_set)
	var picture := _picture(controller_svg(entries), controller_width)
	var height := controller_width * picture.get_height() / picture.get_width()
	_add_picture(
		picture,
		Vector2(label_column, 0.0),
		Vector2(controller_width, height),
	)
	var device := DeviceTracker.Device.CONTROLLER
	for slot in controller_layout.slot_names.size():
		var slot_name := controller_layout.slot_names[slot]
		if not entries.has(slot_name):
			continue
		var on_right := controller_layout.slot_on_right[slot]
		var row := _row("Slot_" + slot_name)
		row.alignment = BoxContainer.ALIGNMENT_END
		if on_right:
			row.alignment = BoxContainer.ALIGNMENT_BEGIN
		for entry: Array in entries[slot_name]:
			var path := icon_set.path(entry[0], device)
			row.add_child(
				_icon(path, Vector2.ONE * controller_icon_size, false)
			)
			row.add_child(_label(entry[1]))
		add_child(row)
		row.size = Vector2(label_column - ROW_GAP, controller_icon_size)
		row.position = Vector2(
			label_column + controller_width + ROW_GAP if on_right else 0.0,
			controller_layout.slot_heights[slot] * height
			- controller_icon_size * 0.5,
		)
	return Vector2(label_column * 2.0 + controller_width, height)


func _build_keyboard() -> Vector2:
	var picture := _picture(keyboard_svg(), keyboard_width)
	var drawn := Vector2(
		keyboard_width,
		keyboard_width * picture.get_height() / picture.get_width(),
	)
	_add_picture(picture, Vector2.ZERO, drawn)
	var captions := keyboard_layout.captions(labels)
	for code: int in captions:
		var unit := keyboard_layout.rect_of(code)
		_add_key(
			code,
			Rect2(unit.position * drawn, unit.size * drawn),
			" / ".join(captions[code]),
		)
	var legend := _row("Legend")
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", int(LEGEND_GAP))
	var device := DeviceTracker.Device.KEYBOARD_MOUSE
	for extra: Array in keyboard_layout.extras(labels, icon_set):
		var path := icon_set.path(extra[0], device)
		legend.add_child(_icon(path, Vector2.ONE * legend_icon_size, false))
		legend.add_child(_label(extra[1]))
	add_child(legend)
	legend.size = Vector2(keyboard_width, legend_icon_size)
	legend.position = Vector2(0.0, drawn.y + LEGEND_GAP)
	return Vector2(keyboard_width, drawn.y + LEGEND_GAP + legend_icon_size)


func _add_key(code: int, rect: Rect2, caption: String) -> void:
	var key := Panel.new()
	key.name = "Key_%d" % code
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lit := StyleBoxFlat.new()
	lit.bg_color = key_glow
	lit.border_color = key_border
	lit.set_border_width_all(2)
	lit.set_corner_radius_all(5)
	key.add_theme_stylebox_override("panel", lit)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	key.add_child(stack)
	var path := icon_set.path(
		InputIcons.key_name(code),
		DeviceTracker.Device.KEYBOARD_MOUSE,
	)
	var cap := Vector2(rect.size.x - 6.0, rect.size.y * key_icon_share)
	stack.add_child(_icon(path, cap, true))
	var label := _label(caption)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", key_caption_size)
	stack.add_child(label)
	add_child(key)
	key.position = rect.position
	key.size = rect.size


func _add_picture(texture: Texture2D, at: Vector2, shown: Vector2) -> void:
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	picture.position = at
	picture.size = shown


func _picture(svg: String, width: float) -> Texture2D:
	var key := "%d@%d" % [svg.hash(), int(width * svg_oversample)]
	if _pictures.has(key):
		return _pictures[key]
	var probe := Image.new()
	probe.load_svg_from_string(svg, 1.0)
	var image := Image.new()
	image.load_svg_from_string(svg, width * svg_oversample / probe.get_width())
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_pictures[key] = texture
	return texture


func _row(row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(ENTRY_GAP))
	return row


func _icon(path: String, shown: Vector2, crop: bool) -> Control:
	var texture := InputIcons.texture(path, crop)
	if texture == null:
		return _label(path.get_file().get_basename().to_upper())
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.custom_minimum_size = shown
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"HoloGold"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
