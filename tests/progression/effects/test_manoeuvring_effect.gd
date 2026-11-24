extends SkillEffectTestCase


func resource_path() -> String:
	return "res://resources/progression/effects/manoeuvring_effect.tres"


func changes() -> Dictionary:
	return { "pitch_torque": "×", "turn_torque": "×", "roll_torque": "×" }


func test_it_changes_only_its_own_stat() -> void:
	assert_changes_only_its_own_stat()


func test_amount_zero_changes_nothing() -> void:
	assert_amount_zero_changes_nothing()
