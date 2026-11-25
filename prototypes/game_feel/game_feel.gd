extends Node

# Drives every game-feel effect on top of the real level. Finds the player
# in the sibling GeneratedLevel instance.

@export_group("Camera lag")
## How fast the camera catches up with the ship's turn (higher = tighter).
@export var follow_speed := 4.0
## How fast the camera catches up while boosting (higher = tighter).
@export var boost_follow_speed := 6.0

@export_group("Bank")
## Bank (degrees) per rad/s of yaw rate.
@export var bank_per_yaw_rate := 25.0
@export var max_bank_degrees := 35.0
## How fast the ship tilts into and out of the turn.
@export var bank_speed := 6.0
## Also bank a little with roll input feel? 0 = off.
@export var bank_from_input := 0.0

@export_group("Boost pull")
## Furthest the ship pulls ahead, as a fraction of the camera distance.
@export var max_pull := 0.35
## Seconds of boosting to reach the full pull.
@export var pull_ramp_time := 1.5
## Boost force that counts as "1x" strength (the base back_thrust_force).
@export var reference_force := 150.0
## Spring that moves the camera towards the pull target.
@export var pull_stiffness := 30.0
@export var pull_damping := 8.0

@export_group("Speed lines")
## Acceleration (units/s²) where the lines start, and where they're full.
@export var lines_min_accel := 5.0
@export var lines_max_accel := 150.0
@export var lines_amount := 400
@export var lines_lifetime := 0.8
## Extra speed the lines get on top of the ship's, as a fraction of it.
@export var lines_extra_speed := 0.3
## Width of the spawn box, as multiples of the camera distance.
@export var lines_spread := 3.0
@export var lines_length := 1.5
@export var lines_max_alpha := 0.6
## Line speed (units/s) at the peak of a warp.
@export var warp_line_speed := 600.0
## Line length at the peak of a warp, as a multiple of the normal length.
@export var warp_line_stretch := 4.0

@export_group("Ambient lines")
## Always-on short motes drifting lazily along the direction of travel.
## They wrap round a box around the ship, so they stay at any speed.
@export var ambient_amount := 250
## Drift speed (units/s) on top of the ship's own motion, scaled by camera distance.
@export var ambient_drift := 0.15
## Mote length, as a fraction of the camera distance.
@export var ambient_length := 0.04
@export var ambient_alpha := 0.35
## Half-size of the wrapping box, as multiples of the camera distance.
@export var ambient_spread := 2.5

@export_group("Boost blur")
@export var blur_strength := 0.6
@export var blur_clear_radius := 0.12
@export var blur_speed := 4.0
## Blur at the peak of a warp.
@export var warp_blur := 1.0
## Chromatic aberration at the peak of a warp (colour split, as a fraction of
## the distance from the ship on screen).
@export var warp_aberration := 0.04

@export_group("Acceleration")
## How quickly the measured acceleration follows changes (higher = twitchier).
@export var accel_smoothing := 8.0

@export_group("Rumble")
## Acceleration (units/s²) where the rumble starts, and where it peaks.
@export var rumble_min_accel := 5.0
@export var rumble_max_accel := 150.0
## Rumble at top speed (0–1). The speed rumble never goes above this.
@export var rumble_max := 0.35
@export var death_rumble := 1.0
@export var death_rumble_time := 0.8
## One punchy rumble when a pickup lands in the ship.
@export var pickup_strong := 0.7
@export var pickup_weak := 0.4
@export var pickup_rumble_time := 0.18
## Higher = snappier tail (1 = linear fade).
@export var pickup_fade_power := 2.0
## Warp rumble: builds up to the jump on the way out, and starts at its peak
## and settles on the way in.
@export var warp_weak := 0.6
@export var warp_strong := 1.0
## How late the heavy motor kicks in (higher = more of a final surge).
@export var warp_strong_power := 3.0

@export_group("Thrust FX")
## Engine level when idle (0–1).
@export var idle_level := 0.15
@export var spool_up := 6.0
@export var spool_down := 3.0
@export var idle_amount := 0.25
@export var idle_velocity := 0.3
@export var boost_velocity := 1.3
@export var idle_scale := 0.5
@export var boost_scale := 1.2

@export_group("FOV kick")
## Extra degrees of field of view at a full boost (1x strength; up to 2x).
@export var fov_kick := 10.0
## How quickly the FOV widens and settles back.
@export var fov_speed := 4.0

@export_group("Camera roll")
## Fraction of the ship's bank the camera rolls with (0 = off, 1 = locked).
@export var camera_roll := 0.2

@export_group("Absorb squash")
## Bodies being sucked in squash first, then stretch towards the ship.
@export var absorb_squash_enabled := true
## Fraction of the suck spent on the anticipation squash.
@export var anticipation := 0.2
## How flat the squash gets (0.3 = 30% shorter along the pull).
@export var squash_amount := 0.3
## How long the stretch gets at the end (2 = 3x long).
@export var stretch_amount := 2.0

@export_group("Hit-stop")
## Real seconds the game freezes on the crash.
@export var hitstop_time := 0.12
## Time scale during the freeze (0.02 = near frozen).
@export var hitstop_scale := 0.02
## Time scale the slow motion starts at after the freeze, easing back to 1.
@export var slowmo_scale := 0.25
## Real seconds the slow motion takes to ease back to normal speed.
@export var slowmo_time := 1.2
## Real seconds after the slow motion before the crash pop-up shows.
@export var popup_delay := 0.2

@export_group("Crash bounce")
## Share of the impact speed the ship keeps as it bounces off (0–1).
@export var bounce_restitution := 0.5
## Least bounce-off speed, in camera distances per second.
@export var bounce_min_speed := 1.5
## How quickly the bounce slows down (per second of game time).
@export var bounce_drag := 1.2
## Tumble spin as the ship bounces away, in degrees per second.
@export var bounce_tumble := 360.0
## Keep the explosion centred on the ship as it bounces, not at the impact.
@export var explosion_follows_ship := true

@export_group("Camera shake")
## Shake on the crash (0–1 trauma); it decays at shake_decay per second.
@export var death_shake := 1.0
## Shake at the peak of a warp (follows the warp curve).
@export var warp_shake := 0.6
@export var shake_decay := 1.2
## Largest offset, as a fraction of the camera distance.
@export var shake_offset := 0.06
@export var shake_frequency := 25.0

@export_group("HUD")
## Cargo tanks per row; a full row spans the boost bar's width.
@export var tanks_per_row := 5
## Space between rows of cargo tanks, in pixels.
@export var tank_row_gap := 3.0
## Space between tanks in a row, as a fraction of a tank's slot.
@export var tank_gap := 0.08
## Space between the BOOST and CARGO gauges, in pixels.
@export var gauge_gap := 2.0

@export_group("Debug")
@export var show_readout := true

var player: RigidBody3D
var camera_component: Node3D
var camera: Camera3D
var mesh: Node3D
var thrust_fx: GPUParticles3D
var thruster: Node
var flight_input: Node
var fuel: Node

var _lagged := Quaternion.IDENTITY
var _bank := 0.0
var _pull := 0.0
var _pull_velocity := 0.0
var _boost_time := 0.0
var _engine := 0.0
var _blur := 0.0
var _lost := false
var _death_left := 0.0
var _pickup_left := 0.0
var warp_effect: Node
var _base_fov := 75.0
var _fov_level := 0.0
var _last_usec := 0
var _hitstop_left := 0.0
var _slowmo_left := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var _noise := FastNoiseLite.new()
var absorb: Node
var lose_overlay: CanvasLayer
var crash_effect: Node
var _fuel_gauge: Node
var _cargo_gauge: Node
var _popup_left := -1.0
var _bounce_velocity := Vector3.ZERO
var _tumble_axis := Vector3.RIGHT
var _tumble_speed := 0.0
var _rumble_tick := 0.0
var _last_velocity := Vector3.ZERO
var _accel := 0.0
var _thrust_accel := 0.0

var _thrust_material: ParticleProcessMaterial
var _base_velocity := Vector2.ZERO
var _base_scale := Vector2.ZERO

var _lines: GPUParticles3D
var _lines_material: ParticleProcessMaterial
var _lines_mesh: CylinderMesh
var _lines_draw: StandardMaterial3D
var _blur_rect: ColorRect
var _ambient: GPUParticles3D
var _ambient_material: ShaderMaterial
var _ambient_mesh: CylinderMesh
var _ambient_draw: StandardMaterial3D
var _readout: Label


# Player-facing "mass" becomes "cargo". The skill tree is a shared resource,
# so renaming its titles here (in memory only) is picked up when the shop
# builds its views.
func _enter_tree() -> void:
	var tree: Resource = load("res://resources/progression/skill_tree.tres")
	for node in tree.nodes:
		node.title = node.title.replace("Mass", "Cargo").replace("mass", "cargo")


func _ready() -> void:
	process_physics_priority = 100
	var level := get_node("../GeneratedLevel")
	player = level.get_node("Player")
	camera_component = player.get_node("CameraComponent")
	camera = camera_component.get_node("Camera3D")
	mesh = player.get_node("Mesh")
	thrust_fx = mesh.get_node("ThrustFX")
	thruster = player.get_node("ThrusterComponent")
	flight_input = player.get_node("PlayerInputComponent")
	fuel = player.get_node("FuelComponent")
	_lagged = player.global_basis.get_rotation_quaternion()
	level.get_node("LoseController").lost_game.connect(_on_lost)
	player.get_node("AbsorbEffect").absorbed.connect(_on_absorbed)
	warp_effect = level.get_node("WarpEffect")
	absorb = player.get_node("AbsorbEffect")
	lose_overlay = level.get_node("LoseOverlay")
	crash_effect = level.get_node("CrashEffect")
	# Gauges keep only their title and bar: no FUL/MASS readout underneath.
	_fuel_gauge = level.get_node("FuelGauge")
	_cargo_gauge = level.get_node("CargoGauge")
	_fuel_gauge.readout.visible = false
	_cargo_gauge.readout.visible = false
	# Plain titles, and no panel border or background.
	_fuel_gauge.title.text = "BOOST"
	_cargo_gauge.title.text = "CARGO"
	# Boost reads as one solid bar rather than cells: swap the gauge's own
	# segment drawing for a plain fill.
	var fuel_bar: Control = _fuel_gauge.bar
	var segmented := Callable(_fuel_gauge, "_draw_bar")
	if fuel_bar.draw.is_connected(segmented):
		fuel_bar.draw.disconnect(segmented)
	fuel_bar.draw.connect(_draw_solid_fuel_bar)
	# Cargo tanks at a fixed width, five to a row.
	var cargo_bar: Control = _cargo_gauge.bar
	var stretched := Callable(_cargo_gauge, "_draw_bar")
	if cargo_bar.draw.is_connected(stretched):
		cargo_bar.draw.disconnect(stretched)
	cargo_bar.draw.connect(_draw_cargo_rows)
	# The scanline overlay spans the whole bar area, which shows as a strip
	# behind a part-filled row; only the tanks should draw.
	var scanlines := cargo_bar.get_node_or_null("Scanlines") as CanvasItem
	if scanlines:
		scanlines.visible = false
	_cargo_gauge.gap_px = gauge_gap
	for gauge in [_fuel_gauge, _cargo_gauge]:
		var style := gauge.panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.set_border_width_all(0)
			style.draw_center = false
	if OS.is_debug_build():
		print("[GameFeel] level seed %d" % level.get_node("HierarchyStreamer").resolved_seed)
	flight_input.invert_pitch = RunProgress.get_meta(&"game_feel_invert_pitch", false)
	_base_fov = warp_effect._start_fov if warp_effect.playing else camera.fov
	level.get_node("Minimap").title.visible = false
	_noise.frequency = 1.0
	_last_usec = Time.get_ticks_usec()
	_setup_thrust()
	_setup_lines()
	_setup_ambient()
	_setup_blur()
	_setup_readout()


func _physics_process(delta: float) -> void:
	_update_accel(delta)
	var boosting := _boost_input()
	_update_camera(delta, boosting)
	_update_bank(delta)
	_update_engine(delta, boosting)


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := minf((now - _last_usec) / 1e6, 0.1)
	_last_usec = now
	# The cargo gauge rewrites its title ("// MASS TANKS 2/3") every frame.
	_cargo_gauge.title.text = "CARGO"
	_update_hud_layout()
	_update_rumble(real)
	_update_hitstop(real)
	_update_shake(real)
	_update_fov(real)
	_update_squash()
	_update_lines()
	_update_ambient()
	_update_blur(delta)
	if _readout:
		_readout.text = (
			"speed %.1f  accel %.1f  thrust accel %.1f  engine %.2f  pull %.2f  bank %.0f°  boost t %.1f"
			% [_speed(), _accel, _thrust_accel, _engine, _pull, rad_to_deg(_bank), _boost_time]
		)


func _update_accel(delta: float) -> void:
	var velocity := player.linear_velocity
	var raw := (velocity - _last_velocity).length() / maxf(delta, 1e-4)
	_last_velocity = velocity
	if _lost:
		raw = 0.0
	_accel = lerpf(_accel, raw, 1.0 - exp(-accel_smoothing * delta))
	# Engine-only acceleration: drops to zero the moment the boost stops.
	var engine: float = (
		_boost_input() * thruster.back_thrust_force * thruster.thrust_multiplier
		/ maxf(player.mass, 1e-4)
	)
	_thrust_accel = lerpf(_thrust_accel, engine, 1.0 - exp(-accel_smoothing * delta))
	if _thrust_accel < 0.01:
		_thrust_accel = 0.0


func _speed() -> float:
	return player.linear_velocity.length()


func _boost_input() -> float:
	if _lost:
		return 0.0
	if fuel.fuel <= 0.0:
		return 0.0
	return absf(flight_input.thrust_intent.z)


func _strength() -> float:
	return thruster.back_thrust_force * thruster.thrust_multiplier / reference_force


# --- Camera lag and boost pull -------------------------------------------

func _update_camera(delta: float, boosting: float) -> void:
	if _lost:
		return
	var target := player.global_basis.get_rotation_quaternion()
	var rate := lerpf(follow_speed, boost_follow_speed, boosting)
	_lagged = _lagged.slerp(target, 1.0 - exp(-rate * delta)).normalized()

	if boosting > 0.0:
		_boost_time = minf(_boost_time + delta * boosting, pull_ramp_time * 3.0)
	else:
		_boost_time = maxf(_boost_time - delta * 2.0, 0.0)
	var ramp := clampf(_boost_time / pull_ramp_time, 0.0, 1.0)
	var target_pull: float = (
		max_pull * boosting * _strength() * ease(ramp, 0.5) * camera_component.distance
	)
	_pull_velocity += (target_pull - _pull) * pull_stiffness * delta
	_pull_velocity -= _pull_velocity * pull_damping * delta
	_pull += _pull_velocity * delta

	var look := Basis.from_euler(
		Vector3(camera_component.pitch, camera_component.yaw, 0.0)
	)
	var lagged_basis := Basis(_lagged)
	var back := player.global_basis.z.normalized()
	camera_component.global_transform = Transform3D(
		lagged_basis * look * Basis(Vector3.BACK, _bank * camera_roll), player.global_position + back * _pull
	)


# --- Bank ----------------------------------------------------------------

func _update_bank(delta: float) -> void:
	if _lost:
		_update_bounce(delta)
		return
	var local_spin: Vector3 = player.global_basis.orthonormalized().inverse() * player.angular_velocity
	var target := local_spin.y * deg_to_rad(bank_per_yaw_rate)
	target += flight_input.rotation_intent.y * deg_to_rad(bank_from_input)
	var limit := deg_to_rad(max_bank_degrees)
	target = clampf(target, -limit, limit)
	if _lost:
		target = _bank
	_bank = lerpf(_bank, target, 1.0 - exp(-bank_speed * delta))
	mesh.rotation = Vector3(0.0, 0.0, _bank)


func _draw_solid_fuel_bar() -> void:
	var fuel_bar: Control = _fuel_gauge.bar
	var rect := Rect2(Vector2.ZERO, fuel_bar.size)
	fuel_bar.draw_rect(rect.grow(-1.0), _fuel_gauge.TRACK_COLOUR)
	var filled := clampf(_fuel_gauge.fraction, 0.0, 1.0) * (rect.size.x - 1.0)
	if filled > 0.0:
		fuel_bar.draw_rect(
			Rect2(0.5, 0.5, filled, rect.size.y - 1.0), _fuel_gauge.bar_colour()
		)


func _update_hud_layout() -> void:
	var fuel_bar: Control = _fuel_gauge.bar
	var cargo_bar: Control = _cargo_gauge.bar
	var rows := maxi(1, ceili(float(_cargo_gauge.fills.size()) / maxi(tanks_per_row, 1)))
	var row_height: float = _cargo_gauge.bar_height_px
	cargo_bar.custom_minimum_size = Vector2(
		fuel_bar.size.x, rows * row_height + (rows - 1) * tank_row_gap
	)
	# Trim the panels' inner padding where the two gauges meet.
	var fuel_style := _fuel_gauge.panel.get_theme_stylebox("panel") as StyleBoxFlat
	var cargo_style := _cargo_gauge.panel.get_theme_stylebox("panel") as StyleBoxFlat
	if fuel_style:
		fuel_style.content_margin_bottom = 0.0
	if cargo_style:
		cargo_style.content_margin_top = 0.0


func _draw_cargo_rows() -> void:
	var cargo_bar: Control = _cargo_gauge.bar
	var fills: PackedFloat32Array = _cargo_gauge.fills
	var per_row := maxi(tanks_per_row, 1)
	var slot_width: float = _fuel_gauge.bar.size.x / per_row
	var gap := maxf(2.0, slot_width * tank_gap)
	var width := slot_width - gap
	var height: float = _cargo_gauge.bar_height_px - 1.0
	for tank in fills.size():
		var x := (tank % per_row) * slot_width + 0.5
		var y: float = (tank / per_row) * (_cargo_gauge.bar_height_px + tank_row_gap) + 0.5
		var full := fills[tank] >= 1.0
		var shown: Color = _cargo_gauge.tank_colour(full)
		var slot := Rect2(x, y, width, height)
		cargo_bar.draw_rect(slot, _cargo_gauge.TRACK_COLOUR)
		cargo_bar.draw_rect(slot, Color(shown, _cargo_gauge.OUTLINE_ALPHA), false, 1.0)
		if fills[tank] > 0.0:
			cargo_bar.draw_rect(Rect2(x, y, width * fills[tank], height), shown)


# --- Crash bounce --------------------------------------------------------

func _start_bounce(other: Node3D) -> void:
	var normal := player.global_position - other.global_position
	normal = normal.normalized() if normal.length() > 0.001 else player.global_basis.z
	var velocity := player.linear_velocity
	var into := velocity.dot(normal)
	if into < 0.0:
		velocity -= (1.0 + bounce_restitution) * into * normal
	var least: float = bounce_min_speed * camera_component.distance
	var out := velocity.dot(normal)
	if out < least:
		velocity += (least - out) * normal
	_bounce_velocity = velocity
	_tumble_axis = normal.cross(velocity).normalized()
	if _tumble_axis.length() < 0.5:
		_tumble_axis = player.global_basis.x
	_tumble_speed = deg_to_rad(bounce_tumble)


# The body is frozen once the run is lost, so move it by hand. Physics delta
# is scaled by Engine.time_scale, so this plays in the crash slow motion.
func _update_bounce(delta: float) -> void:
	player.global_position += _bounce_velocity * delta
	if explosion_follows_ship:
		for blast in crash_effect._explosions:
			blast.global_position = mesh.global_position
	_bounce_velocity *= exp(-bounce_drag * delta)
	_tumble_speed *= exp(-bounce_drag * 0.5 * delta)
	mesh.global_basis = (
		Basis(_tumble_axis, _tumble_speed * delta) * mesh.global_basis
	)


# --- Thrust FX -----------------------------------------------------------

func _setup_thrust() -> void:
	player.get_node("ThrustEffect").process_mode = Node.PROCESS_MODE_DISABLED
	_thrust_material = thrust_fx.process_material.duplicate()
	thrust_fx.process_material = _thrust_material
	_base_velocity = Vector2(
		_thrust_material.initial_velocity_min, _thrust_material.initial_velocity_max
	)
	_base_scale = Vector2(_thrust_material.scale_min, _thrust_material.scale_max)
	thrust_fx.emitting = true


func _update_engine(delta: float, boosting: float) -> void:
	var target := maxf(idle_level, boosting * minf(_strength(), 2.0))
	var rate := spool_up if target > _engine else spool_down
	_engine = lerpf(_engine, target, 1.0 - exp(-rate * delta))
	var level := clampf(_engine, 0.0, 1.0)
	thrust_fx.emitting = not _lost and not warp_effect.playing
	thrust_fx.amount_ratio = lerpf(idle_amount, 1.0, level)
	var v := lerpf(idle_velocity, boost_velocity, _engine)
	_thrust_material.initial_velocity_min = _base_velocity.x * v
	_thrust_material.initial_velocity_max = _base_velocity.y * v
	var s := lerpf(idle_scale, boost_scale, level)
	_thrust_material.scale_min = _base_scale.x * s
	_thrust_material.scale_max = _base_scale.y * s


# --- Speed lines ---------------------------------------------------------

func _setup_lines() -> void:
	_lines = GPUParticles3D.new()
	_lines.top_level = true
	_lines.local_coords = false
	_lines.amount = lines_amount
	_lines.lifetime = lines_lifetime
	_lines.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	_lines.visibility_aabb = AABB(Vector3(-1e4, -1e4, -1e4), Vector3(2e4, 2e4, 2e4))
	_lines_material = ParticleProcessMaterial.new()
	_lines_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_lines_material.spread = 0.0
	_lines_material.gravity = Vector3.ZERO
	_lines_material.alpha_curve = _fade_curve()
	_lines.process_material = _lines_material
	_lines_mesh = CylinderMesh.new()
	_lines_mesh.top_radius = 0.015
	_lines_mesh.bottom_radius = 0.015
	_lines_mesh.radial_segments = 4
	_lines_mesh.rings = 1
	_lines_draw = StandardMaterial3D.new()
	_lines_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lines_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lines_draw.vertex_color_use_as_albedo = true
	_lines_draw.albedo_color = Color(0.8, 0.9, 1.0, 0.0)
	_lines_mesh.material = _lines_draw
	_lines.draw_pass_1 = _lines_mesh
	add_child(_lines)


func _fade_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _update_lines() -> void:
	var velocity := player.linear_velocity
	var speed := velocity.length()
	var ratio := clampf(
		(_thrust_accel - lines_min_accel) / maxf(lines_max_accel - lines_min_accel, 0.01), 0.0, 1.0
	)
	if _lost:
		ratio = 0.0
	var warp := _warp_t()
	var stretch := 1.0
	var extra := speed * lines_extra_speed
	if warp > 0.0:
		ratio = maxf(ratio, warp)
		var forward := -player.global_basis.z.normalized()
		velocity = forward * maxf(speed, 1.0)
		speed = maxf(speed, 1.0)
		extra = warp_line_speed * warp
		stretch = lerpf(1.0, warp_line_stretch, warp)
	_lines.emitting = ratio > 0.0
	_lines.amount_ratio = maxf(ratio, 0.01)
	_lines_draw.albedo_color.a = lines_max_alpha * ratio
	if speed < 0.01:
		return
	var dir := velocity / speed
	var distance: float = camera_component.distance
	var relative := speed + extra
	var ahead := relative * lines_lifetime * 0.5
	_lines.global_position = player.global_position + dir * ahead
	var spread := distance * lines_spread
	_lines_material.emission_box_extents = Vector3(spread, spread, spread)
	_lines_material.direction = -dir
	_lines_material.initial_velocity_min = extra
	_lines_material.initial_velocity_max = extra
	_lines_mesh.height = lines_length * distance * (0.3 + ratio) * stretch


# --- Ambient lines (wrapping space dust) --------------------------------

func _setup_ambient() -> void:
	_ambient = GPUParticles3D.new()
	_ambient.top_level = true
	_ambient.local_coords = false
	_ambient.amount = ambient_amount
	_ambient.lifetime = 600.0
	_ambient.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	_ambient.visibility_aabb = AABB(Vector3(-1e7, -1e7, -1e7), Vector3(2e7, 2e7, 2e7))
	_ambient_material = ShaderMaterial.new()
	_ambient_material.shader = preload("res://prototypes/game_feel/ambient_dust.gdshader")
	_ambient.process_material = _ambient_material
	_ambient_mesh = CylinderMesh.new()
	_ambient_mesh.radial_segments = 4
	_ambient_mesh.rings = 1
	_ambient_draw = StandardMaterial3D.new()
	_ambient_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ambient_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ambient_draw.vertex_color_use_as_albedo = true
	_ambient_draw.albedo_color = Color(0.8, 0.9, 1.0, ambient_alpha)
	_ambient_mesh.material = _ambient_draw
	_ambient.draw_pass_1 = _ambient_mesh
	_update_ambient()
	_ambient.emitting = true
	add_child(_ambient)


func _update_ambient() -> void:
	var velocity := player.linear_velocity
	var speed := velocity.length()
	var dir := velocity / speed if speed > 0.5 else -player.global_basis.z.normalized()
	var distance: float = camera_component.distance
	_ambient.visible = not _lost
	_ambient_draw.albedo_color.a = ambient_alpha
	_ambient_material.set_shader_parameter("box_centre", player.global_position)
	_ambient_material.set_shader_parameter("box_half", distance * ambient_spread)
	_ambient_material.set_shader_parameter("drift", -dir * ambient_drift * distance)
	_ambient_mesh.top_radius = 0.004 * distance
	_ambient_mesh.bottom_radius = 0.004 * distance
	_ambient_mesh.height = ambient_length * distance


# --- Boost blur ----------------------------------------------------------

func _setup_blur() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	_blur_rect = ColorRect.new()
	_blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://prototypes/game_feel/radial_blur.gdshader")
	_blur_rect.material = material
	layer.add_child(_blur_rect)


func _update_blur(delta: float) -> void:
	var target := _boost_input() * blur_strength * minf(_strength(), 2.0)
	_blur = lerpf(_blur, target, 1.0 - exp(-blur_speed * delta))
	_blur = maxf(_blur, warp_blur * _warp_t())
	var split := warp_aberration * _warp_t()
	_blur_rect.visible = _blur > 0.002 or split > 0.0001
	var material := _blur_rect.material as ShaderMaterial
	material.set_shader_parameter("strength", _blur)
	material.set_shader_parameter("aberration", split)
	material.set_shader_parameter("clear_radius", blur_clear_radius)
	var viewport := get_viewport().get_visible_rect().size
	var focus := mesh.global_position
	if not camera.is_position_behind(focus):
		material.set_shader_parameter("centre", camera.unproject_position(focus) / viewport)


# --- Rumble --------------------------------------------------------------

func _update_rumble(delta: float) -> void:
	_rumble_tick -= delta
	if _rumble_tick > 0.0:
		return
	_rumble_tick = 0.03
	if not RunProgress.get_meta(&"game_feel_rumble", true):
		for device in Input.get_connected_joypads():
			Input.stop_joy_vibration(device)
		return
	var weak := 0.0
	var strong := 0.0
	if _death_left > 0.0:
		_death_left -= 0.03
		var fade := clampf(_death_left / death_rumble_time, 0.0, 1.0)
		weak = death_rumble * fade
		strong = death_rumble * fade * fade
	elif not _lost:
		var ratio := clampf(
			(_thrust_accel - rumble_min_accel) / maxf(rumble_max_accel - rumble_min_accel, 0.01),
			0.0,
			1.0,
		)
		weak = rumble_max * ratio
	if _pickup_left > 0.0 and not _lost:
		var t := clampf(_pickup_left / pickup_rumble_time, 0.0, 1.0)
		var envelope := pow(t, pickup_fade_power)
		weak = maxf(weak, pickup_weak * envelope)
		strong = maxf(strong, pickup_strong * envelope)
		_pickup_left -= 0.03
	if warp_effect.playing and not _lost:
		var t := _warp_t()
		weak = maxf(weak, warp_weak * t)
		strong = maxf(strong, warp_strong * pow(t, warp_strong_power))
	for device in Input.get_connected_joypads():
		if weak > 0.0 or strong > 0.0:
			Input.start_joy_vibration(device, weak, strong, 0.12)
		else:
			Input.stop_joy_vibration(device)


# 0 outside a warp; on the way out it rises 0 → 1, on the way in 1 → 0.
func _warp_t() -> float:
	if warp_effect == null or not warp_effect.playing or _lost:
		return 0.0
	var progress := clampf(warp_effect._elapsed / warp_effect.warp_duration, 0.0, 1.0)
	return 1.0 - progress if warp_effect.playing_in else progress


func _on_absorbed(_mass: float) -> void:
	_pickup_left = pickup_rumble_time
	_rumble_tick = 0.0


func _on_lost(other: Node3D) -> void:
	_lost = true
	# CrashEffect spawned its blast on this same signal (it connected first).
	# Local coordinates make the whole cloud travel with it.
	if explosion_follows_ship:
		for blast in crash_effect._explosions:
			for particles in blast.find_children("*", "GPUParticles3D", true, false):
				particles.local_coords = true
	_start_bounce(other)
	_hitstop_left = hitstop_time
	_slowmo_left = slowmo_time
	Engine.time_scale = hitstop_scale
	_trauma = maxf(_trauma, death_shake)
	# The overlay showed itself on the same signal; hold it back until the
	# explosion has played in slow motion.
	lose_overlay.visible = false
	_popup_left = hitstop_time + slowmo_time + popup_delay
	_death_left = death_rumble_time
	_rumble_tick = 0.0


# --- Readout -------------------------------------------------------------

func _setup_readout() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_readout = Label.new()
	_readout.position = Vector2(12, 12)
	_readout.visible = show_readout
	layer.add_child(_readout)


# --- FOV kick ------------------------------------------------------------

func _update_fov(delta: float) -> void:
	var target := _boost_input() * minf(_strength(), 2.0)
	_fov_level = lerpf(_fov_level, target, 1.0 - exp(-fov_speed * delta))
	if warp_effect.playing:
		return
	camera.fov = _base_fov + fov_kick * _fov_level


# --- Hit-stop and slow motion (real time) -------------------------------

func _update_hitstop(real: float) -> void:
	if _popup_left >= 0.0:
		_popup_left -= real
		if _popup_left < 0.0:
			lose_overlay.visible = true
	if _hitstop_left > 0.0:
		_hitstop_left -= real
		Engine.time_scale = hitstop_scale
		return
	if _slowmo_left > 0.0:
		_slowmo_left = maxf(_slowmo_left - real, 0.0)
		var t := 1.0 - _slowmo_left / maxf(slowmo_time, 0.001)
		Engine.time_scale = lerpf(slowmo_scale, 1.0, t * t)
		return
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0


# --- Camera shake --------------------------------------------------------

func _update_shake(real: float) -> void:
	_trauma = maxf(_trauma - shake_decay * real, 0.0)
	var amount := maxf(_trauma, warp_shake * _warp_t())
	_shake_time += real * shake_frequency
	var size: float = amount * amount * shake_offset * camera_component.distance
	camera.h_offset = _noise.get_noise_2d(_shake_time, 0.0) * size
	camera.v_offset = _noise.get_noise_2d(0.0, _shake_time + 100.0) * size


# --- Absorb squash and stretch ------------------------------------------

func _update_squash() -> void:
	if not absorb_squash_enabled:
		return
	var duration: float = maxf(absorb.suck_duration, 0.001)
	for slot in absorb._bodies.size():
		var body = absorb._bodies[slot]
		if not is_instance_valid(body) or body.mesh == null:
			continue
		var t := minf(absorb._elapsed[slot] / duration, 1.0)
		var to_ship: Vector3 = player.global_position - body.global_position
		if to_ship.length() < 0.001:
			continue
		var dir := to_ship.normalized()
		var along := 1.0
		if t < anticipation:
			along = 1.0 - squash_amount * sin(PI * t / maxf(anticipation, 0.001))
		else:
			var u := (t - anticipation) / maxf(1.0 - anticipation, 0.001)
			along = 1.0 + stretch_amount * u * u
		var across := 1.0 / sqrt(along)
		var size: Vector3 = absorb._scales[slot]
		if absorb.shrink:
			size *= 1.0 - t * t
		var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
		body.mesh.global_basis = (
			Basis.looking_at(dir, up) * Basis.from_scale(size * Vector3(across, across, along))
		)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	for device in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)
