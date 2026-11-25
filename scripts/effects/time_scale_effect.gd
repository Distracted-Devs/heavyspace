class_name TimeScaleEffect
extends Node

signal finished

@export_group("Components")
@export var lose_controller: LoseController:
	set(value):
		if lose_controller != null:
			lose_controller.lost_game.disconnect(_on_lost_game)
		lose_controller = value
		if lose_controller != null:
			lose_controller.lost_game.connect(_on_lost_game)

@export_group("Time")
@export_range(0.01, 1.0, 0.01, "or_greater") var hitstop_time := 0.12:
	set(value):
		if _positive(value, "hitstop_time"):
			hitstop_time = value
@export_range(0.001, 1.0, 0.001) var hitstop_scale := 0.02:
	set(value):
		if _scale_valid(value, "hitstop_scale"):
			hitstop_scale = value
@export_range(0.001, 1.0, 0.001) var slowmo_scale := 0.01:
	set(value):
		if _scale_valid(value, "slowmo_scale"):
			slowmo_scale = value
@export_range(0.05, 10.0, 0.05, "or_greater") var slowmo_time := 2.0:
	set(value):
		if _positive(value, "slowmo_time"):
			slowmo_time = value

var playing := false

var _elapsed := 0.0
var _last_usec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := minf((now - _last_usec) / 1e6, 0.1)
	_last_usec = now
	update(real)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func play() -> void:
	playing = true
	_elapsed = 0.0
	Engine.time_scale = hitstop_scale


func total_time() -> float:
	return hitstop_time + slowmo_time


func update(delta: float) -> void:
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	if not playing:
		return
	_elapsed += delta
	if _elapsed < hitstop_time:
		Engine.time_scale = hitstop_scale
	elif _elapsed < total_time():
		var t := (_elapsed - hitstop_time) / slowmo_time
		Engine.time_scale = lerpf(slowmo_scale, 1.0, t * t)
	else:
		Engine.time_scale = 1.0
		playing = false
		finished.emit()
	Contract.invariant(
		Engine.time_scale > 0.0 and Engine.time_scale <= 1.0,
		"the time scale must be within (0, 1]",
	)


func _on_lost_game(_other: Node3D) -> void:
	play()


func _positive(value: float, setting: String) -> bool:
	return Contract.require(value > 0.0, "%s must be positive" % setting)


func _scale_valid(value: float, setting: String) -> bool:
	return Contract.require(
		value > 0.0 and value <= 1.0,
		"%s must be within (0, 1]" % setting,
	)
