class_name RumbleSource
extends Node

var held_source := &""

var rumble: RumbleMixer:
	get:
		if rumble == null and is_inside_tree():
			rumble = get_node_or_null(^"/root/Rumble") as RumbleMixer
		return rumble


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		release_hold()


func release_hold() -> void:
	if held_source != &"" and is_instance_valid(rumble):
		rumble.release(held_source)


static func motor_valid(value: float, setting: String) -> bool:
	return Contract.require(
		value >= 0.0 and value <= 1.0,
		"%s must be within [0, 1]" % setting,
	)


static func positive(value: float, setting: String) -> bool:
	return Contract.require(value > 0.0, "%s must be positive" % setting)
