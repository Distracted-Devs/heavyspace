extends Node

# Title screen over the live level. Shown once per launch: Start marks it
# seen and restarts the scene, which then plays as normal (warp in and all).
# While it shows, the player is frozen and hidden, the HUD is hidden, and an
# overview camera frames the system's central body on the bottom-left
# third-lines intersection while the orbits run fast.

const SEEN := &"game_feel_title_seen"
const RUMBLE := &"game_feel_rumble"
const INVERT := &"game_feel_invert_pitch"
const ENDGAME := &"game_feel_endgame"

@export var enabled := true
## How much faster the orbits run behind the title.
@export var time_speed := 100.0
## Camera distance from the central body, in body radii.
@export var distance_radii := 2.67
## Camera elevation above the orbital plane, in degrees.
@export var elevation_degrees := 28.0
## Slow orbit of the camera around the body, in degrees per second.
@export var camera_orbit_speed := 1.5
## Where the body's centre sits on screen (0–1; 2/3, 2/3 = bottom-right third).
@export var screen_point := Vector2(2.0 / 3.0, 2.0 / 3.0)
## The menu layout. Edit prototypes/game_feel/title_menu.tscn in the editor.
@export var menu_scene: PackedScene = preload("res://prototypes/game_feel/title_menu.tscn")
## Level seed behind the title, so it looks the same every launch. Each run
## prints its own seed ("[GameFeel] level seed ..."), so a run you liked can
## be copied here. 0 = random.
@export var title_seed := 1

var level: Node
var player: Node3D
var clock: Node
var pool: Node
var camera: Camera3D
var streamer: Node
var _renderer: Node3D
var _radius := 0.0
var _angle := 0.0
var _menu: Control
var _options: Control
var _start: Button
var _endgame_button: Button
var _rumble_button: Button
var _invert_button: Button


# Every node in the scene enters the tree before any is ready, so the seed
# is in place before the streamer generates the level in its _ready.
func _enter_tree() -> void:
	if not enabled or RunProgress.get_meta(SEEN, false):
		return
	get_node("../GeneratedLevel/HierarchyStreamer").level_seed = title_seed


func _ready() -> void:
	level = get_node("../GeneratedLevel")
	if not enabled or RunProgress.get_meta(SEEN, false):
		set_process(false)
		set_process_unhandled_input(false)
		queue_free()
		return
	player = level.get_node("Player")
	clock = level.get_node("Clock")
	pool = level.get_node("LiveBodyPool")
	streamer = level.get_node("HierarchyStreamer")
	_quiet_the_level()
	camera = Camera3D.new()
	camera.far = 1e6
	add_child(camera)
	camera.current = true
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _quiet_the_level() -> void:
	player.stop_flight()
	player.visible = false
	var warp := level.get_node("WarpEffect")
	warp.playing = false
	warp.playing_in = false
	warp.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("WarpFade/Fade").color.a = 0.0
	for node_name in [
		"PauseController", "WarpController", "LoseController",
		"TutorialOverlay",
	]:
		level.get_node(node_name).process_mode = Node.PROCESS_MODE_DISABLED
	for child in level.get_children():
		if child is CanvasLayer:
			child.visible = false
	var feel := get_node_or_null("../GameFeel")
	if feel:
		feel.process_mode = Node.PROCESS_MODE_DISABLED
		for child in feel.get_children():
			if child is CanvasLayer or child is Node3D:
				child.visible = false
	var endgame := get_node_or_null("../EndgameBuild")
	if endgame:
		for child in endgame.get_children():
			if child is CanvasLayer:
				child.visible = false
	clock.running = false


func _process(delta: float) -> void:
	clock._time += delta * time_speed
	clock._publish()
	if _renderer == null or not is_instance_valid(_renderer):
		_pick_biggest()
	if _renderer == null:
		return
	_angle += deg_to_rad(camera_orbit_speed) * delta
	_frame(_renderer.global_position, _radius)


# The hierarchy's root body: the top-tier parent every system orbits. It
# sits at the root renderer's origin with the streamer's root_radius.
func _pick_biggest() -> void:
	_renderer = null
	if streamer._renderers.is_empty():
		return
	_renderer = streamer._renderers[0]
	_radius = streamer.root_radius


func _frame(centre: Vector3, radius: float) -> void:
	var distance := radius * distance_radii
	var elevation := deg_to_rad(elevation_degrees)
	var offset := Vector3(
		cos(elevation) * sin(_angle), sin(elevation), cos(elevation) * cos(_angle)
	) * distance
	var eye := centre + offset
	var look := Transform3D(Basis.IDENTITY, eye).looking_at(centre, Vector3.UP)
	# Turn the camera so the centre lands on screen_point instead of the
	# middle: NDC x is left -1..1 right, y is bottom -1..1 top.
	var ndc := Vector2(screen_point.x * 2.0 - 1.0, 1.0 - screen_point.y * 2.0)
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var tan_v := tan(deg_to_rad(camera.fov) * 0.5)
	var yaw := atan(ndc.x * tan_v * aspect)
	var pitch := atan(ndc.y * tan_v)
	var turned := look.basis * Basis.from_euler(Vector3(-pitch, yaw, 0.0), EULER_ORDER_YXZ)
	camera.global_transform = Transform3D(turned, eye)


# --- Menu ----------------------------------------------------------------

# The layout lives in title_menu.tscn so it can be edited in the editor;
# this only wires the buttons up by their unique names.
func _build_ui() -> void:
	var ui: CanvasLayer = menu_scene.instantiate()
	add_child(ui)
	_menu = ui.get_node("%Menu")
	_options = ui.get_node("%OptionsMenu")
	_start = ui.get_node("%Start")
	_endgame_button = ui.get_node("%EndgameBuild")
	_rumble_button = ui.get_node("%Vibration")
	_invert_button = ui.get_node("%InvertPitch")
	_start.pressed.connect(_on_start)
	ui.get_node("%Options").pressed.connect(_on_options)
	ui.get_node("%Exit").pressed.connect(_on_exit)
	_endgame_button.pressed.connect(_toggle.bind(ENDGAME, true))
	_rumble_button.pressed.connect(_toggle.bind(RUMBLE, true))
	_invert_button.pressed.connect(_toggle.bind(INVERT, false))
	ui.get_node("%Back").pressed.connect(_on_back)
	_options.visible = false
	_menu.visible = true
	_refresh_options()
	_start.grab_focus.call_deferred()


func _refresh_options() -> void:
	var endgame_default: bool = get_node("../EndgameBuild").enabled
	_endgame_button.text = "ENDGAME BUILD: %s" % _on_off(RunProgress.get_meta(ENDGAME, endgame_default))
	_rumble_button.text = "VIBRATION: %s" % _on_off(RunProgress.get_meta(RUMBLE, true))
	_invert_button.text = "INVERT PITCH: %s" % _on_off(RunProgress.get_meta(INVERT, false))


func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"


func _toggle(key: StringName, default: bool) -> void:
	if key == ENDGAME:
		default = get_node("../EndgameBuild").enabled
	var on: bool = not RunProgress.get_meta(key, default)
	RunProgress.set_meta(key, on)
	if key == ENDGAME and not on:
		RunProgress.progression = Progression.new()
	if key == RUMBLE and on:
		for device in Input.get_connected_joypads():
			Input.start_joy_vibration(device, 0.3, 0.5, 0.15)
	_refresh_options()


func _on_start() -> void:
	RunProgress.set_meta(SEEN, true)
	get_tree().reload_current_scene()


func _on_options() -> void:
	_menu.visible = false
	_options.visible = true
	_endgame_button.grab_focus()


func _on_back() -> void:
	_options.visible = false
	_menu.visible = true
	_menu.get_node("Options").grab_focus()


func _on_exit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
