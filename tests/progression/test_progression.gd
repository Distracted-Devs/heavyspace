extends GutTest

var _was_enabled: bool
var _progression: Progression


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_progression = Progression.new()


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_starts_empty() -> void:
	assert_eq(_progression.bank, 0.0)
	assert_eq(_progression.runs, 0)
	assert_eq(_progression.player_level(), 0)


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


func test_runs_count_up() -> void:
	_progression.start_run()
	_progression.start_run()
	assert_eq(_progression.runs, 2)


func test_every_change_emits_changed() -> void:
	watch_signals(_progression)
	_progression.bank_mass(5.0)
	_progression.buy(_skill(&"booster", 5.0))
	_progression.start_run()
	assert_signal_emit_count(_progression, "changed", 3)


func _skill(
	id: StringName,
	cost: float,
	max_buys := 5,
	level := 0,
) -> SkillNode:
	var node := SkillNode.new()
	node.id = id
	node.effect = BoosterEffect.new()
	node.cost = cost
	node.max_buys = max_buys
	node.required_level = level
	return node


func test_nodes_start_unbought_at_level_zero() -> void:
	var node := _skill(&"booster", 10.0)
	assert_eq(_progression.buys(node), 0)
	assert_eq(_progression.player_level(), 0)
	assert_eq(_progression.buys_by_id(), { })


func test_buying_a_node_spends_its_flat_cost_and_raises_the_level() -> void:
	var node := _skill(&"booster", 10.0)
	_progression.bank_mass(25.0)
	watch_signals(_progression)
	assert_true(_progression.buy(node))
	assert_true(_progression.buy(node))
	assert_eq(_progression.bank, 5.0)
	assert_eq(_progression.buys(node), 2)
	assert_eq(_progression.player_level(), 2)
	assert_signal_emit_count(_progression, "changed", 2)


func test_the_player_level_counts_buys_across_every_node() -> void:
	var a := _skill(&"a", 1.0)
	var b := _skill(&"b", 1.0)
	_progression.bank_mass(10.0)
	_progression.buy(a)
	_progression.buy(b)
	_progression.buy(b)
	assert_eq(_progression.player_level(), 3)
	assert_eq(_progression.buys_by_id(), { &"a": 1, &"b": 2 })


func test_a_node_unlocks_once_the_level_reaches_its_requirement() -> void:
	var first := _skill(&"first", 1.0)
	var gated := _skill(&"gated", 1.0, 5, 2)
	_progression.bank_mass(10.0)
	assert_false(_progression.is_unlocked(gated))
	assert_false(_progression.buy(gated))
	_progression.buy(first)
	_progression.buy(first)
	assert_true(_progression.is_unlocked(gated))
	assert_true(_progression.buy(gated))


func test_a_maxed_node_cannot_be_bought_again() -> void:
	var node := _skill(&"once", 1.0, 1)
	_progression.bank_mass(10.0)
	assert_true(_progression.buy(node))
	assert_true(_progression.is_maxed(node))
	assert_false(_progression.can_buy(node))
	assert_false(_progression.buy(node))
	assert_eq(_progression.bank, 9.0)


func test_an_unaffordable_node_is_refused_and_changes_nothing() -> void:
	var node := _skill(&"dear", 10.0)
	_progression.bank_mass(9.0)
	watch_signals(_progression)
	assert_false(_progression.buy(node))
	assert_eq(_progression.bank, 9.0)
	assert_eq(_progression.buys(node), 0)
	assert_signal_not_emitted(_progression, "changed")


func test_the_whole_bank_can_be_spent_exactly() -> void:
	var node := _skill(&"exact", 10.0)
	_progression.bank_mass(10.0)
	assert_true(_progression.buy(node))
	assert_eq(_progression.bank, 0.0)


func test_a_null_or_invalid_node_cannot_be_bought() -> void:
	var nameless := _skill(&"", 1.0)
	_progression.bank_mass(10.0)
	assert_false(_progression.can_buy(null))
	assert_false(_progression.buy(null))
	assert_false(_progression.buy(nameless))
	assert_eq(_progression.bank, 10.0)


func test_buys_of_a_missing_node_are_reported() -> void:
	assert_eq(_progression.buys(null), 0)
	assert_push_error("[Contract] Pre-condition broken: node must be set")
