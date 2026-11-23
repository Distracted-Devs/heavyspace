class_name WarpController
extends Node

signal warp_started(banked: float)
signal warp_finished

@export_group("Components")
@export var player: Player
@export var lose_controller: LoseController
@export var warp_effect: WarpEffect

@export_group("Warp")
@export_range(0.0, 1000.0, 0.1, "or_greater") var warp_cost := 10.0:
	set(value):
		if not Contract.require(value >= 0.0, "warp_cost must not be negative"):
			return
		warp_cost = value
@export var warp_spends_cost := true

var progression: Progression
var run_start_mass := 0.0
var warping := false


func _enter_tree() -> void:
	if progression == null:
		progression = RunProgress.progression


func _ready() -> void:
	if not Contract.require(
		player != null and lose_controller != null,
		"player and lose_controller must be set",
	):
		return
	run_start_mass = player.mass_component.current_mass


func collected() -> float:
	return player.mass_component.current_mass - run_start_mass


func can_warp() -> bool:
	return not warping and not lose_controller.lost and collected() >= warp_cost


func warp_out() -> bool:
	if not can_warp():
		return false
	var gained := collected()
	var banked := maxf(gained - warp_cost if warp_spends_cost else gained, 0.0)
	var bank_before := progression.bank
	progression.bank_mass(banked)
	warping = true
	lose_controller.disarm()
	player.stop_flight()
	Contract.ensure(
		warping and is_equal_approx(progression.bank, bank_before + banked),
		"warping must bank the collected mass once",
	)
	warp_started.emit(banked)
	if warp_effect == null:
		warp_finished.emit()
	else:
		warp_effect.finished.connect(warp_finished.emit, CONNECT_ONE_SHOT)
		warp_effect.play()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("warp_out") and warp_out():
		get_viewport().set_input_as_handled()
