class_name CameraShakeEffect
extends Node

const NOISE_SECOND_AXIS := 100.0

@export_group("Components")
@export var camera_component: CameraComponent
@export var lose_controller: LoseController:
	set(value):
		if lose_controller != null:
			lose_controller.lost_game.disconnect(_on_lost_game)
		lose_controller = value
		if lose_controller != null:
			lose_controller.lost_game.connect(_on_lost_game)
@export var warp_effect: WarpEffect

@export_group("Shake")
@export_range(0.0, 5.0, 0.1, "or_greater") var death_shake := 2.0:
	set(value):
		if _not_negative(value, "death_shake"):
			death_shake = value
@export_range(0.0, 5.0, 0.1, "or_greater") var warp_shake := 3.0:
	set(value):
		if _not_negative(value, "warp_shake"):
			warp_shake = value
@export_range(0.1, 10.0, 0.1, "or_greater") var shake_decay := 1.2:
	set(value):
		if _positive(value, "shake_decay"):
			shake_decay = value
@export_range(0.0, 0.5, 0.01, "or_greater") var shake_offset := 0.06:
	set(value):
		if _not_negative(value, "shake_offset"):
			shake_offset = value
@export_range(0.1, 100.0, 0.1, "or_greater") var shake_frequency := 25.0:
	set(value):
		if _positive(value, "shake_frequency"):
			shake_frequency = value

var trauma := 0.0

var _noise := FastNoiseLite.new()
var _time := 0.0
var _last_usec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.frequency = 1.0
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := minf((now - _last_usec) / 1e6, 0.1)
	_last_usec = now
	update(real)


func add_trauma(amount: float) -> void:
	if not Contract.require(amount >= 0.0, "amount must not be negative"):
		return
	trauma += amount


func shake() -> float:
	var warp := warp_effect.intensity() if warp_effect != null else 0.0
	return maxf(trauma, warp_shake * warp)


func update(delta: float) -> void:
	if not Contract.require(
		camera_component != null and camera_component.camera != null,
		"camera_component must be set",
	):
		return
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	trauma = maxf(trauma - shake_decay * delta, 0.0)
	_time += delta * shake_frequency
	var amount := shake()
	var size := amount * amount * shake_offset * camera_component.distance
	var camera := camera_component.camera
	camera.h_offset = _wobble(_time, 0.0) * size
	camera.v_offset = _wobble(0.0, _time + NOISE_SECOND_AXIS) * size
	Contract.invariant(trauma >= 0.0, "trauma must not be negative")
	Contract.invariant(
		absf(camera.h_offset) <= size and absf(camera.v_offset) <= size,
		"the shake must stay within its size",
	)


func _wobble(x: float, y: float) -> float:
	return clampf(_noise.get_noise_2d(x, y), -1.0, 1.0)


func _on_lost_game(_other: Node3D) -> void:
	add_trauma(death_shake)


func _positive(value: float, setting: String) -> bool:
	return Contract.require(value > 0.0, "%s must be positive" % setting)


func _not_negative(value: float, setting: String) -> bool:
	return Contract.require(value >= 0.0, "%s must not be negative" % setting)
