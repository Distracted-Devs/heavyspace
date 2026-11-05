class_name PointOfInterest
extends Node3D


const GROUP := &"points_of_interest"


func _enter_tree() -> void:
	add_to_group(GROUP)


func _exit_tree() -> void:
	remove_from_group(GROUP)
