class_name SkillNodeView
extends Button

enum State {
	BUYABLE,
	UNAFFORDABLE,
	LOCKED,
	MAXED,
}

const BORDER_WIDTH := 2
const FOCUS_WIDTH := 3
const GLOW_SIZE := 16
const CONTENT_MARGIN := 14.0
const COUNT_FONT_SIZE := 18
const COUNT_GAP := 6.0
const TITLE_LIFT := "\n\n"
const TITLE_COLOURS: Array[StringName] = [
	&"font_color",
	&"font_hover_color",
	&"font_focus_color",
	&"font_pressed_color",
]

@export_group("Components")
@export var footer: Label
@export var tab: Label
@export var tab_panel: Control
@export var slots: Control

@export_group("Layout")
@export_range(1.0, 100.0, 1.0, "or_greater") var slot_size := 20.0:
	set(value):
		if not Contract.require(value > 0.0, "slot_size must be positive"):
			return
		slot_size = value
@export_range(0.0, 50.0, 1.0, "or_greater") var slot_gap := 5.0:
	set(value):
		if not Contract.require(value >= 0.0, "slot_gap must not be negative"):
			return
		slot_gap = value

@export_group("Colours")
@export var cyan := Color(0.3, 0.9, 1.0)
@export var magenta := Color(1.0, 0.3, 0.8)
@export var gold := Color(1.0, 0.88, 0.3)
@export var amber := Color(0.95, 0.7, 0.15)
@export var green := Color(0.3, 1.0, 0.5)
@export var red := Color(1.0, 0.25, 0.2)
@export var panel := Color(0.0, 0.04, 0.07, 0.75)
@export var track := Color(0.0, 0.09, 0.12, 0.8)

var node: SkillNode
var state := State.LOCKED
var slot_count := 0
var filled := 0

var _shown: SkillNode
var _normal := _box(BORDER_WIDTH)
var _hover := _box(BORDER_WIDTH)
var _pressed := _box(FOCUS_WIDTH)
var _focus := _box(FOCUS_WIDTH)


func _ready() -> void:
	add_theme_stylebox_override("normal", _normal)
	add_theme_stylebox_override("disabled", _normal)
	add_theme_stylebox_override("hover", _hover)
	add_theme_stylebox_override("pressed", _pressed)
	add_theme_stylebox_override("focus", _focus)
	_focus.draw_center = false
	_focus.border_color = magenta
	_focus.shadow_color = Color(magenta, 0.45)
	_focus.shadow_size = GLOW_SIZE
	_pressed.bg_color = Color(magenta, 0.25)
	_pressed.border_color = magenta
	if slots != null:
		slots.draw.connect(_draw_slots)


func show_node(shown: SkillNode, progression: Progression) -> void:
	if not Contract.require(
		shown != null and shown.is_valid() and progression != null,
		"a valid node and a progression must be set",
	):
		return
	var new_state := state_of(shown, progression)
	var new_filled := progression.buys(shown)
	node = shown
	if shown == _shown and new_state == state and new_filled == filled:
		return
	_shown = shown
	state = new_state
	slot_count = node.max_buys
	filled = new_filled
	text = node.title.to_upper() + TITLE_LIFT
	footer.text = footer_text()
	footer.add_theme_color_override("font_color", footer_colour())
	tab.text = "LV %d" % node.required_level
	tab.add_theme_color_override("font_color", tab_colour())
	_style()
	slots.queue_redraw()


func footer_text() -> String:
	match state:
		State.MAXED:
			return "MAXED"
		State.LOCKED:
			return "LOCKED | LV %d" % node.required_level
	return MassText.mkg(node.cost)


func footer_colour() -> Color:
	match state:
		State.BUYABLE:
			return green
		State.UNAFFORDABLE:
			return red
		State.LOCKED:
			return Color(magenta, 0.6)
	return gold


func tab_colour() -> Color:
	match state:
		State.LOCKED:
			return magenta
		State.MAXED:
			return gold
	return cyan


func border_colour() -> Color:
	match state:
		State.BUYABLE:
			return cyan
		State.UNAFFORDABLE:
			return Color(cyan, 0.5)
		State.LOCKED:
			return Color(cyan, 0.15)
	return gold


func count_text() -> String:
	return "%d/%d" % [filled, slot_count]


static func state_of(of: SkillNode, progression: Progression) -> State:
	if progression.is_maxed(of):
		return State.MAXED
	if not progression.is_unlocked(of):
		return State.LOCKED
	if progression.can_buy(of):
		return State.BUYABLE
	return State.UNAFFORDABLE


func _style() -> void:
	var fill := panel
	var title := Color(cyan, 0.75)
	match state:
		State.BUYABLE:
			title = Color(0.85, 0.98, 1.0)
		State.LOCKED:
			fill = Color(0.0, 0.02, 0.04, 0.6)
			title = Color(cyan, 0.28)
		State.MAXED:
			fill = Color(0.16, 0.11, 0.0, 0.8)
			title = gold
	_normal.bg_color = fill
	_normal.border_color = border_colour()
	_hover.bg_color = fill
	_hover.border_color = Color(magenta, 0.7)
	tab_panel.self_modulate = tab_colour()
	for colour in TITLE_COLOURS:
		add_theme_color_override(colour, title)


func _draw_slots() -> void:
	var unlocked := state != State.LOCKED
	for index in slot_count:
		var square := Rect2(
			Vector2(index * (slot_size + slot_gap), 0.0),
			Vector2(slot_size, slot_size),
		)
		var bought := index < filled
		slots.draw_rect(square, track)
		if bought:
			slots.draw_rect(square.grow(-2.0), gold)
		var outline := 0.35 if unlocked or bought else 0.15
		slots.draw_rect(square, Color(amber, outline), false, 1.0)
	slots.draw_string(
		footer.get_theme_font("font"),
		Vector2(
			slot_count * (slot_size + slot_gap) + COUNT_GAP,
			slot_size - 4.0,
		),
		count_text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		COUNT_FONT_SIZE,
		gold if filled > 0 else Color(amber, 0.45),
	)


func _box(width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_border_width_all(width)
	box.set_content_margin_all(CONTENT_MARGIN)
	return box
