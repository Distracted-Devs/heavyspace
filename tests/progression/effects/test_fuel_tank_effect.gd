extends SkillEffectTestCase


func resource_path() -> String:
	return "res://resources/progression/effects/fuel_tank_effect.tres"


func changes() -> Dictionary:
	return { "tank_size": "×" }


func test_it_changes_only_its_own_stat() -> void:
	assert_changes_only_its_own_stat()


func test_amount_zero_changes_nothing() -> void:
	assert_amount_zero_changes_nothing()
