class_name ObjectiveTracker
extends CanvasLayer
## Arcade-style objective panel under the minimap: header, objective text,
## a big kill counter and one block per asteroid in a segmented bar.

@export var minimap: OrbitMinimap
@export var objective_template: String = "Destroy all %d asteroids across the planet and save humanity"
@export var gap_px: float = 8.0
## Most blocks drawn in the progress bar; beyond this the bar fills proportionally.
@export_range(1, 40) var max_blocks: int = 16
## How long the counter flashes after an asteroid is destroyed, in seconds.
@export var hit_flash_seconds: float = 0.6

var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _title: Label
var _objective: Label
var _counter: Label
var _bar: Control
var _total := 0
var _destroyed := 0
var _border_px := 3.0
var _flash_left := 0.0


func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	_collect_missions.call_deferred()


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(0.0, _flash_left - delta)
	_refresh()


func _collect_missions() -> void:
	if minimap == null:
		for node in get_tree().current_scene.find_children("*", "CanvasLayer", true, false):
			if node is OrbitMinimap:
				minimap = node
				break
		_update_layout()
	for node in get_tree().current_scene.find_children("*", "Node3D", true, false):
		if node is AsteroidMission:
			var mission := node as AsteroidMission
			_total += 1
			if mission.is_completed:
				_destroyed += 1
			else:
				mission.completed.connect(_on_mission_completed)
	_refresh()


func _on_mission_completed() -> void:
	_destroyed += 1
	_flash_left = hit_flash_seconds
	_refresh()


func _is_done() -> bool:
	return _total > 0 and _destroyed >= _total


func _refresh() -> void:
	_objective.text = objective_template % _total
	_counter.text = "%02d/%02d" % [_destroyed, _total]
	var colour := ArcadeUI.GOOD_COLOUR if _is_done() else ArcadeUI.ACCENT_COLOUR
	var flashing := _flash_left > 0.0 and fmod(_flash_left * 8.0, 1.0) < 0.5
	_counter.add_theme_color_override("font_color", ArcadeUI.TEXT_COLOUR if flashing else colour)
	_title.text = "OBJECTIVE COMPLETE" if _is_done() else "OBJECTIVE"
	_title.add_theme_color_override("font_color", colour if _is_done() else ArcadeUI.TEXT_COLOUR)
	_panel_style.border_color = colour if _is_done() or flashing else ArcadeUI.FRAME_COLOUR
	_bar.queue_redraw()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel_style = ArcadeUI.make_frame_style()
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	_title = ArcadeUI.make_label("OBJECTIVE")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title)

	_counter = ArcadeUI.make_label("", ArcadeUI.ACCENT_COLOUR)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_counter)

	_objective = ArcadeUI.make_label("", ArcadeUI.SUBTEXT_COLOUR)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_objective)

	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_bar.add_child(ArcadeUI.make_scanlines())
	vbox.add_child(_bar)

	_refresh()


func _update_layout() -> void:
	var screen_height := get_viewport().get_visible_rect().size.y
	var size_ratio := 0.34
	var margin_ratio := 0.015
	var min_size := 160.0
	if minimap:
		size_ratio = minimap.size_ratio
		margin_ratio = minimap.margin_ratio
		min_size = minimap.min_size_px
	var size := maxf(min_size, screen_height * size_ratio)
	var margin := screen_height * margin_ratio
	var font_size := ArcadeUI.font_size(screen_height)

	_border_px = ArcadeUI.border_px(screen_height)
	ArcadeUI.apply_frame(_panel_style, _border_px, maxf(4.0, screen_height * 0.01))
	_panel.offset_left = -margin - size
	_panel.offset_right = -margin
	# Leave room for the minimap's drop shadow.
	_panel.offset_top = margin + size + gap_px + _border_px
	_title.add_theme_font_size_override("font_size", font_size)
	_counter.add_theme_font_size_override("font_size", font_size + 6)
	_objective.add_theme_font_size_override("font_size", maxi(9, font_size - 6))
	_bar.custom_minimum_size = Vector2(0, maxf(12.0, screen_height * 0.022))


func _draw_bar() -> void:
	var fraction := float(_destroyed) / _total if _total > 0 else 0.0
	var colour := ArcadeUI.GOOD_COLOUR if _is_done() else ArcadeUI.ACCENT_COLOUR
	ArcadeUI.draw_segment_bar(_bar, fraction, clampi(_total, 1, max_blocks), colour, _border_px)
