class_name UpgradeTestCase
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const LEVEL := 2

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func resource_path() -> String:
	return ""


func expected_id() -> StringName:
	return &""


func expected_step() -> float:
	return 0.0


func expected_cost_growth() -> float:
	return 1.6


func effects() -> Dictionary:
	return { }


func upgrade() -> Upgrade:
	return load(resource_path())


func stats(player: Player) -> Dictionary:
	return {
		"start_multiplier": player.mass_component.start_multiplier,
		"tank_size": player.fuel_component.tank_size,
		"refill_time": player.fuel_component.refill_time,
		"back_thrust_force": player.thruster.back_thrust_force,
		"pickup_radius": player.pickup_component.pickup_radius,
		"pitch_torque": player.rotator.pitch_torque,
		"turn_torque": player.rotator.turn_torque,
		"roll_torque": player.rotator.roll_torque,
		"cargo_tanks": float(player.cargo.tanks),
	}


func assert_changes_only_its_own_stat() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	var before := stats(player)
	upgrade().apply(player, LEVEL)
	var after := stats(player)
	var by := upgrade().multiplier(LEVEL)
	var changes := effects()
	for stat: String in before:
		var expected: float = before[stat]
		if changes.get(stat) == "×":
			expected *= by
		elif changes.get(stat) == "÷":
			expected /= by
		elif changes.get(stat) == "+":
			expected += by - 1.0
		assert_almost_eq(after[stat], expected, 1e-6, stat)
	player.free()


func assert_level_zero_changes_nothing() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	var before := stats(player)
	upgrade().apply(player, 0)
	assert_eq(stats(player), before)
	player.free()


func assert_tuned_values() -> void:
	var tuned := upgrade()
	assert_eq(tuned.id, expected_id())
	assert_eq(tuned.step, expected_step())
	assert_eq(tuned.base_cost, 5.0)
	assert_eq(tuned.cost_growth, expected_cost_growth())
	assert_ne(tuned.display_name, "")
