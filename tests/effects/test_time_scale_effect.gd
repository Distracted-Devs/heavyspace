extends GutTest

const STEP := 1.0 / 60.0

var _was_enabled: bool
var _effect: TimeScaleEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_effect = TimeScaleEffect.new()
	_effect.set_process(false)
	add_child_autofree(_effect)
	watch_signals(_effect)


func after_each() -> void:
	Engine.time_scale = 1.0
	Contract.enabled = _was_enabled


func _run(seconds: float) -> void:
	for step in roundi(seconds / STEP):
		_effect.update(STEP)


func test_normal_speed_until_played() -> void:
	_run(0.5)
	assert_eq(Engine.time_scale, 1.0)


func test_the_crash_freezes_then_slows() -> void:
	_effect.play()
	_effect.update(0.0)
	assert_almost_eq(Engine.time_scale, _effect.hitstop_scale, 1e-6)
	_run(_effect.hitstop_time + STEP)
	assert_lt(Engine.time_scale, 0.1, "slow motion starts near frozen")


func test_the_slow_motion_eases_back_to_normal() -> void:
	_effect.play()
	_run(_effect.hitstop_time + _effect.slowmo_time * 0.5)
	var halfway := Engine.time_scale
	var expected := lerpf(_effect.slowmo_scale, 1.0, 0.25)
	assert_almost_eq(halfway, expected, 0.02)
	_run(_effect.slowmo_time)
	assert_eq(Engine.time_scale, 1.0)
	assert_false(_effect.playing)
	assert_signal_emit_count(_effect, "finished", 1)


func test_a_lost_game_plays_it() -> void:
	var lose: LoseController = autofree(LoseController.new())
	_effect.lose_controller = lose
	lose.lost_game.emit(add_child_autofree(Node3D.new()))
	assert_true(_effect.playing)


func test_leaving_the_tree_restores_normal_speed() -> void:
	_effect.play()
	_effect.update(0.0)
	remove_child(_effect)
	assert_eq(Engine.time_scale, 1.0)
	add_child(_effect)


func test_bad_settings_are_reported_and_ignored() -> void:
	_effect.hitstop_time = 0.0
	assert_push_error("hitstop_time must be positive")
	_effect.hitstop_scale = 0.0
	assert_push_error("hitstop_scale must be within (0, 1]")
	_effect.slowmo_scale = 1.5
	assert_push_error("slowmo_scale must be within (0, 1]")
	var slowmo_time := _effect.slowmo_time
	_effect.slowmo_time = -1.0
	assert_push_error("slowmo_time must be positive")
	assert_eq(_effect.slowmo_time, slowmo_time)
