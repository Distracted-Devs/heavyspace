class_name FpsOverlay
extends CanvasLayer

const LAYER := 50
const MARGIN := 8.0
const ALPHA := 0.6

@export_range(0.05, 2.0, 0.05, "or_greater") var refresh_interval := 0.25:
	set(value):
		var message := "refresh_interval must be positive"
		if not Contract.require(value > 0.0, message):
			return
		refresh_interval = value

var settings: GameSettings
var shown_fps := 0
var label: Label

var _until_refresh := 0.0


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_right = -MARGIN
	label.offset_bottom = -MARGIN
	label.offset_left = -MARGIN
	label.offset_top = -MARGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.modulate = Color(1.0, 1.0, 1.0, ALPHA)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _ready() -> void:
	if settings == null:
		settings = get_node_or_null(^"/root/Settings") as GameSettings
	if settings == null:
		visible = false
		return
	settings.changed.connect(_follow_setting)
	_follow_setting()


func _process(delta: float) -> void:
	update(delta)


func update(delta: float) -> void:
	if not visible:
		return
	_until_refresh -= delta
	if _until_refresh > 0.0:
		return
	_until_refresh = refresh_interval
	shown_fps = roundi(Engine.get_frames_per_second())
	label.text = "FPS %d" % shown_fps


func _follow_setting() -> void:
	visible = settings.show_fps
	_until_refresh = 0.0
