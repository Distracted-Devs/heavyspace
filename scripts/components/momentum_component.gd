class_name MomentumComponent
extends Node

@export_group("Components")
@export var body: RigidBody3D
@export var mass_component: MassComponent

@export_group("Momentum")
@export var conserve_momentum := true
@export_range(0.0, 2.0, 0.01, "or_greater") var momentum_exponent := 1.0:
	set(value):
		var message := "momentum_exponent must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		momentum_exponent = value

var _last_mass := 0.0


func _ready() -> void:
	if not Contract.require(
		body != null and mass_component != null,
		"body and mass_component must be set",
	):
		return
	_last_mass = mass_component.current_mass
	mass_component.mass_changed.connect(_on_mass_changed)


func _on_mass_changed(new_mass: float) -> void:
	if not Contract.require(new_mass > 0.0, "new_mass must be positive"):
		return
	var old_mass := _last_mass
	_last_mass = new_mass
	if not conserve_momentum or body.freeze:
		return
	var before := body.linear_velocity
	var factor := pow(old_mass / new_mass, momentum_exponent)
	body.linear_velocity = before * factor
	Contract.ensure(
		body.linear_velocity.is_equal_approx(before * factor),
		"changing mass must scale the velocity by the momentum factor",
	)
