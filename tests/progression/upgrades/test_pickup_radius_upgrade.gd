extends UpgradeTestCase


func resource_path() -> String:
	return "res://resources/progression/upgrades/pickup_radius_upgrade.tres"


func expected_id() -> StringName:
	return &"pickup_radius"


func expected_step() -> float:
	return 0.2


func effects() -> Dictionary:
	return { "pickup_radius": "×" }


func test_it_changes_only_the_pickup_radius_by_its_multiplier() -> void:
	assert_changes_only_its_own_stat()


func test_level_zero_changes_nothing() -> void:
	assert_level_zero_changes_nothing()


func test_its_resource_holds_the_tuned_values() -> void:
	assert_tuned_values()


func test_a_player_without_a_pickup_is_reported() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.pickup_component = null
	upgrade().apply(player, 1)
	assert_push_error(
		"[Contract] Pre-condition broken: player must have a pickup component"
	)
	player.free()
