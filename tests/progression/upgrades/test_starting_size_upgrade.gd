extends UpgradeTestCase


func resource_path() -> String:
	return "res://resources/progression/upgrades/starting_size_upgrade.tres"


func expected_id() -> StringName:
	return &"starting_size"


func expected_step() -> float:
	return 0.5


func effects() -> Dictionary:
	return { "start_multiplier": "×" }


func test_it_changes_only_the_start_multiplier_by_its_multiplier() -> void:
	assert_changes_only_its_own_stat()


func test_level_zero_changes_nothing() -> void:
	assert_level_zero_changes_nothing()


func test_its_resource_holds_the_tuned_values() -> void:
	assert_tuned_values()


func test_a_bigger_start_starts_heavier() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	var base := player.mass_component.starting_mass
	upgrade().apply(player, LEVEL)
	add_child_autofree(player)
	player.freeze = true
	assert_almost_eq(
		player.mass_component.current_mass,
		base * upgrade().multiplier(LEVEL),
		1e-6,
	)
