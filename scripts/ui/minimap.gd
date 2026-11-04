class_name OrbitMinimap
extends CanvasLayer
## Sci-fi wireframe 3D minimap for the Player (scripts/player/player_controller.gd).
##
## - Reads the ship's rotation, velocity and mass from its RigidBody3D.
## - Predicts the path if the player touches nothing, using the same gravity as
##   Player._apply_gravity() plus the ship's linear damping.
## - Every node in the "bodies" group is drawn as a wireframe planet.
## - Size, zoom and line sizes all scale with the screen and the orbit, so it
##   works for any planet size or distance.
##
## Usage: instance orbit_minimap.tscn in a scene that has a Player.

## Leave empty to use the first Player found in the current scene.
@export var player: Player

@export_group("Layout")
## Height of the 3D view as a fraction of the screen height.
@export_range(0.05, 1.0) var size_ratio: float = 0.25
## Width / height of the 3D view.
@export var aspect: float = 1.15
## Distance from the top-right corner as a fraction of the screen height.
@export_range(0.0, 0.2) var margin_ratio: float = 0.015
@export var min_height_px: float = 120.0

@export_group("View")
## Camera angle away from straight down on the orbit plane, in degrees.
@export var camera_tilt_degrees: float = 35.0
## Extra room around the orbit (1 = tight fit).
@export var fit_padding: float = 1.3
## How quickly the map zooms to fit the orbit.
@export var zoom_smoothing: float = 2.0

@export_group("Prediction")
## How far ahead the path is simulated when not in a closed orbit, in seconds.
@export var path_seconds: float = 60.0
## In a closed orbit the path covers one full revolution, capped at this.
@export var max_path_seconds: float = 400.0
@export var path_step: float = 1.0 / 15.0
## The lowest point of the orbit must clear the surface by this fraction of the
## planet radius to count as stable.
@export var stable_margin: float = 0.02
## Flash speed of the path in Hz while the orbit is unstable.
@export var flash_hz: float = 2.0
## How much of the flown path is kept, in seconds.
@export var trail_seconds: float = 60.0
@export var trail_interval: float = 0.1
## Dashed limit ring at this altitude above the focused planet. 0 = hidden.
@export var limit_altitude: float = 0.0

const HOLO_COLOUR := Color(0.3, 0.9, 1.0)
const PLANET_FILL_COLOUR := Color(0.0, 0.05, 0.08)
const TRAIL_COLOUR := Color(0.3, 0.9, 1.0)
const PATH_STABLE_COLOUR := Color(0.3, 1.0, 0.5)
const PATH_UNSTABLE_COLOUR := Color(1.0, 0.25, 0.2)
const LIMIT_COLOUR := Color(1.0, 0.45, 0.2, 0.8)
const SHIP_COLOUR := Color(1.0, 0.15, 0.15)

const LATITUDE_LINES := 8
const LONGITUDE_LINES := 12
const RING_SEGMENTS := 48
## Ship marker length as a fraction of the visible radius.
const MARKER_SIZE := 0.12
const SCANLINE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.3, 0.9, 1.0, 0.05);
void fragment() {
	float line = step(0.5, fract(FRAGCOORD.y / 3.0));
	// Slightly brighter towards the edges, like a hologram frame.
	vec2 edge = abs(UV - 0.5) * 2.0;
	float vignette = smoothstep(0.6, 1.0, max(edge.x, edge.y));
	COLOR = vec4(tint.rgb, tint.a * line + vignette * 0.08);
}
"""

# UI
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _title: Label
var _frame: Control
var _label: Label

# 3D map. Everything is placed relative to the focused planet, so the map
# works no matter how far from the world origin things are.
var _root: Node3D
var _camera: Camera3D
var _ship_marker: Node3D
var _trail_mesh: ImmediateMesh
var _path_mesh: ImmediateMesh
var _limit_mesh: ImmediateMesh
var _planet_wire: ImmediateMesh # unit sphere, shared by every planet
var _planet_nodes := { } # body Node3D -> map Node3D

# State
var _trail: PackedVector3Array = []
var _trail_timer := 0.0
var _predicted: PackedVector3Array = []
var _will_crash := false
var _will_escape := false
var _stable := false
var _flash := 0.0
var _plane_normal := Vector3.UP
var _view_radius := -1.0


func _ready() -> void:
	_build_ui()
	_build_world()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _process(delta: float) -> void:
	if not _find_player():
		return
	var ship := player.ship
	var bodies := _get_bodies()
	var focus := _strongest_body(bodies, ship.global_position)
	if focus == null:
		return

	_flash += delta
	_record_trail(ship.global_position, delta)
	_predict(ship, bodies, focus)
	_sync_planets(bodies, focus)
	_update_orbit_plane(ship, focus, delta)
	_update_zoom(ship, focus, delta)
	_update_ship_marker(ship, focus)
	_draw_line(_trail_mesh, _trail, TRAIL_COLOUR, focus, true, ship.global_position)
	var colour := _path_colour()
	_draw_line(_path_mesh, _predicted, colour, focus, false)
	_draw_limit_ring(focus)
	_update_camera(ship, focus)
	_title.text = "// ORBIT SCAN  %s" % _orbit_status()
	_title.add_theme_color_override("font_color", colour)
	_label.text = "SPD %5.1f | ALT %5.0f | MAS %.2f" % [
		ship.linear_velocity.length(),
		ship.global_position.distance_to(focus.global_position) - _body_radius(focus),
		player.mass_component.mass,
	]


func _find_player() -> bool:
	if is_instance_valid(player) and is_instance_valid(player.ship):
		return true
	var scene := get_tree().current_scene
	if scene == null:
		return false
	for node in scene.find_children("*", "Node3D", true, false):
		if node is Player:
			player = node
			return is_instance_valid(player.ship)
	return false

# --- Gravity (mirrors Player) --------------------------------------------


func _get_bodies() -> Array[Node3D]:
	var bodies: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("bodies"):
		if node is Node3D and node != player and node != player.ship:
			bodies.append(node)
	return bodies


## Same as Player._get_mass().
func _body_mass(body: Node3D) -> float:
	if body is RigidBody3D:
		return body.mass
	return body.get_meta("mass", 1.0)


## Acceleration from Player._apply_gravity(): force / ship mass.
func _gravity_at(point: Vector3, bodies: Array[Node3D]) -> Vector3:
	var accel := Vector3.ZERO
	for body in bodies:
		var offset := body.global_position - point
		var dist_sq := offset.length_squared() + player.softening * player.softening
		accel += offset.normalized() * player.gravitational_constant * _body_mass(body) / dist_sq
	return accel


func _strongest_body(bodies: Array[Node3D], point: Vector3) -> Node3D:
	var best: Node3D = null
	var best_pull := 0.0
	for body in bodies:
		var pull := _body_mass(body) / maxf(body.global_position.distance_squared_to(point), 0.0001)
		if pull > best_pull:
			best_pull = pull
			best = body
	return best


## Surface radius: a "radius" property, a "radius" meta, or the first sphere collider.
func _body_radius(body: Node3D) -> float:
	if "radius" in body:
		return body.radius
	if body.has_meta("radius"):
		return body.get_meta("radius")
	for child in body.find_children("*", "CollisionShape3D", true, false):
		var shape := (child as CollisionShape3D).shape
		if shape is SphereShape3D:
			var shape_scale := (child as Node3D).global_basis.get_scale()
			return (shape as SphereShape3D).radius * maxf(
				shape_scale.x,
				maxf(shape_scale.y, shape_scale.z),
			)
	return 1.0


func _linear_damp(ship: RigidBody3D) -> float:
	var damp := ship.linear_damp
	if ship.linear_damp_mode == RigidBody3D.DAMP_MODE_COMBINE:
		damp += ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.0)
	return damp

# --- Prediction & trail ------------------------------------------------------


func _record_trail(ship_position: Vector3, delta: float) -> void:
	_trail_timer += delta
	if _trail_timer < trail_interval:
		return
	_trail_timer = 0.0
	_trail.append(ship_position)
	var max_points := int(trail_seconds / trail_interval)
	if _trail.size() > max_points:
		_trail = _trail.slice(_trail.size() - max_points)


## Simulates the ship forward with no input (gravity + damping only) and
## decides whether the current orbit is stable.
func _predict(ship: RigidBody3D, bodies: Array[Node3D], focus: Node3D) -> void:
	_predicted.clear()
	_predicted.append(ship.global_position)
	_will_crash = false
	var radii: Array[float] = []
	for body in bodies:
		radii.append(_body_radius(body))

	# Two-body orbit around the focused planet: energy says bound or escaping,
	# periapsis says whether the lowest point clears the surface.
	var mu := player.gravitational_constant * _body_mass(focus)
	var r_vec := ship.global_position - focus.global_position
	var r := maxf(r_vec.length(), 0.001)
	var v := ship.linear_velocity
	var energy := v.length_squared() * 0.5 - mu / r
	_will_escape = energy >= 0.0
	var periapsis := 0.0
	var horizon := path_seconds
	if not _will_escape and mu > 0.0:
		var semi_major := -mu / (2.0 * energy)
		var ecc := (v.cross(r_vec.cross(v)) / mu - r_vec / r).length()
		periapsis = semi_major * (1.0 - ecc)
		var period := TAU * sqrt(pow(semi_major, 3.0) / mu)
		horizon = clampf(period * 1.02, path_seconds, max_path_seconds)

	# Numerical path, so damping and other planets are accounted for.
	var p := ship.global_position
	var damping := maxf(0.0, 1.0 - _linear_damp(ship) * path_step)
	var steps := int(horizon / path_step)
	for i in steps:
		v += _gravity_at(p, bodies) * path_step
		v *= damping
		p += v * path_step
		for j in bodies.size():
			if p.distance_to(bodies[j].global_position) < radii[j]:
				_will_crash = true
		if _will_crash:
			_predicted.append(p)
			break
		if i % 3 == 0:
			_predicted.append(p)

	_stable = not _will_escape and not _will_crash \
			and periapsis > _body_radius(focus) * (1.0 + stable_margin)


## Steady green when stable, flashing red otherwise.
func _path_colour() -> Color:
	if _stable:
		return PATH_STABLE_COLOUR
	var colour := PATH_UNSTABLE_COLOUR
	colour.a = 0.35 + 0.65 * absf(sin(_flash * PI * flash_hz))
	return colour


func _orbit_status() -> String:
	if _stable:
		return "STABLE"
	if _will_crash:
		return "IMPACT"
	if _will_escape:
		return "ESCAPE"
	return "DECAYING"

# --- UI ----------------------------------------------------------------------


func _build_ui() -> void:
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])

	_panel = PanelContainer.new()
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.0, 0.04, 0.07, 0.6)
	_panel_style.border_color = Color(HOLO_COLOUR, 0.6)
	_panel_style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top-right corner.
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.text = "// ORBIT SCAN"
	_title.add_theme_font_override("font", mono)
	_title.add_theme_color_override("font_color", Color(HOLO_COLOUR, 0.8))
	vbox.add_child(_title)

	# The 3D view with a scanline overlay on top.
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_frame)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(container)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	_root = Node3D.new()
	viewport.add_child(_root)

	var scanlines := ColorRect.new()
	scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SCANLINE_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	scanlines.material = shader_material
	_frame.add_child(scanlines)

	_label = Label.new()
	_label.add_theme_font_override("font", mono)
	_label.add_theme_color_override("font_color", HOLO_COLOUR)
	vbox.add_child(_label)


## Sizes everything from the screen height so it looks the same at any resolution.
func _update_layout() -> void:
	var screen_height := get_viewport().get_visible_rect().size.y
	var height := maxf(min_height_px, screen_height * size_ratio)
	var margin := screen_height * margin_ratio
	var font_size := maxi(9, int(height * 0.065))

	_frame.custom_minimum_size = Vector2(height * aspect, height)
	_panel.offset_left = -margin
	_panel.offset_right = -margin
	_panel.offset_top = margin
	_panel_style.set_content_margin_all(maxf(3.0, height * 0.03))
	_title.add_theme_font_size_override("font_size", font_size - 1)
	_label.add_theme_font_size_override("font_size", font_size)

# --- 3D map ------------------------------------------------------------------


func _build_world() -> void:
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_root.add_child(_camera)
	_camera.current = true

	# Ship marker: a red cone pointing along -Z, the ship's nose. Unit length,
	# scaled with the zoom so it always reads the same size.
	_ship_marker = Node3D.new()
	_root.add_child(_ship_marker)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.35
	cone.height = 1.0
	cone.radial_segments = 4
	cone.rings = 1
	var marker_material := _unshaded(SHIP_COLOUR)
	# Always drawn on top so the ship is never lost behind a planet.
	marker_material.no_depth_test = true
	marker_material.render_priority = 10
	cone.material = marker_material
	var cone_instance := MeshInstance3D.new()
	cone_instance.mesh = cone
	cone_instance.rotation_degrees.x = -90.0
	_ship_marker.add_child(cone_instance)

	_trail_mesh = _add_line_instance(false)
	# The prediction is drawn on top so a crash into a planet is always visible.
	_path_mesh = _add_line_instance(true)
	_limit_mesh = _add_line_instance(false)
	_planet_wire = _build_unit_wire_sphere()


func _add_line_instance(on_top: bool) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _line_material(on_top)
	_root.add_child(instance)
	return mesh


func _line_material(on_top: bool) -> StandardMaterial3D:
	var material := _unshaded(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = on_top
	return material


func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material


## Latitude / longitude rings on a sphere of radius 1.
func _build_unit_wire_sphere() -> ImmediateMesh:
	var wire := ImmediateMesh.new()
	wire.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(1, LATITUDE_LINES):
		var lat := PI * i / LATITUDE_LINES - PI / 2.0
		var alpha := 0.9 if i * 2 == LATITUDE_LINES else 0.45 # brighter equator
		_add_ring(
			wire,
			Vector3(0, sin(lat), 0),
			cos(lat),
			Vector3.RIGHT,
			Vector3.BACK,
			Color(HOLO_COLOUR, alpha),
			false,
		)
	for i in LONGITUDE_LINES:
		var lon := PI * i / LONGITUDE_LINES
		_add_ring(
			wire,
			Vector3.ZERO,
			1.0,
			Vector3(cos(lon), 0, sin(lon)),
			Vector3.UP,
			Color(HOLO_COLOUR, 0.45),
			false,
		)
	wire.surface_end()
	return wire


## Adds a ring as PRIMITIVE_LINES segments. dashed = every other segment.
func _add_ring(
	mesh: ImmediateMesh,
	centre: Vector3,
	radius: float,
	a: Vector3,
	b: Vector3,
	colour: Color,
	dashed: bool,
) -> void:
	var segments := RING_SEGMENTS * (2 if dashed else 1)
	var step := 2 if dashed else 1
	for i in range(0, segments, step):
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		mesh.surface_set_color(colour)
		mesh.surface_add_vertex(centre + (a * cos(a0) + b * sin(a0)) * radius)
		mesh.surface_set_color(colour)
		mesh.surface_add_vertex(centre + (a * cos(a1) + b * sin(a1)) * radius)


## Keeps one wireframe planet per body: a dark core hides the back lines.
func _sync_planets(bodies: Array[Node3D], focus: Node3D) -> void:
	for body in _planet_nodes.keys():
		if not is_instance_valid(body) or not bodies.has(body):
			_planet_nodes[body].queue_free()
			_planet_nodes.erase(body)

	for body in bodies:
		if not _planet_nodes.has(body):
			var node := Node3D.new()
			var core := SphereMesh.new()
			core.radius = 0.98
			core.height = 1.96
			core.material = _unshaded(PLANET_FILL_COLOUR)
			var core_instance := MeshInstance3D.new()
			core_instance.mesh = core
			node.add_child(core_instance)
			var wire_instance := MeshInstance3D.new()
			wire_instance.mesh = _planet_wire
			wire_instance.material_override = _line_material(false)
			node.add_child(wire_instance)
			_root.add_child(node)
			_planet_nodes[body] = node

		var map_node: Node3D = _planet_nodes[body]
		map_node.position = _to_map(body.global_position, focus)
		map_node.basis = Basis(body.global_basis.get_rotation_quaternion()).scaled(
			Vector3.ONE * _body_radius(body)
		)


func _to_map(world_point: Vector3, focus: Node3D) -> Vector3:
	return world_point - focus.global_position


## The orbit plane's normal, smoothed so the camera doesn't jitter.
func _update_orbit_plane(ship: RigidBody3D, focus: Node3D, delta: float) -> void:
	var offset := ship.global_position - focus.global_position
	var normal := offset.cross(ship.linear_velocity)
	if normal.length_squared() < 0.0001:
		return
	_plane_normal = _plane_normal.lerp(normal.normalized(), clampf(delta * 2.0, 0.0, 1.0)).normalized()


## Zooms so the planet, the ship and the nearby predicted path fit in view.
func _update_zoom(ship: RigidBody3D, focus: Node3D, delta: float) -> void:
	var ship_distance := ship.global_position.distance_to(focus.global_position)
	var target := maxf(_body_radius(focus) * 1.2, ship_distance)
	if limit_altitude > 0.0:
		target = maxf(target, _body_radius(focus) + limit_altitude)
	# Include the predicted path, but don't zoom out forever for escape paths.
	for point in _predicted:
		target = maxf(target, minf(point.distance_to(focus.global_position), ship_distance * 2.0))
	target *= fit_padding
	if _view_radius < 0.0:
		_view_radius = target
	else:
		_view_radius = lerpf(_view_radius, target, clampf(delta * zoom_smoothing, 0.0, 1.0))


func _update_ship_marker(ship: RigidBody3D, focus: Node3D) -> void:
	_ship_marker.position = _to_map(ship.global_position, focus)
	# The ship's real rotation (what the player is steering).
	var ship_rotation := ship.global_basis.get_rotation_quaternion()
	_ship_marker.basis = Basis(ship_rotation).scaled(Vector3.ONE * _view_radius * MARKER_SIZE)


func _draw_line(
	mesh: ImmediateMesh,
	points: PackedVector3Array,
	colour: Color,
	focus: Node3D,
	fade_in: bool,
	extra_end := Vector3.INF,
) -> void:
	mesh.clear_surfaces()
	var count := points.size() + (0 if extra_end == Vector3.INF else 1)
	if count < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in count:
		var point: Vector3 = points[i] if i < points.size() else extra_end
		var t := float(i) / (count - 1)
		var c := colour
		# Trail fades out toward its oldest point, the prediction toward its end.
		c.a = (lerpf(0.1, 0.9, t) if fade_in else lerpf(1.0, 0.25, t)) * colour.a
		mesh.surface_set_color(c)
		mesh.surface_add_vertex(_to_map(point, focus))
	mesh.surface_end()


func _draw_limit_ring(focus: Node3D) -> void:
	_limit_mesh.clear_surfaces()
	if limit_altitude <= 0.0:
		return
	var a := _plane_normal.cross(Vector3.RIGHT)
	if a.length_squared() < 0.01:
		a = _plane_normal.cross(Vector3.FORWARD)
	a = a.normalized()
	var b := _plane_normal.cross(a).normalized()
	_limit_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_ring(
		_limit_mesh,
		Vector3.ZERO,
		_body_radius(focus) + limit_altitude,
		a,
		b,
		LIMIT_COLOUR,
		true,
	)
	_limit_mesh.surface_end()


## Looks down on the orbit plane, tilted toward the ship so the planet never
## hides it, with the ship always at the top of the map.
func _update_camera(ship: RigidBody3D, focus: Node3D) -> void:
	var out := (ship.global_position - focus.global_position).normalized()
	out = (out - _plane_normal * out.dot(_plane_normal)).normalized()
	if out.is_zero_approx():
		return
	var tilt := deg_to_rad(camera_tilt_degrees)
	var direction := (_plane_normal * cos(tilt) + out * sin(tilt)).normalized()
	var distance := _view_radius / tan(deg_to_rad(_camera.fov) * 0.5)
	_camera.near = distance * 0.01
	_camera.far = distance * 4.0
	_camera.position = direction * distance
	_camera.look_at(Vector3.ZERO, out)
