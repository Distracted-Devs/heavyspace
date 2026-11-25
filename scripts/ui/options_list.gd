class_name OptionsList
extends VBoxContainer

@export_group("Components")
@export var vibration_button: Button
@export var invert_pitch_button: Button
@export var show_fps_button: Button

@export_group("Test pulse")
@export_range(0.0, 1.0, 0.01) var pulse_weak := 0.3
@export_range(0.0, 1.0, 0.01) var pulse_strong := 0.5
@export_range(0.01, 1.0, 0.01) var pulse_time := 0.15

var settings: GameSettings
var rumble: RumbleMixer


func _ready() -> void:
	if settings == null:
		settings = get_node_or_null(^"/root/Settings") as GameSettings
	if rumble == null:
		rumble = get_node_or_null(^"/root/Rumble") as RumbleMixer
	if not Contract.require(settings != null, "settings must be set"):
		return
	vibration_button.pressed.connect(toggle_vibration)
	invert_pitch_button.pressed.connect(toggle_invert_pitch)
	show_fps_button.pressed.connect(toggle_show_fps)
	settings.changed.connect(relabel)
	relabel()


func first_button() -> Button:
	return vibration_button


func toggle_vibration() -> void:
	settings.vibration = not settings.vibration
	if settings.vibration and rumble != null:
		rumble.pulse(pulse_weak, pulse_strong, pulse_time)


func toggle_invert_pitch() -> void:
	settings.invert_pitch = not settings.invert_pitch


func toggle_show_fps() -> void:
	settings.show_fps = not settings.show_fps


func relabel() -> void:
	vibration_button.text = "VIBRATION: %s" % _on_off(settings.vibration)
	invert_pitch_button.text = "INVERT PITCH: %s" % _on_off(
		settings.invert_pitch
	)
	show_fps_button.text = "SHOW FPS: %s" % _on_off(settings.show_fps)


func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"
