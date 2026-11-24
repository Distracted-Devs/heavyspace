class_name InputIcons

const ARROWS: PackedStringArray = ["up", "down", "left", "right"]
const DPAD: PackedStringArray = [
	"dpad_up",
	"dpad_down",
	"dpad_left",
	"dpad_right",
]
const WHEEL: PackedStringArray = ["mouse_scroll_up", "mouse_scroll_down"]
const MOUSE_BUTTONS: Dictionary[int, String] = {
	MOUSE_BUTTON_LEFT: "mouse_left",
	MOUSE_BUTTON_RIGHT: "mouse_right",
	MOUSE_BUTTON_MIDDLE: "mouse_middle",
	MOUSE_BUTTON_WHEEL_UP: "mouse_scroll_up",
	MOUSE_BUTTON_WHEEL_DOWN: "mouse_scroll_down",
}
const KEYS: Dictionary[int, String] = {
	KEY_SHIFT: "shift",
	KEY_SPACE: "space",
	KEY_ESCAPE: "esc",
	KEY_CTRL: "ctrl",
	KEY_ALT: "alt",
	KEY_TAB: "tab",
	KEY_ENTER: "enter",
	KEY_BACKSPACE: "backspace",
	KEY_CAPSLOCK: "capslock",
	KEY_UP: "up",
	KEY_DOWN: "down",
	KEY_LEFT: "left",
	KEY_RIGHT: "right",
	KEY_COMMA: "comma",
	KEY_PERIOD: "period",
	KEY_SLASH: "slash",
	KEY_SEMICOLON: "semicolon",
	KEY_APOSTROPHE: "quotation",
	KEY_BRACKETLEFT: "brackets_l",
	KEY_BRACKETRIGHT: "brackets_r",
	KEY_QUOTELEFT: "tilde",
	KEY_MINUS: "minus",
	KEY_EQUAL: "plus",
}

static var _textures: Dictionary[String, Texture2D] = { }


static func names(
	actions: Array[StringName],
	device: DeviceTracker.Device,
	icon_set: InputIconSet,
) -> PackedStringArray:
	var found := PackedStringArray()
	for action in actions:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			var icon := event_name(event, device, icon_set)
			if icon != "" and not found.has(icon):
				found.append(icon)
	return merge(found, icon_set)


static func merge(
	found: PackedStringArray,
	icon_set: InputIconSet,
) -> PackedStringArray:
	for merging in _merges(icon_set):
		found = _merged(found, merging[0], merging[1])
	return _without_spare_arrows(found)


static func paths(
	actions: Array[StringName],
	device: DeviceTracker.Device,
	icon_set: InputIconSet,
) -> PackedStringArray:
	var found := PackedStringArray()
	for icon in names(actions, device, icon_set):
		found.append(icon_set.path(icon, device))
	return found


static func event_name(
	event: InputEvent,
	device: DeviceTracker.Device,
	icon_set: InputIconSet,
) -> String:
	if device == DeviceTracker.Device.CONTROLLER:
		var button := event as InputEventJoypadButton
		if button:
			return icon_set.buttons.get(button.button_index, "")
		var motion := event as InputEventJoypadMotion
		if motion:
			return _axis_name(motion, icon_set)
		return ""
	var key := event as InputEventKey
	if key:
		var code := key.physical_keycode
		return key_name(code if code != KEY_NONE else key.keycode)
	var mouse := event as InputEventMouseButton
	if mouse:
		return MOUSE_BUTTONS.get(mouse.button_index, "")
	return ""


static func key_name(code: int) -> String:
	if (code >= KEY_A and code <= KEY_Z) or (code >= KEY_0 and code <= KEY_9):
		return String.chr(code).to_lower()
	if code >= KEY_F1 and code <= KEY_F12:
		return "f%d" % (code - KEY_F1 + 1)
	if KEYS.has(code):
		return KEYS[code]
	return OS.get_keycode_string(code as Key).to_snake_case()


static func texture(path: String, crop := false) -> Texture2D:
	var key := "%s|%s" % [path, crop]
	if _textures.has(key):
		return _textures[key]
	if not ResourceLoader.exists(path):
		return null
	var image := (load(path) as Texture2D).get_image()
	image.decompress()
	if crop:
		image = image.get_region(image.get_used_rect())
	image.generate_mipmaps()
	var made := ImageTexture.create_from_image(image)
	_textures[key] = made
	return made


static func _axis_name(
	motion: InputEventJoypadMotion,
	icon_set: InputIconSet,
) -> String:
	var negative := motion.axis_value < 0.0
	match motion.axis:
		JOY_AXIS_LEFT_X:
			return icon_set.left_stick + ("_left" if negative else "_right")
		JOY_AXIS_LEFT_Y:
			return icon_set.left_stick + ("_up" if negative else "_down")
		JOY_AXIS_RIGHT_X:
			return icon_set.right_stick + ("_left" if negative else "_right")
		JOY_AXIS_RIGHT_Y:
			return icon_set.right_stick + ("_up" if negative else "_down")
		JOY_AXIS_TRIGGER_LEFT:
			return icon_set.left_trigger
		JOY_AXIS_TRIGGER_RIGHT:
			return icon_set.right_trigger
	return ""


static func _merges(icon_set: InputIconSet) -> Array:
	var merges: Array = [[DPAD, "dpad"]]
	for stick in [icon_set.left_stick, icon_set.right_stick]:
		var up: String = stick + "_up"
		var down: String = stick + "_down"
		var left: String = stick + "_left"
		var right: String = stick + "_right"
		merges.append(
			[PackedStringArray([up, down, left, right]), stick + "_2d"]
		)
		merges.append([PackedStringArray([up, down]), stick + "_y"])
		merges.append([PackedStringArray([left, right]), stick + "_x"])
	merges.append([WHEEL, "mouse_scroll"])
	return merges


static func _merged(
	found: PackedStringArray,
	members: PackedStringArray,
	replacement: String,
) -> PackedStringArray:
	var first := found.size()
	for member in members:
		var at := found.find(member)
		if at < 0:
			return found
		first = mini(first, at)
	var merged := PackedStringArray()
	for index in found.size():
		if index == first:
			merged.append(replacement)
		if not members.has(found[index]):
			merged.append(found[index])
	return merged


static func _without_spare_arrows(
	found: PackedStringArray
) -> PackedStringArray:
	var others := PackedStringArray()
	for icon in found:
		if not ARROWS.has(icon):
			others.append(icon)
	return found if others.is_empty() else others
