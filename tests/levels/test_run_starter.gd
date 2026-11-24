extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TREE := preload("res://resources/progression/skill_tree.tres")

var _was_enabled: bool
var _progression: Progression
var _base_thrust: float


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_progression = Progression.new()
	var probe: Player = PLAYER_SCENE.instantiate()
	_base_thrust = probe.thruster.back_thrust_force
	probe.free()


func after_each() -> void:
	Contract.enabled = _was_enabled


func _buy(id: StringName, times: int) -> void:
	var node := TREE.find(id)
	for time in times:
		_progression.bank_mass(node.cost)
		assert_true(_progression.buy(node), "buy %s" % id)


func _level(tree: SkillTree = TREE) -> RunStarter:
	var level := Node3D.new()
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	var starter := RunStarter.new()
	starter.player = player
	starter.tree = tree
	starter.progression = _progression
	level.add_child(starter)
	level.add_child(player)
	add_child_autofree(level)
	player.freeze = true
	return starter


func test_an_unbought_tree_changes_nothing() -> void:
	var starter := _level()
	assert_true(starter.started)
	assert_eq(starter.player.thruster.back_thrust_force, _base_thrust)
	assert_eq(starter.player.cargo.tanks, 1)


func test_each_effect_is_applied_once_with_its_summed_amount() -> void:
	_buy(&"tank_1", 1)
	_buy(&"booster", 3)
	_buy(&"tank_2", 2)
	var starter := _level()
	assert_eq(starter.player.cargo.tanks, 1 + 1 + 2)
	assert_almost_eq(
		starter.player.thruster.back_thrust_force,
		_base_thrust * (1.0 + 3 * 0.2),
		1e-4,
	)


func test_the_ability_is_switched_on_when_bought() -> void:
	_buy(&"tank_1", 1)
	_buy(&"booster", 2)
	_buy(&"refill_rate", 1)
	_buy(&"tank_2", 2)
	_buy(&"boost_missing_fuel", 1)
	var starter := _level()
	assert_eq(starter.player.missing_fuel_boost.bonus_per_missing, 1.0)


func test_without_a_tree_the_run_starts_unchanged() -> void:
	var starter := _level(null)
	assert_true(starter.started)
	assert_eq(starter.player.thruster.back_thrust_force, _base_thrust)


func test_starting_counts_one_run() -> void:
	var starter := _level()
	assert_true(starter.started)
	assert_eq(_progression.runs, 1)


func test_entering_the_tree_again_applies_nothing_twice() -> void:
	_buy(&"tank_1", 1)
	_buy(&"booster", 1)
	var starter := _level()
	var level := starter.get_parent()
	level.remove_child(starter)
	level.add_child(starter)
	assert_eq(_progression.runs, 1)
	assert_almost_eq(
		starter.player.thruster.back_thrust_force,
		_base_thrust * 1.2,
		1e-4,
	)


func test_a_ready_player_is_reported_and_not_changed() -> void:
	_buy(&"tank_1", 1)
	_buy(&"booster", 1)
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	add_child_autofree(player)
	player.freeze = true
	var starter := RunStarter.new()
	starter.player = player
	starter.tree = TREE
	starter.progression = _progression
	add_child_autofree(starter)
	assert_push_error("player must be set and not yet ready")
	assert_false(starter.started)
	assert_eq(_progression.runs, 0)
	assert_eq(player.thruster.back_thrust_force, _base_thrust)


func test_an_invalid_tree_is_reported_and_nothing_applied() -> void:
	_buy(&"tank_1", 1)
	var broken := SkillTree.new()
	broken.nodes = [TREE.nodes[0], TREE.nodes[0]]
	var starter := _level(broken)
	assert_push_error("the skill tree must be valid")
	assert_false(starter.started)
	assert_eq(starter.player.cargo.tanks, 1)
	assert_eq(_progression.runs, 0)


func test_without_a_progression_it_uses_the_autoload() -> void:
	var starter := RunStarter.new()
	starter.player = PLAYER_SCENE.instantiate()
	starter.progression = null
	var runs := RunProgress.progression.runs
	add_child_autofree(starter)
	assert_same(starter.progression, RunProgress.progression)
	assert_eq(RunProgress.progression.runs, runs + 1)
	starter.player.free()
