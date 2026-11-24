class_name FlightTraining
extends Node

signal step_started(index: int)
signal step_completed(index: int)
signal finished

@export var steps: Array[TrainingStep] = []

@export_group("Feel")
@export_range(0.05, 5.0, 0.05, "or_greater") var hold_time := 0.7:
	set(value):
		if not Contract.require(value > 0.0, "hold_time must be positive"):
			return
		hold_time = value
@export_range(0.01, 1.0, 0.01) var input_threshold := 0.3:
	set(value):
		if not Contract.require(
			value > 0.0 and value <= 1.0,
			"input_threshold must be within (0, 1]",
		):
			return
		input_threshold = value
@export_range(10.0, 5000.0, 10.0, "or_greater") var mouse_distance := 600.0:
	set(value):
		if not Contract.require(value > 0.0, "mouse_distance must be positive"):
			return
		mouse_distance = value
@export_range(0.0, 3.0, 0.05, "or_greater") var step_gap := 0.6:
	set(value):
		if not Contract.require(value >= 0.0, "step_gap must not be negative"):
			return
		step_gap = value

var running := false
var index := 0
var progress := 0.0

var _gap_left := -1.0


func _process(delta: float) -> void:
	advance(delta)


func _input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_mouse_motion(motion.relative)


func start() -> void:
	if not Contract.require(not steps.is_empty(), "steps must not be empty"):
		return
	running = true
	_begin(0)


func current_step() -> TrainingStep:
	return steps[index] if running else null


func advance(delta: float) -> void:
	if not running:
		return
	if _gap_left >= 0.0:
		_gap_left -= delta
		if _gap_left < 0.0:
			_next()
		return
	var strength := 0.0
	for action in steps[index].actions:
		strength = maxf(strength, Input.get_action_strength(action))
	if strength >= input_threshold:
		_fill(delta / hold_time)


func add_mouse_motion(relative: Vector2) -> void:
	if running and _gap_left < 0.0 and steps[index].counts_mouse_motion:
		_fill(relative.length() / mouse_distance)


func _fill(amount: float) -> void:
	progress = minf(progress + amount, 1.0)
	if progress >= 1.0:
		_gap_left = step_gap
		step_completed.emit(index)
	Contract.invariant(
		progress >= 0.0 and progress <= 1.0,
		"progress must be within [0, 1]",
	)


func _next() -> void:
	if index + 1 >= steps.size():
		running = false
		_gap_left = -1.0
		finished.emit()
		return
	_begin(index + 1)


func _begin(step: int) -> void:
	index = step
	progress = 0.0
	_gap_left = -1.0
	step_started.emit(step)
