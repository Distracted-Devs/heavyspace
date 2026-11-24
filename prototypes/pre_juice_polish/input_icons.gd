extends RefCounted

## Prototype input icons: which icon shows a binding on each device, read
## from the input map, with the textures cropped and mipmapped.

const CONTROLLER := "res://resources/input_icons/xbox/default/%s.png"
const KEYBOARD := "res://resources/input_icons/keyboard_mouse/dark/%s.png"

const BUTTON_ICONS := {
	JOY_BUTTON_A: "a_color",
	JOY_BUTTON_B: "b_color",
	JOY_BUTTON_X: "x_color",
	JOY_BUTTON_Y: "y_color",
	JOY_BUTTON_BACK: "view",
	JOY_BUTTON_START: "menu",
	JOY_BUTTON_LEFT_STICK: "left_stick_click",
	JOY_BUTTON_RIGHT_STICK: "right_stick_click",
	JOY_BUTTON_LEFT_SHOULDER: "lb",
	JOY_BUTTON_RIGHT_SHOULDER: "rb",
	JOY_BUTTON_DPAD_UP: "dpad_up",
	JOY_BUTTON_DPAD_DOWN: "dpad_down",
	JOY_BUTTON_DPAD_LEFT: "dpad_left",
	JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}

const MOUSE_ICONS := {
	MOUSE_BUTTON_LEFT: "mouse_left",
	MOUSE_BUTTON_RIGHT: "mouse_right",
	MOUSE_BUTTON_MIDDLE: "mouse_middle",
	MOUSE_BUTTON_WHEEL_UP: "mouse_scroll_up",
	MOUSE_BUTTON_WHEEL_DOWN: "mouse_scroll_down",
}

## When every icon in a set is in a prompt, they become one icon ("" drops
## them, e.g. the arrow keys when WASD does the same job).
const MERGES := [
	[["dpad_up", "dpad_down", "dpad_left", "dpad_right"], "dpad"],
	[["l_up", "l_down", "l_left", "l_right"], "l_2d"],
	[["l_up", "l_down"], "l_y"],
	[["l_left", "l_right"], "l_x"],
	[["r_up", "r_down", "r_left", "r_right"], "r_2d"],
	[["r_up", "r_down"], "r_y"],
	[["r_left", "r_right"], "r_x"],
	[["mouse_scroll_up", "mouse_scroll_down"], "mouse_scroll"],
	[["up", "down", "left", "right"], ""],
]

static var _textures := { }


static func is_controller(device: int) -> bool:
	return device == PlayerInputComponent.Device.CONTROLLER


## The icon paths for a prompt covering these actions, in action order.
static func prompt(actions: Array, device: int) -> Array[String]:
	var names: Array[String] = []
	for action: StringName in actions:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			var icon := event_icon(event, device)
			if icon != "" and not names.has(icon):
				names.append(icon)
	names = _merge(names)
	var base := CONTROLLER if is_controller(device) else KEYBOARD
	var paths: Array[String] = []
	for icon in names:
		paths.append(base % icon)
	return paths


## The icon name (not path) for one event on this device, or "".
static func event_icon(event: InputEvent, device: int) -> String:
	if is_controller(device):
		var button := event as InputEventJoypadButton
		if button:
			return BUTTON_ICONS.get(button.button_index, "")
		var motion := event as InputEventJoypadMotion
		if motion:
			return axis_icon(motion.axis, motion.axis_value)
		return ""
	var key := event as InputEventKey
	if key:
		var code := (
			key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		)
		return key_icon(code)
	var mouse := event as InputEventMouseButton
	if mouse:
		return MOUSE_ICONS.get(mouse.button_index, "")
	return ""


static func axis_icon(axis: int, value: float) -> String:
	var negative := value < 0.0
	match axis:
		JOY_AXIS_LEFT_X:
			return "l_left" if negative else "l_right"
		JOY_AXIS_LEFT_Y:
			return "l_up" if negative else "l_down"
		JOY_AXIS_RIGHT_X:
			return "r_left" if negative else "r_right"
		JOY_AXIS_RIGHT_Y:
			return "r_up" if negative else "r_down"
		JOY_AXIS_TRIGGER_LEFT:
			return "lt"
		JOY_AXIS_TRIGGER_RIGHT:
			return "rt"
	return ""


static func key_icon(code: int) -> String:
	if code >= KEY_A and code <= KEY_Z:
		return String.chr(code).to_lower()
	if code >= KEY_0 and code <= KEY_9:
		return String.chr(code)
	if code >= KEY_F1 and code <= KEY_F12:
		return "f%d" % (code - KEY_F1 + 1)
	match code:
		KEY_SHIFT:
			return "shift"
		KEY_SPACE:
			return "space"
		KEY_ESCAPE:
			return "esc"
		KEY_CTRL:
			return "ctrl"
		KEY_ALT:
			return "alt"
		KEY_TAB:
			return "tab"
		KEY_ENTER:
			return "enter"
		KEY_BACKSPACE:
			return "backspace"
		KEY_CAPSLOCK:
			return "capslock"
		KEY_UP:
			return "up"
		KEY_DOWN:
			return "down"
		KEY_LEFT:
			return "left"
		KEY_RIGHT:
			return "right"
		KEY_COMMA:
			return "comma"
		KEY_PERIOD:
			return "period"
		KEY_SLASH:
			return "slash"
		KEY_SEMICOLON:
			return "semicolon"
		KEY_APOSTROPHE:
			return "quotation"
		KEY_BRACKETLEFT:
			return "brackets_l"
		KEY_BRACKETRIGHT:
			return "brackets_r"
		KEY_QUOTELEFT:
			return "tilde"
		KEY_MINUS:
			return "minus"
		KEY_EQUAL:
			return "plus"
	return OS.get_keycode_string(code as Key).to_snake_case()


## The icon with mipmaps, so it shrinks well. The pack draws every icon to
## one scale on a 128 px canvas, so shown whole they all match. `crop` cuts
## it to its visible pixels instead, for a key cap that must fill its key
## (wide keys like Shift sit small in the square canvas).
static func texture(path: String, crop := false) -> Texture2D:
	var key := path + (" cropped" if crop else "")
	if _textures.has(key):
		return _textures[key]
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		var image := (load(path) as Texture2D).get_image()
		image.decompress()
		if crop:
			image = image.get_region(image.get_used_rect())
		image.generate_mipmaps()
		result = ImageTexture.create_from_image(image)
	_textures[key] = result
	return result


## A control showing the icon at this height, or its name if it's missing.
static func icon_rect(path: String, height: float, crop := false) -> Control:
	var icon := texture(path, crop)
	if icon == null:
		var label := Label.new()
		label.text = path.get_file().get_basename().to_upper()
		return label
	var rect := TextureRect.new()
	rect.texture = icon
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var aspect := float(icon.get_width()) / icon.get_height()
	rect.custom_minimum_size = Vector2(height * aspect, height)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _merge(names: Array[String]) -> Array[String]:
	for merge: Array in MERGES:
		var members: Array = merge[0]
		if not members.all(func(member: String) -> bool: return names.has(member)):
			continue
		var replacement: String = merge[1]
		if replacement == "" and names.size() == members.size():
			continue  # Nothing else does the job, so keep them.
		var at := names.find(members[0])
		for member: String in members:
			at = mini(at, names.find(member))
		var merged: Array[String] = []
		for index in names.size():
			if index == at and replacement != "":
				merged.append(replacement)
			if not members.has(names[index]):
				merged.append(names[index])
		names = merged
	return names
