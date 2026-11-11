class_name MainMenu
extends CanvasLayer
## Arcade-style title screen: "PRESS [A] OR [ENTER] TO PLAY" plus credits.
##
## Only shown while GameState.in_menu is true (first launch). Pressing A on a
## controller or Enter on the keyboard asks GameState to start; the camera
## then flies to the ship and enables the controls when it arrives.

## Gameplay UI hidden while the menu is up, shown again once the game starts.
@export var hide_during_menu: Array[CanvasLayer] = []
## Full on/off cycles per second of the play prompt.
@export var blink_hz := 1.5
## Seconds the menu takes to fade out after Play is pressed.
@export var fade_out_time := 0.4

@onready var _root: Control = $Root
@onready var _prompt: Label = $Root/Prompt

var _time := 0.0


func _ready() -> void:
	if not GameState.in_menu:
		queue_free()
		return
	for layer in hide_during_menu:
		if is_instance_valid(layer):
			layer.visible = false
	GameState.game_started.connect(_on_game_started)


func _process(delta: float) -> void:
	_time += delta
	if GameState.is_starting():
		return
	# Hard on/off, no fade, like an arcade attract screen.
	_prompt.modulate.a = 1.0 if fmod(_time * blink_hz, 1.0) < 0.5 else 0.0


func _input(event: InputEvent) -> void:
	if GameState.is_starting() or not _is_play_event(event):
		return
	get_viewport().set_input_as_handled()
	_prompt.modulate.a = 1.0
	GameState.request_play()
	create_tween().tween_property(_root, ^"modulate:a", 0.0, fade_out_time)


func _is_play_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventJoypadButton:
		return event.button_index == JOY_BUTTON_A
	if event is InputEventKey:
		return event.keycode in [KEY_ENTER, KEY_KP_ENTER]
	return false


func _on_game_started() -> void:
	for layer in hide_during_menu:
		if is_instance_valid(layer):
			layer.visible = true
	queue_free()
