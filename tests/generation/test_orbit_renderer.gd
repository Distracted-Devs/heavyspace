extends GutTest

const PARENT_RADIUS := 50.0
const BAD_INDEX := (
	"[Contract] Pre-condition broken: "
	+ "index must be within the drawn children"
)

var _was_enabled: bool
var _renderer: OrbitRenderer
var _layout: TierLayout


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	var tier := Tier.new()
	tier.plane_tilt_max_degrees = 40.0
	_layout = TierGenerator.generate(
		1,
		PackedInt32Array([2]),
		PARENT_RADIUS,
		tier,
	)
	_renderer = add_child_autofree(OrbitRenderer.new())
	_renderer.show_layout(_layout)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_one_instance_per_child() -> void:
	assert_gt(_layout.size(), 0)
	assert_eq(_renderer.count(), _layout.size())
	assert_eq(_renderer.multimesh.instance_count, _layout.size())


func test_instances_carry_their_child_radius_and_orbit() -> void:
	for index in _layout.size():
		var orbit := _renderer.instance_orbit(index)
		assert_almost_eq(
			_renderer.instance_radius(index),
			_layout.radius[index],
			1.0e-5,
		)
		assert_almost_eq(orbit.x, _layout.orbit_radius[index], 1.0e-4)
		assert_almost_eq(orbit.y, _layout.height[index], 1.0e-5)
		assert_almost_eq(orbit.z, _layout.phase[index], 1.0e-5)
		assert_almost_eq(orbit.w, _layout.angular_speed[index], 1.0e-7)


func test_every_instance_starts_visible_and_untinted() -> void:
	for index in _layout.size():
		assert_false(_renderer.is_hidden(index))
		assert_eq(_renderer.tint(index), OrbitRenderer.UNTINTED)


func test_node_basis_is_the_ring_plane() -> void:
	assert_true(_renderer.basis.is_equal_approx(_layout.plane))


func test_culling_box_holds_every_child_at_every_time() -> void:
	var bounds := _renderer.multimesh.custom_aabb.grow(1.0e-3)
	for time in [0.0, 7.0, 31.0, 400.0]:
		for index in _layout.size():
			var local := _renderer.global_transform.affine_inverse() * (
				_renderer.child_position(index, time)
			)
			assert_true(bounds.has_point(local))


func test_child_position_follows_the_orbit_in_world_space() -> void:
	_renderer.global_position = Vector3(100.0, -20.0, 5.0)
	var index := _layout.size() - 1
	var local := Orbit.position(
		_layout.orbit_radius[index],
		_layout.height[index],
		_layout.phase[index],
		_layout.angular_speed[index],
		12.0,
	)
	var expected := _renderer.global_transform * local
	var actual := _renderer.child_position(index, 12.0)
	assert_almost_eq(actual.distance_to(expected), 0.0, 1.0e-4)


func test_moving_the_renderer_moves_its_children() -> void:
	var before := _renderer.child_position(0, 3.0)
	_renderer.global_position += Vector3(10.0, 0.0, 0.0)
	var after := _renderer.child_position(0, 3.0)
	assert_almost_eq(after.x - before.x, 10.0, 1.0e-4)


func test_hiding_keeps_the_tint() -> void:
	_renderer.set_tint(0, Color.RED)
	_renderer.set_hidden(0, true)
	assert_true(_renderer.is_hidden(0))
	assert_eq(_renderer.tint(0), Color.RED)
	_renderer.set_hidden(0, false)
	assert_false(_renderer.is_hidden(0))


func test_tinting_keeps_the_hidden_state() -> void:
	_renderer.set_hidden(1, true)
	_renderer.set_tint(1, Color.GREEN)
	assert_true(_renderer.is_hidden(1))
	assert_eq(_renderer.tint(1), Color.GREEN)


func test_changing_one_instance_leaves_the_others_alone() -> void:
	_renderer.set_hidden(0, true)
	_renderer.set_tint(0, Color.RED)
	assert_false(_renderer.is_hidden(1))
	assert_eq(_renderer.tint(1), OrbitRenderer.UNTINTED)


func test_showing_a_new_layout_replaces_the_old_one() -> void:
	_renderer.set_hidden(0, true)
	var empty := TierLayout.new()
	_renderer.show_layout(empty)
	assert_eq(_renderer.count(), 0)
	_renderer.show_layout(_layout)
	assert_eq(_renderer.count(), _layout.size())
	assert_false(_renderer.is_hidden(0))


func test_drawn_mesh_is_a_low_poly_unit_sphere_with_the_orbit_shader() -> void:
	var mesh := _renderer.multimesh.mesh as SphereMesh
	assert_not_null(mesh)
	assert_eq(mesh.radius, 1.0)
	assert_eq(mesh.radial_segments, _renderer.proxy_segments)
	var material := mesh.material as ShaderMaterial
	assert_eq(material.shader, OrbitRenderer.SHADER)


func test_missing_layout_is_reported() -> void:
	_renderer.show_layout(null)
	assert_push_error(
		"[Contract] Pre-condition broken: layout must not be null"
	)
	assert_eq(_renderer.count(), _layout.size())


func test_out_of_range_index_is_reported() -> void:
	_renderer.set_hidden(_layout.size(), true)
	assert_push_error(BAD_INDEX)
	_renderer.set_tint(-1, Color.RED)
	assert_push_error(BAD_INDEX)


func test_child_velocity_is_the_rate_of_change_of_child_position() -> void:
	_renderer.global_position = Vector3(30.0, 0.0, -10.0)
	var step := 1.0e-2
	for index in [0, _layout.size() - 1]:
		var before := _renderer.child_position(index, 5.0 - step)
		var after := _renderer.child_position(index, 5.0 + step)
		var estimate := (after - before) / (2.0 * step)
		var velocity := _renderer.child_velocity(index, 5.0)
		assert_almost_eq(estimate.distance_to(velocity), 0.0, 1.0e-3)


func test_child_positions_match_child_position() -> void:
	_renderer.global_position = Vector3(3.0, 4.0, 5.0)
	for time in [0.0, 9.0]:
		var positions := _renderer.child_positions(time)
		assert_eq(positions.size(), _layout.size())
		for index in _layout.size():
			var expected := _renderer.child_position(index, time)
			assert_almost_eq(
				positions[index].distance_to(expected),
				0.0,
				1.0e-3,
			)


func test_child_positions_follow_the_renderer_when_it_moves() -> void:
	var before := _renderer.child_positions(2.0)[0]
	_renderer.global_position += Vector3(0.0, 7.0, 0.0)
	var after := _renderer.child_positions(2.0)[0]
	assert_almost_eq(after.y - before.y, 7.0, 1.0e-4)


func test_every_child_stays_within_reach_of_the_centre() -> void:
	var reach := _renderer.reach()
	for time in [0.0, 13.0, 250.0]:
		for position in _renderer.child_positions(time):
			var gap := position.distance_to(_renderer.global_position)
			assert_lte(gap, reach)
