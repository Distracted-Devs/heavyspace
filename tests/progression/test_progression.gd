extends GutTest

var _was_enabled: bool
var _progression: Progression
var _upgrade: Upgrade


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_progression = Progression.new()
	_upgrade = BoosterUpgrade.new()
	_upgrade.id = &"booster"
	_upgrade.base_cost = 5.0
	_upgrade.cost_growth = 2.0


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_starts_empty() -> void:
	assert_eq(_progression.bank, 0.0)
	assert_eq(_progression.runs, 0)
	assert_eq(_progression.level_of(_upgrade), 0)


func test_banking_adds_to_the_bank() -> void:
	_progression.bank_mass(3.5)
	_progression.bank_mass(0.0)
	_progression.bank_mass(1.5)
	assert_eq(_progression.bank, 5.0)


func test_banking_a_negative_amount_is_reported_and_ignored() -> void:
	_progression.bank_mass(2.0)
	_progression.bank_mass(-1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: banked amount must not be negative"
	)
	assert_eq(_progression.bank, 2.0)


func test_can_afford_compares_the_next_cost_with_the_bank() -> void:
	_progression.bank_mass(4.0)
	assert_false(_progression.can_afford(_upgrade))
	_progression.bank_mass(1.0)
	assert_true(_progression.can_afford(_upgrade))


func test_buying_spends_the_cost_and_adds_a_level() -> void:
	_progression.bank_mass(20.0)
	assert_true(_progression.buy(_upgrade))
	assert_eq(_progression.bank, 15.0)
	assert_eq(_progression.level_of(_upgrade), 1)
	assert_true(_progression.buy(_upgrade))
	assert_eq(_progression.bank, 5.0)
	assert_eq(_progression.level_of(_upgrade), 2)


func test_an_unaffordable_buy_is_refused_and_changes_nothing() -> void:
	_progression.bank_mass(4.0)
	watch_signals(_progression)
	assert_false(_progression.buy(_upgrade))
	assert_eq(_progression.bank, 4.0)
	assert_eq(_progression.level_of(_upgrade), 0)
	assert_signal_not_emitted(_progression, "changed")


func test_the_bank_never_goes_negative() -> void:
	_progression.bank_mass(30.0)
	while _progression.buy(_upgrade):
		assert_gte(_progression.bank, 0.0)
	assert_gte(_progression.bank, 0.0)
	assert_eq(_progression.level_of(_upgrade), 2)


func test_levels_are_kept_per_upgrade() -> void:
	var other := FuelTankUpgrade.new()
	other.id = &"tank"
	_progression.bank_mass(5.0)
	_progression.buy(_upgrade)
	assert_eq(_progression.level_of(_upgrade), 1)
	assert_eq(_progression.level_of(other), 0)


func test_a_broken_upgrade_is_never_affordable() -> void:
	var broken := BoosterUpgrade.new()
	_progression.bank_mass(1000.0)
	assert_false(_progression.buy(broken))
	assert_push_error("upgrade id must be set")
	assert_eq(_progression.bank, 1000.0)


func test_runs_count_up() -> void:
	_progression.start_run()
	_progression.start_run()
	assert_eq(_progression.runs, 2)


func test_every_change_emits_changed() -> void:
	watch_signals(_progression)
	_progression.bank_mass(5.0)
	_progression.buy(_upgrade)
	_progression.start_run()
	assert_signal_emit_count(_progression, "changed", 3)
