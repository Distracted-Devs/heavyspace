class_name SkillEffectTestCase
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const AMOUNT := 0.6

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func resource_path() -> String:
	return ""


func changes() -> Dictionary:
	return { }


func effect() -> SkillEffect:
	return load(resource_path())


func stats(player: Player) -> Dictionary:
	return {
		"tank_size": player.fuel_component.tank_size,
		"refill_time": player.fuel_component.refill_time,
		"back_thrust_force": player.thruster.back_thrust_force,
		"pickup_radius": player.pickup_component.pickup_radius,
		"mass_conversion": player.pickup_component.mass_conversion,
		"pitch_torque": player.rotator.pitch_torque,
		"turn_torque": player.rotator.turn_torque,
		"roll_torque": player.rotator.roll_torque,
		"cargo_tanks": float(player.cargo.tanks),
		"cargo_weight": player.cargo_weight.cargo_weight,
		"start_multiplier": player.mass_component.start_multiplier,
		"bonus_per_missing": player.missing_fuel_boost.bonus_per_missing,
	}


func expected(before: float, change: String, amount: float) -> float:
	match change:
		"×":
			return before * (1.0 + amount)
		"÷":
			return before / (1.0 + amount)
		"+":
			return before + roundi(amount)
		"−":
			return before * maxf(0.0, 1.0 - amount)
		"add":
			return before + amount
	return before


func assert_changes_only_its_own_stat(amount := AMOUNT) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	var before := stats(player)
	effect().apply(player, amount)
	var after := stats(player)
	var changed := changes()
	for stat: String in before:
		var want := expected(before[stat], changed.get(stat, ""), amount)
		assert_almost_eq(after[stat], want, 1e-6, stat)
	player.free()


func assert_amount_zero_changes_nothing() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	var before := stats(player)
	effect().apply(player, 0.0)
	assert_eq(stats(player), before)
	player.free()
