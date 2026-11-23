extends GutTest

const LEVEL_PATH := "res://scenes/levels/generated_level.tscn"
const STEP := 1.0 / 60.0
const FRAME_BUDGET_MS := 16.6
const MEAN_BUDGET_MS := 2.0
const FLIGHT_SPEED := 300.0

var _level: Node3D
var _player: Player
var _streamer: HierarchyStreamer
var _pool: LiveBodyPool
var _tint: MassTintDebug


func before_each() -> void:
	var scene: PackedScene = load(LEVEL_PATH)
	_level = scene.instantiate()
	_player = _level.get_node("Player")
	_player.flight_input.capture_mouse = false
	add_child_autofree(_level)
	_streamer = _level.get_node("HierarchyStreamer")
	_pool = _level.get_node("LiveBodyPool")
	_tint = _level.get_node("MassTintDebug")


func _frame_ms(focus: Vector3, time: float) -> float:
	var start := Time.get_ticks_usec()
	_streamer.update(focus, time)
	_pool.update(focus, time)
	_tint._process(STEP)
	return (Time.get_ticks_usec() - start) / 1000.0


func _fly(velocity: Vector3, frames: int) -> PackedFloat64Array:
	var focus := _player.global_position
	var time := 0.0
	var timings := PackedFloat64Array()
	for frame in frames:
		time += STEP
		focus += velocity * STEP
		timings.append(_frame_ms(focus, time))
	return timings


func _report(scenario: String, timings: PackedFloat64Array) -> void:
	var total := 0.0
	var worst := 0.0
	for timing in timings:
		total += timing
		worst = maxf(worst, timing)
	var mean := total / timings.size()
	gut.p(
		"%s: mean %.2fms, worst %.2fms, live %d, drawn %d"
		% [
			scenario,
			mean,
			worst,
			_pool.live_count(),
			_streamer.expanded_paths().size(),
		]
	)
	assert_lt(mean, MEAN_BUDGET_MS, "%s mean frame" % scenario)
	assert_lt(worst, FRAME_BUDGET_MS, "%s worst frame" % scenario)


func _nearest_other_system() -> Vector3:
	var systems := _streamer.renderer_for(PackedInt32Array())
	var positions := systems.child_positions(0.0)
	var nearest := Vector3.INF
	for index in range(1, positions.size()):
		var gap := positions[index].distance_to(_player.global_position)
		if gap < nearest.distance_to(_player.global_position):
			nearest = positions[index]
	return nearest


func test_orbiting_the_home_system_stays_within_budget() -> void:
	_report("orbiting", _fly(_player.linear_velocity, 120))


func test_flying_through_the_systems_stays_within_budget() -> void:
	var heading := _player.global_position.direction_to(_nearest_other_system())
	var velocity := _player.linear_velocity + heading * FLIGHT_SPEED
	_report("flying", _fly(velocity, 240))
