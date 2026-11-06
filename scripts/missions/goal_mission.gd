class_name GoalMission
extends Mission
## Completed when the player's ship flies into the goal area.

@export var goal_area: Area3D


func _ready() -> void:
	if goal_area:
		goal_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _is_player_ship(body):
		complete()
