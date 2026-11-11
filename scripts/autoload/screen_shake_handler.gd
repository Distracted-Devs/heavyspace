extends Node
## Global screen shake, autoloaded as `ScreenShakeHandler`.
##
## Call it from anywhere:
##     ScreenShakeHandler.shake()                              # default small shake
##     ScreenShakeHandler.shake(0.6, 0.8)                      # stronger, longer
##     ScreenShakeHandler.shake(0.2, 1.5, 8.0, 2.0)            # slow, rolling rumble
##     ScreenShakeHandler.shake_at(explosion_pos, 30.0, 0.8)   # weaker the farther the camera is
##
## Several shakes can run at the same time; their offsets are added together.
## Translation is applied through the active Camera3D's h_offset / v_offset, so any
## camera works without changes. Rotation needs the camera to read
## get_rotation_basis() (camera.gd already does).

class Shake:
	var strength: float
	var duration: float
	var frequency: float
	var rotation: float
	var falloff: float
	var elapsed := 0.0
	var seed: float

## Turn every shake off (e.g. an accessibility option).
@export var enabled := true
## Scales every shake (e.g. a "screen shake intensity" slider).
@export_range(0.0, 2.0) var global_multiplier := 1.0
## Upper bound for the combined translation offset, in meters.
@export var max_offset := 2.0
## Upper bound for the combined rotation, in degrees.
@export var max_rotation_degrees := 10.0

var _shakes: Array[Shake] = []
var _noise := FastNoiseLite.new()
var _offset := Vector2.ZERO
var _rotation := Vector3.ZERO
var _applied_offset := Vector2.ZERO
var _camera: Camera3D


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()


## Starts a new shake.
## [param strength]: max camera displacement in meters.
## [param duration]: seconds until it fades out completely.
## [param frequency]: how fast it jitters (low = rumble, high = rattle).
## [param rotation_deg]: max camera tilt in degrees (0 = translation only).
## [param falloff]: fade curve exponent (1 = linear, 2+ = sharp hit that settles fast).
func shake(
	strength := 0.3,
	duration := 0.4,
	frequency := 20.0,
	rotation_deg := 0.5,
	falloff := 2.0,
) -> void:
	if not enabled or duration <= 0.0 or (strength <= 0.0 and rotation_deg <= 0.0):
		return
	var s := Shake.new()
	s.strength = strength
	s.duration = duration
	s.frequency = frequency
	s.rotation = deg_to_rad(rotation_deg)
	s.falloff = falloff
	s.seed = randf() * 10000.0
	_shakes.append(s)


## Like shake(), but scaled down by the camera's distance to [param source].
## No shake happens if the camera is farther than [param radius].
func shake_at(
	source: Vector3,
	radius: float,
	strength := 0.3,
	duration := 0.4,
	frequency := 20.0,
	rotation_deg := 0.5,
	falloff := 2.0,
) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or radius <= 0.0:
		return
	var dist := cam.global_position.distance_to(source)
	if dist >= radius:
		return
	var attenuation := pow(1.0 - dist / radius, 2.0)
	shake(strength * attenuation, duration, frequency, rotation_deg * attenuation, falloff)


## Current rotation offset. Multiply the camera's basis by this after positioning it.
func get_rotation_basis() -> Basis:
	return Basis.from_euler(_rotation)


func _process(delta: float) -> void:
	_offset = Vector2.ZERO
	_rotation = Vector3.ZERO

	for i in range(_shakes.size() - 1, -1, -1):
		var s := _shakes[i]
		s.elapsed += delta
		if s.elapsed >= s.duration:
			_shakes.remove_at(i)
			continue
		var t := s.elapsed * s.frequency
		var amount := pow(1.0 - s.elapsed / s.duration, s.falloff)
		_offset += Vector2(_sample(s.seed, t), _sample(s.seed + 100.0, t)) * s.strength * amount
		_rotation += Vector3(
			_sample(s.seed + 200.0, t),
			_sample(s.seed + 300.0, t),
			_sample(s.seed + 400.0, t),
		) * s.rotation * amount

	var mult := global_multiplier if enabled else 0.0
	_offset = _offset.limit_length(max_offset) * mult
	var max_rot := deg_to_rad(max_rotation_degrees)
	_rotation = _rotation.clamp(Vector3.ONE * -max_rot, Vector3.ONE * max_rot) * mult
	_apply_offset()


func _sample(row: float, t: float) -> float:
	return _noise.get_noise_2d(t, row)


func _apply_offset() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != _camera:
		# Camera switched: give the old one its original offsets back.
		if is_instance_valid(_camera):
			_camera.h_offset -= _applied_offset.x
			_camera.v_offset -= _applied_offset.y
		_applied_offset = Vector2.ZERO
		_camera = cam
	if _camera == null:
		return
	# Apply only the change so the camera's own h/v offset is preserved.
	_camera.h_offset += _offset.x - _applied_offset.x
	_camera.v_offset += _offset.y - _applied_offset.y
	_applied_offset = _offset
