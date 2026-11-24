class_name ShopOverlay
extends CanvasLayer

signal launched

const TAB_ROOM := Vector2(40.0, 60.0)

@export_group("Components")
@export var warp_controller: WarpController
@export var run_starter: RunStarter
@export var camera: ShopCamera
@export var view: Control
@export var tree_area: Control
@export var level_label: Label
@export var bank_label: Label
@export var warp_button: Button
@export var sky_camera: Camera3D

@export_group("Shop")
@export var reload_on_launch := true
@export var node_scene: PackedScene = preload(
	"res://scenes/ui/skill_node_view.tscn"
)

@export_group("Layout")
@export_range(10.0, 1000.0, 1.0, "or_greater") var column := 340.0
@export_range(10.0, 1000.0, 1.0, "or_greater") var row := 190.0

@export_group("Sky")
@export_range(0.0, 20.0, 0.1, "or_greater") var sky_spin_speed := 1.5
@export_range(0.0, 60.0, 0.5, "or_greater") var sky_parallax := 6.0

var progression: Progression
var is_open := false
var views: Array[SkillNodeView] = []

var _sky_time := 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	if progression == null:
		progression = RunProgress.progression


func _ready() -> void:
	visible = false
	if not Contract.require(
		(
			warp_controller != null and run_starter != null
			and run_starter.tree != null and run_starter.tree.is_valid()
		),
		"warp_controller and run_starter with a valid tree must be set",
	):
		return
	_add_views(run_starter.tree)
	warp_button.pressed.connect(launch)
	warp_controller.warp_finished.connect(open)
	progression.changed.connect(_refresh)


func open() -> void:
	if not Contract.require(not is_open, "the shop must not already be open"):
		return
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	var first := _first_focus()
	first.grab_focus()
	camera.snap(_centre_of(first))
	_place_tree()


func launch() -> void:
	if not Contract.require(is_open, "the shop must be open"):
		return
	is_open = false
	get_tree().paused = false
	launched.emit()
	if reload_on_launch:
		get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if not is_open:
		return
	var focused := get_viewport().gui_get_focus_owner() as SkillNodeView
	var target := camera.position
	if focused != null and focused in views:
		target = _centre_of(focused)
	var push := (
		Input.get_action_strength(&"shop_zoom_in")
		- Input.get_action_strength(&"shop_zoom_out")
	)
	camera.advance(delta, target, clampf(push, -1.0, 1.0))
	_place_tree()
	_turn_sky(delta)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action("pause") or event.is_action("restart"):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("warp_out"):
		get_viewport().set_input_as_handled()
		launch()
	elif event is InputEventMouseButton and event.pressed:
		if event.is_action(&"shop_zoom_in"):
			camera.step_zoom(1.0)
		elif event.is_action(&"shop_zoom_out"):
			camera.step_zoom(-1.0)


func _add_views(tree: SkillTree) -> void:
	var lowest := Vector2(INF, INF)
	var highest := Vector2(-INF, -INF)
	for node in tree.nodes:
		lowest = lowest.min(_grid_position(node))
		highest = highest.max(_grid_position(node))
	for node in tree.nodes:
		var node_view: SkillNodeView = node_scene.instantiate()
		node_view.position = _grid_position(node) - lowest + TAB_ROOM
		node_view.pressed.connect(progression.buy.bind(node))
		tree_area.add_child(node_view)
		node_view.node = node
		views.append(node_view)
	var node_size := views[0].size if not views.is_empty() else Vector2.ZERO
	tree_area.size = highest - lowest + node_size + TAB_ROOM * 2.0


func _grid_position(node: SkillNode) -> Vector2:
	return Vector2(node.grid.x * column, node.grid.y * row)


func _first_focus() -> SkillNodeView:
	for node_view in views:
		if progression.can_buy(node_view.node):
			return node_view
	return views[0]


func _centre_of(node_view: Control) -> Vector2:
	return node_view.position + node_view.size * 0.5


func _place_tree() -> void:
	tree_area.scale = Vector2.ONE * camera.zoom
	tree_area.position = camera.offset(view.size).round()


func _turn_sky(delta: float) -> void:
	if sky_camera == null:
		return
	_sky_time += delta
	var pan := camera.position * sky_parallax / 1000.0
	sky_camera.rotation_degrees = Vector3(
		-pan.y,
		-_sky_time * sky_spin_speed - pan.x,
		0.0,
	)


func _refresh() -> void:
	if not is_open:
		return
	level_label.text = "PILOT LV %d" % progression.player_level()
	bank_label.text = "BANK %s" % MassText.mkg(progression.bank)
	for node_view in views:
		node_view.show_node(node_view.node, progression)
	Contract.invariant(
		_views_match(),
		"one view per node, in order, each showing its node's state",
	)


func _views_match() -> bool:
	var nodes := run_starter.tree.nodes
	if views.size() != nodes.size():
		return false
	for index in views.size():
		var node_view := views[index]
		if node_view.node != nodes[index]:
			return false
		if node_view.state != SkillNodeView.state_of(nodes[index], progression):
			return false
	return true
