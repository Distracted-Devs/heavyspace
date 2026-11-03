class_name Collectable
extends Area3D

signal collected(collector: Node)

@export var collector_group: StringName = &"collector"
@export var free_on_collect := true

var _collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group(collector_group):
		return
	_collected = true

	for child in get_children():
		if child is CollectableEffect:
			child.apply(body)

	collected.emit(body)

	if free_on_collect:
		queue_free()
