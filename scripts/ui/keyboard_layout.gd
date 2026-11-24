class_name KeyboardLayout
extends Resource

@export_file("*.svg") var picture := ""
@export var outline_colour := "stroke:#22262c"
@export var shown_outline_colour := "stroke:#4ce6ff"

@export_group("Keys")
@export var key_codes := PackedInt32Array()
@export var key_rects := PackedVector4Array()


func require_valid() -> bool:
	var checks := [
		Contract.require(
			key_rects.size() == key_codes.size(),
			"every key needs a rectangle",
		),
		Contract.require(
			Array(key_rects).all(
				func(rect: Vector4) -> bool:
					return (
						rect.x >= 0.0 and rect.y >= 0.0
						and rect.x + rect.z <= 1.0 and rect.y + rect.w <= 1.0
					),
			),
			"every key must be inside the picture",
		),
	]
	return not checks.has(false)


func has_key(code: int) -> bool:
	return key_codes.has(code)


func rect_of(code: int) -> Rect2:
	var index := key_codes.find(code)
	if index < 0:
		return Rect2()
	var rect := key_rects[index]
	return Rect2(rect.x, rect.y, rect.z, rect.w)


func captions(labels: ControlLabels) -> Dictionary:
	var found := { }
	for row in labels.actions.size():
		for code in _key_codes_of(labels.actions[row]):
			if not has_key(code):
				continue
			var captions_here: PackedStringArray = found.get(
				code,
				PackedStringArray(),
			)
			if not captions_here.has(labels.short_labels[row]):
				captions_here.append(labels.short_labels[row])
			found[code] = captions_here
	return found


func extras(labels: ControlLabels, icon_set: InputIconSet) -> Array:
	var found := []
	for row in labels.actions.size():
		var action := labels.actions[row]
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key and has_key(_code_of(key)):
				continue
			if not (key or event is InputEventMouseButton):
				continue
			var icon := InputIcons.event_name(
				event,
				DeviceTracker.Device.KEYBOARD_MOUSE,
				icon_set,
			)
			var entry := [icon, labels.labels[row]]
			if icon != "" and not found.has(entry):
				found.append(entry)
	for extra in labels.keyboard_extra_icons.size():
		found.append(
			[
				labels.keyboard_extra_icons[extra],
				labels.keyboard_extra_labels[extra],
			]
		)
	return found


func _key_codes_of(action: StringName) -> PackedInt32Array:
	var codes := PackedInt32Array()
	if not InputMap.has_action(action):
		return codes
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key:
			codes.append(_code_of(key))
	return codes


func _code_of(key: InputEventKey) -> int:
	var physical := key.physical_keycode
	return physical if physical != KEY_NONE else key.keycode
