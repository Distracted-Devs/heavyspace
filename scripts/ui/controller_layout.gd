class_name ControllerLayout
extends Resource

@export_file("*.svg") var picture := ""
@export var line_colour := "fill:#000000"
@export var shown_line_colour := "fill:#4ce6ff"

@export_group("Slots")
@export var slot_names := PackedStringArray()
@export var slot_on_right: Array[bool] = []
@export var slot_heights := PackedFloat32Array()
@export var slot_lines: Array[PackedStringArray] = []
@export var button_slots: Dictionary[int, String] = { }
@export var axis_slots: Dictionary[int, String] = { }


func require_valid() -> bool:
	var slots := slot_names.size()
	var checks := [
		Contract.require(
			(
				slot_on_right.size() == slots and slot_heights.size() == slots
				and slot_lines.size() == slots
			),
			"every slot needs a side, a height and lines",
		),
		Contract.require(
			Array(slot_heights).all(
				func(height: float) -> bool:
					return height >= 0.0 and height <= 1.0,
			),
			"every slot height must be within [0, 1]",
		),
	]
	return not checks.has(false)


func entries(labels: ControlLabels, icon_set: InputIconSet) -> Dictionary:
	var found := { }
	var stick_groups := { }
	for row in labels.actions.size():
		var action := labels.actions[row]
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			var button := event as InputEventJoypadButton
			if button and button_slots.has(button.button_index):
				var icon: String = icon_set.buttons.get(button.button_index, "")
				_add(
					found,
					button_slots[button.button_index],
					icon,
					labels.labels[row],
				)
			var motion := event as InputEventJoypadMotion
			if motion and axis_slots.has(motion.axis):
				var icon := InputIcons.event_name(
					motion,
					DeviceTracker.Device.CONTROLLER,
					icon_set,
				)
				var slot: String = axis_slots[motion.axis]
				if _is_trigger(motion.axis):
					_add(found, slot, icon, labels.labels[row])
					continue
				var groups: Dictionary = stick_groups.get_or_add(slot, { })
				var icons: PackedStringArray = groups.get(
					labels.axis_labels[row],
					[],
				)
				if not icons.has(icon):
					icons.append(icon)
				groups[labels.axis_labels[row]] = icons
	for slot: String in stick_groups:
		for text: String in stick_groups[slot]:
			for icon in InputIcons.merge(stick_groups[slot][text], icon_set):
				_add(found, slot, icon, text)
	return found


func unused_lines(used: Array) -> PackedStringArray:
	var unused := PackedStringArray()
	for slot in slot_names.size():
		if not used.has(slot_names[slot]):
			unused.append_array(slot_lines[slot])
	return unused


func _is_trigger(axis: int) -> bool:
	return axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT


func _add(found: Dictionary, slot: String, icon: String, text: String) -> void:
	var entries_here: Array = found.get_or_add(slot, [])
	var entry := [icon, text]
	if not entries_here.has(entry):
		entries_here.append(entry)
