class_name ArcadeFlightComponent
extends Node

const BACKWARDS_EPSILON := 1.0e-6

@export_group("Components")
@export var body: RigidBody3D

@export_group("Arcade flight")
@export_range(0.0, 1.0, 0.01) var alignment := 1.0:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"alignment must be within [0, 1]",
		):
			return
		alignment = value


func _init() -> void:
	process_physics_priority = 1


func _physics_process(_delta: float) -> void:
	align()


func align() -> void:
	if not Contract.require(body != null, "body must be set"):
		return
	var velocity := body.linear_velocity
	var speed := velocity.length()
	if speed == 0.0:
		return
	var forward := -body.global_basis.z
	var turned := velocity.lerp(forward * speed, alignment)
	if turned.length_squared() < BACKWARDS_EPSILON * speed * speed:
		turned = forward
	body.linear_velocity = turned.normalized() * speed
	Contract.ensure(
		is_equal_approx(body.linear_velocity.length(), speed),
		"aligning must keep the speed",
	)
