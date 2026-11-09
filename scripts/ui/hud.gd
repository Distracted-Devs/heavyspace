extends CanvasLayer
## Sci-fi holographic thrust/fuel readout, styled to match OrbitMinimap.
##
## Reads the ship's fuel (FuelComponent.fuel / max_fuel) and draws a segmented
## holo bar with a scanline overlay. Turns red and flashes below low_fuel_ratio.
##
## Usage: instance hud.tscn in a scene that has a Player.

## Leave empty to use the first Player found in the current scene.
@export var player: Player

@export_group("Layout")
## Bar length as a fraction of the screen width.
@export_range(0.05, 0.5) var bar_width_ratio: float = 0.16
## Bar height in pixels (clamped to at least 10).
@export var bar_height_px: float = 14.0
## Number of segments in the bar.
@export_range(2, 60) var segments: int = 20
## Distance from the top-left corner as a fraction of the screen height.
@export_range(0.0, 0.2) var margin_ratio: float = 0.015

@export_group("Feedback")
## Below this fraction of fuel the readout warns (red + flashing).
@export var low_fuel: float = 10.0
## Flash speed in Hz while warning.
@export var flash_hz: float = 2.0

const HOLO_COLOUR := Color(0.3, 0.9, 1.0)
const LOW_COLOUR := Color(1.0, 0.25, 0.2)
const SCANLINE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.3, 0.9, 1.0, 0.05);
void fragment() {
	float line = step(0.5, fract(FRAGCOORD.y / 3.0));
	// Slightly brighter towards the edges, like a hologram frame.
	vec2 edge = abs(UV - 0.5) * 2.0;
	float vignette = smoothstep(0.6, 1.0, max(edge.x, edge.y));
	COLOR = vec4(tint.rgb, tint.a * line + vignette * 0.08);
}
"""

var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _title: Label
var _bar: Control
var _label: Label
var _flash := 0.0


func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _process(delta: float) -> void:
	if not _find_player():
		return
	_flash += delta
	_update()

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
	var mono: Font = preload("res://resources/Fonts/PixelSans/PixelifySans-Regular.ttf")

	_panel = PanelContainer.new()
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.0, 0.04, 0.07, 0.6)
	_panel_style.border_color = Color(HOLO_COLOUR, 0.6)
	_panel_style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	_panel.add_child(vbox)

	_title = Label.new()
	_title.text = "// THRUST RESERVE"
	_title.add_theme_font_override("font", mono)
	_title.add_theme_color_override("font_color", Color(HOLO_COLOUR, 0.8))
	vbox.add_child(_title)

	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	vbox.add_child(_bar)

	var scanlines := ColorRect.new()
	scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SCANLINE_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	scanlines.material = shader_material
	_bar.add_child(scanlines)

	_label = Label.new()
	_label.add_theme_font_override("font", mono)
	_label.add_theme_color_override("font_color", HOLO_COLOUR)
	vbox.add_child(_label)


## Sizes everything from the screen so it looks the same at any resolution.
func _update_layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var margin := screen.y * margin_ratio
	var font_size := maxi(9, int(screen.y * 0.02))

	_bar.custom_minimum_size = Vector2(screen.x * bar_width_ratio, maxf(10.0, bar_height_px))
	_panel.offset_left = margin
	_panel.offset_top = margin
	_panel_style.set_content_margin_all(maxf(3.0, screen.y * 0.01))
	_title.add_theme_font_size_override("font_size", font_size - 1)
	_label.add_theme_font_size_override("font_size", font_size)


func _update() -> void:
	var fuel: float = player.fuel_component.fuel
	var warning := fuel < low_fuel
	var colour := LOW_COLOUR if warning else HOLO_COLOUR
	if warning:
		colour.a = 0.5 + 0.5 * absf(sin(_flash * TAU * flash_hz))
	var fraction := clampf(player.fuel_component.get_fraction(), 0.0, 1.0)

	_title.add_theme_color_override("font_color", Color(colour, 0.8) if not warning else colour)
	_label.add_theme_color_override("font_color", colour)
	_bar.queue_redraw()
	_bar.set_meta("fraction", fraction)
	_bar.set_meta("colour", colour)

	var seconds_left: float = fuel / maxf(player.fuel_drain_rate, 0.001)
	_label.text = "FUEL %3d | T-%.1fs" % [int(fuel), seconds_left]


func _draw_bar() -> void:
	var rect := _bar.get_rect()
	var fraction: float = _bar.get_meta("fraction", 0.0)
	var colour: Color = _bar.get_meta("colour", HOLO_COLOUR)
	var gap := maxf(1.0, rect.size.x / segments * 0.25)
	var segment_width := rect.size.x / segments

	# Unlit track.
	_bar.draw_rect(rect.grow(-1), Color(0.0, 0.09, 0.12, 0.8))

	# Lit segments: full segments solid, the partial one a clipped sliver.
	var lit := fraction * segments
	for i in segments:
		var x := i * segment_width
		var width := segment_width - gap
		if i >= lit:
			break
		if i + 1 > lit:
			width = maxf(0.0, width * (lit - i))
		_bar.draw_rect(Rect2(x + 0.5, 0.5, width, rect.size.y - 1.0), colour)
