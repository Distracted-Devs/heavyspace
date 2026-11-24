class_name WarpController
extends Node

signal warp_started(banked: float)
signal warp_finished

@export_group("Components")
@export var player: Player
@export var lose_controller: LoseController
@export var warp_effect: WarpEffect

@export_group("Warp")
@export var warp_needs_all_tanks := true
@export_range(0, 10, 1, "or_greater") var tanks_to_warp := 1:
	set(value):
		var message := "tanks_to_warp must not be negative"
		if not Contract.require(value >= 0, message):
			return
		tanks_to_warp = value
@export var bank_partial_tank := true
@export_range(0.0, 1000.0, 0.1, "or_greater") var warp_spend := 0.0:
	set(value):
		var message := "warp_spend must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		warp_spend = value

var progression: Progression
var warping := false


func _enter_tree() -> void:
	if progression == null:
		progression = RunProgress.progression


func _ready() -> void:
	Contract.require(
		player != null and lose_controller != null and player.cargo != null,
		"player with a cargo and lose_controller must be set",
	)


func collected() -> float:
	return player.cargo.stored


func tanks_required() -> int:
	var cargo := player.cargo
	if warp_needs_all_tanks:
		return cargo.tanks
	return mini(tanks_to_warp, cargo.tanks)


func can_warp() -> bool:
	return (
		not warping and not lose_controller.lost
		and player.cargo.full_tanks() >= tanks_required()
	)


func bankable() -> float:
	var cargo := player.cargo
	var held := (
		cargo.stored
		if bank_partial_tank
		else cargo.full_tanks() * cargo.tank_size
	)
	return maxf(held - warp_spend, 0.0)


func warp_out() -> bool:
	if not can_warp():
		return false
	var banked := bankable()
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
