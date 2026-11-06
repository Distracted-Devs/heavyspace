class_name Mission
extends PointOfInterest
## Base class for mission objectives. Shows up on the minimap as a point of
## interest (via PointOfInterest) until it is completed.

signal completed

var is_completed := false


func complete() -> void:
	if is_completed:
		return
	is_completed = true
	# Stop showing on the minimap once done.
	remove_from_group(GROUP)
	completed.emit()


## True if the body belongs to the player's ship.
func _is_player_ship(body: Node) -> bool:
	for player in get_tree().get_nodes_in_group(&"player"):
		if player is Player and (player as Player).ship == body:
			return true
	return false
