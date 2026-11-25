class_name CargoGauge
extends CanvasLayer

const TITLE := "CARGO"
const TRACK_COLOUR := Color(0.0, 0.09, 0.12, 0.8)
const MIN_BAR_HEIGHT := 10.0
const FONT_SCREEN_RATIO := 0.02
const MIN_FONT_SIZE := 9
const PADDING_SCREEN_RATIO := 0.01
const MIN_TANK_GAP := 2.0
const OUTLINE_ALPHA := 0.35
const READY_WHITEN := 0.4
const TOLERANCE := 1e-3

@export_group("Components")
@export var cargo: CargoComponent
@export var warp_controller: WarpController
@export var below: Control
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
@export_range(0.0, 100.0, 1.0, "or_greater") var gap_px := 2.0:
	set(value):
		if not Contract.require(value >= 0.0, "gap_px must not be negative"):
			return
		gap_px = value
@export_range(1, 20, 1, "or_greater") var tanks_per_row := 5:
	set(value):
		var message := "tanks_per_row must be at least 1"
		if not Contract.require(value >= 1, message):
			return
		tanks_per_row = value
@export_range(0.0, 20.0, 1.0, "or_greater") var row_gap_px := 3.0:
	set(value):
		var message := "row_gap_px must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		row_gap_px = value
@export_range(0.0, 0.49, 0.01) var tank_gap_ratio := 0.08:
	set(value):
		if not Contract.require(
			value >= 0.0 and value < 0.5,
			"tank_gap_ratio must be within [0, 0.5)",
		):
			return
		tank_gap_ratio = value

@export_group("Colours")
@export var filling_colour := Color(0.95, 0.7, 0.15)
@export var full_colour := Color(1.0, 0.88, 0.3)
@export_range(0.1, 20.0, 0.1, "or_greater") var ready_flash_hz := 1.5:
	set(value):
		var message := "ready_flash_hz must be positive"
		if not Contract.require(value > 0.0, message):
			return
		ready_flash_hz = value

var fills := PackedFloat32Array()
var warp_ready := false

var _flash_time := 0.0


func _ready() -> void:
	title.text = TITLE
	bar.draw.connect(_draw_bar)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()


func _process(delta: float) -> void:
	refresh(delta)


func refresh(delta: float) -> void:
	if not Contract.require(cargo != null, "cargo must be set"):
		return
	_flash_time += delta
	fills.resize(cargo.tanks)
	for tank in cargo.tanks:
		fills[tank] = cargo.fill_of(tank)
	warp_ready = warp_controller != null and warp_controller.can_warp()
	title.add_theme_color_override(
		"font_color",
		Color(tank_colour(warp_ready), 0.8),
	)
	bar.custom_minimum_size.y = bar_height()
	if below != null:
		panel.position.y = below.position.y + below.size.y + gap_px
	bar.queue_redraw()
	Contract.invariant(_fills_valid(), "one fill in [0, 1] per owned tank")
	Contract.invariant(
		_tanks_inside_the_bar(),
		"every tank must lie inside the bar",
	)


func tank_colour(full: bool) -> Color:
	if not full:
		return filling_colour
	if not warp_ready:
		return full_colour
	var flash := absf(sin(_flash_time * TAU * ready_flash_hz))
	return full_colour.lerp(Color.WHITE, READY_WHITEN * flash)


func rows() -> int:
	return maxi(1, ceili(float(fills.size()) / tanks_per_row))


func bar_width() -> float:
	return bar.custom_minimum_size.x


func bar_height() -> float:
	return rows() * bar_height_px + (rows() - 1) * row_gap_px


func tank_rect(tank: int) -> Rect2:
	if not Contract.require(
		tank >= 0 and tank < fills.size(),
		"tank must be an owned tank",
	):
		return Rect2()
	var slot_width := bar_width() / tanks_per_row
	var gap := maxf(MIN_TANK_GAP, slot_width * tank_gap_ratio)
	var column := tank % tanks_per_row
	var row := floori(float(tank) / tanks_per_row)
	return Rect2(
		column * slot_width + 0.5,
		row * (bar_height_px + row_gap_px) + 0.5,
		maxf(slot_width - gap, 0.0),
		bar_height_px - 1.0,
	)


func _fills_valid() -> bool:
	if fills.size() != cargo.tanks:
		return false
	for fill in fills:
		if fill < 0.0 or fill > 1.0:
			return false
	return true


func _tanks_inside_the_bar() -> bool:
	var area := Rect2(Vector2.ZERO, Vector2(bar_width(), bar_height()))
	area = area.grow(TOLERANCE)
	for tank in fills.size():
		if not area.encloses(tank_rect(tank)):
			return false
	return true


func _update_layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var margin := screen.y * margin_ratio
	var font_size := maxi(MIN_FONT_SIZE, int(screen.y * FONT_SCREEN_RATIO))
	bar.custom_minimum_size = Vector2(screen.x * bar_width_ratio, bar_height())
	panel.position = Vector2(margin, margin)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.set_content_margin_all(maxf(3.0, screen.y * PADDING_SCREEN_RATIO))
		style.content_margin_top = 0.0
	title.add_theme_font_size_override("font_size", font_size - 1)


func _draw_bar() -> void:
	for tank in fills.size():
		var slot := tank_rect(tank)
		var shown := tank_colour(fills[tank] >= 1.0)
		bar.draw_rect(slot, TRACK_COLOUR)
		bar.draw_rect(slot, Color(shown, OUTLINE_ALPHA), false, 1.0)
		if fills[tank] > 0.0:
			var filled := Rect2(
				slot.position,
				slot.size * Vector2(fills[tank], 1),
			)
			bar.draw_rect(filled, shown)
