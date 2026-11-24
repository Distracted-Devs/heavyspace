class_name ArcadeFlightComponent
extends Node

const BACKWARDS_EPSILON := 1.0e-6

@export_group("Components")
@export var body: RigidBody3D
@export var gravity_receiver: GravityReceiverComponent

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
	var drift := _drift()
	var own := body.linear_velocity - drift
	var speed := own.length()
	if speed == 0.0:
		return
	var forward := -body.global_basis.z
	var turned := own.lerp(forward * speed, alignment)
	if turned.length_squared() < BACKWARDS_EPSILON * speed * speed:
		turned = forward
	body.linear_velocity = turned.normalized() * speed + drift
	Contract.ensure(
		is_equal_approx((body.linear_velocity - drift).length(), speed),
		"aligning must keep the speed",
	)


func _drift() -> Vector3:
	if gravity_receiver == null or not gravity_receiver.drift_enabled:
		return Vector3.ZERO
	return gravity_receiver.drift
