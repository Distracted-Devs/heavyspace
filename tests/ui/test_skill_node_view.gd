extends GutTest

const VIEW_SCENE := preload("res://scenes/ui/skill_node_view.tscn")

var _was_enabled: bool
var _progression: Progression
var _view: SkillNodeView


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_progression = Progression.new()
	_view = VIEW_SCENE.instantiate()
	add_child_autofree(_view)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _node(cost := 10.0, max_buys := 5, level := 0) -> SkillNode:
	var node := SkillNode.new()
	node.id = &"booster"
	node.title = "Booster strength +20%"
	node.effect = BoosterEffect.new()
	node.cost = cost
	node.max_buys = max_buys
	node.required_level = level
	return node


func _buy(node: SkillNode, times: int) -> void:
	for time in times:
		_progression.bank_mass(node.cost)
		_progression.buy(node)


func test_an_affordable_node_shows_its_cost_in_green() -> void:
	var node := _node()
	_progression.bank_mass(10.0)
	_view.show_node(node, _progression)
	assert_eq(_view.state, SkillNodeView.State.BUYABLE)
	assert_eq(_view.footer.text, "10Mkg")
	assert_eq(_view.footer_colour(), _view.green)
	assert_eq(_view.tab_colour(), _view.cyan)
	assert_eq(_view.border_colour(), _view.cyan)


func test_an_unaffordable_node_shows_its_cost_in_red() -> void:
	_view.show_node(_node(), _progression)
	assert_eq(_view.state, SkillNodeView.State.UNAFFORDABLE)
	assert_eq(_view.footer.text, "10Mkg")
	assert_eq(_view.footer_colour(), _view.red)
	assert_eq(_view.tab_colour(), _view.cyan)


func test_a_locked_node_shows_its_level_in_magenta() -> void:
	_progression.bank_mass(100.0)
	_view.show_node(_node(10.0, 5, 4), _progression)
	assert_eq(_view.state, SkillNodeView.State.LOCKED)
	assert_eq(_view.footer.text, "LOCKED | LV 4")
	assert_eq(_view.tab.text, "LV 4")
	assert_eq(_view.tab_colour(), _view.magenta)


func test_a_maxed_node_is_gold() -> void:
	var node := _node(10.0, 2)
	_buy(node, 2)
	_view.show_node(node, _progression)
	assert_eq(_view.state, SkillNodeView.State.MAXED)
	assert_eq(_view.footer.text, "MAXED")
	assert_eq(_view.footer_colour(), _view.gold)
	assert_eq(_view.tab_colour(), _view.gold)
	assert_eq(_view.border_colour(), _view.gold)


func test_maxed_wins_over_locked() -> void:
	var node := _node(1.0, 1, 0)
	_buy(node, 1)
	node.required_level = 50
	_view.show_node(node, _progression)
	assert_eq(_view.state, SkillNodeView.State.MAXED)


func test_one_slot_per_possible_buy_and_the_bought_ones_filled() -> void:
	var node := _node(10.0, 5)
	_buy(node, 2)
	_view.show_node(node, _progression)
	assert_eq(_view.slot_count, 5)
	assert_eq(_view.filled, 2)
	assert_eq(_view.count_text(), "2/5")


func test_the_title_is_upper_case_and_the_tab_shows_the_level() -> void:
	_view.show_node(_node(10.0, 5, 0), _progression)
	assert_string_starts_with(_view.text, "BOOSTER STRENGTH +20%")
	assert_eq(_view.tab.text, "LV 0")


func test_a_missing_node_is_reported_and_changes_nothing() -> void:
	_view.show_node(null, _progression)
	assert_push_error("a valid node and a progression must be set")
	assert_eq(_view.footer.text, "")
	assert_eq(_view.slot_count, 0)


func test_showing_an_unchanged_node_again_restyles_nothing() -> void:
	var node := _node()
	_view.show_node(node, _progression)
	_view.footer.text = "untouched"
	_view.show_node(node, _progression)
	assert_eq(_view.footer.text, "untouched")
	_progression.bank_mass(10.0)
	_view.show_node(node, _progression)
	assert_eq(_view.footer.text, "10Mkg")
