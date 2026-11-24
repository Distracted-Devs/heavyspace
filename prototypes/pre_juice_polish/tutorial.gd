extends CanvasLayer

## Prototype tutorial, once per game session:
## 1. Flight training: each control in turn (pitch, yaw, roll, look, boost),
##    waiting for the player to hold it until the bar fills.
## 2. Objective: "MINE YOUR QUOTA", with an arrow to the nearest planet and
##    one at the mass tanks, until the first mass is collected.

const Icons := preload("res://prototypes/pre_juice_polish/input_icons.gd")
const Holo := preload("res://prototypes/pre_juice_polish/holo.gd")

## [title, hint, actions]. Look on the keyboard is the mouse, which isn't
## an action, so it's handled on its own.
const STEPS := [
	["PITCH", "tip the nose up and down", [&"pitch_down", &"pitch_up"]],
	["YAW", "swing the nose left and right", [&"turn_left", &"turn_right"]],
	["ROLL", "roll the ship over", [&"roll_left", &"roll_right"]],
	[
		"LOOK",
		"look around with the camera",
		[&"look_up", &"look_down", &"look_left", &"look_right"],
	],
	["BOOST", "fire the booster to fly forward", [&"back_thruster"]],
]

enum Phase { IDLE, CONTROLS, OBJECTIVE, DONE }

## Kept across scene reloads, so the tutorial runs once per game session.
static var controls_done := false
static var objective_done := false

@export var enabled := true
## Show it on every run, not just the first (for trying it out).
@export var every_run := false

@export_group("Controls")
## Seconds a control must be held to count.
@export_range(0.1, 5.0, 0.05) var hold_time := 0.7
## Mouse travel (pixels) that counts as looking around.
@export_range(10.0, 5000.0, 10.0) var mouse_distance := 600.0
@export_range(0.0, 1.0, 0.01) var input_threshold := 0.3
## Pause on the tick between steps.
@export_range(0.0, 3.0, 0.05) var step_gap := 0.6
@export_range(12.0, 96.0, 1.0) var icon_size := 40.0

@export_group("Objective")
## The planet arrow hides once the ship is this close to the surface.
@export_range(0.0, 5000.0, 10.0) var arrived_distance := 150.0
## Seconds the "well done" stays up after the first pickup.
@export_range(0.0, 10.0, 0.1) var objective_linger := 3.0
@export_range(0.1, 10.0, 0.1) var pulse_hz := 1.4

var _phase := Phase.IDLE
var _step := 0
var _progress := 0.0
var _gap := 0.0
var _linger := 0.0
var _time := 0.0
var _fade := 0.0

var _tracker: Node
var _player: Player
var _streamer: HierarchyStreamer
var _lose: LoseController
var _warp: WarpController
var _cargo_panel: Control

var _panel: PanelContainer
var _header: Label
var _prompt: HBoxContainer
var _hint: Label
var _bar: Control
var _overlay: Control


func setup(level: Node, tracker: Node) -> void:
	layer = 11
	_tracker = tracker
	_player = level.get_node("Player")
	_streamer = level.get_node("HierarchyStreamer")
	_lose = level.get_node("LoseController")
	_warp = level.get_node("WarpController")
	_cargo_panel = level.get_node("CargoGauge/Panel")
	_build()
	tracker.device_changed.connect(func(_device: int) -> void: _show_step())


## Called once the warp in has finished.
func begin() -> void:
	if not enabled:
		return
	if every_run or not controls_done:
		_phase = Phase.CONTROLS
		_step = 0
		_progress = 0.0
		_show_step()
	elif not objective_done:
		_start_objective()


func _process(delta: float) -> void:
	_time += delta
	match _phase:
		Phase.CONTROLS:
			_advance_controls(delta)
		Phase.OBJECTIVE:
			_advance_objective(delta)
	var showing := (
		_phase in [Phase.CONTROLS, Phase.OBJECTIVE]
		and not _lose.lost and not _warp.warping
	)
	_fade = move_toward(_fade, 1.0 if showing else 0.0, delta * 4.0)
	_panel.modulate.a = _fade
	_overlay.modulate.a = _fade
	_bar.queue_redraw()
	_overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if _phase != Phase.CONTROLS or _gap > 0.0 or STEPS[_step][0] != "LOOK":
		return
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_progress += motion.relative.length() / mouse_distance


# --- Controls -----------------------------------------------------------------


func _advance_controls(delta: float) -> void:
	if _gap > 0.0:
		_gap -= delta
		if _gap <= 0.0:
			_step += 1
			_progress = 0.0
			if _step >= STEPS.size():
				controls_done = true
				_start_objective()
			else:
				_show_step()
		return
	var strength := 0.0
	for action: StringName in STEPS[_step][2]:
		strength = maxf(strength, Input.get_action_strength(action))
	if strength >= input_threshold:
		_progress += delta / hold_time
	if _progress >= 1.0:
		_progress = 1.0
		_gap = step_gap
		_hint.text = "NICE!"
		_hint.add_theme_color_override("font_color", Holo.GOLD)


func _show_step() -> void:
	if _phase != Phase.CONTROLS or _step >= STEPS.size():
		return
	var step: Array = STEPS[_step]
	_header.text = "// FLIGHT TRAINING %d/%d" % [_step + 1, STEPS.size()]
	var icons := Icons.prompt(step[2], _tracker.device)
	if icons.is_empty() and step[0] == "LOOK":
		icons = [Icons.KEYBOARD % "mouse_xy"]
	_fill_prompt(icons, step[0])
	_hint.text = step[1].to_upper()
	_hint.add_theme_color_override("font_color", Color(Holo.CYAN, 0.85))
	_bar.visible = true


# --- Objective ------------------------------------------------------------------


func _start_objective() -> void:
	_phase = Phase.OBJECTIVE
	_linger = -1.0
	_header.text = "// OBJECTIVE"
	_fill_prompt([], "MINE YOUR QUOTA")
	_hint.text = "FLY INTO BODIES SMALLER THAN YOU TO FILL YOUR TANKS"
	_hint.add_theme_color_override("font_color", Color(Holo.CYAN, 0.85))
	_bar.visible = false


func _advance_objective(delta: float) -> void:
	if _linger < 0.0:
		if _player.cargo.stored > 0.0:
			_linger = objective_linger
			_fill_prompt([], "NICE! KEEP MINING")
			_hint.text = "FILL EVERY TANK, THEN WARP OUT"
			_hint.add_theme_color_override("font_color", Holo.GOLD)
		return
	_linger -= delta
	if _linger <= 0.0:
		objective_done = true
		_phase = Phase.DONE


func _mining() -> bool:
	return _phase == Phase.OBJECTIVE and _linger < 0.0


# --- Drawing ----------------------------------------------------------------------


func _build() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_END
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(centre)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 36.0
	stack.add_child(spacer)

	_panel = Holo.panel(Holo.CYAN, 0.7, 14.0)
	_panel.modulate.a = 0.0
	centre.add_child(_panel)
	var column := Holo.column(6)
	_panel.add_child(column)
	_header = Holo.label("", 14, Holo.CYAN, 0.7)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_header)
	_prompt = Holo.row(10)
	column.add_child(_prompt)
	_hint = Holo.label("", 16, Holo.CYAN, 0.85)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(320.0, 8.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	column.add_child(_bar)


func _fill_prompt(icons: Array, title: String) -> void:
	for child in _prompt.get_children():
		_prompt.remove_child(child)
		child.queue_free()
	for path: String in icons:
		_prompt.add_child(Icons.icon_rect(path, icon_size))
	_prompt.add_child(Holo.label(title, 28, Holo.GOLD))


func _draw_bar() -> void:
	var rect := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(rect, Color(0.0, 0.09, 0.12, 0.8))
	_bar.draw_rect(
		Rect2(rect.position, Vector2(rect.size.x * clampf(_progress, 0.0, 1.0), rect.size.y)),
		Holo.GOLD if _gap > 0.0 else Holo.MAGENTA,
	)
	_bar.draw_rect(rect, Color(Holo.CYAN, 0.5), false, 1.0)


func _draw_overlay() -> void:
	if not _mining():
		return
	var glow := Holo.pulse(_time, pulse_hz)
	var bounce := absf(sin(_time * PI * pulse_hz)) * 10.0
	_draw_cargo_arrow(glow, bounce)
	_draw_planet_marker(glow)


## An arrow at the mass tanks gauge, from its right.
func _draw_cargo_arrow(glow: float, bounce: float) -> void:
	var rect := _cargo_panel.get_global_rect()
	var tip := Vector2(rect.end.x + 10.0 + bounce, rect.get_center().y)
	var colour := Holo.GOLD.lerp(Color.WHITE, glow * 0.4)
	Holo.draw_arrow(_overlay, tip, Vector2.LEFT, 22.0, colour)
	_overlay.draw_string(
		Holo.font(),
		tip + Vector2(30.0, 7.0),
		"YOUR QUOTA",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		colour,
	)


## A reticle on the nearest planet, or an arrow at the screen edge when
## it's off screen.
func _draw_planet_marker(glow: float) -> void:
	var camera := _overlay.get_viewport().get_camera_3d()
	var planet := _nearest_planet()
	if camera == null or planet.is_empty():
		return
	var centre: Vector3 = planet[0]
	var radius: float = planet[1]
	var surface := _player.global_position.distance_to(centre) - radius
	if surface < arrived_distance:
		return
	var screen := _overlay.get_viewport_rect().size
	var middle := screen * 0.5
	var margin := 70.0
	var behind := camera.is_position_behind(centre)
	var point := camera.unproject_position(centre)
	var safe := Rect2(Vector2.ONE * margin, screen - Vector2.ONE * margin * 2.0)
	var colour := Holo.MAGENTA.lerp(Color.WHITE, glow * 0.35)
	var text := "PLANET %dm" % int(surface)
	if not behind and safe.has_point(point):
		var size := 26.0 + glow * 6.0
		var diamond := PackedVector2Array([
			point + Vector2(0, -size),
			point + Vector2(size, 0),
			point + Vector2(0, size),
			point + Vector2(-size, 0),
			point + Vector2(0, -size),
		])
		_overlay.draw_polyline(diamond, colour, 2.0, true)
		_overlay.draw_string(
			Holo.font(),
			point + Vector2(-60.0, size + 22.0),
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			120.0,
			16,
			colour,
		)
		return
	var direction := point - middle
	if behind:
		direction = -direction
	if direction.length() < 1.0:
		direction = Vector2.UP
	var half := middle - Vector2.ONE * margin
	var reach := minf(
		half.x / absf(direction.x) if direction.x != 0.0 else INF,
		half.y / absf(direction.y) if direction.y != 0.0 else INF,
	)
	var tip := middle + direction * reach
	Holo.draw_arrow(_overlay, tip, direction, 26.0, colour)
	var label_at := tip - direction.normalized() * 56.0
	_overlay.draw_string(
		Holo.font(),
		label_at + Vector2(-60.0, 6.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		120.0,
		16,
		colour,
	)


## [centre, radius] of the nearest planet, or [] if there are none.
func _nearest_planet() -> Array:
	var systems := _streamer.renderer_for(PackedInt32Array())
	if systems == null or systems.count() == 0:
		return []
	var time := _streamer.clock.time if _streamer.clock != null else 0.0
	var positions := systems.child_positions(time)
	var from := _player.global_position
	var best := INF
	var nearest := 0
	for index in positions.size():
		var distance := from.distance_squared_to(positions[index])
		if distance < best:
			best = distance
			nearest = index
	return [positions[nearest], systems.layout.radius[nearest]]
