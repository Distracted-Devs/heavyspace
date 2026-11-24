extends UpgradeTestCase


func resource_path() -> String:
	return "res://resources/progression/upgrades/cargo_tanks_upgrade.tres"


func expected_id() -> StringName:
	return &"cargo_tanks"


func expected_step() -> float:
	return 1.0


func expected_cost_growth() -> float:
	return 2.0


func effects() -> Dictionary:
	return { "cargo_tanks": "+" }


func test_it_adds_one_tank_per_level_and_changes_nothing_else() -> void:
	assert_changes_only_its_own_stat()


func test_level_zero_changes_nothing() -> void:
	assert_level_zero_changes_nothing()


func test_its_resource_holds_the_tuned_values() -> void:
	assert_tuned_values()


func test_it_is_capped_at_three_tanks() -> void:
	assert_eq(upgrade().max_level, 2)
	var player: Player = PLAYER_SCENE.instantiate()
	upgrade().apply(player, upgrade().max_level)
	assert_eq(player.cargo.tanks, 3)
	player.free()


func test_a_player_without_a_cargo_is_reported() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.cargo = null
	upgrade().apply(player, 1)
	assert_push_error(
		"[Contract] Pre-condition broken: player must have a cargo"
	)
	player.free()
