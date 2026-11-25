class_name CrashBounceEffect
extends Node

const SAME_POINT := 0.001
const MIN_AXIS := 0.5

@export_group("Components")
@export var player: Player
@export var mesh: Node3D
@export var camera_component: CameraComponent
@export var lose_controller: LoseController:
	set(value):
		if lose_controller != null:
			lose_controller.lost_game.disconnect(bounce_off)
		lose_controller = value
		if lose_controller != null:
			lose_controller.lost_game.connect(bounce_off)

@export_group("Bounce")
@export_range(0.0, 1.0, 0.01) var restitution := 0.5:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"restitution must be within [0, 1]",
		):
			return
		restitution = value
@export_range(0.0, 10.0, 0.1, "or_greater") var min_speed := 1.5:
	set(value):
		if _not_negative(value, "min_speed"):
			min_speed = value
@export_range(0.0, 10.0, 0.1, "or_greater") var drag := 1.2:
	set(value):
		if _not_negative(value, "drag"):
			drag = value
@export_range(0.0, 1440.0, 10.0, "or_greater") var tumble_degrees := 360.0:
	set(value):
		if _not_negative(value, "tumble_degrees"):
			tumble_degrees = value

var bouncing := false
var velocity := Vector3.ZERO

var _tumble_axis := Vector3.RIGHT
var _tumble_speed := 0.0


func _physics_process(delta: float) -> void:
	update(delta)


func bounce_off(other: Node3D) -> void:
	if not Contract.require(
		player != null and mesh != null and camera_component != null,
		"player, mesh and camera_component must be set",
	):
		return
	var normal := player.global_position - other.global_position
	if normal.length() < SAME_POINT:
		normal = player.global_basis.z
	normal = normal.normalized()
	velocity = player.linear_velocity
	var into := velocity.dot(normal)
	if into < 0.0:
		velocity -= (1.0 + restitution) * into * normal
	var least := min_speed * camera_component.distance
	var away := velocity.dot(normal)
	if away < least:
		velocity += (least - away) * normal
	_tumble_axis = normal.cross(velocity).normalized()
	if _tumble_axis.length() < MIN_AXIS:
		_tumble_axis = player.global_basis.x.normalized()
	_tumble_speed = deg_to_rad(tumble_degrees)
	bouncing = true
	Contract.ensure(
		velocity.dot(normal) >= least - 1e-4,
		"the bounce must move away from what was hit",
	)


func update(delta: float) -> void:
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	if not bouncing:
		return
	player.global_position += velocity * delta
	velocity *= exp(-drag * delta)
	_tumble_speed *= exp(-drag * 0.5 * delta)
	mesh.global_basis = (
		Basis(_tumble_axis, _tumble_speed * delta) * mesh.global_basis
	)


func _not_negative(value: float, setting: String) -> bool:
	return Contract.require(value >= 0.0, "%s must not be negative" % setting)
