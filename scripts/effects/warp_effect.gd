class_name WarpEffect
extends Node

signal finished

const EXPO_FLOOR := 1.0 / 1024.0

@export_group("Components")
@export var camera: Camera3D
@export var mesh: Node3D
@export var fade: ColorRect

@export_group("Warp")
@export_range(0.01, 10.0, 0.01, "or_greater") var warp_duration := 1.5:
	set(value):
		if not Contract.require(value > 0.0, "warp_duration must be positive"):
			return
		warp_duration = value
@export_range(1.0, 179.0, 0.1) var warp_fov := 130.0:
	set(value):
		if not Contract.require(
			value > 0.0 and value < 180.0,
			"warp_fov must be within (0, 180)",
		):
			return
		warp_fov = value
@export_range(0.0, 10000.0, 1.0, "or_greater") var warp_distance := 400.0:
	set(value):
		var message := "warp_distance must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		warp_distance = value
@export_range(1.0, 20.0, 0.1, "or_greater") var stretch := 6.0:
	set(value):
		if not Contract.require(value >= 1.0, "stretch must be at least 1"):
			return
		stretch = value
@export_range(0.01, 1.0, 0.01) var stretch_fraction := 0.6:
	set(value):
		if not Contract.require(
			value > 0.0 and value <= 1.0,
			"stretch_fraction must be within (0, 1]",
		):
			return
		stretch_fraction = value
@export_range(0.0, 0.99, 0.01) var fade_start := 0.5:
	set(value):
		if not Contract.require(
			value >= 0.0 and value < 1.0,
			"fade_start must be within [0, 1)",
		):
			return
		fade_start = value

var playing := false

var _elapsed := 0.0
var _start_fov := 0.0
var _start_scale_z := 1.0
var _start_position_z := 0.0


func _process(delta: float) -> void:
	if playing:
		advance(delta)


func play() -> void:
	if not Contract.require(not playing, "the warp must not already play"):
		return
	if not Contract.require(
		camera != null and mesh != null,
		"camera and mesh must be set",
	):
		return
	_elapsed = 0.0
	_start_fov = camera.fov
	_start_scale_z = mesh.scale.z
	_start_position_z = mesh.position.z
	playing = true


func advance(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta
	var t := minf(_elapsed / warp_duration, 1.0)
	var stretched := minf(t / stretch_fraction, 1.0)
	camera.fov = lerpf(_start_fov, warp_fov, stretched)
	mesh.scale.z = lerpf(_start_scale_z, _start_scale_z * stretch, stretched)
	mesh.position.z = _start_position_z - warp_distance * _expo_in(t)
	if fade:
		fade.color.a = clampf((t - fade_start) / (1.0 - fade_start), 0.0, 1.0)
	if t >= 1.0:
		playing = false
		finished.emit()


func _expo_in(t: float) -> float:
	if t <= 0.0:
		return 0.0
	return (pow(2.0, 10.0 * (t - 1.0)) - EXPO_FLOOR) / (1.0 - EXPO_FLOOR)
