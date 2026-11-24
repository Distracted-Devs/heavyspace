class_name ShopCamera
extends Node

const ZOOM_BASE := 2.0

@export_group("Camera")
@export_range(0.01, 2.0, 0.01, "or_greater") var smooth_time := 0.25:
	set(value):
		if not Contract.require(value > 0.0, "smooth_time must be positive"):
			return
		smooth_time = value
@export_range(0.05, 4.0, 0.05, "or_greater") var default_zoom := 0.95
@export_range(0.05, 4.0, 0.05, "or_greater") var min_zoom := 0.45:
	set(value):
		if not Contract.require(value > 0.0, "min_zoom must be positive"):
			return
		min_zoom = value
@export_range(0.05, 4.0, 0.05, "or_greater") var max_zoom := 2.2:
	set(value):
		var message := "max_zoom must be at least min_zoom"
		if not Contract.require(value >= min_zoom, message):
			return
		max_zoom = value
@export_range(0.1, 10.0, 0.1, "or_greater") var zoom_speed := 1.5:
	set(value):
		if not Contract.require(value > 0.0, "zoom_speed must be positive"):
			return
		zoom_speed = value
@export_range(1.01, 2.0, 0.01, "or_greater") var wheel_step := 1.15:
	set(value):
		if not Contract.require(value > 1.0, "wheel_step must be above 1"):
			return
		wheel_step = value
@export_range(0.1, 60.0, 0.1, "or_greater") var zoom_rate := 12.0:
	set(value):
		if not Contract.require(value > 0.0, "zoom_rate must be positive"):
			return
		zoom_rate = value

var position: Vector2:
	get:
		return _position
var zoom: float:
	get:
		return _zoom
var target_zoom: float:
	get:
		return _target_zoom

var _position := Vector2.ZERO
var _velocity := Vector2.ZERO
var _zoom := 1.0
var _target_zoom := 1.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED


func _ready() -> void:
	_zoom = _clamp_zoom(default_zoom)
	_target_zoom = _zoom


func snap(target: Vector2) -> void:
	_position = target
	_velocity = Vector2.ZERO
	_zoom = _clamp_zoom(default_zoom)
	_target_zoom = _zoom
	_check_zoom()


func advance(delta: float, target: Vector2, push: float) -> void:
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	if not Contract.require(
		push >= -1.0 and push <= 1.0,
		"push must be within [-1, 1]",
	):
		return
	_position = _glide(_position, target, delta)
	_target_zoom = _clamp_zoom(
		_target_zoom * pow(ZOOM_BASE, push * zoom_speed * delta)
	)
	_zoom = lerpf(_zoom, _target_zoom, 1.0 - exp(-zoom_rate * delta))
	_check_zoom()


func step_zoom(notches: float) -> void:
	_target_zoom = _clamp_zoom(_target_zoom * pow(wheel_step, notches))
	_check_zoom()


func offset(view_size: Vector2) -> Vector2:
	return view_size * 0.5 - _position * _zoom


# Critically damped spring (Game Programming Gems 4, 1.10). Its
# approximation can step past the target, so a step that would is clamped.
func _glide(from: Vector2, to: Vector2, delta: float) -> Vector2:
	var omega := 2.0 / smooth_time
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := from - to
	var temp := (_velocity + omega * change) * delta
	_velocity = (_velocity - omega * temp) * decay
	var result := to + (change + temp) * decay
	if (to - from).dot(result - to) > 0.0:
		_velocity = Vector2.ZERO
		return to
	return result


func _clamp_zoom(value: float) -> float:
	return clampf(value, min_zoom, max_zoom)


func _check_zoom() -> void:
	Contract.invariant(
		(
			_zoom >= min_zoom - 1e-6 and _zoom <= max_zoom + 1e-6
			and _target_zoom >= min_zoom and _target_zoom <= max_zoom
		),
		"zoom must stay within its range",
	)
