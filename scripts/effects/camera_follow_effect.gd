class_name CameraFollowEffect
extends Node

const PULL_EASE := 0.5
const BOOST_TIME_CAP := 3.0

@export_group("Components")
@export var ship: RigidBody3D
@export var camera_component: CameraComponent
@export var engine_meter: EngineMeterComponent
@export var bank_effect: BankEffect
@export var warp_effect: WarpEffect

@export_group("Lag")
@export_range(0.1, 30.0, 0.1, "or_greater") var follow_speed := 2.0:
	set(value):
		if _positive(value, "follow_speed"):
			follow_speed = value
@export_range(0.1, 30.0, 0.1, "or_greater") var boost_follow_speed := 4.0:
	set(value):
		if _positive(value, "boost_follow_speed"):
			boost_follow_speed = value

@export_group("Pull")
@export_range(0.0, 2.0, 0.01, "or_greater") var max_pull := 0.35:
	set(value):
		if _not_negative(value, "max_pull"):
			max_pull = value
@export_range(0.1, 10.0, 0.1, "or_greater") var pull_ramp_time := 1.5:
	set(value):
		if _positive(value, "pull_ramp_time"):
			pull_ramp_time = value
@export_range(0.1, 200.0, 0.1, "or_greater") var pull_stiffness := 30.0:
	set(value):
		if _positive(value, "pull_stiffness"):
			pull_stiffness = value
@export_range(0.0, 50.0, 0.1, "or_greater") var pull_damping := 8.0:
	set(value):
		if _not_negative(value, "pull_damping"):
			pull_damping = value
@export_range(0.0, 20.0, 0.1, "or_greater") var pull_drain := 2.0:
	set(value):
		if _not_negative(value, "pull_drain"):
			pull_drain = value

@export_group("Roll")
@export_range(0.0, 1.0, 0.01) var camera_roll := 0.15:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"camera_roll must be within [0, 1]",
		):
			return
		camera_roll = value

@export_group("FOV")
@export_range(0.0, 45.0, 0.5, "or_greater") var fov_kick := 5.0:
	set(value):
		if _not_negative(value, "fov_kick"):
			fov_kick = value
@export_range(0.1, 30.0, 0.1, "or_greater") var fov_speed := 4.0:
	set(value):
		if _positive(value, "fov_speed"):
			fov_speed = value

var base_fov := 75.0
var boost_time := 0.0
var pull := 0.0

var _lagged := Quaternion.IDENTITY
var _snapped := false
var _pull_velocity := 0.0
var _fov_level := 0.0


func _ready() -> void:
	process_physics_priority = -1
	if camera_component != null and camera_component.camera != null:
		base_fov = camera_component.camera.fov


func _physics_process(delta: float) -> void:
	update(delta)


func update(delta: float) -> void:
	if not Contract.require(
		ship != null and camera_component != null and engine_meter != null,
		"ship, camera_component and engine_meter must be set",
	):
		return
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	if ship.freeze:
		return
	var boost := engine_meter.boost()
	var facing := ship.global_basis.get_rotation_quaternion()
	if not _snapped:
		snap()
	var rate := lerpf(follow_speed, boost_follow_speed, boost)
	_lagged = _lagged.slerp(facing, 1.0 - exp(-rate * delta)).normalized()
	_update_pull(boost, delta)
	camera_component.follow_rotation = (facing.inverse() * _lagged).normalized()
	camera_component.follow_offset = Vector3(0.0, 0.0, pull)
	if bank_effect != null:
		camera_component.follow_roll = bank_effect.bank * camera_roll
	_update_fov(delta)
	Contract.invariant(
		_lagged.is_normalized(),
		"the lagged rotation must be a unit quaternion",
	)


func snap() -> void:
	_lagged = ship.global_basis.get_rotation_quaternion()
	_snapped = true


func _update_pull(boost: float, delta: float) -> void:
	if boost > 0.0:
		var cap := pull_ramp_time * BOOST_TIME_CAP
		boost_time = minf(boost_time + delta * boost, cap)
	else:
		boost_time = maxf(boost_time - delta * pull_drain, 0.0)
	var ramp := minf(boost_time / pull_ramp_time, 1.0)
	var target := (
		max_pull * boost * engine_meter.strength()
		* ease(ramp, PULL_EASE) * camera_component.distance
	)
	_pull_velocity += (target - pull) * pull_stiffness * delta
	_pull_velocity -= _pull_velocity * pull_damping * delta
	pull += _pull_velocity * delta


func _update_fov(delta: float) -> void:
	var target := engine_meter.scaled_boost()
	_fov_level = lerpf(_fov_level, target, 1.0 - exp(-fov_speed * delta))
	if warp_effect != null and warp_effect.playing:
		return
	var camera := camera_component.camera
	if camera != null:
		camera.fov = base_fov + fov_kick * _fov_level


func _positive(value: float, setting: String) -> bool:
	return Contract.require(value > 0.0, "%s must be positive" % setting)


func _not_negative(value: float, setting: String) -> bool:
	return Contract.require(value >= 0.0, "%s must not be negative" % setting)
