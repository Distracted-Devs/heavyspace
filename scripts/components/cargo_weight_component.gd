class_name CargoWeightComponent
extends Node

@export_group("Components")
@export var body: RigidBody3D
@export var mass_component: MassComponent
@export var cargo: CargoComponent
@export var gravity_receiver: GravityReceiverComponent

@export_group("Cargo weight")
@export_range(0.0, 10.0, 0.01, "or_greater") var cargo_weight := 0.5:
	set(value):
		var message := "cargo_weight must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		cargo_weight = value
@export_range(0.0, 4.0, 0.05, "or_greater") var mass_exponent := 1.0:
	set(value):
		var message := "mass_exponent must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		mass_exponent = value
@export var conserve_momentum := true

var _active := false


func _ready() -> void:
	if not Contract.require(
		body != null and mass_component != null and cargo != null,
		"body, mass_component and cargo must be set",
	):
		return
	_active = true
	cargo.changed.connect(_on_cargo_changed)
	mass_component.mass_changed.connect(_on_core_mass_changed)
	_apply_mass()


func handling_mass() -> float:
	var core := mass_component.current_mass
	var real := core + cargo.stored * cargo_weight
	return core * pow(real / core, mass_exponent)


func _on_cargo_changed(_stored: float) -> void:
	var before := body.mass
	_apply_mass()
	if not conserve_momentum or body.freeze:
		return
	var keep := before / body.mass
	body.linear_velocity *= keep
	if gravity_receiver != null:
		gravity_receiver.drift *= keep


func _on_core_mass_changed(_mass: float) -> void:
	_apply_mass()


func _apply_mass() -> void:
	if not _active:
		return
	body.mass = handling_mass()
	Contract.ensure(
		is_equal_approx(body.mass, handling_mass()),
		"body.mass must equal the handling mass",
	)
