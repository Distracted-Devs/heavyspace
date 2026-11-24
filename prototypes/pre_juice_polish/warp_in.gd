extends Node

## Prototype warp in: the level's WarpEffect played backwards at the start
## of every run. It starts white, wide and stretched with the ship far ahead,
## and ends with the ship in place at the normal field of view.

signal finished

## Multiplies the warp-out duration.
@export_range(0.1, 5.0, 0.01) var duration_scale := 1.0

var playing := false

var _effect: WarpEffect
var _elapsed := 0.0
var _duration := 1.0
var _base_fov := 75.0
var _base_scale_z := 1.0
var _base_z := 0.0


func play(effect: WarpEffect) -> void:
	_effect = effect
	_duration = effect.warp_duration * duration_scale
	_base_fov = effect.camera.fov
	_base_scale_z = effect.mesh.scale.z
	_base_z = effect.mesh.position.z
	_elapsed = 0.0
	playing = true
	_apply(1.0)


func _process(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta
	var t := 1.0 - minf(_elapsed / _duration, 1.0)
	_apply(t)
	if t <= 0.0:
		playing = false
		finished.emit()


## The warp-out pose at time t (1 = fully warped), mirroring
## WarpEffect.advance.
func _apply(t: float) -> void:
	var stretched := minf(t / _effect.stretch_fraction, 1.0)
	_effect.camera.fov = lerpf(_base_fov, _effect.warp_fov, stretched)
	_effect.mesh.scale.z = lerpf(
		_base_scale_z,
		_base_scale_z * _effect.stretch,
		stretched,
	)
	_effect.mesh.position.z = _base_z - _effect.warp_distance * _expo_in(t)
	if _effect.fade:
		_effect.fade.color.a = clampf(
			(t - _effect.fade_start) / (1.0 - _effect.fade_start),
			0.0,
			1.0,
		)


func _expo_in(t: float) -> float:
	if t <= 0.0:
		return 0.0
	return (pow(2.0, 10.0 * (t - 1.0)) - WarpEffect.EXPO_FLOOR) / (
		1.0 - WarpEffect.EXPO_FLOOR
	)
