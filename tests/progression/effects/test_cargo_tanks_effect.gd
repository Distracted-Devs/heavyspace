extends SkillEffectTestCase


func resource_path() -> String:
	return "res://resources/progression/effects/cargo_tanks_effect.tres"


func changes() -> Dictionary:
	return { "cargo_tanks": "+" }


func test_it_changes_only_its_own_stat() -> void:
	assert_changes_only_its_own_stat()


func test_amount_zero_changes_nothing() -> void:
	assert_amount_zero_changes_nothing()


func test_it_adds_the_rounded_amount_of_tanks() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	var tanks := player.cargo.tanks
	effect().apply(player, 2.0)
	assert_eq(player.cargo.tanks, tanks + 2)
	player.free()


func test_a_player_without_a_cargo_is_reported() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.cargo = null
	effect().apply(player, 1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: player must have a cargo"
	)
	player.free()
