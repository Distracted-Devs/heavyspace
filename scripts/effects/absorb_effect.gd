class_name AbsorbEffect
extends Node

signal absorbed(mass: float)

const SQUASH_MIN_DISTANCE := 0.001

@export_group("Components")
@export var ship: Node3D

@export_group("Absorb")
@export_range(0.01, 10.0, 0.01, "or_greater") var suck_duration := 0.5:
	set(value):
		if not Contract.require(value > 0.0, "suck_duration must be positive"):
			return
		suck_duration = value
@export var shrink := true

@export_group("Squash")
@export var squash_enabled := true
@export_range(0.0, 0.99, 0.01) var anticipation := 0.2:
	set(value):
		if not Contract.require(
			value >= 0.0 and value < 1.0,
			"anticipation must be within [0, 1)",
		):
			return
		anticipation = value
@export_range(0.0, 0.99, 0.01) var squash_amount := 0.3:
	set(value):
		if not Contract.require(
			value >= 0.0 and value < 1.0,
			"squash_amount must be within [0, 1)",
		):
			return
		squash_amount = value
@export_range(0.0, 10.0, 0.1, "or_greater") var stretch_amount := 2.0:
	set(value):
		var message := "stretch_amount must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		stretch_amount = value

var _bodies: Array[MassBody] = []
var _offsets := PackedVector3Array()
var _scales := PackedVector3Array()
var _elapsed := PackedFloat64Array()
var _masses := PackedFloat64Array()


func _physics_process(delta: float) -> void:
	advance(delta)


func absorbing_count() -> int:
	return _bodies.size()


func is_absorbing(body: MassBody) -> bool:
	return _bodies.has(body)


func absorb(body: MassBody, extra_mass := 0.0) -> void:
	if not Contract.require(ship != null, "ship must be set"):
		return
	if not Contract.require(is_instance_valid(body), "body must be valid"):
		return
	if not Contract.require(
		not is_absorbing(body),
		"body must not already be absorbing",
	):
		return
	if not Contract.require(
		extra_mass >= 0.0,
		"extra_mass must not be negative",
	):
		return
	_stop_gravity(body)
	if body.get_parent() == null:
		add_child(body)
	else:
		body.reparent(self)
	body.collider.set_deferred("disabled", true)
	# It can no longer collide, so it moves directly rather than sweeping.
	body.sync_to_physics = false
	_bodies.append(body)
	_offsets.append(body.global_position - ship.global_position)
	_scales.append(body.mesh.scale)
	_elapsed.append(0.0)
	_masses.append(body.mass + extra_mass)
	Contract.ensure(
		is_absorbing(body) and body.get_parent() == self,
		"a caught body must be held by the effect",
	)


func advance(delta: float) -> void:
	for slot in range(_bodies.size() - 1, -1, -1):
		var body := _bodies[slot]
		if not is_instance_valid(body):
			_forget(slot)
			continue
		_elapsed[slot] += delta
		var t := minf(_elapsed[slot] / suck_duration, 1.0)
		var remaining := 1.0 - t * t
		body.global_position = ship.global_position + _offsets[slot] * remaining
		var size := _scales[slot] * remaining if shrink else _scales[slot]
		if squash_enabled:
			_squash(body, size, t)
		elif shrink:
			body.mesh.scale = size
		if t >= 1.0:
			var mass := _masses[slot]
			body.queue_free()
			_forget(slot)
			absorbed.emit(mass)


func _squash(body: MassBody, size: Vector3, t: float) -> void:
	var to_ship := ship.global_position - body.global_position
	if to_ship.length() < SQUASH_MIN_DISTANCE:
		body.mesh.scale = size
		return
	var pull := to_ship.normalized()
	var length := AbsorbSquash.along(
		t,
		anticipation,
		squash_amount,
		stretch_amount,
	)
	var across := 1.0 / sqrt(length)
	var up := Vector3.UP if absf(pull.y) < 0.95 else Vector3.RIGHT
	body.mesh.global_basis = (
		Basis.looking_at(pull, up)
		* Basis.from_scale(size * Vector3(across, across, length))
	)


func _stop_gravity(body: MassBody) -> void:
	var source := body.gravity
	if source == null:
		return
	body.gravity = null
	source.get_parent().remove_child(source)
	source.free()


func _forget(slot: int) -> void:
	var last := _bodies.size() - 1
	_bodies[slot] = _bodies[last]
	_offsets[slot] = _offsets[last]
	_scales[slot] = _scales[last]
	_elapsed[slot] = _elapsed[last]
	_masses[slot] = _masses[last]
	_bodies.resize(last)
	_offsets.resize(last)
	_scales.resize(last)
	_elapsed.resize(last)
	_masses.resize(last)
