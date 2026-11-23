extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const UPGRADES := "res://resources/progression/upgrades/"

var _was_enabled: bool
var _progression: Progression
var _size: Upgrade
var _booster: Upgrade
var _base_thrust: float
var _base_mass: float


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_progression = Progression.new()
	_size = load(UPGRADES + "starting_size_upgrade.tres")
	_booster = load(UPGRADES + "booster_upgrade.tres")
	var probe: Player = PLAYER_SCENE.instantiate()
	_base_thrust = probe.thruster.back_thrust_force
	_base_mass = probe.mass_component.starting_mass
	probe.free()


func after_each() -> void:
	Contract.enabled = _was_enabled


func _buy(upgrade: Upgrade, times: int) -> void:
	for time in times:
		_progression.bank_mass(upgrade.cost(_progression.level_of(upgrade)))
		_progression.buy(upgrade)


func _level(upgrades: Array[Upgrade]) -> RunStarter:
	var level := Node3D.new()
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	var starter := RunStarter.new()
	starter.player = player
	starter.upgrades = upgrades
	starter.progression = _progression
	level.add_child(starter)
	level.add_child(player)
	add_child_autofree(level)
	player.freeze = true
	return starter


func test_upgrades_are_applied_at_their_levels() -> void:
	_buy(_booster, 2)
	var starter := _level([_size, _booster])
	assert_almost_eq(
		starter.player.thruster.back_thrust_force,
		_base_thrust * _booster.multiplier(2),
		1e-4,
	)


func test_the_run_starts_at_the_upgraded_mass() -> void:
	_buy(_size, 1)
	var starter := _level([_size, _booster])
	assert_almost_eq(
		starter.player.mass_component.current_mass,
		_base_mass * _size.multiplier(1),
		1e-6,
	)
	assert_eq(starter.player.mass_component.starting_mass, _base_mass)


func test_starting_counts_one_run() -> void:
	var starter := _level([_size, _booster])
	assert_true(starter.started)
	assert_eq(_progression.runs, 1)


func test_entering_the_tree_again_applies_nothing_twice() -> void:
	_buy(_booster, 1)
	var starter := _level([_booster])
	var level := starter.get_parent()
	level.remove_child(starter)
	level.add_child(starter)
	assert_eq(_progression.runs, 1)
	assert_almost_eq(
		starter.player.thruster.back_thrust_force,
		_base_thrust * _booster.multiplier(1),
		1e-4,
	)


func test_a_ready_player_is_reported_and_not_upgraded() -> void:
	_buy(_booster, 1)
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	add_child_autofree(player)
	player.freeze = true
	var starter := RunStarter.new()
	starter.player = player
	starter.upgrades = [_booster]
	starter.progression = _progression
	add_child_autofree(starter)
	assert_push_error("player must be set and not yet ready")
	assert_false(starter.started)
	assert_eq(_progression.runs, 0)
	assert_eq(player.thruster.back_thrust_force, _base_thrust)


func test_duplicate_upgrades_are_reported_and_nothing_applied() -> void:
	_buy(_booster, 1)
	var starter := _level([_booster, _booster])
	assert_push_error("upgrades must be set with unique ids")
	assert_false(starter.started)
	assert_eq(starter.player.thruster.back_thrust_force, _base_thrust)


func test_without_a_progression_it_uses_the_autoload() -> void:
	var starter := RunStarter.new()
	starter.player = PLAYER_SCENE.instantiate()
	starter.progression = null
	var runs := RunProgress.progression.runs
	add_child_autofree(starter)
	assert_same(starter.progression, RunProgress.progression)
	assert_eq(RunProgress.progression.runs, runs + 1)
	starter.player.free()
