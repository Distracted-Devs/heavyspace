class_name RumbleMixer
extends Node

@export_group("Output")
@export_range(0.01, 0.5, 0.01) var send_interval := 0.03:
	set(value):
		if not Contract.require(value > 0.0, "send_interval must be positive"):
			return
		send_interval = value
@export_range(0.01, 1.0, 0.01) var command_time := 0.12:
	set(value):
		if not Contract.require(value > 0.0, "command_time must be positive"):
			return
		command_time = value

var settings: GameSettings
var sent_weak := 0.0
var sent_strong := 0.0

var _held := { }
var _pulse_weak := PackedFloat32Array()
var _pulse_strong := PackedFloat32Array()
var _pulse_age := PackedFloat32Array()
var _pulse_duration := PackedFloat32Array()
var _pulse_power := PackedFloat32Array()
var _until_send := 0.0
var _last_usec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if settings == null:
		settings = get_node_or_null(^"/root/Settings") as GameSettings
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := minf((now - _last_usec) / 1e6, 0.1)
	_last_usec = now
	advance(real)
	_until_send -= real
	if _until_send <= 0.0:
		_until_send = send_interval
		send()


func _exit_tree() -> void:
	_stop_pads()


func pulse(
	light: float,
	heavy: float,
	duration: float,
	fade_power := 1.0,
) -> void:
	if not _motors_valid(light, heavy):
		return
	if not Contract.require(duration > 0.0, "duration must be positive"):
		return
	if not Contract.require(fade_power > 0.0, "fade_power must be positive"):
		return
	_pulse_weak.append(light)
	_pulse_strong.append(heavy)
	_pulse_age.append(0.0)
	_pulse_duration.append(duration)
	_pulse_power.append(fade_power)
	_until_send = 0.0


func hold(source: StringName, light: float, heavy: float) -> void:
	if not _motors_valid(light, heavy):
		return
	if light <= 0.0 and heavy <= 0.0:
		release(source)
		return
	_held[source] = Vector2(light, heavy)


func release(source: StringName) -> void:
	_held.erase(source)


func weak() -> float:
	return _mix().x


func strong() -> float:
	return _mix().y


func advance(delta: float) -> void:
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	for slot in range(_pulse_age.size() - 1, -1, -1):
		_pulse_age[slot] += delta
		if _pulse_age[slot] >= _pulse_duration[slot]:
			_forget(slot)


func send() -> void:
	var on := settings == null or settings.vibration
	var mix := _mix() if on else Vector2.ZERO
	sent_weak = mix.x
	sent_strong = mix.y
	if mix == Vector2.ZERO:
		_stop_pads()
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, mix.x, mix.y, command_time)


func _mix() -> Vector2:
	var mix := Vector2.ZERO
	for level: Vector2 in _held.values():
		mix = mix.max(level)
	for slot in _pulse_age.size():
		var left := 1.0 - _pulse_age[slot] / _pulse_duration[slot]
		var envelope := pow(maxf(left, 0.0), _pulse_power[slot])
		mix = mix.max(
			Vector2(_pulse_weak[slot], _pulse_strong[slot]) * envelope
		)
	Contract.invariant(
		mix.x >= 0.0 and mix.x <= 1.0 and mix.y >= 0.0 and mix.y <= 1.0,
		"the mix must be within [0, 1]",
	)
	return mix


func _motors_valid(weak_level: float, strong_level: float) -> bool:
	return Contract.require(
		weak_level >= 0.0 and weak_level <= 1.0
		and strong_level >= 0.0 and strong_level <= 1.0,
		"motors must be within [0, 1]",
	)


func _stop_pads() -> void:
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)


func _forget(slot: int) -> void:
	var last := _pulse_age.size() - 1
	_pulse_weak[slot] = _pulse_weak[last]
	_pulse_strong[slot] = _pulse_strong[last]
	_pulse_age[slot] = _pulse_age[last]
	_pulse_duration[slot] = _pulse_duration[last]
	_pulse_power[slot] = _pulse_power[last]
	_pulse_weak.resize(last)
	_pulse_strong.resize(last)
	_pulse_age.resize(last)
	_pulse_duration.resize(last)
	_pulse_power.resize(last)
