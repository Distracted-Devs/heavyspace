extends UpgradeTestCase


func resource_path() -> String:
	return "res://resources/progression/upgrades/refill_rate_upgrade.tres"


func expected_id() -> StringName:
	return &"refill_rate"


func expected_step() -> float:
	return 0.25


func effects() -> Dictionary:
	return { "refill_time": "÷" }


func test_it_changes_only_the_refill_time_by_its_multiplier() -> void:
	assert_changes_only_its_own_stat()


func test_level_zero_changes_nothing() -> void:
	assert_level_zero_changes_nothing()


func test_its_resource_holds_the_tuned_values() -> void:
	assert_tuned_values()
