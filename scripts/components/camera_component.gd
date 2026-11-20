class_name CameraComponent
extends Node3D

const TOLERANCE := 1e-3

@export_group("Components")
@export var player_input: PlayerInputComponent
@export var camera: Camera3D

@export_group("Look")
@export var look_speed := 2.0:
	set(value):
		var message := "look_speed must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		look_speed = value
@export_range(1.0, 89.0) var max_pitch_degrees := 80.0:
	set(value):
		if not Contract.require(
			value > 0.0 and value < 90.0,
			"max_pitch_degrees must be within (0, 90)",
		):
			return
		max_pitch_degrees = value
@export var start_pitch_degrees := -20.0
@export var distance := 2.7:
	set(value):
		if not Contract.require(value > 0.0, "distance must be positive"):
			return
		distance = value

var yaw := 0.0
var pitch := 0.0


func _ready() -> void:
	pitch = _start_pitch()
	_apply()


func _physics_process(delta: float) -> void:
	update_look(player_input.look_intent, player_input.mouse_look, delta)


func update_look(stick: Vector2, mouse: Vector2, delta: float) -> void:
	yaw -= mouse.x + stick.x * look_speed * delta
	pitch -= mouse.y + stick.y * look_speed * delta
	_apply()


func _apply() -> void:
	var limit := _max_pitch()
	pitch = clampf(pitch, -limit, limit)
	rotation = Vector3(pitch, yaw, 0.0)
	camera.transform = Transform3D(Basis.IDENTITY, Vector3.BACK * distance)
	Contract.invariant(
		absf(pitch) <= limit + TOLERANCE,
		"camera pitch must be within max_pitch",
	)
	Contract.invariant(
		_is_framing_the_ship(),
		"camera must be at distance and look at the ship",
	)


func _is_framing_the_ship() -> bool:
	var to_ship := global_position - camera.global_position
	var looks_at_ship := (-camera.global_basis.z).dot(to_ship.normalized())
	return (
		absf(to_ship.length() - distance) < TOLERANCE
		and looks_at_ship > 1.0 - TOLERANCE
	)


func _max_pitch() -> float:
	return deg_to_rad(max_pitch_degrees)


func _start_pitch() -> float:
	return clampf(deg_to_rad(start_pitch_degrees), -_max_pitch(), _max_pitch())
