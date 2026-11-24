extends CanvasLayer

## Prototype pause menu: Resume / Restart / Quit, and the active device's
## layout picture with every bound control labelled with its icon. The device
## follows whatever was used last, even while paused.

const Icons := preload("res://prototypes/pre_juice_polish/input_icons.gd")
const CONTROLLER_ICONS := Icons.CONTROLLER
const KEYBOARD_ICONS := Icons.KEYBOARD
const CONTROLLER_LAYOUT := "res://resources/input_textures/controller_layout.svg"
const KEYBOARD_LAYOUT := "res://resources/input_textures/keyboard_layout.svg"

const CYAN := Color(0.3, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.3, 0.8)
const GOLD := Color(1.0, 0.88, 0.3)
const FONT_NAMES := ["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"]

## [action, label, short label for a key cap, label when on a stick axis]
const ACTIONS := [
	["back_thruster", "Boost", "Boost", "Boost"],
	["pitch_down", "Pitch down", "Pitch ↓", "Pitch"],
	["pitch_up", "Pitch up", "Pitch ↑", "Pitch"],
	["turn_left", "Yaw left", "Yaw ←", "Yaw"],
	["turn_right", "Yaw right", "Yaw →", "Yaw"],
	["roll_left", "Roll left", "Roll ←", "Roll"],
	["roll_right", "Roll right", "Roll →", "Roll"],
	["warp_out", "Warp out", "Warp out", "Warp out"],
	["restart", "Restart", "Restart", "Restart"],
	["pause", "Pause", "Pause", "Pause"],
	["look_left", "Look", "Look", "Look"],
	["look_right", "Look", "Look", "Look"],
	["look_up", "Look", "Look", "Look"],
	["look_down", "Look", "Look", "Look"],
]

## Where each leader line of the controller picture ends: [side, y / height].
## Side 0 is the left edge, 1 the right. Measured from the SVG.
const SLOTS := {
	"lt": [0, 0.0759],
	"lb": [0, 0.1838],
	"view": [0, 0.3136],
	"dpad_up": [0, 0.3775],
	"dpad_right": [0, 0.4461],
	"dpad_left": [0, 0.5133],
	"dpad_down": [0, 0.5792],
	"ls": [0, 0.7790],
	"rt": [1, 0.0759],
	"rb": [1, 0.1838],
	"menu": [1, 0.3136],
	"y": [1, 0.3775],
	"x": [1, 0.4461],
	"b": [1, 0.5133],
	"a": [1, 0.5792],
	"rs": [1, 0.7790],
}

## The SVG shapes that draw each slot's leader line (a line, and a hook if it
## bends to its button), so unbound slots can be drawn without one.
const SLOT_LINES := {
	"lt": ["rect256"],
	"lb": ["rect254", "rect255"],
	"view": ["rect285", "rect284"],
	"dpad_up": ["rect234"],
	"dpad_right": ["rect172"],
	"dpad_left": ["rect247", "rect248"],
	"dpad_down": ["rect235", "rect238"],
	"ls": ["rect253", "rect252"],
	"rt": ["rect283"],
	"rb": ["rect228", "rect229"],
	"menu": ["rect227", "rect226"],
	"y": ["rect220"],
	"x": ["rect221"],
	"b": ["rect224", "rect225"],
	"a": ["rect222", "rect223"],
	"rs": ["rect282", "rect268"],
}

## button index -> [slot, icon]
const BUTTONS := {
	JOY_BUTTON_A: ["a", "a_color"],
	JOY_BUTTON_B: ["b", "b_color"],
	JOY_BUTTON_X: ["x", "x_color"],
	JOY_BUTTON_Y: ["y", "y_color"],
	JOY_BUTTON_BACK: ["view", "view"],
	JOY_BUTTON_START: ["menu", "menu"],
	JOY_BUTTON_LEFT_STICK: ["ls", "left_stick_click"],
	JOY_BUTTON_RIGHT_STICK: ["rs", "right_stick_click"],
	JOY_BUTTON_LEFT_SHOULDER: ["lb", "lb"],
	JOY_BUTTON_RIGHT_SHOULDER: ["rb", "rb"],
	JOY_BUTTON_DPAD_UP: ["dpad_up", "dpad_up"],
	JOY_BUTTON_DPAD_DOWN: ["dpad_down", "dpad_down"],
	JOY_BUTTON_DPAD_LEFT: ["dpad_left", "dpad_left"],
	JOY_BUTTON_DPAD_RIGHT: ["dpad_right", "dpad_right"],
}

## axis -> [slot, icon for this axis alone]
const AXES := {
	JOY_AXIS_LEFT_X: ["ls", "l_x"],
	JOY_AXIS_LEFT_Y: ["ls", "l_y"],
	JOY_AXIS_RIGHT_X: ["rs", "r_x"],
	JOY_AXIS_RIGHT_Y: ["rs", "r_y"],
	JOY_AXIS_TRIGGER_LEFT: ["lt", "lt"],
	JOY_AXIS_TRIGGER_RIGHT: ["rt", "rt"],
}

const MOUSE_BUTTONS := Icons.MOUSE_ICONS

@export_group("Controller view")
@export_range(100.0, 1000.0, 1.0) var controller_width := 420.0
@export_range(50.0, 500.0, 1.0) var label_column := 220.0
## Every icon is shown at this square size (the pack's padding included, so
## buttons, triggers and sticks all keep the same scale).
@export_range(12.0, 96.0, 1.0) var controller_icon_size := 36.0
## Leave out the leader lines of controls that do nothing.
@export var hide_unused_lines := true

@export_group("Keyboard view")
@export_range(200.0, 1400.0, 1.0) var keyboard_width := 860.0
## Share of a key's height given to its icon; the caption gets the rest.
@export_range(0.2, 1.0, 0.01) var key_icon_share := 0.6
@export_range(6, 32, 1) var key_caption_size := 11
@export_range(12.0, 96.0, 1.0) var legend_icon_size := 36.0
@export var show_key_captions := true

@export_group("Look")
@export_range(8, 64, 1) var label_size := 16
@export_range(0.0, 1.0, 0.01) var backdrop_alpha := 0.55
## Both devices' views get at least this size, so the panel doesn't jump
## when the device switches.
@export var view_min_size := Vector2(860.0, 356.0)
## Rasterise the SVG pictures at this many pixels per displayed pixel.
@export_range(1.0, 4.0, 0.1) var svg_oversample := 2.0

var pause_controller: Node
var tracker: Node

var _device := -1
var _textures := { }
var _font := SystemFont.new()
var _header: Label
var _view: Control
var _resume: Button


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	layer = 20
	visible = false
	_font.font_names = PackedStringArray(FONT_NAMES)
	_build()


func setup(controller: Node, device_tracker: Node) -> void:
	pause_controller = controller
	tracker = device_tracker
	pause_controller.paused_changed.connect(_on_paused_changed)
	tracker.device_changed.connect(_show_device)
	_show_device(tracker.device)


func _on_paused_changed(paused: bool) -> void:
	visible = paused
	if paused:
		_resume.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var button := event as InputEventJoypadButton
	if button and button.pressed and button.button_index == JOY_BUTTON_B:
		_on_resume()
		get_viewport().set_input_as_handled()


# --- Menu ---------------------------------------------------------------


func _build() -> void:
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = label_size

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, backdrop_alpha)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.theme = theme
	add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	centre.add_child(column)

	var title := Label.new()
	title.text = "// PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", MAGENTA)
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_box())
	column.add_child(panel)

	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 12)
	panel.add_child(inside)

	_header = Label.new()
	_header.add_theme_color_override("font_color", CYAN)
	_header.add_theme_font_size_override("font_size", 18)
	inside.add_child(_header)

	var view_centre := CenterContainer.new()
	inside.add_child(view_centre)
	_view = Control.new()
	view_centre.add_child(_view)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_resume = _button("RESUME", _on_resume)
	buttons.add_child(_resume)
	buttons.add_child(_button("RESTART", _on_restart))
	buttons.add_child(_button("QUIT", _on_quit))


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150.0, 40.0)
	button.add_theme_color_override("font_color", CYAN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _box(CYAN, 0.0, 0.6))
	button.add_theme_stylebox_override("hover", _box(MAGENTA, 0.2, 1.0))
	button.add_theme_stylebox_override("focus", _box(MAGENTA, 0.2, 1.0))
	button.add_theme_stylebox_override("pressed", _box(MAGENTA, 0.35, 1.0))
	button.pressed.connect(action)
	return button


func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.04, 0.07, 0.85)
	box.border_color = Color(CYAN, 0.6)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(20.0)
	return box


func _box(colour: Color, fill: float, border: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(colour, fill) if fill > 0.0 else Color(0, 0.04, 0.07, 0.9)
	box.border_color = Color(colour, border)
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	return box


func _on_resume() -> void:
	pause_controller.set_paused(false)


func _on_restart() -> void:
	pause_controller.set_paused(false)
	get_tree().reload_current_scene()


func _on_quit() -> void:
	get_tree().quit()


# --- Controls view --------------------------------------------------------


func _show_device(device: int) -> void:
	if device == _device:
		return
	_device = device
	for child in _view.get_children():
		_view.remove_child(child)
		child.queue_free()
	if device == PlayerInputComponent.Device.CONTROLLER:
		_header.text = "// CONTROLS : CONTROLLER"
		_build_controller()
	else:
		_header.text = "// CONTROLS : KEYBOARD & MOUSE"
		_build_keyboard()
	# Centre the content in the shared size.
	var content := _view.custom_minimum_size
	var room := view_min_size.max(content)
	for child: Control in _view.get_children():
		child.position += ((room - content) * 0.5).floor()
	_view.custom_minimum_size = room


func _build_controller() -> void:
	var slots := _controller_entries()
	var unused: Array[String] = []
	if hide_unused_lines:
		for slot: String in SLOT_LINES:
			if not slots.has(slot):
				unused.append_array(SLOT_LINES[slot])
	var picture := _svg(CONTROLLER_LAYOUT, controller_width, {
		# The leader lines are black; make them read on the dark panel.
		"fill:#000000": "fill:#4ce6ff",
	}, unused)
	var height := controller_width * picture.get_height() / picture.get_width()
	_view.custom_minimum_size = Vector2(
		label_column * 2.0 + controller_width,
		height,
	)
	_add_picture(picture, Vector2(label_column, 0.0), controller_width, height)

	var gap := 4.0
	var row_height := controller_icon_size
	for slot: String in slots:
		var right: bool = SLOTS[slot][0] == 1
		var y: float = SLOTS[slot][1] * height
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = (
			BoxContainer.ALIGNMENT_BEGIN if right else BoxContainer.ALIGNMENT_END
		)
		row.position = Vector2(
			label_column + controller_width + gap if right else 0.0,
			y - row_height * 0.5,
		)
		row.size = Vector2(label_column - gap, row_height)
		var first := true
		for entry: Array in slots[slot]:
			if not first:
				row.add_child(_spacer(6.0))
			first = false
			row.add_child(_icon_rect(CONTROLLER_ICONS % entry[0], controller_icon_size))
			row.add_child(_label(entry[1], label_size, GOLD))
		_view.add_child(row)


## slot -> [[icon, label], ...], in ACTIONS order.
func _controller_entries() -> Dictionary:
	var slots := { }
	# Stick axes are grouped by label first: pitch up + down on one axis is
	# one "Pitch" entry, and look on both axes is one 2D "Look" entry.
	var sticks := { }
	for row: Array in ACTIONS:
		if not InputMap.has_action(row[0]):
			continue
		for event in InputMap.action_get_events(row[0]):
			if event is InputEventJoypadButton and BUTTONS.has(event.button_index):
				var button: Array = BUTTONS[event.button_index]
				_add_entry(slots, button[0], button[1], row[1])
			elif event is InputEventJoypadMotion and AXES.has(event.axis):
				var axis: Array = AXES[event.axis]
				if axis[0] == "lt" or axis[0] == "rt":
					_add_entry(slots, axis[0], axis[1], row[1])
					continue
				var groups: Dictionary = sticks.get_or_add(axis[0], { })
				var axes: Array = groups.get_or_add(row[3], [])
				if not axes.has(event.axis):
					axes.append(event.axis)
	for slot: String in sticks:
		for label: String in sticks[slot]:
			var axes: Array = sticks[slot][label]
			var icon: String = (
				slot.left(1) + "_2d" if axes.size() > 1 else AXES[axes[0]][1]
			)
			_add_entry(slots, slot, icon, label)
	return slots


func _add_entry(slots: Dictionary, slot: String, icon: String, label: String) -> void:
	var entries: Array = slots.get_or_add(slot, [])
	for entry: Array in entries:
		if entry[1] == label:
			return
	entries.append([icon, label])


func _build_keyboard() -> void:
	var picture := _svg(KEYBOARD_LAYOUT, keyboard_width, {
		"stroke:#22262c": "stroke:#4ce6ff",
	})
	var height := keyboard_width * picture.get_height() / picture.get_width()
	var picture_size := Vector2(keyboard_width, height)
	var legend_height := legend_icon_size + 16.0
	_view.custom_minimum_size = Vector2(keyboard_width, height + legend_height)
	_add_picture(picture, Vector2.ZERO, keyboard_width, height)

	var rects := _key_rects()
	# code -> [short labels], and keys or buttons not on the picture.
	var keys := { }
	var legend: Array = []
	for row: Array in ACTIONS:
		if not InputMap.has_action(row[0]):
			continue
		for event in InputMap.action_get_events(row[0]):
			if event is InputEventKey:
				var code: int = (
					event.physical_keycode
					if event.physical_keycode != KEY_NONE
					else event.keycode
				)
				if rects.has(code):
					var labels: Array = keys.get_or_add(code, [])
					if not labels.has(row[2]):
						labels.append(row[2])
				else:
					legend.append([KEYBOARD_ICONS % _key_icon(code), row[1]])
			elif event is InputEventMouseButton and MOUSE_BUTTONS.has(event.button_index):
				legend.append(
					[KEYBOARD_ICONS % MOUSE_BUTTONS[event.button_index], row[1]]
				)
	# Mouse look isn't an action: PlayerInputComponent reads mouse motion.
	legend.append([KEYBOARD_ICONS % "mouse_xy", "Look"])

	for code: int in keys:
		var unit: Rect2 = rects[code]
		var rect := Rect2(unit.position * picture_size, unit.size * picture_size)
		_add_key(rect, KEYBOARD_ICONS % _key_icon(code), " / ".join(keys[code]))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0.0, height + 12.0)
	row.size = Vector2(keyboard_width, legend_icon_size)
	var first := true
	for entry: Array in legend:
		if not first:
			row.add_child(_spacer(18.0))
		first = false
		row.add_child(_icon_rect(entry[0], legend_icon_size))
		row.add_child(_label(entry[1], label_size, GOLD))
	_view.add_child(row)


func _add_key(rect: Rect2, icon_path: String, caption: String) -> void:
	var glow := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(CYAN, 0.18)
	box.border_color = MAGENTA
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	glow.add_theme_stylebox_override("panel", box)
	glow.position = rect.position
	glow.size = rect.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(glow)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.position = rect.position
	stack.size = rect.size
	_view.add_child(stack)
	var share := key_icon_share if show_key_captions else 0.85
	# Cropped, so a wide key's cap fills its wide key.
	var icon := _icon_rect(icon_path, rect.size.y * share, true)
	icon.custom_minimum_size.x = rect.size.x - 6.0
	stack.add_child(icon)
	if show_key_captions:
		var label := _label(caption, key_caption_size, GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.custom_minimum_size.x = rect.size.x
		stack.add_child(label)


## The keys on the keyboard picture, as fractions of its size. Measured from
## the SVG: number row, QWERTY row, home row, shift row, space row. The right
## shift, alt and ctrl are left out, so a binding lights up the left one.
func _key_rects() -> Dictionary:
	var rects := { }
	_add_row(rects, 0.0054, [
		[KEY_QUOTELEFT, 0.0019], [KEY_1, 0.0712], [KEY_2, 0.1405],
		[KEY_3, 0.2098], [KEY_4, 0.2791], [KEY_5, 0.3484], [KEY_6, 0.4178],
		[KEY_7, 0.4871], [KEY_8, 0.5564], [KEY_9, 0.6257], [KEY_0, 0.6950],
		[KEY_MINUS, 0.7643], [KEY_EQUAL, 0.8336], [KEY_BACKSPACE, 0.9029, 0.0952],
	])
	_add_row(rects, 0.2104, [
		[KEY_TAB, 0.0019, 0.0988], [KEY_Q, 0.1091], [KEY_W, 0.1781],
		[KEY_E, 0.2472], [KEY_R, 0.3162], [KEY_T, 0.3852], [KEY_Y, 0.4543],
		[KEY_U, 0.5233], [KEY_I, 0.5923], [KEY_O, 0.6614], [KEY_P, 0.7304],
		[KEY_BRACKETLEFT, 0.7994], [KEY_BRACKETRIGHT, 0.8685],
		[KEY_BACKSLASH, 0.9375],
	])
	_add_row(rects, 0.4154, [
		[KEY_CAPSLOCK, 0.0019, 0.1068], [KEY_A, 0.1177], [KEY_S, 0.1874],
		[KEY_D, 0.2570], [KEY_F, 0.3267], [KEY_G, 0.3964], [KEY_H, 0.4660],
		[KEY_J, 0.5357], [KEY_K, 0.6053], [KEY_L, 0.6750],
		[KEY_SEMICOLON, 0.7446], [KEY_APOSTROPHE, 0.8143],
		[KEY_ENTER, 0.8839, 0.1142],
	])
	_add_row(rects, 0.6204, [
		[KEY_SHIFT, 0.0019, 0.1423], [KEY_Z, 0.1534], [KEY_X, 0.2233],
		[KEY_C, 0.2931], [KEY_V, 0.3629], [KEY_B, 0.4328], [KEY_N, 0.5026],
		[KEY_M, 0.5724], [KEY_COMMA, 0.6423], [KEY_PERIOD, 0.7121],
		[KEY_SLASH, 0.7819],
	])
	_add_row(rects, 0.8254, [
		[KEY_CTRL, 0.0019, 0.1037], [KEY_ALT, 0.2198, 0.1037],
		[KEY_SPACE, 0.3341, 0.3318],
	])
	return rects


func _add_row(rects: Dictionary, y: float, keys: Array) -> void:
	for key: Array in keys:
		var width: float = key[2] if key.size() > 2 else 0.0606
		rects[key[0]] = Rect2(key[1], y, width, 0.1724)


func _key_icon(code: int) -> String:
	return Icons.key_icon(code)


# --- Building blocks ------------------------------------------------------


func _add_picture(texture: Texture2D, at: Vector2, width: float, height: float) -> void:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.position = at
	rect.size = Vector2(width, height)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(rect)


func _icon_rect(path: String, size: float, crop := false) -> Control:
	var texture := Icons.texture(path, crop)
	if texture == null:
		# No icon for this key: fall back to its name.
		return _label(path.get_file().get_basename().to_upper(), label_size, CYAN)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var aspect := float(texture.get_width()) / texture.get_height()
	rect.custom_minimum_size = Vector2(size * aspect, size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _spacer(width: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(width, 0.0)
	return spacer


## The layout pictures are loaded straight from the SVG at the size shown, so
## they stay sharp, with colours swapped to read on the dark panel and the
## shapes with the `remove` ids left out.
func _svg(
	path: String,
	width: float,
	recolour: Dictionary,
	remove: Array[String] = [],
) -> Texture2D:
	var key := "%s@%d-%s" % [path, int(width * svg_oversample), ",".join(remove)]
	if _textures.has(key):
		return _textures[key]
	var text := FileAccess.get_file_as_string(path)
	for from: String in recolour:
		text = text.replace(from, recolour[from])
	for id in remove:
		var shape := RegEx.create_from_string('<rect\\b[^>]*\\bid="%s"[^>]*/>' % id)
		text = shape.sub(text, "")
	var probe := Image.new()
	probe.load_svg_from_string(text, 1.0)
	var image := Image.new()
	image.load_svg_from_string(text, width * svg_oversample / probe.get_width())
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture
