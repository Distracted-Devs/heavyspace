class_name RestartPrompt
extends Label
## Text that tells the player how to restart, e.g. "PRESS [START] TO RESTART".
##
## The button name follows the input device: Start when a controller is
## plugged in, R otherwise. Can blink arcade-style and/or appear only once
## the player has died.

## "%s" is replaced by the button name.
@export var template := "PRESS [%s] TO RESTART"
@export var keyboard_button := "R"
@export var controller_button := "START"
## Forces the final text to capital letters.
@export var all_caps := true

@export_group("Blink")
@export var blink := true
## Full on/off cycles per second.
@export var blink_hz := 1.5

@export_group("Visibility")
## Hidden until the player dies.
@export var only_after_death := false
## Seconds to wait after death before showing (lets the explosion play).
@export var death_delay := 1.0

var _time := 0.0
var _death_time := -1.0


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_text()
	if only_after_death:
		modulate.a = 0.0


func _process(delta: float) -> void:
	_time += delta

	if only_after_death:
		if _death_time < 0.0:
			if _is_player_dead():
				_death_time = _time
			modulate.a = 0.0
			return
		if _time - _death_time < death_delay:
			modulate.a = 0.0
			return

	if blink:
		# Hard on/off, no fade, like an arcade attract screen.
		modulate.a = 1.0 if fmod(_time * blink_hz, 1.0) < 0.5 else 0.0
	else:
		modulate.a = 1.0


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_text()


func _refresh_text() -> void:
	var has_controller := not Input.get_connected_joypads().is_empty()
	var button := controller_button if has_controller else keyboard_button
	var result := template % button
	text = result.to_upper() if all_caps else result


func _is_player_dead() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	return player != null and player.is_dead()
