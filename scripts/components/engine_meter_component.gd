class_name EngineMeterComponent
extends Node

const SNAP_TO_ZERO := 0.01

@export_group("Components")
@export var body: RigidBody3D
@export var flight_input: InputComponent
@export var fuel: FuelComponent
@export var thruster: ThrusterComponent

@export_group("Meter")
@export_range(1.0, 1000.0, 1.0, "or_greater") var reference_force := 150.0:
	set(value):
		var message := "reference_force must be positive"
		if not Contract.require(value > 0.0, message):
			return
		reference_force = value
@export_range(1.0, 10.0, 0.1, "or_greater") var max_strength := 2.0:
	set(value):
		var message := "max_strength must be at least 1"
		if not Contract.require(value >= 1.0, message):
			return
		max_strength = value
@export_range(0.1, 50.0, 0.1, "or_greater") var accel_smoothing := 8.0:
	set(value):
		var message := "accel_smoothing must be positive"
		if not Contract.require(value > 0.0, message):
			return
		accel_smoothing = value

var thrust_acceleration := 0.0


func _physics_process(delta: float) -> void:
	update(delta)


func boost() -> float:
	if body.freeze or fuel.fuel <= 0.0:
		return 0.0
	var level := clampf(absf(flight_input.thrust_intent.z), 0.0, 1.0)
	Contract.invariant(level >= 0.0 and level <= 1.0, "boost must be in [0, 1]")
	return level


func strength() -> float:
	return _force() / reference_force


func scaled_boost() -> float:
	return boost() * minf(strength(), max_strength)


func update(delta: float) -> void:
	if not Contract.require(
		body != null and flight_input != null
		and fuel != null and thruster != null,
		"body, flight_input, fuel and thruster must be set",
	):
		return
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	var engine := boost() * _force() / maxf(body.mass, 1e-4)
	var blend := 1.0 - exp(-accel_smoothing * delta)
	thrust_acceleration = lerpf(thrust_acceleration, engine, blend)
	if thrust_acceleration < SNAP_TO_ZERO:
		thrust_acceleration = 0.0
	Contract.invariant(
		thrust_acceleration >= 0.0,
		"thrust_acceleration must not be negative",
	)


func _force() -> float:
	return thruster.back_thrust_force * thruster.thrust_multiplier
