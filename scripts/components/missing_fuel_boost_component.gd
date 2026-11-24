class_name MissingFuelBoostComponent
extends Node

const SNAP_STEPS := 10.0
const SNAP_EPSILON := 1e-4

@export_group("Components")
@export var thruster: ThrusterComponent
@export var fuel: FuelComponent

@export_group("Missing fuel boost")
@export_range(0.0, 10.0, 0.05, "or_greater") var bonus_per_missing := 0.0:
	set(value):
		var message := "bonus_per_missing must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		bonus_per_missing = value
@export var snap_to_tenths := true

var _active := false


func _init() -> void:
	process_physics_priority = -1


func _ready() -> void:
	_active = Contract.require(
		thruster != null and fuel != null,
		"thruster and fuel must be set",
	)


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	thruster.thrust_multiplier = boost()
	Contract.ensure(
		is_equal_approx(thruster.thrust_multiplier, boost()),
		"the thrust multiplier must match the boost",
	)


func missing() -> float:
	var fraction := clampf(1.0 - fuel.fuel / fuel.tank_size, 0.0, 1.0)
	if snap_to_tenths:
		fraction = floorf(fraction * SNAP_STEPS + SNAP_EPSILON) / SNAP_STEPS
	return fraction


func boost() -> float:
	return 1.0 + bonus_per_missing * missing()
