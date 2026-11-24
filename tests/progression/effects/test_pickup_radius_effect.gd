extends SkillEffectTestCase


func resource_path() -> String:
	return "res://resources/progression/effects/pickup_radius_effect.tres"


func changes() -> Dictionary:
	return { "pickup_radius": "×" }


func test_it_changes_only_its_own_stat() -> void:
	assert_changes_only_its_own_stat()


func test_amount_zero_changes_nothing() -> void:
	assert_amount_zero_changes_nothing()


func test_a_player_without_a_pickup_component_is_reported() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.pickup_component = null
	effect().apply(player, 1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: player must have a pickup component"
	)
	player.free()
