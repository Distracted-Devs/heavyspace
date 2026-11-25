class_name Minimap
extends CanvasLayer

const MARKER_SIZE := 0.16
const BODY_REACH := 1.5
const PATH_END_ALPHA := 0.25
const NEAR_RATIO := 0.01
const FAR_RATIO := 4.0
const BORDER_RATIO := 0.004

@export_group("Components")
@export var player: Player
@export var pool: LiveBodyPool
@export var frame: Panel
@export var border: Panel
@export var grid: ColorRect
@export var map_root: Node3D
@export var camera: Camera3D
@export var ship_marker: Node3D
@export var path: MeshInstance3D

@export_group("Colours")
@export var edible_colour := Color(0.3, 1.0, 0.5)
@export var danger_colour := Color(0.45, 0.25, 0.35, 0.45)
@export var ship_colour := Color.WHITE
@export var impact_colour := Color(1.0, 0.25, 0.2)
@export var escape_colour := Color(1.0, 0.8, 0.2)
@export var orbit_colour := Color(0.3, 1.0, 0.5)
@export var path_colour := Color(0.3, 0.9, 1.0)

@export_group("Layout")
@export_range(0.05, 1.0) var size_ratio := 0.34
@export_range(0.0, 0.2) var margin_ratio := 0.015
@export_range(16.0, 1024.0, 1.0, "or_greater") var min_size_px := 160.0

@export_group("View")
@export_range(0.0, 89.0) var camera_tilt_degrees := 35.0
@export_range(1.0, 3.0) var fit_padding := 1.15
@export_range(0.0, 3.0) var focus_fit := 1.2
@export_range(0.0, 20.0) var zoom_smoothing := 2.0
@export_range(1.0, 100000.0, 1.0, "or_greater") var min_view_radius := 150.0:
	set(value):
		var message := "min_view_radius must be positive"
		if not Contract.require(value > 0.0, message):
			return
		min_view_radius = value
@export_range(1.0, 100000.0, 1.0, "or_greater") var max_view_radius := 20000.0:
	set(value):
		if not Contract.require(
			value >= min_view_radius,
			"max_view_radius must be at least min_view_radius",
		):
			return
		max_view_radius = value

@export_group("Prediction")
@export_range(0.001, 1.0, 0.001) var step := 0.25
@export_range(1.0, 600.0, 1.0, "or_greater") var duration := 20.0
@export_range(1, 10000, 1, "or_greater") var max_steps := 2400
@export_range(0, 100, 1, "or_greater") var max_sources := 8
@export_range(1, 32, 1) var smoothing_segments := 8:
	set(value):
		var message := "smoothing_segments must be at least 1"
		if not Contract.require(value >= 1, message):
			return
		smoothing_segments = value

var view_radius := -1.0

var _predictor := PathPredictor.new()
var _path_mesh := ImmediateMesh.new()
var _sphere := SphereMesh.new()
var _edible_material: StandardMaterial3D
var _danger_material: StandardMaterial3D
var _map_bodies: Dictionary[int, MeshInstance3D] = { }
var _plane_normal := Vector3.UP
var _focus := Vector3.ZERO
var _focus_radius := 0.0
var _candidate_positions := PackedVector3Array()
var _candidate_masses := PackedFloat64Array()
var _candidate_radii := PackedFloat64Array()
var _candidate_depths := PackedInt32Array()


func _ready() -> void:
	_sphere.radius = 1.0
	_sphere.height = 2.0
	path.mesh = _path_mesh
	_edible_material = _flat_material(edible_colour)
	_danger_material = _flat_material(danger_colour)
	_danger_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var marker_material := _flat_material(ship_colour)
	marker_material.no_depth_test = true
	marker_material.render_priority = 10
	for child in ship_marker.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = marker_material
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _process(delta: float) -> void:
	refresh(delta)


func refresh(delta: float) -> void:
	if not Contract.require(player != null, "player must be set"):
		return
	_predictor.step = step
	_predictor.duration = duration
	_predictor.max_steps = max_steps
	_predictor.max_sources = max_sources
	var receiver := player.gravity_receiver
	_predictor.falloff_exponent = receiver.falloff_exponent
	_predictor.drift_enabled = receiver.drift_enabled
	var core_mass := receiver.core_mass()
	var positions := GravityRegistry.positions
	var masses := GravityRegistry.masses
	_gather_candidates()
	var focus := PathPredictor.focus_index(
		player.global_position,
		core_mass,
		_candidate_positions,
		_candidate_masses,
		_candidate_depths,
	)
	_focus = player.global_position
	_focus_radius = 0.0
	if focus >= 0:
		_focus = _candidate_positions[focus]
		_focus_radius = _candidate_radii[focus]
	_predictor.predict(
		player.global_position,
		player.linear_velocity,
		-player.global_basis.z,
		_alignment(),
		player.linear_damp,
		player.gravity_receiver.gravity_constant,
		positions,
		masses,
		GravityRegistry.radii,
		core_mass,
		_focus,
		receiver.drift,
	)
	_update_zoom(delta)
	_update_plane(delta)
	ship_marker.position = player.global_position - _focus
	ship_marker.basis = (
		Basis(player.global_basis.get_rotation_quaternion()).scaled(
			Vector3.ONE * view_radius * MARKER_SIZE
		)
	)
	_draw_path()
	_update_camera()
	_sync_bodies()
	Contract.invariant(
		view_radius >= min_view_radius and view_radius <= max_view_radius,
		"view_radius must be within [min_view_radius, max_view_radius]",
	)


func focus_position() -> Vector3:
	return _focus


func forecast() -> PathPredictor.Forecast:
	return _predictor.forecast


func forecast_colour() -> Color:
	match _predictor.forecast:
		PathPredictor.Forecast.IMPACT:
			return impact_colour
		PathPredictor.Forecast.ESCAPE:
			return escape_colour
		PathPredictor.Forecast.ORBIT:
			return orbit_colour
	return path_colour


func map_body_count() -> int:
	return _map_bodies.size()


func map_body_for(body: MassBody) -> MeshInstance3D:
	return _map_bodies.get(body.get_instance_id())


func edible_material() -> Material:
	return _edible_material


func danger_material() -> Material:
	return _danger_material


func _sync_bodies() -> void:
	var core_mass := player.gravity_receiver.core_mass()
	var reach := view_radius * BODY_REACH
	var wanted: Dictionary[int, MassBody] = { }
	for node in get_tree().get_nodes_in_group(MassBody.GROUP):
		var body := node as MassBody
		if body.global_position.distance_to(_focus) < reach + body.radius:
			wanted[body.get_instance_id()] = body
	for id in _map_bodies.keys():
		if not wanted.has(id):
			_map_bodies[id].queue_free()
			_map_bodies.erase(id)
	for id in wanted:
		var body := wanted[id]
		var map_body: MeshInstance3D = _map_bodies.get(id)
		if map_body == null:
			map_body = MeshInstance3D.new()
			map_body.mesh = _sphere
			map_root.add_child(map_body)
			_map_bodies[id] = map_body
		map_body.position = body.global_position - _focus
		map_body.scale = Vector3.ONE * body.radius
		map_body.material_override = (
			_danger_material if body.mass > core_mass else _edible_material
		)
		map_body.visible = not _blocks_view(map_body.position, body.radius)


func _blocks_view(centre: Vector3, radius: float) -> bool:
	var from := camera.position
	var to := ship_marker.position
	var along := to - from
	var t := 0.0
	if along.length_squared() > 0.0:
		t = clampf(
			(centre - from).dot(along) / along.length_squared(),
			0.0,
			1.0,
		)
	return centre.distance_to(from + along * t) < radius


func _gather_candidates() -> void:
	if pool == null:
		_candidate_positions = GravityRegistry.positions
		_candidate_masses = GravityRegistry.masses
		_candidate_radii = GravityRegistry.radii
		_candidate_depths.resize(_candidate_masses.size())
		_candidate_depths.fill(0)
		return
	var bodies := pool.live_bodies()
	var depths := pool.live_depths()
	var count := bodies.size() + (1 if pool.root_body else 0)
	_candidate_positions.resize(count)
	_candidate_masses.resize(count)
	_candidate_radii.resize(count)
	_candidate_depths.resize(count)
	for slot in bodies.size():
		_set_candidate(slot, bodies[slot], depths[slot])
	if pool.root_body:
		_set_candidate(bodies.size(), pool.root_body, 0)


func _set_candidate(slot: int, body: MassBody, depth: int) -> void:
	_candidate_positions[slot] = body.global_position
	_candidate_masses[slot] = body.mass
	_candidate_radii[slot] = body.radius
	_candidate_depths[slot] = depth


func _alignment() -> float:
	if player.arcade_flight == null:
		return 0.0
	return player.arcade_flight.alignment


func _update_zoom(delta: float) -> void:
	var ship_distance := player.global_position.distance_to(_focus)
	var target := maxf(ship_distance, _focus_radius * focus_fit)
	for point in _predictor.points:
		target = maxf(
			target,
			minf(point.distance_to(_focus), ship_distance * 2.0),
		)
	target = clampf(target * fit_padding, min_view_radius, max_view_radius)
	if view_radius < 0.0:
		view_radius = target
	else:
		view_radius = lerpf(
			view_radius,
			target,
			clampf(delta * zoom_smoothing, 0.0, 1.0),
		)


func _update_plane(delta: float) -> void:
	var normal := (
		player.global_position - _focus
	).cross(player.linear_velocity)
	if normal.length_squared() < 1.0e-4:
		return
	var weight := clampf(delta * 2.0, 0.0, 1.0)
	_plane_normal = _plane_normal.lerp(normal.normalized(), weight).normalized()


func _draw_path() -> void:
	_path_mesh.clear_surfaces()
	var points := smooth(_predictor.points, smoothing_segments)
	if points.size() < 2:
		return
	var colour := forecast_colour()
	_path_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for index in points.size():
		var faded := colour
		faded.a = lerpf(1.0, PATH_END_ALPHA, float(index) / (points.size() - 1))
		_path_mesh.surface_set_color(faded)
		_path_mesh.surface_add_vertex(points[index] - _focus)
	_path_mesh.surface_end()


static func smooth(
	points: PackedVector3Array,
	segments: int,
) -> PackedVector3Array:
	if points.size() < 2 or segments <= 1:
		return points
	var last := points.size() - 1
	var curve := PackedVector3Array()
	curve.resize(last * segments + 1)
	for span in last:
		var before := points[maxi(span - 1, 0)]
		var from := points[span]
		var to := points[span + 1]
		var after := points[mini(span + 2, last)]
		for step_index in segments:
			var t := float(step_index) / segments
			curve[span * segments + step_index] = from.cubic_interpolate(
				to,
				before,
				after,
				t,
			)
	curve[last * segments] = points[last]
	return curve


func _update_camera() -> void:
	var out := player.global_position - _focus
	if out.length_squared() < 1.0e-4:
		out = -player.global_basis.z
	out -= _plane_normal * out.dot(_plane_normal)
	if out.is_zero_approx():
		out = _plane_normal.cross(Vector3.RIGHT)
		if out.is_zero_approx():
			out = _plane_normal.cross(Vector3.FORWARD)
	out = out.normalized()
	var tilt := deg_to_rad(camera_tilt_degrees)
	var direction := (_plane_normal * cos(tilt) + out * sin(tilt)).normalized()
	var reach := view_radius / tan(deg_to_rad(camera.fov) * 0.5)
	camera.near = reach * NEAR_RATIO
	camera.far = reach * FAR_RATIO
	camera.position = direction * reach
	camera.look_at(Vector3.ZERO, out)


func _update_layout() -> void:
	var screen_height := get_viewport().get_visible_rect().size.y
	var size := maxf(min_size_px, screen_height * size_ratio)
	var margin := screen_height * margin_ratio
	frame.offset_left = -margin - size
	frame.offset_right = -margin
	frame.offset_top = margin
	frame.offset_bottom = margin + size
	(
		grid.material as ShaderMaterial
	).set_shader_parameter("size", Vector2(size, size))
	var line := maxf(2.0, roundf(screen_height * BORDER_RATIO))
	var shadow := frame.get_theme_stylebox("panel") as StyleBoxFlat
	shadow.shadow_offset = Vector2(line, line)
	(
		border.get_theme_stylebox("panel") as StyleBoxFlat
	).set_border_width_all(int(line))


func _flat_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material
