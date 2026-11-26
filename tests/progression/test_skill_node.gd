extends GutTest

const BOOSTER := preload(
	"res://resources/progression/effects/booster_effect.tres"
)

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func _node() -> SkillNode:
	var node := SkillNode.new()
	node.id = &"booster"
	node.effect = BOOSTER
	return node


func test_a_node_with_an_id_and_an_effect_is_valid() -> void:
	assert_true(_node().is_valid())


func test_a_node_without_an_id_or_effect_is_invalid() -> void:
	var nameless := _node()
	nameless.id = &""
	var pointless := _node()
	pointless.effect = null
	assert_false(nameless.is_valid())
	assert_false(pointless.is_valid())


func test_bad_numbers_are_reported_and_ignored() -> void:
	var node := _node()
	var step := node.step
	node.step = -1.0
	var cost := node.cost
	node.cost = 0.0
	var max_buys := node.max_buys
	node.max_buys = 0
	var required_level := node.required_level
	node.required_level = -1
	assert_push_error("step must not be negative")
	assert_push_error("cost must be positive")
	assert_push_error("max_buys must be at least 1")
	assert_push_error("required_level must not be negative")
	assert_eq(node.step, step)
	assert_eq(node.cost, cost)
	assert_eq(node.max_buys, max_buys)
	assert_eq(node.required_level, required_level)
