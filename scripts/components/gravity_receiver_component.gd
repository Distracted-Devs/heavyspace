class_name GravityReceiverComponent
extends Node

@export_group("Components")
@export var body: RigidBody3D
@export var mass_component: MassComponent

@export_group("Gravity")
@export var gravity_constant := 0.001
@export_range(0.1, 6.0, 0.05, "or_greater") var falloff_exponent := 2.0:
	set(value):
		var message := "falloff_exponent must be positive"
		if not Contract.require(value > 0.0, message):
			return
		falloff_exponent = value
@export var drift_enabled := false

var drift := Vector3.ZERO


static func acceleration_at(
	position: Vector3,
	sources: PackedInt32Array,
	positions: PackedVector3Array,
	masses: PackedFloat64Array,
	radii: PackedFloat64Array,
	constant: float,
	exponent: float,
) -> Vector3:
	var total := Vector3.ZERO
	for index in sources:
		var offset := positions[index] - position
		var distance := maxf(offset.length(), radii[index])
		total += (
			offset.normalized() * constant * masses[index]
			/ pow(distance, exponent)
		)
	return total


func _physics_process(_delta: float) -> void:
	apply_gravity()


func core_mass() -> float:
	return mass_component.current_mass if mass_component else body.mass


func reset_drift() -> void:
	drift = Vector3.ZERO


func apply_gravity() -> void:
	if not Contract.require(
		gravity_constant >= 0.0,
		"gravity_constant must not be negative",
	):
		return
	var acceleration := acceleration_at(
		body.global_position,
		GravityRegistry.sources_heavier_than(core_mass()),
		GravityRegistry.positions,
		GravityRegistry.masses,
		GravityRegistry.radii,
		gravity_constant,
		falloff_exponent,
	)
	if not Contract.ensure(
		acceleration.is_finite(),
		"gravity acceleration must be finite",
	):
		return
	if not drift_enabled:
		body.apply_central_force(acceleration * body.mass)
		return
	var delta := get_physics_process_delta_time()
	var kept := maxf(0.0, 1.0 - body.linear_damp * delta)
	drift = (drift + acceleration * delta) * kept
	body.linear_velocity += acceleration * delta
