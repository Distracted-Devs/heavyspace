class_name ThrustRumble
extends RumbleSource

const SOURCE := &"thrust"

@export_group("Components")
@export var engine_meter: EngineMeterComponent

@export_group("Rumble")
@export_range(0.0, 100.0, 0.5, "or_greater") var min_accel := 5.0:
	set(value):
		var message := "min_accel must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		min_accel = value
@export_range(1.0, 1000.0, 1.0, "or_greater") var max_accel := 150.0:
	set(value):
		var message := "max_accel must be above min_accel"
		if not Contract.require(value > min_accel, message):
			return
		max_accel = value
@export_range(0.0, 1.0, 0.01) var max_weak := 0.35:
	set(value):
		if motor_valid(value, "max_weak"):
			max_weak = value


func _process(_delta: float) -> void:
	update()


func _init() -> void:
	held_source = SOURCE


func update() -> void:
	if not Contract.require(engine_meter != null, "engine_meter must be set"):
		return
	if rumble == null:
		return
	if engine_meter.body.freeze:
		rumble.release(SOURCE)
		return
	var span := max_accel - min_accel
	var place := (engine_meter.thrust_acceleration - min_accel) / span
	rumble.hold(SOURCE, max_weak * clampf(place, 0.0, 1.0), 0.0)
