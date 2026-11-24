extends GutTest

const TUNED := preload("res://resources/progression/skill_tree.tres")
const EFFECTS := "res://resources/progression/effects/%s_effect.tres"
const TANKS := preload(
	"res://resources/progression/effects/cargo_tanks_effect.tres"
)
const BOOSTER := preload(
	"res://resources/progression/effects/booster_effect.tres"
)

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func _node(id: StringName, effect: SkillEffect, step: float) -> SkillNode:
	var node := SkillNode.new()
	node.id = id
	node.effect = effect
	node.step = step
	return node


func _tree() -> SkillTree:
	var tree := SkillTree.new()
	tree.nodes = [
		_node(&"tank_a", TANKS, 1.0),
		_node(&"booster", BOOSTER, 0.2),
		_node(&"tank_b", TANKS, 1.0),
	]
	return tree


func test_a_tree_with_unique_valid_nodes_is_valid() -> void:
	assert_true(_tree().is_valid())


func test_a_repeated_id_or_missing_node_makes_it_invalid() -> void:
	var repeated := _tree()
	repeated.nodes[2].id = &"tank_a"
	var holed := _tree()
	holed.nodes[1] = null
	assert_false(repeated.is_valid())
	assert_false(holed.is_valid())


func test_find_returns_the_node_with_that_id_or_null() -> void:
	var tree := _tree()
	assert_eq(tree.find(&"booster"), tree.nodes[1])
	assert_null(tree.find(&"nothing"))


func test_effects_lists_each_shared_effect_once_in_order() -> void:
	assert_eq(_tree().effects(), [TANKS, BOOSTER] as Array[SkillEffect])


func test_amount_sums_step_times_buys_over_nodes_sharing_the_effect() -> void:
	var levels := { &"tank_a": 1, &"tank_b": 2, &"booster": 3 }
	assert_almost_eq(_tree().amount(TANKS, levels), 3.0, 1e-6)
	assert_almost_eq(_tree().amount(BOOSTER, levels), 0.6, 1e-6)


func test_unbought_nodes_add_nothing() -> void:
	assert_eq(_tree().amount(TANKS, { }), 0.0)


func test_negative_buys_are_reported_and_give_nothing() -> void:
	assert_eq(_tree().amount(TANKS, { &"tank_a": -1 }), 0.0)
	assert_push_error("buys must not be negative")


func test_the_tuned_tree_is_valid() -> void:
	assert_true(TUNED.is_valid())


func test_the_tuned_tree_holds_the_accepted_values() -> void:
	var efficiency := [&"mass_efficiency", "mass_efficiency", 0.15]
	var expected := [
		[&"tank_1", "cargo_tanks", 1.0, 5.0, 1, 0, Vector2(0, 0)],
		[&"fuel_tank", "fuel_tank", 0.25, 10.0, 5, 1, Vector2(1, -1)],
		[&"refill_rate", "refill_rate", 0.1, 10.0, 5, 1, Vector2(1, 0)],
		[&"booster", "booster", 0.2, 10.0, 5, 1, Vector2(1, 1)],
		[&"tank_2", "cargo_tanks", 1.0, 25.0, 2, 4, Vector2(2, 0)],
		[&"pickup_radius", "pickup_radius", 0.2, 10.0, 5, 6, Vector2(3, -2)],
		[&"mining", "mining", 0.2, 10.0, 5, 6, Vector2(3, -1)],
		[
			&"boost_missing_fuel",
			"missing_fuel_boost",
			1.0,
			15.0,
			1,
			6,
			Vector2(3, 0),
		],
		[&"manoeuvring", "manoeuvring", 0.2, 10.0, 5, 6, Vector2(3, 1)],
		efficiency + [10.0, 5, 6, Vector2(3, 2)],
		[&"tank_3", "cargo_tanks", 1.0, 25.0, 1, 15, Vector2(4, 0)],
	]
	assert_eq(TUNED.nodes.size(), expected.size())
	for index in expected.size():
		var want: Array = expected[index]
		var node: SkillNode = TUNED.nodes[index]
		assert_eq(node.id, want[0])
		assert_eq(node.effect, load(EFFECTS % want[1]), node.id)
		assert_almost_eq(node.step, want[2], 1e-6, node.id)
		assert_eq(node.cost, want[3], node.id)
		assert_eq(node.max_buys, want[4], node.id)
		assert_eq(node.required_level, want[5], node.id)
		assert_eq(node.grid, want[6], node.id)
		assert_ne(node.title, "", node.id)
