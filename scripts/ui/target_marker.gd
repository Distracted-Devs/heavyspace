class_name TargetMarker
extends Control

const CAPTION_WIDTH := 140.0
const CAPTION_INSET := 56.0

@export var colour := Color(1.0, 0.3, 0.8)
@export_range(0.0, 400.0, 1.0, "or_greater") var margin := 70.0:
	set(value):
		if not Contract.require(value >= 0.0, "margin must not be negative"):
			return
		margin = value
@export_range(4.0, 128.0, 1.0) var diamond_size := 26.0
@export_range(4.0, 128.0, 1.0) var arrow_size := 26.0
@export_range(6, 64, 1) var font_size := 16
@export_range(0.05, 10.0, 0.05) var pulse_hz := 1.4

var target := Vector3.ZERO
var has_target := false
var text := ""
var on_screen := false
var marker_position := Vector2.ZERO
var pointing := Vector2.UP

var _marking := false
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	place(get_viewport().get_camera_3d())


func is_marking() -> bool:
	return _marking


func place(camera: Camera3D) -> void:
	_marking = has_target and camera != null
	queue_redraw()
	if not _marking:
		return
	var screen := camera.get_viewport().get_visible_rect().size
	var middle := screen * 0.5
	var behind := camera.is_position_behind(target)
	var projected := camera.unproject_position(target)
	var safe := Rect2(Vector2.ONE * margin, screen - Vector2.ONE * margin * 2.0)
	on_screen = not behind and safe.has_point(projected)
	if on_screen:
		marker_position = projected
		return
	var direction := projected - middle
	if behind:
		direction = -direction
	if direction.length() < 1.0:
		direction = Vector2.UP
	pointing = direction.normalized()
	var half := middle - Vector2.ONE * margin
	var reach := minf(
		half.x / absf(pointing.x) if not is_zero_approx(pointing.x) else INF,
		half.y / absf(pointing.y) if not is_zero_approx(pointing.y) else INF,
	)
	marker_position = middle + pointing * reach


func _draw() -> void:
	if not _marking:
		return
	var glow := 0.5 - 0.5 * cos(TAU * pulse_hz * _time)
	var shown := colour.lerp(Color.WHITE, glow * 0.35)
	if on_screen:
		var reach := diamond_size + glow * 6.0
		var diamond := PackedVector2Array(
			[
				marker_position + Vector2(0.0, -reach),
				marker_position + Vector2(reach, 0.0),
				marker_position + Vector2(0.0, reach),
				marker_position + Vector2(-reach, 0.0),
				marker_position + Vector2(0.0, -reach),
			]
		)
		draw_polyline(diamond, shown, 2.0, true)
		_caption(marker_position + Vector2(0.0, reach + 22.0), shown)
		return
	var side := Vector2(-pointing.y, pointing.x)
	var back := marker_position - pointing * arrow_size
	var arrow := PackedVector2Array(
		[
			marker_position,
			back + side * arrow_size * 0.6,
			back - side * arrow_size * 0.6,
		]
	)
	draw_colored_polygon(arrow, shown)
	_caption(marker_position - pointing * CAPTION_INSET, shown)


func _caption(centre: Vector2, shown: Color) -> void:
	if text == "":
		return
	draw_string(
		get_theme_default_font(),
		centre + Vector2(-CAPTION_WIDTH * 0.5, font_size * 0.4),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		CAPTION_WIDTH,
		font_size,
		shown,
	)
