extends CanvasLayer
## Arcade-style thrust/fuel gauge.
##
## Reads the ship's fuel (FuelComponent.fuel / max_fuel) and draws a chunky,
## segmented bar with a hard drop shadow, bevelled blocks and CRT scanlines.
## The fill colour steps through tiers as the tank empties
## (green -> yellow -> orange -> red) and flashes when low.
##
## Usage: instance hud.tscn in a scene that has a Player.

## Leave empty to use the first Player found in the current scene.
@export var player: Player

@export_group("Layout")
## Bar length as a fraction of the screen width.
@export_range(0.05, 0.5) var bar_width_ratio: float = 0.18
## Bar height as a fraction of the screen height (clamped to at least 14 px).
@export_range(0.01, 0.1) var bar_height_ratio: float = 0.03
## Number of segments in the bar.
@export_range(2, 60) var segments: int = 16
## Distance from the top-left corner as a fraction of the screen height.
@export_range(0.0, 0.2) var margin_ratio: float = 0.015

@export_group("Colours")
## Fill colour per tier, used while fuel fraction is at or above the threshold.
@export var full_colour := Color(0.2, 1.0, 0.35)
@export var mid_colour := Color(1.0, 0.9, 0.15)
@export_range(0.0, 1.0) var mid_threshold: float = 0.6
@export var low_colour := Color(1.0, 0.5, 0.1)
@export_range(0.0, 1.0) var low_threshold: float = 0.3
@export var critical_colour := Color(1.0, 0.15, 0.2)

@export_group("Feedback")
## Below this amount of fuel the gauge flashes and shows a warning.
@export var low_fuel: float = 10.0
## Flash speed in Hz while warning.
@export var flash_hz: float = 4.0

var _root: VBoxContainer
var _title: Label
var _percent: Label
var _bar: Control
var _label: Label
var _flash := 0.0
var _fraction := 1.0
var _display_fraction := 1.0
var _fill_colour := Color.WHITE
var _warning := false
var _border_px := 3.0


func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _process(delta: float) -> void:
	if not _find_player():
		return
	_flash += delta
	_update(delta)

# --- UI ----------------------------------------------------------------------


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


func _build_ui() -> void:
	_root = VBoxContainer.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_theme_constant_override("separation", 4)
	add_child(_root)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(header)

	_title = ArcadeUI.make_label("THRUST")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)

	_percent = ArcadeUI.make_label()
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_percent)

	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_root.add_child(_bar)

	_bar.add_child(ArcadeUI.make_scanlines())

	_label = ArcadeUI.make_label()
	_root.add_child(_label)


## Sizes everything from the screen so it looks the same at any resolution.
func _update_layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var margin := screen.y * margin_ratio
	var font_size := ArcadeUI.font_size(screen.y)

	_border_px = ArcadeUI.border_px(screen.y)
	_bar.custom_minimum_size = Vector2(
		screen.x * bar_width_ratio, maxf(14.0, screen.y * bar_height_ratio)
	)
	_root.position = Vector2(margin, margin)
	_title.add_theme_font_size_override("font_size", font_size)
	_percent.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_font_size_override("font_size", maxi(9, font_size - 4))


func _tier_colour(fraction: float) -> Color:
	if fraction >= mid_threshold:
		return full_colour
	if fraction >= low_threshold:
		return mid_colour
	if not _warning:
		return low_colour
	return critical_colour


func _update(delta: float) -> void:
	var fuel: float = player.fuel_component.fuel
	_fraction = clampf(player.fuel_component.get_fraction(), 0.0, 1.0)
	# Ease the visible bar towards the real value for a snappier arcade feel.
	_display_fraction = lerpf(_display_fraction, _fraction, 1.0 - exp(-12.0 * delta))
	_warning = fuel < low_fuel
	_fill_colour = _tier_colour(_fraction)

	var blink_on := not _warning or fmod(_flash * flash_hz, 1.0) < 0.5
	var text_colour := _fill_colour if blink_on else Color(_fill_colour, 0.25)

	_percent.add_theme_color_override("font_color", text_colour)
	_percent.text = "%3d%%" % roundi(_fraction * 100.0)
	_label.add_theme_color_override("font_color", text_colour)

	if _warning:
		_label.text = "!! LOW FUEL !!" if blink_on else ""
	else:
		var seconds_left: float = fuel / maxf(player.fuel_drain_rate, 0.001)
		_label.text = "T-%04.1f" % seconds_left

	_bar.queue_redraw()


func _draw_bar() -> void:
	var blink_on := not _warning or fmod(_flash * flash_hz, 1.0) < 0.5
	ArcadeUI.draw_segment_bar(
		_bar, _display_fraction, segments, _fill_colour, _border_px,
		ArcadeUI.FRAME_COLOUR if blink_on else _fill_colour
	)
