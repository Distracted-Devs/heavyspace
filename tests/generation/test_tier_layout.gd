extends GutTest


func test_new_layout_is_empty_and_flat() -> void:
	var layout := TierLayout.new()
	assert_eq(layout.size(), 0)
	assert_eq(layout.plane, Basis.IDENTITY)


func test_append_adds_one_child_to_every_array() -> void:
	var layout := TierLayout.new()
	layout.append(2.0, 64.0, 90.0, -1.5, 0.25, 0.1)
	layout.append(1.0, 8.0, 100.0, 3.0, 4.0, -0.2)
	assert_eq(layout.size(), 2)
	assert_eq(layout.mass.size(), 2)
	assert_eq(layout.orbit_radius.size(), 2)
	assert_eq(layout.height.size(), 2)
	assert_eq(layout.phase.size(), 2)
	assert_eq(layout.angular_speed.size(), 2)


func test_append_stores_values_at_the_same_index() -> void:
	var layout := TierLayout.new()
	layout.append(2.0, 64.0, 90.0, -1.5, 0.25, 0.1)
	layout.append(1.0, 8.0, 100.0, 3.0, 4.0, -0.2)
	assert_eq(layout.radius[1], 1.0)
	assert_eq(layout.mass[1], 8.0)
	assert_eq(layout.orbit_radius[1], 100.0)
	assert_eq(layout.height[1], 3.0)
	assert_eq(layout.phase[1], 4.0)
	assert_eq(layout.angular_speed[1], -0.2)
