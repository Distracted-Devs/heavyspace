extends UpgradeTestCase


func resource_path() -> String:
	return "res://resources/progression/upgrades/turn_speed_upgrade.tres"


func expected_id() -> StringName:
	return &"turn_speed"


func expected_step() -> float:
	return 0.2


func effects() -> Dictionary:
	return { "pitch_torque": "×", "turn_torque": "×", "roll_torque": "×" }


func test_it_changes_only_the_three_torques_by_its_multiplier() -> void:
	assert_changes_only_its_own_stat()


func test_level_zero_changes_nothing() -> void:
	assert_level_zero_changes_nothing()


func test_its_resource_holds_the_tuned_values() -> void:
	assert_tuned_values()
