class_name TitleScreen
extends Node3D

const QUIET_NODES: Array[StringName] = [
	&"PauseController",
	&"WarpController",
	&"LoseController",
	&"TutorialOverlay",
	&"WarpEffect",
]
const CAMERA_FAR := 1e6

@export_group("Scenes")
@export var level_scene: PackedScene = preload(
	"res://scenes/levels/generated_level.tscn"
)
@export_file(
	"*.tscn"
) var game_scene := "res://scenes/levels/generated_level.tscn"
@export var menu_scene: PackedScene = preload("res://scenes/ui/title_menu.tscn")

@export_group("Overview")
@export var title_seed := 1
@export_range(0.0, 1000.0, 1.0, "or_greater") var time_speed := 100.0:
	set(value):
		var message := "time_speed must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		time_speed = value
@export_range(-30.0, 30.0, 0.1) var orbit_speed_degrees := 1.5
@export var framing := TitleFraming.new()

@export_group("Events")
@export var events: GameEvents

var level: Node3D
var menu: TitleMenu
var camera: Camera3D
var streamer: HierarchyStreamer

var _angle := 0.0


func _ready() -> void:
	if not Contract.require(
		level_scene != null and menu_scene != null and framing != null,
		"level_scene, menu_scene and framing must be set",
	):
		return
	_add_level()
	_quiet_level()
	camera = Camera3D.new()
	camera.far = CAMERA_FAR
	add_child(camera)
	camera.make_current()
	menu = menu_scene.instantiate()
	menu.start_pressed.connect(start)
	menu.exit_pressed.connect(get_tree().quit)
	add_child(menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update(0.0)
	_start_session()


func _process(delta: float) -> void:
	update(delta)


func update(delta: float) -> void:
	_angle += deg_to_rad(orbit_speed_degrees) * delta
	var root := streamer.renderer_for(PackedInt32Array())
	if root == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var aspect := screen.x / maxf(screen.y, 1.0)
	camera.global_transform = TitleCamera.frame(
		root.global_position,
		streamer.root_radius,
		_angle,
		framing,
		camera.fov,
		aspect,
	)


func start() -> void:
	get_tree().change_scene_to_file(game_scene)


func _start_session() -> void:
	if events == null:
		events = get_node_or_null(^"/root/Events") as GameEvents
	if events != null:
		events.start_session()


func _add_level() -> void:
	level = level_scene.instantiate()
	streamer = level.get_node("HierarchyStreamer")
	streamer.level_seed = title_seed
	(level.get_node("Clock") as Clock).speed = time_speed
	(level.get_node("WarpEffect") as WarpEffect).play_in_on_ready = false
	add_child(level)


func _quiet_level() -> void:
	var player: Player = level.get_node("Player")
	player.stop_flight()
	player.visible = false
	for quiet in QUIET_NODES:
		level.get_node(NodePath(quiet)).process_mode = (
			Node.PROCESS_MODE_DISABLED
		)
	for child in level.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	(level.get_node("WarpFade/Fade") as ColorRect).color.a = 0.0
