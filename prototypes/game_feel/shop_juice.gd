extends Node

# Purchase punch and unlock reveal for the shop. Runs while the shop pauses
# the game.

@export_group("Purchase punch")
## The newly filled slot square pops from this scale back to its size.
@export var slot_punch_scale := 2.5
@export var punch_time := 0.35
## How bright the bought node flashes (1 = no flash).
@export var flash := 2.0
@export var bank_tick_time := 0.45
@export var bank_punch := 1.15
@export var rumble_strong := 0.45
@export var rumble_weak := 0.25
@export var rumble_time := 0.12

@export_group("Unlock reveal")
## Seconds between each newly unlocked node lighting up.
@export var reveal_stagger := 0.12
@export var reveal_time := 0.4
@export var reveal_from_scale := 0.6
@export var reveal_from_alpha := 0.15
@export var reveal_rumble := 0.15

var shop
var progression
var _states := {}
var _buys := {}
var _bank_shown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shop = get_node("../GeneratedLevel/ShopOverlay")
	progression = shop.progression
	_snapshot()
	progression.changed.connect(_on_changed)


func _snapshot() -> void:
	for view in shop.views:
		_states[view.node.id] = SkillNodeView.state_of(view.node, progression)
	_buys = progression.buys_by_id()
	_bank_shown = progression.bank


func _on_changed() -> void:
	var new_buys: Dictionary = progression.buys_by_id()
	var bought: Control = null
	for view in shop.views:
		if new_buys.get(view.node.id, 0) > _buys.get(view.node.id, 0):
			bought = view
	var revealed: Array = []
	for view in shop.views:
		var state = SkillNodeView.state_of(view.node, progression)
		var was = _states.get(view.node.id, state)
		if was == SkillNodeView.State.LOCKED and state != SkillNodeView.State.LOCKED:
			revealed.append(view)
		_states[view.node.id] = state
	_buys = new_buys
	if not shop.is_open:
		_bank_shown = progression.bank
		return
	if bought != null:
		_flash(bought)
		_punch_slot(bought)
		_rumble(rumble_weak, rumble_strong, rumble_time)
	_tick_bank()
	if revealed.is_empty():
		return
	var from: Vector2 = _centre(bought) if bought != null else _centre(revealed[0])
	revealed.sort_custom(
		func(a, b): return _centre(a).distance_to(from) < _centre(b).distance_to(from)
	)
	var start := punch_time * 0.5 if bought != null else 0.0
	for index in revealed.size():
		_reveal(revealed[index], start + index * reveal_stagger)


func _centre(view: Control) -> Vector2:
	return view.position + view.size * 0.5


func _flash(view: Control) -> void:
	view.modulate = Color(flash, flash, flash)
	var tween := view.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(view, "modulate", Color.WHITE, punch_time * 0.6)


# The slot squares are drawn by the view, so pop a copy of the newly filled
# one over it and let it settle into place.
func _punch_slot(view: Control) -> void:
	var slots: Control = view.slots
	var index: int = view.filled - 1
	if slots == null or index < 0:
		return
	var square := Rect2(
		Vector2(index * (view.slot_size + view.slot_gap), 0.0),
		Vector2(view.slot_size, view.slot_size),
	).grow(-2.0)
	var pop := ColorRect.new()
	pop.color = view.gold
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.position = square.position
	pop.size = square.size
	pop.pivot_offset = square.size * 0.5
	pop.scale = Vector2.ONE * slot_punch_scale
	pop.modulate = Color(flash, flash, flash)
	slots.add_child(pop)
	var tween := pop.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel()
	tween.tween_property(pop, "scale", Vector2.ONE, punch_time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, "modulate", Color.WHITE, punch_time * 0.6)
	tween.chain().tween_callback(pop.queue_free)


func _reveal(view: Control, delay: float) -> void:
	view.pivot_offset = view.size * 0.5
	view.scale = Vector2.ONE * reveal_from_scale
	view.modulate = Color(1, 1, 1, reveal_from_alpha)
	var tween := view.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(delay)
	tween.tween_callback(_rumble.bind(reveal_rumble * 0.6, reveal_rumble, 0.06))
	tween.set_parallel()
	tween.tween_property(view, "scale", Vector2.ONE, reveal_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "modulate", Color(flash, flash, flash), reveal_time * 0.4)
	tween.chain().tween_property(view, "modulate", Color.WHITE, reveal_time * 0.6)


func _tick_bank() -> void:
	var label: Label = shop.bank_label
	var from := _bank_shown
	var to: float = progression.bank
	_bank_shown = to
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * bank_punch
	var tween := label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel()
	tween.tween_method(
		func(value: float): label.text = "BANK %s" % MassText.mkg(value), from, to, bank_tick_time
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "scale", Vector2.ONE, bank_tick_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _rumble(weak: float, strong: float, time: float) -> void:
	if not RunProgress.get_meta(&"game_feel_rumble", true):
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, time)
