class_name ShopGuide
extends Node

const TAG_GAP := 4.0
const ARROW_GAP := 6.0

@export_group("Components")
@export var shop: ShopOverlay
@export var buy_tag: Control
@export var buy_hint: Control
@export var warp_arrow: Control
@export var buy_tag_bounce: BounceEffect
@export var buy_hint_pulse: PulseEffect
@export var warp_pulse: PulseEffect
@export var warp_arrow_bounce: BounceEffect

@export_group("Guide")
@export var show_buy_tag := true
@export var show_warp_in := true

var _buy_target: Control
var _highlighting_warp_in := false


func _ready() -> void:
	Contract.require(shop != null, "shop must be set")


func _process(_delta: float) -> void:
	refresh()


func buy_target() -> Control:
	return _buy_target


func is_highlighting_warp_in() -> bool:
	return _highlighting_warp_in


func refresh() -> void:
	if shop == null:
		return
	var first := _first_buyable() if shop.is_open else null
	var guiding := show_buy_tag and first != null and not _bought_anything()
	_buy_target = first if guiding else null
	_highlighting_warp_in = show_warp_in and shop.is_open and first == null
	_show_buy_tag()
	_show_warp_in()


func _show_buy_tag() -> void:
	var showing := _buy_target != null
	buy_tag.visible = showing
	_switch(buy_tag_bounce, showing)
	_switch(buy_hint_pulse, showing)
	if not showing:
		return
	if buy_tag.get_parent() != _buy_target:
		buy_tag.reparent(_buy_target, false)
	buy_tag.size = buy_tag.get_combined_minimum_size()
	buy_tag_bounce.base_position = Vector2(
		(_buy_target.size.x - buy_tag.size.x) * 0.5,
		-buy_tag.size.y - TAG_GAP,
	)


func _show_warp_in() -> void:
	warp_arrow.visible = _highlighting_warp_in
	_switch(warp_pulse, _highlighting_warp_in)
	_switch(warp_arrow_bounce, _highlighting_warp_in)
	if not _highlighting_warp_in:
		return
	var button := warp_arrow.get_parent() as Control
	warp_arrow.size = warp_arrow.get_combined_minimum_size()
	warp_arrow_bounce.base_position = Vector2(
		(button.size.x - warp_arrow.size.x) * 0.5,
		-warp_arrow.size.y - ARROW_GAP,
	)


func _switch(effect: Node, on: bool) -> void:
	if effect.get(&"active") != on:
		effect.set(&"active", on)


func _first_buyable() -> Control:
	for view in shop.views:
		if shop.progression.can_buy(view.node):
			return view
	return null


func _bought_anything() -> bool:
	for count: int in shop.progression.buys_by_id().values():
		if count > 0:
			return true
	return false
