class_name WarpRumble
extends RumbleSource

const SOURCE := &"warp"

@export_group("Components")
@export var warp_effect: WarpEffect

@export_group("Rumble")
@export_range(0.0, 1.0, 0.01) var weak := 0.6:
	set(value):
		if motor_valid(value, "weak"):
			weak = value
@export_range(0.0, 1.0, 0.01) var strong := 1.0:
	set(value):
		if motor_valid(value, "strong"):
			strong = value
@export_range(0.1, 10.0, 0.1, "or_greater") var strong_power := 3.0:
	set(value):
		if positive(value, "strong_power"):
			strong_power = value


func _process(_delta: float) -> void:
	update()


func _init() -> void:
	held_source = SOURCE


func update() -> void:
	if not Contract.require(warp_effect != null, "warp_effect must be set"):
		return
	if rumble == null:
		return
	if not warp_effect.playing:
		rumble.release(SOURCE)
		return
	var intensity := warp_effect.intensity()
	rumble.hold(SOURCE, weak * intensity, strong * pow(intensity, strong_power))
