extends GutTest

const LEVEL_SCENE := preload("res://scenes/levels/generated_level.tscn")
const DELTA := 1.0 / 60.0
const FRAMES := 600
const BUDGET_MS := 4.0
const SEED := 42

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled


func after_each() -> void:
	Contract.enabled = _was_enabled


func _spawn_level(pickups_per_body: int) -> GeneratedLevel:
	var level: GeneratedLevel = LEVEL_SCENE.instantiate()
	var settings: SystemSettings = level.streamer.settings.duplicate(true)
	settings.level_seed = SEED
	settings.pickups_per_body = pickups_per_body
	level.streamer.settings = settings
	level.player.flight_input.capture_mouse = false
	return add_child_autofree(level)


func _average_frame_ms(level: GeneratedLevel) -> float:
	var orbits := level.streamer.orbit_system
	var receiver := level.player.gravity_receiver
	var started := Time.get_ticks_usec()
	for frame in FRAMES:
		orbits.time += DELTA
		orbits.update_positions()
		GravityRegistry._physics_process(DELTA)
		receiver.apply_gravity()
		level.streamer.update_streaming()
	return (Time.get_ticks_usec() - started) / 1000.0 / FRAMES


func _measure(pickups_per_body: int) -> Dictionary:
	var level := _spawn_level(pickups_per_body)
	await wait_physics_frames(2)
	Contract.enabled = false
	var average := _average_frame_ms(level)
	Contract.enabled = _was_enabled
	return { "bodies": level.streamer.live_slots().size(), "ms": average }


func test_default_system_frame_fits_a_quarter_of_the_60fps_budget() -> void:
	var result := await _measure(100)
	gut.p(
		"default system: %d live bodies, %.3f ms per frame"
		% [result.bodies, result.ms]
	)
	assert_lt(result.ms, BUDGET_MS)


func test_stress_system_stays_within_the_60fps_budget() -> void:
	var result := await _measure(400)
	gut.p(
		"stress system: %d live bodies, %.3f ms per frame"
		% [result.bodies, result.ms]
	)
	assert_lt(result.ms, 1000.0 / 60.0)


func test_real_physics_frames_fit_the_60fps_budget() -> void:
	var level := _spawn_level(100)
	await wait_physics_frames(10)
	var total := 0.0
	var samples := 120
	for sample in samples:
		await wait_physics_frames(1)
		total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var average_ms := total / samples * 1000.0
	gut.p(
		"engine physics frame: %d live bodies, %.3f ms"
		% [level.streamer.live_slots().size(), average_ms]
	)
	assert_lt(average_ms, 1000.0 / 60.0)
