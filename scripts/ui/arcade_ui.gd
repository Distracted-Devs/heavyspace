class_name ArcadeUI
extends RefCounted
## Shared look for the arcade HUD: chunky white frames, hard black drop
## shadows, outlined pixel text and bevelled segment bars.

const FRAME_COLOUR := Color(1.0, 1.0, 1.0)
const SHADOW_COLOUR := Color(0.0, 0.0, 0.0, 0.85)
const TRACK_COLOUR := Color(0.06, 0.06, 0.1, 0.95)
const PANEL_COLOUR := Color(0.04, 0.04, 0.08, 0.8)
const TEXT_COLOUR := Color(1.0, 1.0, 1.0)
const SUBTEXT_COLOUR := Color(0.8, 0.82, 0.9)
const ACCENT_COLOUR := Color(1.0, 0.9, 0.15)
const GOOD_COLOUR := Color(0.2, 1.0, 0.35)
const DANGER_COLOUR := Color(1.0, 0.15, 0.2)
const FONT: Font = preload("res://resources/Fonts/PixelSans/PixelifySans-Bold.ttf")

const SCANLINE_SHADER := """
shader_type canvas_item;
void fragment() {
	float line = step(0.5, fract(FRAGCOORD.y / 3.0));
	COLOR = vec4(0.0, 0.0, 0.0, 0.18 * line);
}
"""


## Frame thickness for the current screen height.
static func border_px(screen_height: float) -> float:
	return maxf(2.0, roundf(screen_height * 0.004))


## Header font size for the current screen height.
static func font_size(screen_height: float) -> int:
	return maxi(10, int(screen_height * 0.026))


## Outlined, drop-shadowed pixel label.
static func make_label(text := "", colour := TEXT_COLOUR) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(label, colour)
	return label


static func style_label(label: Label, colour := TEXT_COLOUR) -> void:
	label.add_theme_font_override("font", FONT)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", SHADOW_COLOUR)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)


## Panel with a white frame and a hard drop shadow. Call apply_frame() on
## layout changes to size the border for the screen.
static func make_frame_style(bg := PANEL_COLOUR) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = FRAME_COLOUR
	style.shadow_color = SHADOW_COLOUR
	style.shadow_size = 1
	return style


static func apply_frame(style: StyleBoxFlat, border: float, padding := 0.0) -> void:
	style.set_border_width_all(int(border))
	style.shadow_offset = Vector2(border, border)
	style.set_content_margin_all(border + padding)


static func make_scanlines() -> ColorRect:
	var scanlines := ColorRect.new()
	scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SCANLINE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	scanlines.material = material
	return scanlines


## Draws a framed, segmented bar filling `canvas` (call from its draw signal).
static func draw_segment_bar(
	canvas: Control, fraction: float, segments: int, colour: Color, border: float,
	frame_colour := FRAME_COLOUR
) -> void:
	var outer := Rect2(Vector2.ZERO, canvas.size)
	canvas.draw_rect(Rect2(outer.position + Vector2(border, border), outer.size), SHADOW_COLOUR)
	canvas.draw_rect(outer, frame_colour)
	var inner := outer.grow(-border)
	canvas.draw_rect(inner, TRACK_COLOUR)

	segments = maxi(1, segments)
	var area := inner.grow(-maxf(1.0, border * 0.67))
	var gap := maxf(2.0, border)
	var seg_w := (area.size.x - gap * (segments - 1)) / segments
	var lit := clampf(fraction, 0.0, 1.0) * segments
	var hi := colour.lightened(0.55)
	var lo := colour.darkened(0.45)
	var bevel := maxf(1.0, roundf(area.size.y * 0.18))

	for i in segments:
		var block := Rect2(area.position.x + i * (seg_w + gap), area.position.y, seg_w, area.size.y)
		if i >= lit:
			canvas.draw_rect(block, Color(colour, 0.12))
			continue
		if i + 1 > lit:
			block.size.x *= lit - i
		canvas.draw_rect(block, colour)
		canvas.draw_rect(Rect2(block.position, Vector2(block.size.x, bevel)), hi)
		canvas.draw_rect(
			Rect2(block.position + Vector2(0, block.size.y - bevel), Vector2(block.size.x, bevel)), lo
		)
