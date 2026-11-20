class_name DebugOverlay
extends CanvasLayer

@export_group("Components")
@export var player: Player
@export var label: Label

@export_group("Display")
@export var decimals := 2


func _ready() -> void:
	visible = OS.is_debug_build()


func _process(_delta: float) -> void:
	if visible and player:
		label.text = describe(player)


func describe(target: Player) -> String:
	var lines: Array[String] = [
		"Position  %s" % _vector(target.global_position),
		"Rotation  %s°" % _vector(target.global_rotation_degrees),
		(
			"Velocity  %s  |%s|"
			% [
				_vector(target.linear_velocity),
				_number(target.linear_velocity.length()),
			]
		),
		"Spin      %s rad/s" % _vector(target.angular_velocity),
		"Mass      %s" % _number(target.mass_component.current_mass),
		(
			"Fuel      %s / %s"
			% [
				_number(target.fuel_component.fuel),
				_number(target.fuel_component.tank_size),
			]
		),
	]
	return "\n".join(lines)


func _vector(value: Vector3) -> String:
	return "(%s, %s, %s)" % [
		_number(value.x),
		_number(value.y),
		_number(value.z),
	]


func _number(value: float) -> String:
	return "%.*f" % [decimals, value + 0.0]
