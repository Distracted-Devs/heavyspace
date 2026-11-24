extends Node

## Prototype prompts, all icon-based and following the active device:
## - the shop's text hints become icon prompts
## - the crash screen, rebuilt in the holo look
## - every run, a pulsing "WARP OUT" prompt once the warp is ready
## - in the shop, a "BUY" tag over the first item until the first purchase,
##   and a pulsing WARP IN once there's nothing left to buy

const Icons := preload("res://prototypes/pre_juice_polish/input_icons.gd")
const Holo := preload("res://prototypes/pre_juice_polish/holo.gd")

## [hint label in ShopOverlay/Hints/Row, actions in display order, text]
const SHOP_HINTS := [
	["Move", [&"ui_up", &"ui_left", &"ui_down", &"ui_right"], "MOVE"],
	["Buy", [&"ui_accept"], "BUY"],
	["Zoom", [&"shop_zoom_out", &"shop_zoom_in"], "ZOOM"],
]

@export_group("Shop")
@export_range(12.0, 64.0, 1.0) var shop_icon_size := 26.0
@export var buy_hint := true
@export var warp_in_hint := true

@export_group("Crash")
@export_range(12.0, 128.0, 1.0) var crash_icon_size := 44.0

@export_group("Warp out")
@export var warp_out_hint := true
@export_range(12.0, 128.0, 1.0) var warp_icon_size := 40.0

@export_group("Look")
@export_range(0.1, 10.0, 0.1) var pulse_hz := 1.4
@export_range(0.0, 40.0, 0.5) var bounce_px := 8.0

var _tracker: Node
var _warp_controller: WarpController
var _shop: ShopOverlay
var _lose: CanvasLayer
var _time := 0.0
## [row, actions, text, label to copy] for the shop hints.
var _shop_hints: Array = []
## [row, actions, text, size, colour, icon size] for holo prompt rows.
var _rows: Array = []
var _warp_button: Button
var _crash_prompt: HBoxContainer
var _warp_prompt: Control
var _buy_tag: Control
var _warp_in_arrow: Label


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(level: Node, tracker: Node) -> void:
	_tracker = tracker
	_warp_controller = level.get_node("WarpController")
	_shop = level.get_node("ShopOverlay")
	_lose = level.get_node("LoseOverlay")
	_build_shop_hints(level.get_node("ShopOverlay/Hints/Row"))
	_build_crash()
	_build_warp_out()
	_build_shop_highlights()
	tracker.device_changed.connect(_refresh)
	_refresh(tracker.device)


func _process(delta: float) -> void:
	_time += delta
	var glow := Holo.pulse(_time, pulse_hz)
	var bounce := -absf(sin(_time * PI * pulse_hz)) * bounce_px

	_crash_prompt.modulate = Color.WHITE.lerp(Color(1.5, 1.5, 1.5), glow)

	_warp_prompt.visible = (
		warp_out_hint and _warp_controller.can_warp() and not _shop.is_open
	)
	if _warp_prompt.visible:
		_warp_prompt.modulate = Color.WHITE.lerp(Color(1.4, 1.4, 1.4), glow)

	_update_buy_tag(glow, bounce)
	_update_warp_in(glow, bounce)


# --- Shop hints -----------------------------------------------------------


func _build_shop_hints(row: Node) -> void:
	for hint: Array in SHOP_HINTS:
		var original := row.get_node(hint[0]) as Label
		original.visible = false
		var prompt := HBoxContainer.new()
		prompt.add_theme_constant_override("separation", 4)
		prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(prompt)
		row.move_child(prompt, original.get_index())
		_shop_hints.append([prompt, hint[1], hint[2], original])
	_warp_button = row.get_node("WarpButton")
	_warp_button.text = " WARP IN >>"
	_warp_button.add_theme_constant_override("icon_max_width", int(shop_icon_size))


func _refresh(device: int) -> void:
	for hint: Array in _shop_hints:
		var prompt: HBoxContainer = hint[0]
		_clear(prompt)
		for path in Icons.prompt(hint[1], device):
			prompt.add_child(Icons.icon_rect(path, shop_icon_size))
		prompt.add_child(_copy(hint[3], " " + hint[2]))
	var warp := Icons.prompt([&"warp_out"], device)
	_warp_button.icon = Icons.texture(warp[0]) if not warp.is_empty() else null
	for entry: Array in _rows:
		_fill_row(entry, device)


## A label styled like `original`, with new text.
func _copy(original: Label, text: String) -> Label:
	var label := original.duplicate() as Label
	label.visible = true
	label.text = text
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


# --- Holo prompt rows -----------------------------------------------------


## A centred row of [icons] TEXT that rebuilds when the device changes.
func _prompt_row(
	actions: Array,
	text: String,
	size: int,
	colour: Color,
	icon_size: float,
) -> HBoxContainer:
	var prompt := Holo.row(8)
	var entry := [prompt, actions, text, size, colour, icon_size]
	_rows.append(entry)
	if _tracker != null:
		_fill_row(entry, _tracker.device)
	return prompt


func _fill_row(entry: Array, device: int) -> void:
	var prompt: HBoxContainer = entry[0]
	_clear(prompt)
	for path in Icons.prompt(entry[1], device):
		prompt.add_child(Icons.icon_rect(path, entry[5]))
	prompt.add_child(Holo.label(entry[2], entry[3], entry[4]))
	prompt.pivot_offset = prompt.get_combined_minimum_size() * 0.5


# --- Crash screen -----------------------------------------------------------


func _build_crash() -> void:
	(_lose.get_node("Label") as Label).visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.06, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lose.add_child(dim)
	_lose.add_child(Holo.scanlines(Color(Holo.MAGENTA, 0.07)))

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lose.add_child(centre)
	var panel := Holo.panel(Holo.MAGENTA, 0.9, 28.0)
	centre.add_child(panel)
	var column := Holo.column(10)
	panel.add_child(column)

	var title := Holo.label("// CRASHED", 44, Holo.MAGENTA)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var reason := Holo.label("HULL BREACH: YOU HIT SOMETHING HEAVIER", 16, Holo.CYAN, 0.8)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(reason)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8.0
	column.add_child(gap)
	_crash_prompt = _prompt_row([&"restart"], "RESTART", 24, Holo.GOLD, crash_icon_size)
	column.add_child(_crash_prompt)


# --- Warp out (every run) -----------------------------------------------------


func _build_warp_out() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var bottom := _bottom_centre(layer, 36.0)
	var panel := Holo.panel(Holo.MAGENTA, 0.9, 10.0)
	bottom.add_child(panel)
	var column := Holo.column(2)
	panel.add_child(column)
	var quota := Holo.label("QUOTA MET", 14, Holo.GOLD, 0.9)
	quota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(quota)
	column.add_child(
		_prompt_row([&"warp_out"], "WARP OUT >>", 24, Holo.MAGENTA, warp_icon_size)
	)
	_warp_prompt = bottom
	_warp_prompt.visible = false


## A centring container pinned to the bottom of the screen.
func _bottom_centre(layer: CanvasLayer, margin: float) -> CenterContainer:
	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_END
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(stack)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(centre)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = margin
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(spacer)
	return centre


# --- Shop highlights -----------------------------------------------------------


func _build_shop_highlights() -> void:
	var tag := Holo.column(0)
	tag.add_child(_prompt_row([&"ui_accept"], "BUY", 18, Holo.GOLD, 28.0))
	var arrow := Holo.label("▼", 26, Holo.MAGENTA)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_child(arrow)
	tag.visible = false
	_buy_tag = tag
	# Kept in the tree (hidden) until it has an item to point at.
	_shop.add_child(tag)

	_warp_in_arrow = Holo.label("▼", 30, Holo.MAGENTA)
	_warp_in_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warp_in_arrow.visible = false
	_warp_button.add_child(_warp_in_arrow)


## The first item: until anything has been bought, point at the first
## thing that can be bought and pulse the BUY hint.
func _update_buy_tag(glow: float, bounce: float) -> void:
	var target: Control = null
	if buy_hint and _shop.is_open and not _bought_anything():
		target = _first_buyable()
	var buy_row: Control = _shop_hints[1][0]
	if target == null:
		_buy_tag.visible = false
		buy_row.modulate = Color.WHITE
		return
	if _buy_tag.get_parent() != target:
		if _buy_tag.get_parent() != null:
			_buy_tag.get_parent().remove_child(_buy_tag)
		target.add_child(_buy_tag)
	_buy_tag.visible = true
	var size := _buy_tag.get_combined_minimum_size()
	_buy_tag.size = size
	_buy_tag.position = Vector2(
		(target.size.x - size.x) * 0.5,
		-size.y - 4.0 + bounce,
	)
	buy_row.modulate = Color.WHITE.lerp(Color(1.8, 1.8, 1.8), glow)


## Nothing left to buy: pulse WARP IN and bounce an arrow over it.
func _update_warp_in(glow: float, bounce: float) -> void:
	var showing := warp_in_hint and _shop.is_open and _first_buyable() == null
	_warp_in_arrow.visible = showing
	if not showing:
		_warp_button.modulate = Color.WHITE
		return
	var size := _warp_in_arrow.get_combined_minimum_size()
	_warp_in_arrow.size = size
	_warp_in_arrow.position = Vector2(
		(_warp_button.size.x - size.x) * 0.5,
		-size.y - 6.0 + bounce,
	)
	_warp_button.modulate = Color.WHITE.lerp(Color(1.8, 1.8, 1.8), glow)


func _first_buyable() -> Control:
	for view in _shop.views:
		if _shop.progression.can_buy(view.node):
			return view
	return null


func _bought_anything() -> bool:
	for count: int in _shop.progression.buys_by_id().values():
		if count > 0:
			return true
	return false


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
