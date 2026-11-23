class_name ThrustEffect
extends Node

@export_group("Components")
@export var flight_input: InputComponent
@export var fuel: FuelComponent
@export var particles: GPUParticles3D

@export_group("Thrust")
@export_range(0.0, 0.99, 0.01) var threshold := 0.05:
	set(value):
		if not Contract.require(
			value >= 0.0 and value < 1.0,
			"threshold must be within [0, 1)",
		):
			return
		threshold = value


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if not Contract.require(
		flight_input != null and fuel != null and particles != null,
		"flight_input, fuel and particles must be set",
	):
		return
	particles.emitting = is_thrusting()


func is_thrusting() -> bool:
	return absf(flight_input.thrust_intent.z) > threshold and fuel.fuel > 0.0
