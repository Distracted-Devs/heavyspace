extends SkillEffectTestCase


func resource_path() -> String:
	return "res://resources/progression/effects/mass_efficiency_effect.tres"


func changes() -> Dictionary:
	return { "cargo_weight": "−" }


func test_it_changes_only_its_own_stat() -> void:
	assert_changes_only_its_own_stat()


func test_amount_zero_changes_nothing() -> void:
	assert_amount_zero_changes_nothing()


func test_an_amount_past_one_leaves_the_cargo_weightless() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	effect().apply(player, 1.5)
	assert_eq(player.cargo_weight.cargo_weight, 0.0)
	player.free()


func test_a_player_without_a_cargo_weight_is_reported() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.cargo_weight = null
	effect().apply(player, 1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "player must have a cargo weight component"
	)
	player.free()
