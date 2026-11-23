extends GutTest

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func _upgrade(step := 0.25) -> Upgrade:
	var upgrade := BoosterUpgrade.new()
	upgrade.id = &"test"
	upgrade.step = step
	upgrade.base_cost = 5.0
	upgrade.cost_growth = 1.6
	return upgrade


func test_multiplier_adds_one_step_per_level() -> void:
	var upgrade := _upgrade(0.25)
	assert_eq(upgrade.multiplier(0), 1.0)
	assert_eq(upgrade.multiplier(3), 1.75)


func test_cost_grows_by_cost_growth_per_level_rounded() -> void:
	var upgrade := _upgrade()
	var costs := []
	for level in 5:
		costs.append(upgrade.cost(level))
	assert_eq(costs, [5.0, 8.0, 13.0, 20.0, 33.0])


func test_multiplier_and_cost_never_decrease_with_level() -> void:
	var upgrade := _upgrade()
	for level in 20:
		assert_gte(upgrade.multiplier(level + 1), upgrade.multiplier(level))
		assert_gte(upgrade.cost(level + 1), upgrade.cost(level))
		assert_gte(upgrade.multiplier(level), 1.0)


func test_negative_level_is_reported() -> void:
	var upgrade := _upgrade()
	assert_eq(upgrade.multiplier(-1), 1.0)
	assert_eq(upgrade.cost(-1), INF)
	assert_push_error("level must not be negative")
	assert_push_error("level must not be negative")


func test_an_upgrade_without_an_id_is_never_affordable() -> void:
	var upgrade := _upgrade()
	upgrade.id = &""
	assert_eq(upgrade.cost(0), INF)
	assert_push_error("[Contract] Pre-condition broken: upgrade id must be set")


func test_bad_exports_are_reported_and_ignored() -> void:
	var upgrade := _upgrade(0.25)
	upgrade.step = -0.1
	upgrade.base_cost = 0.0
	upgrade.cost_growth = 0.9
	assert_push_error("step must not be negative")
	assert_push_error("base_cost must be positive")
	assert_push_error("cost_growth must be at least 1")
	assert_eq(upgrade.step, 0.25)
	assert_eq(upgrade.base_cost, 5.0)
	assert_eq(upgrade.cost_growth, 1.6)


func test_applying_to_no_player_is_reported() -> void:
	_upgrade().apply(null, 1)
	assert_push_error("[Contract] Pre-condition broken: player must be set")
