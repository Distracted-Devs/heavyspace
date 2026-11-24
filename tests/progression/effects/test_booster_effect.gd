extends SkillEffectTestCase


func resource_path() -> String:
	return "res://resources/progression/effects/booster_effect.tres"


func changes() -> Dictionary:
	return { "back_thrust_force": "×" }


func test_it_changes_only_its_own_stat() -> void:
	assert_changes_only_its_own_stat()


func test_amount_zero_changes_nothing() -> void:
	assert_amount_zero_changes_nothing()
