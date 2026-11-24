extends GutTest

const SHOP_SCENE := preload("res://scenes/ui/shop_overlay.tscn")
const UPGRADES := "res://resources/progression/upgrades/"


class ActionSpy:
	extends Node

	var seen: Array[StringName] = []


	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS


	func _unhandled_input(event: InputEvent) -> void:
		for action: StringName in [&"pause", &"restart"]:
			if event.is_action_pressed(action):
				seen.append(action)


var _was_enabled: bool
var _progression: Progression
var _warp: WarpController
var _starter: RunStarter
var _shop: ShopOverlay
var _booster: Upgrade
var _tank: Upgrade


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_progression = Progression.new()
	_booster = load(UPGRADES + "booster_upgrade.tres")
	_tank = load(UPGRADES + "fuel_tank_upgrade.tres")
	_warp = autofree(WarpController.new())
	_starter = autofree(RunStarter.new())
	_starter.upgrades = [_booster, _tank]
	_shop = SHOP_SCENE.instantiate()
	_shop.warp_controller = _warp
	_shop.run_starter = _starter
	_shop.progression = _progression
	_shop.reload_on_launch = false
	add_child_autofree(_shop)


func after_each() -> void:
	get_tree().paused = false
	Contract.enabled = _was_enabled


func _button(upgrade: Upgrade) -> Button:
	return _shop.buttons[_starter.upgrades.find(upgrade)]


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)


func test_starts_hidden_with_one_button_per_upgrade() -> void:
	assert_false(_shop.visible)
	assert_eq(_shop.buttons.size(), 2)
	assert_eq(_shop.upgrade_list.get_child_count(), 2)


func test_opens_when_the_warp_finishes() -> void:
	_warp.warp_finished.emit()
	assert_true(_shop.is_open)
	assert_true(_shop.visible)
	assert_true(get_tree().paused)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	assert_true(_shop.launch_button.has_focus())


func test_buttons_show_each_upgrades_values() -> void:
	_progression.bank_mass(5.0)
	_progression.buy(_booster)
	_shop.open()
	var text := _button(_booster).text
	assert_string_contains(text, _booster.display_name)
	assert_string_contains(text, "1")
	assert_string_contains(text, "%.2f" % _booster.multiplier(1))
	assert_string_contains(text, "%.2f" % _booster.multiplier(2))
	assert_string_contains(text, "%.0f" % _booster.cost(1))


func test_a_maxed_upgrade_shows_max_and_is_disabled() -> void:
	var capped: Upgrade = _booster.duplicate()
	capped.id = &"capped"
	capped.max_level = 1
	var starter: RunStarter = autofree(RunStarter.new())
	starter.upgrades = [capped]
	var shop: ShopOverlay = SHOP_SCENE.instantiate()
	shop.warp_controller = _warp
	shop.run_starter = starter
	shop.progression = _progression
	shop.reload_on_launch = false
	add_child_autofree(shop)
	_progression.bank_mass(1000.0)
	_progression.buy(capped)
	shop.open()
	assert_string_contains(shop.buttons[0].text, "MAX")
	assert_true(shop.buttons[0].disabled)
	shop.launch()


func test_the_bank_label_shows_the_bank() -> void:
	_progression.bank_mass(12.5)
	_shop.open()
	assert_string_contains(_shop.bank_label.text, "12.5")


func test_a_button_is_disabled_exactly_when_unaffordable() -> void:
	_progression.bank_mass(_booster.cost(0))
	_shop.open()
	assert_false(_button(_booster).disabled)
	assert_false(_button(_tank).disabled)
	_button(_booster).pressed.emit()
	assert_true(_button(_booster).disabled)
	assert_true(_button(_tank).disabled)


func test_pressing_a_button_buys_and_refreshes() -> void:
	_progression.bank_mass(100.0)
	_shop.open()
	_button(_booster).pressed.emit()
	assert_eq(_progression.level_of(_booster), 1)
	assert_string_contains(_shop.bank_label.text, "%.1f" % _progression.bank)
	assert_string_contains(_button(_booster).text, "%.0f" % _booster.cost(1))


func test_focus_returns_to_launch_when_the_focused_upgrade_runs_out() -> void:
	_progression.bank_mass(_booster.cost(0))
	_shop.open()
	_button(_booster).grab_focus()
	_button(_booster).pressed.emit()
	assert_true(_shop.launch_button.has_focus())


func test_pause_and_restart_are_swallowed_while_open() -> void:
	var spy: ActionSpy = add_child_autofree(ActionSpy.new())
	_shop.open()
	_press(&"pause")
	_press(&"restart")
	assert_eq(spy.seen, [] as Array[StringName])
	assert_true(get_tree().paused)


func test_pause_and_restart_pass_through_when_closed() -> void:
	var spy: ActionSpy = add_child_autofree(ActionSpy.new())
	_press(&"pause")
	assert_eq(spy.seen, [&"pause"] as Array[StringName])


func test_launch_unpauses_and_emits_launched() -> void:
	watch_signals(_shop)
	_shop.open()
	_shop.launch_button.pressed.emit()
	assert_false(get_tree().paused)
	assert_false(_shop.is_open)
	assert_signal_emit_count(_shop, "launched", 1)


func test_launching_a_closed_shop_is_reported() -> void:
	_shop.launch()
	assert_push_error("the shop must be open")


func test_opening_twice_is_reported() -> void:
	_shop.open()
	_shop.open()
	assert_push_error("the shop must not already be open")
