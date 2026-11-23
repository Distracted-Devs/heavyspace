extends GutTest

var _was_enabled: bool
var _predictor: PathPredictor


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_predictor = PathPredictor.new()


func after_each() -> void:
	Contract.enabled = _was_enabled


func _predict(positions: PackedVector3Array) -> void:
	var masses := PackedFloat64Array()
	var radii := PackedFloat64Array()
	for each in positions.size():
		masses.append(1000.0)
		radii.append(10.0)
	_predictor.predict(
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.FORWARD,
		0.0,
		0.0,
		10.0,
		positions,
		masses,
		radii,
		1.0,
		Vector3.ZERO,
	)


func test_all_sources_are_simulated_by_default() -> void:
	assert_eq(_predictor.max_sources, 0)
	_predict(
		PackedVector3Array([Vector3(1000.0, 0.0, 0.0), Vector3(0.0, 0.0, 40.0)])
	)
	assert_eq(_predictor.forecast, PathPredictor.Forecast.IMPACT)


func test_a_weak_source_left_out_doesnt_pull_the_path() -> void:
	_predictor.max_sources = 1
	var strong := Vector3(0.0, 0.0, 40.0)
	var weak := Vector3(0.0, 400.0, 0.0)
	_predict(PackedVector3Array([weak, strong]))
	for point in _predictor.points:
		assert_almost_eq(point.y, 0.0, 1.0e-4)


func test_the_strongest_sources_are_kept() -> void:
	_predictor.max_sources = 1
	_predict(
		PackedVector3Array(
			[
				Vector3(0.0, 900.0, 0.0),
				Vector3(0.0, 0.0, 40.0),
				Vector3(800.0, 0.0, 0.0),
			]
		)
	)
	assert_eq(_predictor.forecast, PathPredictor.Forecast.IMPACT)
	var last := _predictor.points[_predictor.points.size() - 1]
	assert_lt(last.distance_to(Vector3(0.0, 0.0, 40.0)), 12.0)


func test_negative_max_sources_is_reported_and_ignored() -> void:
	_predictor.max_sources = -1
	assert_push_error(
		"[Contract] Pre-condition broken: max_sources must not be negative"
	)
	assert_eq(_predictor.max_sources, 0)
