extends SkillEffectTestCase


func resource_path() -> String:
	return "res://resources/progression/effects/missing_fuel_boost_effect.tres"


func changes() -> Dictionary:
	return { "bonus_per_missing": "add" }


func test_it_changes_only_its_own_stat() -> void:
	assert_changes_only_its_own_stat()


func test_amount_zero_changes_nothing() -> void:
	assert_amount_zero_changes_nothing()


func test_amount_one_is_ten_percent_per_tenth_missing() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	effect().apply(player, 1.0)
	assert_eq(player.missing_fuel_boost.bonus_per_missing, 1.0)
	player.free()


func test_a_player_without_the_component_is_reported() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.missing_fuel_boost = null
	effect().apply(player, 1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: player must have a missing fuel boost"
	)
	player.free()
