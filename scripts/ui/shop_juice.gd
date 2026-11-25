class_name ShopJuice
extends RumbleSource

const FLASH_SHARE := 0.6
const SLOT_INSET := 2.0
const REVEAL_FLASH_SHARE := 0.4
const REVEAL_LIGHT_SHARE := 0.6
const REVEAL_RUMBLE_TIME := 0.06

@export_group("Components")
@export var shop: ShopOverlay

@export_group("Purchase")
@export_range(1.0, 5.0, 0.05, "or_greater") var slot_punch_scale := 2.5:
	set(value):
		if _at_least_one(value, "slot_punch_scale"):
			slot_punch_scale = value
@export_range(0.05, 2.0, 0.01, "or_greater") var punch_time := 0.35:
	set(value):
		if positive(value, "punch_time"):
			punch_time = value
@export_range(1.0, 5.0, 0.05, "or_greater") var flash := 2.0:
	set(value):
		if _at_least_one(value, "flash"):
			flash = value
@export_range(0.05, 2.0, 0.01, "or_greater") var bank_tick_time := 0.45:
	set(value):
		if positive(value, "bank_tick_time"):
			bank_tick_time = value
@export_range(1.0, 2.0, 0.01, "or_greater") var bank_punch := 1.15:
	set(value):
		if _at_least_one(value, "bank_punch"):
			bank_punch = value
@export_range(0.0, 1.0, 0.01) var rumble_weak := 0.25:
	set(value):
		if motor_valid(value, "rumble_weak"):
			rumble_weak = value
@export_range(0.0, 1.0, 0.01) var rumble_strong := 0.45:
	set(value):
		if motor_valid(value, "rumble_strong"):
			rumble_strong = value
@export_range(0.01, 1.0, 0.01, "or_greater") var rumble_time := 0.12:
	set(value):
		if positive(value, "rumble_time"):
			rumble_time = value

@export_group("Reveal")
@export_range(0.0, 1.0, 0.01, "or_greater") var reveal_stagger := 0.12:
	set(value):
		var message := "reveal_stagger must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		reveal_stagger = value
@export_range(0.05, 2.0, 0.01, "or_greater") var reveal_time := 0.4:
	set(value):
		if positive(value, "reveal_time"):
			reveal_time = value
@export_range(0.01, 1.0, 0.01) var reveal_from_scale := 0.6:
	set(value):
		if not Contract.require(
			value > 0.0 and value <= 1.0,
			"reveal_from_scale must be within (0, 1]",
		):
			return
		reveal_from_scale = value
@export_range(0.0, 1.0, 0.01) var reveal_from_alpha := 0.15:
	set(value):
		if motor_valid(value, "reveal_from_alpha"):
			reveal_from_alpha = value
@export_range(0.0, 1.0, 0.01) var reveal_rumble := 0.15:
	set(value):
		if motor_valid(value, "reveal_rumble"):
			reveal_rumble = value

var last_bought: SkillNodeView
var revealed: Array[SkillNodeView] = []
var bank_shown := 0.0

var _states := { }
var _buys := { }


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Contract.require(
		shop != null and shop.progression != null,
		"shop with a progression must be set",
	):
		return
	_note()
	shop.progression.changed.connect(_on_changed)


func _note() -> void:
	for view in shop.views:
		_states[view.node.id] = SkillNodeView.state_of(
			view.node,
			shop.progression,
		)
	_buys = shop.progression.buys_by_id()
	bank_shown = shop.progression.bank


func _on_changed() -> void:
	var progression := shop.progression
	var now: Dictionary = progression.buys_by_id()
	var bought: SkillNodeView = null
	var unlocked: Array[SkillNodeView] = []
	for view in shop.views:
		var id := view.node.id
		if now.get(id, 0) > _buys.get(id, 0):
			bought = view
		var was: int = _states.get(id, SkillNodeView.State.LOCKED)
		var state := SkillNodeView.state_of(view.node, progression)
		if was == SkillNodeView.State.LOCKED and state != was:
			unlocked.append(view)
	var from_bank := bank_shown
	_note()
	if not shop.is_open:
		return
	if bought != null:
		last_bought = bought
		_punch(bought)
		_tick_bank(from_bank, progression.bank)
	revealed = unlocked
	if revealed.is_empty():
		return
	var from := _centre(bought if bought != null else revealed[0])
	revealed.sort_custom(
		func(a: SkillNodeView, b: SkillNodeView) -> bool:
			return _centre(a).distance_to(from) < _centre(b).distance_to(from),
	)
	var start := punch_time * 0.5 if bought != null else 0.0
	for index in revealed.size():
		_reveal(revealed[index], start + index * reveal_stagger)


func _punch(view: SkillNodeView) -> void:
	view.modulate = Color(flash, flash, flash)
	var settle := _tween(view)
	settle.tween_property(
		view,
		"modulate",
		Color.WHITE,
		punch_time * FLASH_SHARE,
	)
	var slot := view.filled - 1
	if view.slots != null and slot >= 0 and slot < view.slot_count:
		_pop_slot(view, view.slot_rect(slot).grow(-SLOT_INSET))
	if rumble != null:
		rumble.pulse(rumble_weak, rumble_strong, rumble_time)


func _pop_slot(view: SkillNodeView, square: Rect2) -> void:
	var pop := ColorRect.new()
	pop.color = view.gold
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.position = square.position
	pop.size = square.size
	pop.pivot_offset = square.size * 0.5
	pop.scale = Vector2.ONE * slot_punch_scale
	pop.modulate = Color(flash, flash, flash)
	view.slots.add_child(pop)
	var tween := _tween(pop).set_parallel()
	tween \
			.tween_property(pop, "scale", Vector2.ONE, punch_time) \
			.set_trans(Tween.TRANS_ELASTIC) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(pop, "modulate", Color.WHITE, punch_time * FLASH_SHARE)
	tween.chain().tween_callback(pop.queue_free)


func _tick_bank(from: float, to: float) -> void:
	var label := shop.bank_label
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * bank_punch
	var tween := _tween(label).set_parallel()
	tween \
			.tween_method(_show_bank, from, to, bank_tick_time) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	tween \
			.tween_property(label, "scale", Vector2.ONE, bank_tick_time) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _show_bank(value: float) -> void:
	shop.bank_label.text = "BANK %s" % MassText.mkg(value)


func _reveal(view: SkillNodeView, delay: float) -> void:
	view.pivot_offset = view.size * 0.5
	view.scale = Vector2.ONE * reveal_from_scale
	view.modulate = Color(1.0, 1.0, 1.0, reveal_from_alpha)
	var tween := _tween(view)
	tween.tween_interval(delay)
	tween.tween_callback(_reveal_rumble)
	tween.set_parallel()
	tween \
			.tween_property(view, "scale", Vector2.ONE, reveal_time) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	var bright := Color(flash, flash, flash)
	var light_up := reveal_time * REVEAL_FLASH_SHARE
	tween.tween_property(view, "modulate", bright, light_up)
	tween.chain().tween_property(
		view,
		"modulate",
		Color.WHITE,
		reveal_time * REVEAL_LIGHT_SHARE,
	)


func _reveal_rumble() -> void:
	if rumble != null:
		rumble.pulse(
			reveal_rumble * REVEAL_LIGHT_SHARE,
			reveal_rumble,
			REVEAL_RUMBLE_TIME,
		)


func _tween(target: Node) -> Tween:
	return target.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


func _centre(view: Control) -> Vector2:
	return view.position + view.size * 0.5


func _at_least_one(value: float, setting: String) -> bool:
	return Contract.require(value >= 1.0, "%s must be at least 1" % setting)
