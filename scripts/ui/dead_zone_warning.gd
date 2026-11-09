class_name DeadZoneWarning
extends CanvasLayer
## Full-screen red warning + countdown shown while the ship is outside a DeadZone.
##
## Usage: instance dead_zone_warning.tscn and point `dead_zone` at the level's
## DeadZone. Style the labels in the scene; colour/pulse are driven from here.

## Leave empty to use the first DeadZone in the "dead_zone" group.
@export var dead_zone: DeadZone

@export_group("Look")
## Red overlay colour; its alpha is the strongest the tint gets.
@export var tint_colour: Color = Color(1.0, 0.05, 0.05, 0.35)
## Overlay pulses per second (speeds up as time runs out).
@export var pulse_hz: float = 1.5
## Lowest overlay strength during a pulse, as a fraction of tint alpha.
@export_range(0.0, 1.0) var pulse_min: float = 0.4

@export_group("Nodes")
@export var overlay: ColorRect
@export var title_label: Label
@export var countdown_label: Label

var _time := 0.0
var _active := false


func _ready() -> void:
	_set_active(false)
	_connect_zone()


func _process(delta: float) -> void:
	if not is_instance_valid(dead_zone):
		_connect_zone()
		return
	if not _active:
		return
	_time += delta
	var left := dead_zone.get_time_left()
	var urgency := 1.0 - clampf(left / maxf(dead_zone.return_time, 0.001), 0.0, 1.0)
	var hz := pulse_hz * (1.0 + urgency * 2.0)
	var pulse := 0.5 + 0.5 * cos(_time * hz * TAU)
	var strength := lerpf(pulse_min, 1.0, pulse) * lerpf(0.6, 1.0, urgency)
	if overlay:
		overlay.color = Color(tint_colour, tint_colour.a * strength)
	if countdown_label:
		countdown_label.text = "%.1f" % left
	if title_label:
		title_label.modulate.a = 1.0 if fmod(_time * hz, 1.0) < 0.6 else 0.35


func _connect_zone() -> void:
	if not is_instance_valid(dead_zone):
		dead_zone = get_tree().get_first_node_in_group(&"dead_zone") as DeadZone
	if not is_instance_valid(dead_zone):
		return
	if not dead_zone.player_exited.is_connected(_on_exited):
		dead_zone.player_exited.connect(_on_exited)
		dead_zone.player_returned.connect(_on_hide)
		dead_zone.time_ran_out.connect(_on_hide)


func _on_exited() -> void:
	_time = 0.0
	_set_active(true)


func _on_hide() -> void:
	_set_active(false)


func _set_active(on: bool) -> void:
	_active = on
	visible = on
