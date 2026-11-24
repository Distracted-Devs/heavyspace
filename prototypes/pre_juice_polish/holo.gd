extends RefCounted

## Prototype holo/vaporwave look, matching the HUD and shop: dark glass
## panels with thin neon borders, a monospace font and scanlines.

const CYAN := Color(0.3, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.3, 0.8)
const GOLD := Color(1.0, 0.88, 0.3)
const GLASS := Color(0.0, 0.04, 0.07, 0.75)
const FONT_NAMES := ["Menlo", "Consolas", "DejaVu Sans Mono", "monospace"]
const SCANLINES := preload("res://resources/shaders/holo_scanlines.gdshader")

static var _font: SystemFont


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(FONT_NAMES)
	return _font


static func box(border := CYAN, border_alpha := 0.6, margin := 14.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = GLASS
	style.border_color = Color(border, border_alpha)
	style.set_border_width_all(1)
	style.set_content_margin_all(margin)
	return style


## A glass panel with scanlines behind its content.
static func panel(border := CYAN, border_alpha := 0.6, margin := 14.0) -> PanelContainer:
	var container := PanelContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_theme_stylebox_override("panel", box(border, border_alpha, margin))
	container.add_child(scanlines())
	return container


static func scanlines(tint := Color(CYAN, 0.05)) -> ColorRect:
	var rect := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = SCANLINES
	material.set_shader_parameter("tint", tint)
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect


static func label(text: String, size: int, colour: Color, alpha := 1.0) -> Label:
	var result := Label.new()
	result.text = text
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", font())
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", Color(colour, alpha))
	result.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	result.add_theme_constant_override("outline_size", 4)
	return result


static func row(separation := 8) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.alignment = BoxContainer.ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_constant_override("separation", separation)
	return result


static func column(separation := 6) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_constant_override("separation", separation)
	return result


## 0..1..0 at `hz`, for pulsing highlights.
static func pulse(time: float, hz := 1.5) -> float:
	return 0.5 - 0.5 * cos(time * TAU * hz)


## A filled triangle pointing along `direction` with its tip at `tip`.
static func draw_arrow(
	canvas: CanvasItem,
	tip: Vector2,
	direction: Vector2,
	size: float,
	colour: Color,
) -> void:
	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var back := tip - forward * size
	var points := PackedVector2Array([
		tip,
		back + side * size * 0.6,
		back - side * size * 0.6,
	])
	canvas.draw_colored_polygon(points, colour)
	canvas.draw_polyline(points + PackedVector2Array([tip]), Color.WHITE, 1.5, true)
