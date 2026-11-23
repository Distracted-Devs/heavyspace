extends GutTest

const POINTS := [
	Vector3(0.0, 0.0, 0.0),
	Vector3(10.0, 0.0, 0.0),
	Vector3(20.0, 0.0, 10.0),
	Vector3(20.0, 5.0, 30.0),
]


func _points() -> PackedVector3Array:
	return PackedVector3Array(POINTS)


func test_smoothing_adds_segments_per_span() -> void:
	var curve := Minimap.smooth(_points(), 8)
	assert_eq(curve.size(), 3 * 8 + 1)


func test_smoothed_curve_passes_through_every_point() -> void:
	var curve := Minimap.smooth(_points(), 8)
	for index in POINTS.size():
		assert_almost_eq(
			curve[index * 8].distance_to(POINTS[index]),
			0.0,
			1.0e-4,
		)


func test_smoothed_curve_bends_between_the_points() -> void:
	var curve := Minimap.smooth(_points(), 8)
	var middle := curve[8 + 4]
	var chord_middle := (POINTS[1] + POINTS[2]) * 0.5
	assert_gt(middle.distance_to(chord_middle), 0.01)


func test_too_few_points_come_back_unchanged() -> void:
	var one := PackedVector3Array([Vector3.ONE])
	assert_eq(Minimap.smooth(one, 8), one)


func test_the_minimap_defaults_are_the_agreed_coarse_ones() -> void:
	var map: Minimap = autofree(
		preload("res://scenes/ui/minimap.tscn").instantiate()
	)
	assert_eq(map.step, 0.25)
	assert_eq(map.duration, 20.0)
	assert_eq(map.max_sources, 8)
	assert_eq(map.smoothing_segments, 8)
