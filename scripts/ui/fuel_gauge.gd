class_name FuelGauge
extends CanvasLayer

const TRACK_COLOUR := Color(0.0, 0.09, 0.12, 0.8)
const MIN_BAR_HEIGHT := 10.0
const FONT_SCREEN_RATIO := 0.02
const MIN_FONT_SIZE := 9
const PADDING_SCREEN_RATIO := 0.01
const TITLE := "BOOST"

@export_group("Components")
@export var fuel: FuelComponent
@export var panel: PanelContainer
@export var title: Label
@export var bar: Control

@export_group("Layout")
@export_range(0.05, 0.5) var bar_width_ratio := 0.16
@export_range(10.0, 100.0, 1.0, "or_greater") var bar_height_px := 14.0:
	set(value):
		if not Contract.require(
			value >= MIN_BAR_HEIGHT,
			"bar_height_px must be at least 10",
		):
			return
		bar_height_px = value
@export_range(0.0, 0.2) var margin_ratio := 0.015

@export_group("Warning")
@export_range(0.0, 1.0) var low_fuel_fraction := 0.15:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"low_fuel_fraction must be within [0, 1]",
		):
			return
		low_fuel_fraction = value
@export_range(0.1, 20.0, 0.1, "or_greater") var flash_hz := 2.0:
	set(value):
		if not Contract.require(value > 0.0, "flash_hz must be positive"):
			return
		flash_hz = value

@export_group("Colours")
@export var colour := Color(0.3, 0.9, 1.0)
@export var low_colour := Color(1.0, 0.25, 0.2)

var fraction := 1.0
var warning := false

var _flash_time := 0.0


func _ready() -> void:
	title.text = TITLE
	bar.draw.connect(_draw_bar)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _process(delta: float) -> void:
	refresh(delta)


func refresh(delta: float) -> void:
	if not Contract.require(fuel != null, "fuel must be set"):
		return
	_flash_time += delta
	fraction = clampf(fuel.fuel / fuel.tank_size, 0.0, 1.0)
	warning = fraction < low_fuel_fraction
	var shown := bar_colour()
	title.add_theme_color_override(
		"font_color",
		shown if warning else Color(shown, 0.8),
	)
	bar.queue_redraw()
	Contract.invariant(
		fraction >= 0.0 and fraction <= 1.0,
		"fraction must be within [0, 1]",
	)


func bar_colour() -> Color:
	if not warning:
		return colour
	var flash := absf(sin(_flash_time * TAU * flash_hz))
	return Color(low_colour, 0.5 + 0.5 * flash)


func bar_width() -> float:
	return bar.custom_minimum_size.x


func fill_width() -> float:
	return fraction * maxf(bar_width() - 1.0, 0.0)


func _update_layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var margin := screen.y * margin_ratio
	var font_size := maxi(MIN_FONT_SIZE, int(screen.y * FONT_SCREEN_RATIO))
	bar.custom_minimum_size = Vector2(screen.x * bar_width_ratio, bar_height_px)
	panel.position = Vector2(margin, margin)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.set_content_margin_all(maxf(3.0, screen.y * PADDING_SCREEN_RATIO))
		style.content_margin_bottom = 0.0
	title.add_theme_font_size_override("font_size", font_size - 1)


func _draw_bar() -> void:
	var rect := Rect2(Vector2.ZERO, bar.size)
	bar.draw_rect(rect.grow(-1.0), TRACK_COLOUR)
	var width := fill_width()
	if width > 0.0:
		bar.draw_rect(Rect2(0.5, 0.5, width, rect.size.y - 1.0), bar_colour())
