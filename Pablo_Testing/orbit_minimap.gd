extends CanvasLayer
## Sci-fi wireframe 3D minimap: a holographic copy of the planet with the ship,
## its flown orbit (trail) and the predicted orbit if nothing changes.
## Only speed and altitude are shown as text.
##
## It renders in its own SubViewport + World3D, so nothing here appears in the
## main scene. All data comes from the OrbitShip.

@export var player: OrbitShip
@export var map_size: Vector2i = Vector2i(220, 190)
## World units -> map units.
@export var map_scale: float = 0.01
## Camera distance, as a multiple of the bounds radius.
@export var camera_distance_factor: float = 3.0
## Camera angle away from straight down on the orbit plane, in degrees.
@export var camera_tilt_degrees: float = 35.0
@export var font_size: int = 12
## Margin from the top-right corner of the screen, in pixels.
@export var screen_margin: int = 12

const HOLO_COLOUR := Color(0.3, 0.9, 1.0)
const PLANET_FILL_COLOUR := Color(0.0, 0.05, 0.08)
const TRAIL_COLOUR := Color(0.3, 0.9, 1.0)
const PATH_SAFE_COLOUR := Color(0.3, 1.0, 0.5)
const PATH_CRASH_COLOUR := Color(1.0, 0.25, 0.2)
const PATH_ESCAPE_COLOUR := Color(1.0, 0.8, 0.2)
const BOUNDS_COLOUR := Color(1.0, 0.45, 0.2, 0.8)
const SHIP_COLOUR := Color(1.0, 0.15, 0.15)

const LATITUDE_LINES := 8
const LONGITUDE_LINES := 12
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

var _root: Node3D
var _camera: Camera3D
var _ship_marker: Node3D
var _trail_mesh: ImmediateMesh
var _path_mesh: ImmediateMesh
var _bounds_mesh: ImmediateMesh
var _planet_nodes := {} # OrbitPlanet -> Node3D
var _label: RichTextLabel
var _plane_normal := Vector3.UP


func _ready() -> void:
	_build_ui()
	_build_world()


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var status := player.get_status()
	if status.is_empty():
		return
	var planet: OrbitPlanet = status.planet

	_sync_planets()
	_update_orbit_plane(planet, delta)
	_update_ship_marker(planet)
	_draw_line(_trail_mesh, player.trail, TRAIL_COLOUR, player.global_position, true)
	_draw_line(_path_mesh, player.predicted_path, _path_colour(), Vector3.INF, false)
	_draw_bounds_ring(planet)
	_update_camera(planet)
	_update_text(status)


# --- Setup -------------------------------------------------------------------

func _build_ui() -> void:
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.04, 0.07, 0.6)
	style.border_color = Color(HOLO_COLOUR, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Top-right corner.
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -screen_margin
	panel.offset_right = -screen_margin
	panel.offset_top = screen_margin
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "// ORBIT SCAN"
	title.add_theme_font_override("font", mono)
	title.add_theme_font_size_override("font_size", font_size - 1)
	title.add_theme_color_override("font_color", Color(HOLO_COLOUR, 0.8))
	vbox.add_child(title)

	# The 3D view with a scanline overlay on top.
	var frame := Control.new()
	frame.custom_minimum_size = map_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(frame)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(container)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.size = map_size
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
	frame.add_child(scanlines)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", mono)
	_label.add_theme_font_size_override("normal_font_size", font_size)
	_label.add_theme_color_override("default_color", HOLO_COLOUR)
	vbox.add_child(_label)


func _build_world() -> void:
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.05
	_camera.far = 500.0
	_root.add_child(_camera)
	_camera.current = true

	# Ship marker: a red cone pointing along -Z (its travel direction).
	_ship_marker = Node3D.new()
	_root.add_child(_ship_marker)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.35
	cone.height = 1.0
	cone.radial_segments = 4
	cone.rings = 1
	var marker_material := _unshaded(SHIP_COLOUR)
	# Always drawn on top so the ship is never lost behind the planet.
	marker_material.no_depth_test = true
	marker_material.render_priority = 10
	cone.material = marker_material
	var cone_instance := MeshInstance3D.new()
	cone_instance.mesh = cone
	cone_instance.rotation_degrees.x = -90.0
	_ship_marker.add_child(cone_instance)

	_trail_mesh = _add_line_instance(false)
	# The prediction is drawn on top so a crash into the planet is always visible.
	_path_mesh = _add_line_instance(true)
	_bounds_mesh = _add_line_instance(false)


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


## Makes a wireframe hologram of every planet: a dark core that hides the
## back lines, plus latitude / longitude rings.
func _sync_planets() -> void:
	for source: OrbitPlanet in player.sources:
		if _planet_nodes.has(source):
			continue
		var radius := source.radius * map_scale
		var node := Node3D.new()
		_root.add_child(node)

		var core := SphereMesh.new()
		core.radius = radius * 0.98
		core.height = core.radius * 2.0
		core.material = _unshaded(PLANET_FILL_COLOUR)
		var core_instance := MeshInstance3D.new()
		core_instance.mesh = core
		node.add_child(core_instance)

		var wire := ImmediateMesh.new()
		wire.surface_begin(Mesh.PRIMITIVE_LINES)
		# Latitude rings.
		for i in range(1, LATITUDE_LINES):
			var lat := PI * i / LATITUDE_LINES - PI / 2.0
			var is_equator := i * 2 == LATITUDE_LINES
			var alpha := 0.9 if is_equator else 0.45
			_add_ring(wire, Vector3(0, sin(lat) * radius, 0), cos(lat) * radius, Vector3.RIGHT, Vector3.BACK, alpha)
		# Longitude rings.
		for i in LONGITUDE_LINES:
			var lon := PI * i / LONGITUDE_LINES
			var across := Vector3(cos(lon), 0, sin(lon))
			_add_ring(wire, Vector3.ZERO, radius, across, Vector3.UP, 0.45)
		wire.surface_end()
		var wire_instance := MeshInstance3D.new()
		wire_instance.mesh = wire
		wire_instance.material_override = _line_material(false)
		node.add_child(wire_instance)

		_planet_nodes[source] = node
	for source: OrbitPlanet in _planet_nodes:
		if is_instance_valid(source):
			_planet_nodes[source].position = _to_map(source.global_position)
			_planet_nodes[source].quaternion = source.global_basis.get_rotation_quaternion()


func _add_ring(mesh: ImmediateMesh, centre: Vector3, radius: float, a: Vector3, b: Vector3, alpha: float) -> void:
	var segments := 48
	var colour := Color(HOLO_COLOUR, alpha)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		mesh.surface_set_color(colour)
		mesh.surface_add_vertex(centre + (a * cos(a0) + b * sin(a0)) * radius)
		mesh.surface_set_color(colour)
		mesh.surface_add_vertex(centre + (a * cos(a1) + b * sin(a1)) * radius)


# --- Per frame ---------------------------------------------------------------

func _to_map(world_point: Vector3) -> Vector3:
	return world_point * map_scale


func _path_colour() -> Color:
	if player.will_crash:
		return PATH_CRASH_COLOUR
	if player.will_leave_bounds:
		return PATH_ESCAPE_COLOUR
	return PATH_SAFE_COLOUR


## The orbit plane's normal, smoothed so the camera doesn't jitter.
func _update_orbit_plane(planet: OrbitPlanet, delta: float) -> void:
	var offset := player.global_position - planet.global_position
	var normal := offset.cross(player.velocity)
	if normal.length_squared() < 0.0001:
		return
	_plane_normal = _plane_normal.lerp(normal.normalized(), clampf(delta * 2.0, 0.0, 1.0)).normalized()


func _update_ship_marker(planet: OrbitPlanet) -> void:
	_ship_marker.position = _to_map(player.global_position)
	var forward := player.velocity.normalized()
	var up := (player.global_position - planet.global_position).normalized()
	if forward.is_zero_approx() or absf(forward.dot(up)) > 0.999:
		return
	_ship_marker.basis = Basis.looking_at(forward, up)


func _draw_line(mesh: ImmediateMesh, points: PackedVector3Array, colour: Color, extra_end: Vector3, fade_in: bool) -> void:
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
		c.a = lerpf(0.1, 0.9, t) if fade_in else lerpf(1.0, 0.25, t)
		mesh.surface_set_color(c)
		mesh.surface_add_vertex(_to_map(point))
	mesh.surface_end()


## The max altitude limit, drawn as a dashed ring in the current orbit plane.
func _draw_bounds_ring(planet: OrbitPlanet) -> void:
	_bounds_mesh.clear_surfaces()
	var radius := (planet.radius + player.max_altitude) * map_scale
	var centre := _to_map(planet.global_position)
	var a := _plane_normal.cross(Vector3.RIGHT)
	if a.length_squared() < 0.01:
		a = _plane_normal.cross(Vector3.FORWARD)
	a = a.normalized()
	var b := _plane_normal.cross(a).normalized()
	_bounds_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var dashes := 64
	for i in dashes:
		var a0 := TAU * i / dashes
		var a1 := TAU * (i + 0.5) / dashes
		_bounds_mesh.surface_set_color(BOUNDS_COLOUR)
		_bounds_mesh.surface_add_vertex(centre + (a * cos(a0) + b * sin(a0)) * radius)
		_bounds_mesh.surface_set_color(BOUNDS_COLOUR)
		_bounds_mesh.surface_add_vertex(centre + (a * cos(a1) + b * sin(a1)) * radius)
	_bounds_mesh.surface_end()


## Looks down on the orbit plane, tilted so the planet reads as 3D and the
## ship is always at the top of the map.
func _update_camera(planet: OrbitPlanet) -> void:
	var centre := _to_map(planet.global_position)
	var out := (player.global_position - planet.global_position).normalized()
	# Keep "out" in the orbit plane so the tilt is consistent.
	out = (out - _plane_normal * out.dot(_plane_normal)).normalized()
	if out.is_zero_approx():
		return
	var tilt := deg_to_rad(camera_tilt_degrees)
	# Tilted toward the ship's side, so the planet never hides it.
	var direction := (_plane_normal * cos(tilt) + out * sin(tilt)).normalized()
	var distance := (planet.radius + player.max_altitude) * map_scale * camera_distance_factor
	_camera.position = centre + direction * distance
	_camera.look_at(centre, out)


func _update_text(status: Dictionary) -> void:
	_label.text = "SPD %4.0f   ALT %4.0f" % [status.speed, status.altitude]
