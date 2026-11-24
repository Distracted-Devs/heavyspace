class_name ControlLabels
extends Resource

@export var actions: Array[StringName] = []
@export var labels := PackedStringArray()
@export var short_labels := PackedStringArray()
@export var axis_labels := PackedStringArray()

@export_group("Keyboard extras")
@export var keyboard_extra_icons := PackedStringArray()
@export var keyboard_extra_labels := PackedStringArray()


func require_valid() -> bool:
	var rows := actions.size()
	var checks := [
		Contract.require(
			(
				labels.size() == rows and short_labels.size() == rows
				and axis_labels.size() == rows
			),
			"each action needs a label, a short label and an axis label",
		),
		Contract.require(
			keyboard_extra_icons.size() == keyboard_extra_labels.size(),
			"each keyboard extra needs an icon and a label",
		),
	]
	return not checks.has(false)


func index_of(action: StringName) -> int:
	return actions.find(action)
