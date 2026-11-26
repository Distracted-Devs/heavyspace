extends GutTest

const G := 10.0
const BODY_MASS := 1000.0
const BODY_RADIUS := 10.0

var _was_enabled: bool
var _predictor: PathPredictor
var _positions: PackedVector3Array
var _masses: PackedFloat64Array
var _radii: PackedFloat64Array


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_predictor = PathPredictor.new()
	_positions = PackedVector3Array([Vector3.ZERO])
	_masses = PackedFloat64Array([BODY_MASS])
	_radii = PackedFloat64Array([BODY_RADIUS])


func after_each() -> void:
	Contract.enabled = _was_enabled


func _predict(
	position: Vector3,
	velocity: Vector3,
	mass := 1.0,
	forward := Vector3.FORWARD,
	alignment := 0.0,
) -> void:
	_predictor.predict(
		position,
		velocity,
		forward,
		alignment,
		0.0,
		G,
		_positions,
		_masses,
		_radii,
		mass,
		Vector3.ZERO,
	)


func _circular_speed(distance: float) -> float:
	return sqrt(G * BODY_MASS / distance)


func test_focus_is_the_heavier_source_pulling_hardest() -> void:
	var positions := PackedVector3Array(
		[
			Vector3(100.0, 0.0, 0.0),
			Vector3(30.0, 0.0, 0.0),
			Vector3(5.0, 0.0, 0.0),
		]
	)
	var masses := PackedFloat64Array([1.0e5, 2.0e4, 0.5])
	var depths := PackedInt32Array([1, 1, 1])
	assert_eq(
		PathPredictor.focus_index(Vector3.ZERO, 1.0, positions, masses, depths),
		1,
	)


func test_no_focus_when_nothing_is_heavier() -> void:
	var positions := PackedVector3Array([Vector3(5.0, 0.0, 0.0)])
	var masses := PackedFloat64Array([2.0])
	var depths := PackedInt32Array([1])
	assert_eq(
		PathPredictor.focus_index(Vector3.ZERO, 3.0, positions, masses, depths),
		-1,
	)


func test_focus_only_considers_the_tier_just_above() -> void:
	var positions := PackedVector3Array(
		[
			Vector3(10.0, 0.0, 0.0),
			Vector3(300.0, 0.0, 0.0),
			Vector3(2.0, 0.0, 0.0),
		]
	)
	var masses := PackedFloat64Array([1.0e7, 500.0, 0.5])
	var depths := PackedInt32Array([0, 1, 2])
	assert_eq(
		PathPredictor.focus_index(Vector3.ZERO, 1.0, positions, masses, depths),
		1,
	)


func test_focus_moves_up_a_tier_once_the_ship_outgrows_it() -> void:
	var positions := PackedVector3Array(
		[Vector3(10.0, 0.0, 0.0), Vector3(300.0, 0.0, 0.0)]
	)
	var masses := PackedFloat64Array([1.0e7, 500.0])
	var depths := PackedInt32Array([0, 1])
	assert_eq(
		PathPredictor.focus_index(
			Vector3.ZERO,
			600.0,
			positions,
			masses,
			depths,
		),
		0,
	)


func test_mismatched_focus_arrays_are_reported() -> void:
	PathPredictor.focus_index(
		Vector3.ZERO,
		1.0,
		PackedVector3Array([Vector3.ONE]),
		PackedFloat64Array([2.0]),
		PackedInt32Array(),
	)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "positions, masses and depths must be the same length"
	)


func test_path_starts_at_the_ship() -> void:
	_predict(Vector3(50.0, 0.0, 0.0), Vector3(0.0, 0.0, 5.0))
	assert_eq(_predictor.points[0], Vector3(50.0, 0.0, 0.0))


func test_falling_straight_in_forecasts_an_impact() -> void:
	_predict(Vector3(50.0, 0.0, 0.0), Vector3.ZERO)
	assert_eq(_predictor.forecast, PathPredictor.Forecast.IMPACT)
	var last := _predictor.points[_predictor.points.size() - 1]
	assert_lt(last.length(), BODY_RADIUS + 1.0)


func test_circular_orbit_forecasts_an_orbit() -> void:
	var distance := 50.0
	_predict(
		Vector3(distance, 0.0, 0.0),
		Vector3(0.0, 0.0, _circular_speed(distance)),
	)
	assert_eq(_predictor.forecast, PathPredictor.Forecast.ORBIT)


func test_escape_speed_forecasts_an_escape() -> void:
	var distance := 50.0
	_predict(
		Vector3(distance, 0.0, 0.0),
		Vector3(0.0, 0.0, _circular_speed(distance) * 3.0),
	)
	assert_eq(_predictor.forecast, PathPredictor.Forecast.ESCAPE)


func test_nothing_heavier_forecasts_an_escape_with_one_point() -> void:
	_predict(Vector3(50.0, 0.0, 0.0), Vector3.ZERO, BODY_MASS * 2.0)
	assert_eq(_predictor.forecast, PathPredictor.Forecast.ESCAPE)
	assert_eq(_predictor.points.size(), 1)


func test_full_alignment_runs_straight_along_the_facing() -> void:
	var start := Vector3(0.0, 0.0, 200.0)
	_predict(start, Vector3(5.0, 0.0, 0.0), 1.0, Vector3.FORWARD, 1.0)
	for point in _predictor.points:
		assert_almost_eq(point.x, 0.0, 1.0e-3)
		assert_almost_eq(point.y, 0.0, 1.0e-3)
	assert_lt(_predictor.points[1].z, start.z)


func test_full_alignment_into_a_body_forecasts_an_impact() -> void:
	_predict(
		Vector3(0.0, 0.0, 200.0),
		Vector3(30.0, 0.0, 0.0),
		1.0,
		Vector3.FORWARD,
		1.0,
	)
	assert_eq(_predictor.forecast, PathPredictor.Forecast.IMPACT)


func test_full_alignment_keeps_moving_forward_while_pulled_back() -> void:
	_predict(
		Vector3(0.0, 0.0, -50.0),
		Vector3(0.0, 0.0, -1.0),
		1.0,
		Vector3.FORWARD,
		1.0,
	)
	var points := _predictor.points
	for index in range(1, points.size()):
		assert_lte(points[index].z, points[index - 1].z + 1.0e-4)


func test_zero_alignment_matches_newtonian_flight() -> void:
	var distance := 50.0
	_predict(
		Vector3(distance, 0.0, 0.0),
		Vector3(0.0, 0.0, _circular_speed(distance)),
		1.0,
		Vector3.RIGHT,
		0.0,
	)
	assert_eq(_predictor.forecast, PathPredictor.Forecast.ORBIT)


func test_alignment_outside_zero_to_one_is_reported() -> void:
	_predict(Vector3(50.0, 0.0, 0.0), Vector3.ZERO, 1.0, Vector3.FORWARD, 1.5)
	assert_push_error(
		"[Contract] Pre-condition broken: alignment must be within [0, 1]"
	)


func test_zero_forward_is_reported() -> void:
	_predict(Vector3(50.0, 0.0, 0.0), Vector3.ZERO, 1.0, Vector3.ZERO, 1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: forward must not be zero"
	)


func test_path_is_capped_by_max_steps() -> void:
	_predictor.max_steps = 30
	_predict(Vector3(500.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
	assert_lte(
		_predictor.points.size(),
		floori(float(_predictor.max_steps) / _predictor.sample_every) + 2,
	)
	assert_eq(_predictor.step_count(), 30)


func test_mismatched_arrays_are_reported() -> void:
	_radii = PackedFloat64Array()
	_predict(Vector3(50.0, 0.0, 0.0), Vector3.ZERO)
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "positions, masses and radii must be the same length"
	)


func test_non_positive_step_is_reported_and_ignored() -> void:
	_predictor.step = 0.0
	assert_push_error("[Contract] Pre-condition broken: step must be positive")
	assert_almost_eq(_predictor.step, 1.0 / 30.0, 1.0e-9)


func test_the_falloff_exponent_changes_the_pull() -> void:
	_predictor.duration = 1.0
	_predict(Vector3(100.0, 0.0, 0.0), Vector3.ZERO)
	var squared := _predictor.points[-1].x
	_predictor.falloff_exponent = 3.0
	_predict(Vector3(100.0, 0.0, 0.0), Vector3.ZERO)
	assert_gt(_predictor.points[-1].x, squared, "a steeper falloff pulls less")


func test_with_drift_gravity_bends_a_fully_aligned_path() -> void:
	_predictor.drift_enabled = true
	_predictor.duration = 5.0
	var speed := 5.0
	_predict(
		Vector3(100.0, 0.0, 0.0),
		Vector3.FORWARD * speed,
		1.0,
		Vector3.FORWARD,
		1.0,
	)
	var end := _predictor.points[-1]
	assert_lt(end.x, 100.0, "the path must curve towards the body")


func test_without_drift_a_fully_aligned_path_stays_straight() -> void:
	_predictor.duration = 5.0
	_predict(
		Vector3(100.0, 0.0, 0.0),
		Vector3.FORWARD * 5.0,
		1.0,
		Vector3.FORWARD,
		1.0,
	)
	assert_almost_eq(_predictor.points[-1].x, 100.0, 1e-6)


func test_the_current_drift_carries_on_in_the_prediction() -> void:
	_predictor.drift_enabled = true
	_predictor.duration = 1.0
	var drift := Vector3(0.0, 10.0, 0.0)
	_predictor.predict(
		Vector3(1000.0, 0.0, 0.0),
		drift,
		Vector3.FORWARD,
		1.0,
		0.0,
		G,
		_positions,
		_masses,
		_radii,
		1.0,
		Vector3.ZERO,
		drift,
	)
	assert_gt(_predictor.points[-1].y, 5.0)


func test_non_positive_falloff_exponent_is_reported_and_ignored() -> void:
	var falloff_exponent := _predictor.falloff_exponent
	_predictor.falloff_exponent = 0.0
	assert_push_error("falloff_exponent must be positive")
	assert_eq(_predictor.falloff_exponent, falloff_exponent)


func test_a_step_that_jumps_through_a_body_still_forecasts_an_impact() -> void:
	_predictor.step = 1.0
	_predict(Vector3(0.0, 0.0, 30.0), Vector3.FORWARD * 200.0)
	assert_eq(_predictor.forecast, PathPredictor.Forecast.IMPACT)
	assert_lt(_predictor.points[-1].distance_to(Vector3.ZERO), 30.0)
