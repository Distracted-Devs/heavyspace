class_name WinScreen
extends Label
## Win condition: shows a flashing "VICTORY CAPTAIN" once every
## AsteroidMission in the scene has been destroyed.

## Full on/off cycles per second.
@export var blink_hz := 1.5
## Seconds to wait after the last asteroid explodes before showing.
@export var delay := 1.0

var _remaining := 0
var _won := false
var _time := 0.0


func _ready() -> void:
	modulate.a = 0.0
	_collect_missions.call_deferred()


func _collect_missions() -> void:
	for node in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if node is AsteroidMission and not (node as AsteroidMission).is_completed:
			_remaining += 1
			(node as AsteroidMission).completed.connect(_on_mission_completed)


func _on_mission_completed() -> void:
	_remaining -= 1
	if _remaining <= 0 and not _won:
		_won = true
		_time = -delay


func _process(delta: float) -> void:
	if not _won:
		return
	_time += delta
	if _time < 0.0:
		return
	# Hard on/off, arcade style.
	modulate.a = 1.0 if fmod(_time * blink_hz, 1.0) < 0.5 else 0.0
