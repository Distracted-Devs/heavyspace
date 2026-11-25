extends GutTest

const STEPS := 30

var _was_enabled: bool
var _camera: Camera3D
var _mesh: Node3D
var _fade: ColorRect
var _effect: WarpEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_camera = add_child_autofree(Camera3D.new())
	_camera.fov = 75.0
	_mesh = add_child_autofree(Node3D.new())
	_mesh.scale = Vector3(1.0, 1.0, 2.0)
	_mesh.position = Vector3(0.0, 0.0, 1.0)
	_fade = add_child_autofree(ColorRect.new())
	_fade.color = Color(1.0, 1.0, 1.0, 0.0)
	_effect = WarpEffect.new()
	_effect.camera = _camera
	_effect.mesh = _mesh
	_effect.fade = _fade
	_effect.set_process(false)
	add_child_autofree(_effect)
	watch_signals(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _values() -> Array[float]:
	return [_camera.fov, _mesh.scale.z, -_mesh.position.z, _fade.color.a]


func test_reaches_its_end_values_at_the_duration() -> void:
	_effect.play()
	_effect.advance(_effect.warp_duration)
	assert_almost_eq(_camera.fov, 130.0, 1e-4)
	assert_almost_eq(_mesh.scale.z, 12.0, 1e-4)
	assert_almost_eq(_mesh.position.z, 1.0 - 400.0, 1e-3)
	assert_almost_eq(_fade.color.a, 1.0, 1e-6)
	assert_false(_effect.playing)


func test_emits_finished_once() -> void:
	_effect.play()
	for step in STEPS * 2:
		_effect.advance(_effect.warp_duration / STEPS)
	assert_signal_emit_count(_effect, "finished", 1)


func test_advancing_after_the_end_changes_nothing() -> void:
	_effect.play()
	_effect.advance(_effect.warp_duration)
	var ended := _values()
	_effect.advance(1.0)
	assert_eq(_values(), ended)


func test_every_value_only_moves_towards_its_end() -> void:
	_effect.play()
	var last := _values()
	for step in STEPS:
		_effect.advance(_effect.warp_duration / STEPS)
		var now := _values()
		for index in now.size():
			assert_gte(now[index], last[index] - 1e-5, str(step, " ", index))
		last = now


func test_the_stretch_and_fov_finish_at_the_stretch_fraction() -> void:
	_effect.play()
	_effect.advance(_effect.warp_duration * _effect.stretch_fraction)
	assert_almost_eq(_camera.fov, 130.0, 1e-4)
	assert_almost_eq(_mesh.scale.z, 12.0, 1e-4)
	assert_true(_effect.playing)


func test_the_fade_waits_for_fade_start() -> void:
	_effect.play()
	_effect.advance(_effect.warp_duration * _effect.fade_start * 0.99)
	assert_eq(_fade.color.a, 0.0)
	_effect.advance(_effect.warp_duration * 0.25)
	assert_between(_fade.color.a, 0.0, 1.0)
	assert_gt(_fade.color.a, 0.0)


func test_the_shot_eases_in() -> void:
	_effect.play()
	_effect.advance(_effect.warp_duration * 0.5)
	assert_lt(1.0 - _mesh.position.z, 400.0 * 0.1)


func test_works_without_a_fade() -> void:
	_effect.fade = null
	_effect.play()
	_effect.advance(_effect.warp_duration)
	assert_signal_emit_count(_effect, "finished", 1)


func test_playing_twice_is_reported() -> void:
	_effect.play()
	_effect.play()
	assert_push_error("the warp must not already play")


func test_missing_parts_are_reported_and_nothing_plays() -> void:
	_effect.mesh = null
	_effect.play()
	assert_push_error("camera and mesh must be set")
	assert_false(_effect.playing)


func test_bad_values_are_reported_and_ignored() -> void:
	_effect.warp_duration = 0.0
	_effect.warp_fov = 180.0
	_effect.warp_distance = -1.0
	_effect.stretch = 0.5
	_effect.stretch_fraction = 0.0
	_effect.fade_start = 1.0
	assert_push_error("warp_duration must be positive")
	assert_push_error("warp_fov must be within (0, 180)")
	assert_push_error("warp_distance must not be negative")
	assert_push_error("stretch must be at least 1")
	assert_push_error("stretch_fraction must be within (0, 1]")
	assert_push_error("fade_start must be within [0, 1)")
	assert_eq(_effect.warp_duration, 1.5)
	assert_eq(_effect.stretch, 6.0)


func _reset_pose() -> void:
	_camera.fov = 75.0
	_mesh.scale = Vector3(1.0, 1.0, 2.0)
	_mesh.position = Vector3(0.0, 0.0, 1.0)
	_fade.color.a = 0.0


func test_warp_in_starts_at_the_warp_outs_end_pose() -> void:
	_effect.play_in()
	assert_almost_eq(_camera.fov, 130.0, 1e-4)
	assert_almost_eq(_mesh.scale.z, 12.0, 1e-4)
	assert_almost_eq(_mesh.position.z, 1.0 - 400.0, 1e-3)
	assert_almost_eq(_fade.color.a, 1.0, 1e-6)
	assert_true(_effect.playing)
	assert_true(_effect.playing_in)


func test_warp_in_ends_back_at_the_start_pose() -> void:
	_effect.play_in()
	_effect.advance(_effect.warp_duration)
	assert_almost_eq(_camera.fov, 75.0, 1e-4)
	assert_almost_eq(_mesh.scale.z, 2.0, 1e-4)
	assert_almost_eq(_mesh.position.z, 1.0, 1e-4)
	assert_almost_eq(_fade.color.a, 0.0, 1e-6)
	assert_false(_effect.playing)
	assert_false(_effect.playing_in)
	assert_signal_emit_count(_effect, "finished", 1)


func test_warp_in_mirrors_the_warp_out() -> void:
	_effect.play()
	_effect.advance(_effect.warp_duration * 0.3)
	var out := _values()
	_effect.advance(_effect.warp_duration)
	_reset_pose()
	_effect.play_in()
	_effect.advance(_effect.warp_duration * 0.7)
	var back := _values()
	for index in out.size():
		assert_almost_eq(back[index], out[index], 1e-3)


func test_warp_in_only_moves_towards_the_start_pose() -> void:
	_effect.play_in()
	var previous := _values()
	for step in STEPS:
		_effect.advance(_effect.warp_duration / STEPS)
		var now := _values()
		for index in now.size():
			assert_lte(now[index], previous[index] + 1e-4)
		previous = now


func test_warp_in_while_playing_is_reported() -> void:
	_effect.play()
	_effect.play_in()
	assert_push_error("the warp must not already play")
	assert_false(_effect.playing_in)


func test_play_in_on_ready_starts_the_warp_in() -> void:
	var effect := WarpEffect.new()
	effect.camera = _camera
	effect.mesh = _mesh
	effect.fade = _fade
	effect.play_in_on_ready = true
	effect.set_process(false)
	add_child_autofree(effect)
	assert_true(effect.playing_in)
	assert_almost_eq(_fade.color.a, 1.0, 1e-6)


func test_runs_by_itself_each_frame() -> void:
	_effect.set_process(true)
	_effect.warp_duration = 0.05
	_effect.play()
	await wait_seconds(0.2)
	assert_signal_emit_count(_effect, "finished", 1)


func test_intensity_is_zero_when_not_playing() -> void:
	assert_eq(_effect.intensity(), 0.0)


func test_intensity_rises_over_a_warp_out() -> void:
	_effect.play()
	_effect.advance(_effect.warp_duration * 0.25)
	assert_almost_eq(_effect.intensity(), 0.25, 1e-4)
	_effect.advance(_effect.warp_duration * 0.5)
	assert_almost_eq(_effect.intensity(), 0.75, 1e-4)


func test_intensity_falls_over_a_warp_in() -> void:
	_effect.play_in()
	assert_almost_eq(_effect.intensity(), 1.0, 1e-4)
	_effect.advance(_effect.warp_duration * 0.25)
	assert_almost_eq(_effect.intensity(), 0.75, 1e-4)
	_effect.advance(_effect.warp_duration)
	assert_eq(_effect.intensity(), 0.0)
