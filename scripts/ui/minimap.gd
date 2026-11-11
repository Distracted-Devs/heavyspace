class_name OrbitMinimap
extends CanvasLayer
## Minimal holographic orbit map, top-right corner.
##
## Shows only: the planets, points of interest, the ship and its predicted
## path, the locked orbit (while locked) and a one-word forecast of what
## happens if nothing changes: IMPACT, ESCAPE or STABLE.
##
## Usage: instance minimap.tscn in a scene that has a Player.

## Leave empty to use the first Player found in the current scene.
@export var player: Player

@export_group("Layout")
## Size of the (square) map as a fraction of the screen height.
@export_range(0.05, 1.0) var size_ratio: float = 0.34
## Distance from the top-right corner as a fraction of the screen height.
@export_range(0.0, 0.2) var margin_ratio: float = 0.015
@export var min_size_px: float = 160.0

@export_group("Forecast label")
## The IMPACT / ESCAPE / STABLE label. Style it (font, outline...) in
## minimap.tscn; its colour and blink are driven from here via modulate.
@export var forecast_label: Label
## Blinks per second.
@export var forecast_blink_speed: float = 1.2
## Lowest opacity of the blink.
@export_range(0.0, 1.0) var forecast_blink_min_alpha: float = 0.25
## Scale the font size with the map. Turn off to use the size set on the label.
@export var auto_font_size: bool = true
## Font size as a fraction of the map size (when auto_font_size is on).
@export var font_size_ratio: float = 0.075
## Gap between the bottom of the map and the label, in pixels.
@export var forecast_bottom_gap_px: float = 1.0

@export_group("Grid")
## Number of cells along each side of the map.
@export_range(1, 64) var grid_cells: int = 12:
	set(value):
		grid_cells = value
		_apply_grid()
## Grid line colour; its alpha is the line transparency.
@export var grid_line_colour: Color = Color(0.3, 0.9, 1.0, 0.18):
	set(value):
		grid_line_colour = value
		_apply_grid()
## Background behind the grid; its alpha is the background transparency.
@export var grid_fill_colour: Color = Color(0.0, 0.04, 0.07, 0.35):
	set(value):
		grid_fill_colour = value
		_apply_grid()
## Line thickness in pixels.
@export_range(0.5, 8.0, 0.5) var grid_line_width: float = 1.0:
	set(value):
		grid_line_width = value
		_apply_grid()

@export_group("View")
## Camera angle away from straight down on the orbit plane, in degrees.
@export var camera_tilt_degrees: float = 35.0
## Extra room around the orbit (1 = tight fit).
@export var fit_padding: float = 1.15
## How quickly the map zooms to fit the orbit.
@export var zoom_smoothing: float = 2.0

@export_group("Planets")
## Size of the pixelation blocks on the planets, in pixels (1 = off).
@export_range(1, 32, 1) var planet_pixel_size: int = 4:
	set(value):
		planet_pixel_size = value
		if _pixelate:
			_pixelate.pixel_size = value

@export_group("Prediction")
## Longest the path is simulated, in seconds. Stops early after one full turn
## around the planet or on impact.
@export var path_seconds: float = 3600.0
@export var path_step: float = 1.0 / 30.0
@export var path_max_steps: int = 2400

@export_group("Points of interest")
@export var poi_group: StringName = &"points_of_interest"
## Blinks per second.
@export var poi_blink_speed: float = 1.5

const PATH_COLOUR := Color(0.3, 0.9, 1.0)
const STABLE_COLOUR := Color(0.3, 1.0, 0.5)
const IMPACT_COLOUR := Color(1.0, 0.25, 0.2)
const ESCAPE_COLOUR := Color(1.0, 0.8, 0.2)
const SHIP_COLOUR := Color(1.0, 0.15, 0.15)
const POI_COLOUR := Color(1.0, 0.85, 0.1)
const DEAD_ZONE_COLOUR := Color(1.0, 0.1, 0.1, 0.9)
const DEAD_ZONE_SEGMENTS := 128

## Ship marker length as a fraction of the visible radius.
const MARKER_SIZE := 0.16
## Point of interest dot radius as a fraction of the visible radius.
const POI_SIZE := 0.05
const LOCKED_ORBIT_SEGMENTS := 128
const LOCK_PULSE_HZ := 0.8
## Input action that locks / unlocks the orbit; its binding is shown in the label.
const LOCK_ACTION := &"toggle_orbit_lock"

## Joypad button names by layout, indexed by JoyButton (0-14).
const JOY_NAMES_XBOX := ["A", "B", "X", "Y", "VIEW", "GUIDE", "MENU", "LS", "RS",
		"LB", "RB", "D-UP", "D-DOWN", "D-LEFT", "D-RIGHT"]
const JOY_NAMES_PLAYSTATION := ["CROSS", "CIRCLE", "SQUARE", "TRIANGLE", "SHARE", "PS",
		"OPTIONS", "L3", "R3", "L1", "R1", "D-UP", "D-DOWN", "D-LEFT", "D-RIGHT"]
const JOY_NAMES_NINTENDO := ["B", "A", "Y", "X", "-", "HOME", "+", "LS", "RS",
		"L", "R", "D-UP", "D-DOWN", "D-LEFT", "D-RIGHT"]

## Transparent 12x12 grid of thin lines: the "tech hack" background.
const GRID_SHADER := """
shader_type canvas_item;
uniform vec4 line_colour : source_color = vec4(0.3, 0.9, 1.0, 0.18);
uniform vec4 fill_colour : source_color = vec4(0.0, 0.04, 0.07, 0.35);
uniform float cells = 12.0;
uniform float line_px = 1.0;
uniform vec2 size = vec2(256.0); // panel size in pixels, set from the script
void fragment() {
	vec2 g = fract(UV * cells);
	vec2 d = min(g, 1.0 - g) * size / cells; // pixels to nearest grid line
	float line = 1.0 - step(line_px, min(d.x, d.y));
	COLOR = mix(fill_colour, line_colour, line);
}
"""

var _panel_style: StyleBoxFlat
var _border_style: StyleBoxFlat
var _title: Label
var _frame: Control
var _status: Label
var _grid_material: ShaderMaterial
var _pixelate: PixelateEffect

var _root: Node3D
var _camera: Camera3D
var _ship_marker: Node3D
var _path_mesh: ImmediateMesh
var _dead_zone_mesh: ImmediateMesh
var _planet_nodes := { } # body -> map Node3D
var _poi_nodes := { } # point of interest -> map MeshInstance3D
var _poi_mesh: SphereMesh
var _poi_material: StandardMaterial3D

var _predicted: PackedVector3Array = []
var _will_crash := false
var _will_escape := false
var _plane_normal := Vector3.UP
var _view_radius := -1.0
var _time := 0.0


func _ready() -> void:
	_build_ui()
	_build_world()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _process(delta: float) -> void:
	if not _find_player():
		return
	var ship := player.ship
	var bodies := player.gravity_effect.get_sources()
	var focus := player.gravity_effect.strongest_source(ship.global_position, bodies)
	if focus == null:
		return
	_time += delta

	_predict(ship, bodies, focus)
	_sync_planets(bodies, focus)
	_sync_points_of_interest(focus)
	_update_orbit_plane(ship, focus, delta)
	_update_zoom(ship, focus, delta)
	_update_ship_marker(ship, focus)
	_draw_path(focus)
	_draw_dead_zones(focus)
	_update_camera(ship, focus)
	_update_status()


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


func _body_radius(body: Node3D) -> float:
	return GravityEffect.source_radius(body)

# --- Prediction ----------------------------------------------------------------


## Simulates the ship with no input (gravity + damping) until one full turn
## around the focused planet, an impact, or path_seconds.
func _predict(ship: RigidBody3D, bodies: Array[Node3D], focus: Node3D) -> void:
	_predicted.clear()
	_predicted.append(ship.global_position)
	_will_crash = false
	var orbit := player.get_current_orbit()
	_will_escape = orbit == null or not orbit.is_bound()
	if player.is_orbit_locked():
		return # the locked orbit is drawn instead

	var radii: Array[float] = []
	for body in bodies:
		radii.append(_body_radius(body))
	var focus_pos := focus.global_position
	var p := ship.global_position
	var v := player.get_orbit_velocity()
	var damping := ship.linear_damp
	if ship.linear_damp_mode == RigidBody3D.DAMP_MODE_COMBINE:
		damping += ProjectSettings.get_setting("physics/3d/default_linear_damp", 0.0)

	var step := path_step
	var mu := player.gravity_effect.mu_of(focus)
	if mu > 0.0:
		var r0 := maxf(p.distance_to(focus_pos), 0.001)
		step = maxf(step, TAU * sqrt(r0 * r0 * r0 / mu) / path_max_steps)
	var steps := mini(int(path_seconds / step), path_max_steps)

	var sweep := 0.0
	var prev_rel := p - focus_pos
	for i in steps:
		v += player.gravity_effect.acceleration_at(p, bodies) * step
		v *= maxf(0.0, 1.0 - damping * step)
		p += v * step
		for j in bodies.size():
			if p.distance_to(bodies[j].global_position) < radii[j]:
				_will_crash = true
		if _will_crash:
			_predicted.append(p)
			return
		var rel := p - focus_pos
		sweep += atan2(prev_rel.cross(rel).length(), prev_rel.dot(rel))
		prev_rel = rel
		if i % 3 == 0:
			_predicted.append(p)
		if sweep >= TAU:
			_predicted.append(p)
			return


## The forecast if nothing changes, or "" when none of the three applies.
func _forecast() -> String:
	if player.is_orbit_locked():
		return "STABLE"
	if _will_crash:
		return "IMPACT"
	if _will_escape:
		return "ESCAPE"
	if player.can_lock_orbit():
		return "STABLE"
	return ""


func _forecast_colour(forecast: String) -> Color:
	match forecast:
		"IMPACT":
			return IMPACT_COLOUR
		"ESCAPE":
			return ESCAPE_COLOUR
		"STABLE":
			return STABLE_COLOUR
	return PATH_COLOUR


## The label text: the forecast, plus the lock / unlock prompt when stable.
func _status_text(forecast: String) -> String:
	if forecast != "STABLE":
		return forecast
	var button := _lock_button_name()
	if button.is_empty():
		return "STABLE ORBIT"
	if player.is_orbit_locked():
		return "STABLE ORBIT - PRESS [%s] TO BREAK ORBIT" % button
	return "STABLE ORBIT - PRESS [%s] TO LOCK" % button


## Name of the lock binding: the controller button when a joypad is plugged
## in, otherwise the keyboard key. "" if the action has no matching binding.
func _lock_button_name() -> String:
	var joypads := Input.get_connected_joypads()
	var use_joypad := not joypads.is_empty()
	for event in InputMap.action_get_events(LOCK_ACTION):
		if use_joypad and event is InputEventJoypadButton:
			return _joy_button_name(event.button_index, Input.get_joy_name(joypads[0]))
		if not use_joypad and event is InputEventKey:
			var keycode: Key = event.keycode
			if keycode == KEY_NONE:
				keycode = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
			return OS.get_keycode_string(keycode).to_upper()
	return ""


func _joy_button_name(button: int, joy_name: String) -> String:
	var lower := joy_name.to_lower()
	var names: Array = JOY_NAMES_XBOX
	if lower.contains("ps3") or lower.contains("ps4") or lower.contains("ps5") or lower.contains("playstation") \
			or lower.contains("dualshock") or lower.contains("dualsense"):
		names = JOY_NAMES_PLAYSTATION
	elif lower.contains("nintendo") or lower.contains("switch") or lower.contains("joy-con"):
		names = JOY_NAMES_NINTENDO
	if button >= 0 and button < names.size():
		return names[button]
	return "BUTTON %d" % button


func _lock_pulse() -> float:
	return 0.5 - 0.5 * cos(_time * LOCK_PULSE_HZ * TAU)


func _update_status() -> void:
	var forecast := _forecast()
	var colour := _forecast_colour(forecast)
	_status.text = _status_text(forecast)
	var blink := 0.5 + 0.5 * cos(_time * forecast_blink_speed * TAU)
	_status.modulate = Color(colour, lerpf(forecast_blink_min_alpha, 1.0, blink))
	# Frame flashes red when an impact is coming.
	var alarm := forecast == "IMPACT" and fmod(_time * 4.0, 1.0) < 0.5
	_border_style.border_color = ArcadeUI.DANGER_COLOUR if alarm else ArcadeUI.FRAME_COLOUR

# --- UI --------------------------------------------------------------------------


func _build_ui() -> void:
	# Background + hard drop shadow here; the white frame is a separate overlay
	# drawn on top of the map so the grid and planets can't cover it.
	var panel := Panel.new()
	_panel_style = ArcadeUI.make_frame_style()
	panel.add_theme_stylebox_override("panel", _panel_style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	_frame = panel

	var grid := ColorRect.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = GRID_SHADER
	_grid_material = ShaderMaterial.new()
	_grid_material.shader = shader
	grid.material = _grid_material
	_apply_grid()
	panel.add_child(grid)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(container)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	# No MSAA: the planets are pixelated after the opaque pass, which MSAA's
	# later resolve would overwrite.
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(viewport)
	_root = Node3D.new()
	viewport.add_child(_root)

	panel.add_child(ArcadeUI.make_scanlines())

	var border := Panel.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_style = StyleBoxFlat.new()
	_border_style.draw_center = false
	_border_style.border_color = ArcadeUI.FRAME_COLOUR
	border.add_theme_stylebox_override("panel", _border_style)
	panel.add_child(border)

	_title = ArcadeUI.make_label("ORBIT")
	_title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.add_child(_title)

	# The forecast label lives in minimap.tscn so it can be styled there; it's
	# moved inside the map panel and stretched over it at runtime.
	_status = forecast_label if forecast_label else Label.new()
	if _status.get_parent():
		_status.reparent(panel, false)
	else:
		panel.add_child(_status)
	_status.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The lock prompt can be wider than the map; wrap it onto two lines.
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pushes the Grid settings into the grid shader.
func _apply_grid() -> void:
	if _grid_material == null:
		return
	_grid_material.set_shader_parameter("cells", float(grid_cells))
	_grid_material.set_shader_parameter("line_colour", grid_line_colour)
	_grid_material.set_shader_parameter("fill_colour", grid_fill_colour)
	_grid_material.set_shader_parameter("line_px", grid_line_width)


func _update_layout() -> void:
	var screen_height := get_viewport().get_visible_rect().size.y
	var size := maxf(min_size_px, screen_height * size_ratio)
	var margin := screen_height * margin_ratio
	_frame.offset_left = -margin - size
	_frame.offset_right = -margin
	_frame.offset_top = margin
	_frame.offset_bottom = margin + size
	_grid_material.set_shader_parameter("size", Vector2(size, size))
	var border := ArcadeUI.border_px(screen_height)
	_panel_style.set_border_width_all(0)
	_panel_style.shadow_offset = Vector2(border, border)
	_border_style.set_border_width_all(int(border))
	_title.position = Vector2(border * 3.0, border * 2.0)
	_title.add_theme_font_size_override("font_size", maxi(9, ArcadeUI.font_size(screen_height) - 4))
	_status.offset_bottom = -forecast_bottom_gap_px - border * 2.0
	if auto_font_size:
		var font_size := maxi(10, int(size * font_size_ratio))
		if _status.label_settings:
			_status.label_settings.font_size = font_size
		else:
			_status.add_theme_font_size_override("font_size", font_size)

# --- 3D map ----------------------------------------------------------------------


func _build_world() -> void:
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_root.add_child(_camera)
	_camera.current = true

	# Same pixelation as the main camera, applied only to opaque geometry (the
	# planets); the path, markers and rings are transparent and drawn on top.
	_pixelate = PixelateEffect.new()
	_pixelate.before_transparent = true
	_pixelate.pixel_size = planet_pixel_size
	var compositor := Compositor.new()
	compositor.compositor_effects = [_pixelate]
	_camera.compositor = compositor

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.5
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_root.add_child(world_environment)
	_camera.add_child(DirectionalLight3D.new()) # lit from the viewer

	# Ship: a red cone along -Z (the nose), always drawn on top.
	_ship_marker = Node3D.new()
	_root.add_child(_ship_marker)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.35
	cone.height = 1.0
	cone.radial_segments = 4
	cone.rings = 1
	var marker_material := _unshaded(SHIP_COLOUR)
	# Transparent so it's drawn after the planet pixelation and stays crisp.
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.no_depth_test = true
	marker_material.render_priority = 10
	cone.material = marker_material
	var cone_instance := MeshInstance3D.new()
	cone_instance.mesh = cone
	cone_instance.rotation_degrees.x = -90.0
	_ship_marker.add_child(cone_instance)

	# Path / locked orbit, drawn on top so an impact is always visible.
	_path_mesh = ImmediateMesh.new()
	var path_instance := MeshInstance3D.new()
	path_instance.mesh = _path_mesh
	var line_material := _unshaded(Color.WHITE)
	line_material.vertex_color_use_as_albedo = true
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_material.no_depth_test = true
	path_instance.material_override = line_material
	_root.add_child(path_instance)

	# Dead zone boundary: red ring, on top.
	_dead_zone_mesh = ImmediateMesh.new()
	var zone_instance := MeshInstance3D.new()
	zone_instance.mesh = _dead_zone_mesh
	var zone_material := _unshaded(Color.WHITE)
	zone_material.vertex_color_use_as_albedo = true
	zone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_material.no_depth_test = true
	zone_material.render_priority = 8
	zone_instance.material_override = zone_material
	_root.add_child(zone_instance)

	# Points of interest: blinking yellow dots, on top.
	_poi_material = _unshaded(POI_COLOUR)
	_poi_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_poi_material.no_depth_test = true
	_poi_material.render_priority = 9
	_poi_mesh = SphereMesh.new()
	_poi_mesh.radius = 1.0
	_poi_mesh.height = 2.0
	_poi_mesh.radial_segments = 12
	_poi_mesh.rings = 6
	_poi_mesh.material = _poi_material


func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material


func _to_map(world_point: Vector3, focus: Node3D) -> Vector3:
	return world_point - focus.global_position


## One map copy per gravity body, using the body's own meshes (or a plain
## sphere when it has none).
func _sync_planets(bodies: Array[Node3D], focus: Node3D) -> void:
	for body in _planet_nodes.keys():
		if not is_instance_valid(body) or not bodies.has(body):
			_planet_nodes[body].queue_free()
			_planet_nodes.erase(body)
	for body in bodies:
		# CSG meshes bake deferred: rebuild once they exist.
		if _planet_nodes.has(body) and _planet_nodes[body].has_meta("retry"):
			_planet_nodes[body].queue_free()
			_planet_nodes.erase(body)
		if not _planet_nodes.has(body):
			var copy := _copy_body_visuals(body)
			_root.add_child(copy)
			_planet_nodes[body] = copy
		var node: Node3D = _planet_nodes[body]
		node.position = _to_map(body.global_position, focus)
		var rotation_basis := Basis(body.global_basis.get_rotation_quaternion())
		if node.has_meta("fallback"):
			rotation_basis = rotation_basis.scaled(Vector3.ONE * _body_radius(body))
		node.basis = rotation_basis


func _copy_body_visuals(body: Node3D) -> Node3D:
	var node := Node3D.new()
	var to_local := Transform3D(
		Basis(body.global_basis.get_rotation_quaternion()),
		body.global_position,
	).affine_inverse()
	for child in body.find_children("*", "MeshInstance3D", true, false):
		var source := child as MeshInstance3D
		if source.mesh == null or not source.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = source.mesh
		copy.material_override = source.material_override
		for i in source.get_surface_override_material_count():
			copy.set_surface_override_material(i, source.get_surface_override_material(i))
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.transform = to_local * source.global_transform
		node.add_child(copy)
	for child in body.find_children("*", "CSGShape3D", true, false):
		var csg := child as CSGShape3D
		if not csg.is_root_shape() or not csg.is_visible_in_tree():
			continue
		var baked := csg.get_meshes()
		if baked.size() < 2 or baked[1] == null:
			node.set_meta("retry", true)
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = baked[1]
		copy.material_override = csg.material_override
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.transform = to_local * csg.global_transform * (baked[0] as Transform3D)
		node.add_child(copy)
	if node.get_child_count() == 0:
		node.set_meta("fallback", true)
		var sphere := SphereMesh.new()
		sphere.material = _unshaded(Color(0.0, 0.1, 0.14))
		var instance := MeshInstance3D.new()
		instance.mesh = sphere
		instance.scale = Vector3.ONE * 2.0 # SphereMesh radius is 0.5
		node.add_child(instance)
	return node


func _sync_points_of_interest(focus: Node3D) -> void:
	var points: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(poi_group):
		if node is Node3D:
			points.append(node)
	for point in _poi_nodes.keys():
		if not is_instance_valid(point) or not points.has(point):
			_poi_nodes[point].queue_free()
			_poi_nodes.erase(point)
	for point in points:
		if not _poi_nodes.has(point):
			var dot := MeshInstance3D.new()
			dot.mesh = _poi_mesh
			_root.add_child(dot)
			_poi_nodes[point] = dot
		var map_dot: MeshInstance3D = _poi_nodes[point]
		map_dot.position = _to_map(point.global_position, focus)
		map_dot.scale = Vector3.ONE * _view_radius * POI_SIZE
	var blink := 0.5 + 0.5 * cos(_time * poi_blink_speed * TAU)
	_poi_material.albedo_color = Color(POI_COLOUR, lerpf(0.15, 1.0, blink))


func _update_orbit_plane(ship: RigidBody3D, focus: Node3D, delta: float) -> void:
	var normal := (ship.global_position - focus.global_position).cross(player.get_orbit_velocity())
	if normal.length_squared() < 0.0001:
		return
	_plane_normal = _plane_normal.lerp(normal.normalized(), clampf(delta * 2.0, 0.0, 1.0)).normalized()


## Zooms so the planet, the ship and the nearby path fit in view.
func _update_zoom(ship: RigidBody3D, focus: Node3D, delta: float) -> void:
	var ship_distance := ship.global_position.distance_to(focus.global_position)
	var target := maxf(_body_radius(focus) * 1.2, ship_distance)
	var orbit := player.get_current_orbit()
	if player.is_orbit_locked() and orbit:
		target = maxf(target, orbit.apoapsis)
	for point in _predicted:
		target = maxf(target, minf(point.distance_to(focus.global_position), ship_distance * 2.0))
	target *= fit_padding
	if _view_radius < 0.0:
		_view_radius = target
	else:
		_view_radius = lerpf(_view_radius, target, clampf(delta * zoom_smoothing, 0.0, 1.0))


func _update_ship_marker(ship: RigidBody3D, focus: Node3D) -> void:
	_ship_marker.position = _to_map(ship.global_position, focus)
	_ship_marker.basis = Basis(ship.global_basis.get_rotation_quaternion()).scaled(
		Vector3.ONE * _view_radius * MARKER_SIZE
	)


## Draws the locked orbit (pulsing green ellipse) while locked, otherwise the
## predicted path coloured by the forecast.
func _draw_path(focus: Node3D) -> void:
	_path_mesh.clear_surfaces()
	if player.is_orbit_locked():
		var orbit := player.get_current_orbit()
		var source := player.get_locked_source()
		if orbit == null or source == null or not is_finite(orbit.period):
			return
		var colour := STABLE_COLOUR.lerp(Color.WHITE, _lock_pulse() * 0.6)
		var offset := _to_map(source.global_position, focus)
		_path_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in LOCKED_ORBIT_SEGMENTS + 1:
			var t := orbit.period * i / LOCKED_ORBIT_SEGMENTS
			_path_mesh.surface_set_color(colour)
			_path_mesh.surface_add_vertex(offset + orbit.position_at(t))
		_path_mesh.surface_end()
		return

	if _predicted.size() < 2:
		return
	var colour := _forecast_colour(_forecast())
	_path_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in _predicted.size():
		var c := colour
		c.a = lerpf(1.0, 0.25, float(i) / (_predicted.size() - 1))
		_path_mesh.surface_set_color(c)
		_path_mesh.surface_add_vertex(_to_map(_predicted[i], focus))
	_path_mesh.surface_end()


## Draws each DeadZone as a red ring: the sphere's cross-section through its
## centre on the orbit plane the map is looking at. Blinks while outside.
func _draw_dead_zones(focus: Node3D) -> void:
	_dead_zone_mesh.clear_surfaces()
	for node in get_tree().get_nodes_in_group(&"dead_zone"):
		var zone := node as DeadZone
		if zone == null:
			continue
		var colour := DEAD_ZONE_COLOUR
		if zone.is_player_outside():
			colour.a *= 1.0 if fmod(_time * 3.0, 1.0) < 0.5 else 0.3
		var centre := _to_map(zone.global_position, focus)
		var u := _plane_normal.cross(Vector3.UP)
		if u.length_squared() < 0.0001:
			u = _plane_normal.cross(Vector3.RIGHT)
		u = u.normalized()
		var v := _plane_normal.cross(u).normalized()
		_dead_zone_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in DEAD_ZONE_SEGMENTS + 1:
			var angle := TAU * i / DEAD_ZONE_SEGMENTS
			_dead_zone_mesh.surface_set_color(colour)
			_dead_zone_mesh.surface_add_vertex(centre + (u * cos(angle) + v * sin(angle)) * zone.radius)
		_dead_zone_mesh.surface_end()


## Looks down on the orbit plane, tilted toward the ship, ship at the top.
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
