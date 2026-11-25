extends GutTest

const STEP := 1.0 / 60.0

var _was_enabled: bool
var _view: CameraComponent
var _effect: CameraShakeEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	var ship := Node3D.new()
	_view = CameraComponent.new()
	_view.camera = Camera3D.new()
	_view.add_child(_view.camera)
	_view.set_physics_process(false)
	ship.add_child(_view)
	add_child_autofree(ship)
	_effect = CameraShakeEffect.new()
	_effect.camera_component = _view
	_effect.set_process(false)
	add_child_autofree(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _run(seconds: float) -> float:
	var biggest := 0.0
	for step in roundi(seconds / STEP):
		_effect.update(STEP)
		biggest = maxf(biggest, absf(_view.camera.h_offset))
		biggest = maxf(biggest, absf(_view.camera.v_offset))
	return biggest


func test_still_without_trauma() -> void:
	assert_eq(_run(0.5), 0.0)


func test_trauma_shakes_the_camera_within_its_size() -> void:
	_effect.add_trauma(1.0)
	var biggest := _run(0.2)
	assert_gt(biggest, 0.0)
	assert_lte(biggest, _effect.shake_offset * _view.distance + 1e-6)


func test_trauma_decays_to_stillness() -> void:
	_effect.add_trauma(1.0)
	_run(1.0 / _effect.shake_decay + 0.1)
	assert_eq(_effect.trauma, 0.0)
	assert_eq(_view.camera.h_offset, 0.0)


func test_a_lost_game_adds_the_death_shake() -> void:
	var lose: LoseController = autofree(LoseController.new())
	_effect.lose_controller = lose
	lose.lost_game.emit(_view)
	assert_almost_eq(_effect.trauma, _effect.death_shake, 1e-6)


func test_a_warp_holds_the_shake_up() -> void:
	var warp := WarpEffect.new()
	warp.camera = add_child_autofree(Camera3D.new())
	warp.mesh = add_child_autofree(Node3D.new())
	warp.set_process(false)
	add_child_autofree(warp)
	_effect.warp_effect = warp
	warp.play_in()
	assert_almost_eq(_effect.shake(), _effect.warp_shake, 1e-6)
	assert_gt(_run(0.1), 0.0)


func test_negative_trauma_is_reported_and_ignored() -> void:
	_effect.add_trauma(-1.0)
	assert_push_error("amount must not be negative")
	assert_eq(_effect.trauma, 0.0)


func test_bad_settings_are_reported_and_ignored() -> void:
	_effect.shake_decay = 0.0
	assert_push_error("shake_decay must be positive")
	_effect.death_shake = -1.0
	assert_push_error("death_shake must not be negative")
	_effect.shake_frequency = 0.0
	assert_push_error("shake_frequency must be positive")
	assert_eq(_effect.shake_decay, 1.2)
