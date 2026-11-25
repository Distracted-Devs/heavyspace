extends GutTest

const SHOP_SCENE := preload("res://scenes/ui/shop_overlay.tscn")
const TREE := preload("res://resources/progression/skill_tree.tres")
const TAB_HEIGHT := 26.0


class ActionSpy:
	extends Node

	var seen: Array[StringName] = []


	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS


	func _unhandled_input(event: InputEvent) -> void:
		for action: StringName in [&"pause", &"restart", &"warp_out"]:
			if event.is_action_pressed(action):
				seen.append(action)


var _was_enabled: bool
var _progression: Progression
var _warp: WarpController
var _starter: RunStarter
var _shop: ShopOverlay


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_progression = Progression.new()
	_warp = autofree(WarpController.new())
	_starter = autofree(RunStarter.new())
	_starter.tree = TREE
	_shop = SHOP_SCENE.instantiate()
	_shop.warp_controller = _warp
	_shop.run_starter = _starter
	_shop.progression = _progression
	_shop.reload_on_launch = false
	add_child_autofree(_shop)


func after_each() -> void:
	get_tree().paused = false
	Contract.enabled = _was_enabled


func _view(id: StringName) -> SkillNodeView:
	return _shop.views[TREE.nodes.find(TREE.find(id))]


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)


func _centre(view: Control) -> Vector2:
	return view.position + view.size * 0.5


func test_starts_hidden_with_one_view_per_node_in_order() -> void:
	assert_false(_shop.visible)
	assert_eq(_shop.views.size(), TREE.nodes.size())
	for index in TREE.nodes.size():
		assert_eq(_shop.views[index].node, TREE.nodes[index])
		assert_eq(_shop.views[index].get_parent(), _shop.tree_area)


func test_views_sit_on_the_grid_inside_the_tree_area() -> void:
	var area := Rect2(Vector2.ZERO, _shop.tree_area.size)
	for view in _shop.views:
		var rect := Rect2(view.position, view.size)
		assert_true(area.encloses(rect.grow_side(SIDE_TOP, TAB_HEIGHT)))
	var step := _view(&"refill_rate").position - _view(&"tank_1").position
	assert_eq(step, Vector2(_shop.column, 0.0))
	var below := _view(&"booster").position - _view(&"refill_rate").position
	assert_eq(below, Vector2(0.0, _shop.row))


func test_opens_when_the_warp_finishes() -> void:
	_warp.warp_finished.emit()
	assert_true(_shop.is_open)
	assert_true(_shop.visible)
	assert_true(get_tree().paused)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)


func test_opening_focuses_the_first_buyable_node_and_centres_on_it() -> void:
	_progression.bank_mass(20.0)
	var first := TREE.find(&"tank_1")
	_progression.buy(first)
	_shop.open()
	var fuel := _view(&"fuel_tank")
	assert_true(fuel.has_focus())
	assert_eq(_shop.camera.position, _centre(fuel))
	assert_eq(_shop.camera.zoom, _shop.camera.default_zoom)


func test_with_nothing_buyable_the_first_node_has_focus() -> void:
	_shop.open()
	assert_true(_view(&"tank_1").has_focus())


func test_pressing_a_view_buys_its_node_and_refreshes() -> void:
	_progression.bank_mass(20.0)
	_shop.open()
	_view(&"tank_1").pressed.emit()
	assert_eq(_progression.buys(TREE.find(&"tank_1")), 1)
	assert_eq(_progression.bank, 15.0)
	assert_eq(_view(&"tank_1").state, SkillNodeView.State.MAXED)
	assert_eq(_view(&"booster").state, SkillNodeView.State.BUYABLE)


func test_pressing_a_locked_view_buys_nothing() -> void:
	_progression.bank_mass(100.0)
	_shop.open()
	_view(&"tank_3").pressed.emit()
	assert_eq(_progression.bank, 100.0)
	assert_eq(_progression.player_level(), 0)


func test_the_camera_follows_the_focused_view() -> void:
	_shop.open()
	var far := _view(&"tank_3")
	far.grab_focus()
	var before := _shop.camera.position.distance_to(_centre(far))
	await wait_process_frames(10)
	assert_lt(_shop.camera.position.distance_to(_centre(far)), before)


func test_the_tree_is_placed_by_the_camera() -> void:
	_shop.open()
	await wait_process_frames(2)
	assert_almost_eq(
		_shop.tree_area.position,
		_shop.camera.offset(_shop.view.size).round(),
		Vector2.ONE,
	)
	assert_eq(_shop.tree_area.scale, Vector2.ONE * _shop.camera.zoom)


func test_warp_out_launches_the_next_run() -> void:
	var spy: ActionSpy = add_child_autofree(ActionSpy.new())
	watch_signals(_shop)
	_shop.open()
	_press(&"warp_out")
	assert_false(_shop.is_open)
	assert_signal_emit_count(_shop, "launched", 1)
	assert_eq(spy.seen, [] as Array[StringName])


func test_the_warp_hint_launches_the_next_run() -> void:
	watch_signals(_shop)
	_shop.open()
	_shop.warp_button.pressed.emit()
	assert_false(get_tree().paused)
	assert_false(_shop.is_open)
	assert_signal_emit_count(_shop, "launched", 1)


func test_pause_and_restart_are_swallowed_while_open() -> void:
	var spy: ActionSpy = add_child_autofree(ActionSpy.new())
	_shop.open()
	_press(&"pause")
	_press(&"restart")
	assert_eq(spy.seen, [] as Array[StringName])
	assert_true(get_tree().paused)


func test_pad_x_warps_in_although_it_is_also_restart() -> void:
	_shop.open()
	watch_signals(_shop)
	var x := InputEventJoypadButton.new()
	x.button_index = JOY_BUTTON_X
	x.pressed = true
	assert_true(x.is_action_pressed(&"restart"), "X is also restart")
	_shop._input(x)
	assert_signal_emitted(_shop, "launched")
	assert_false(_shop.is_open)


func test_pause_and_restart_pass_through_when_closed() -> void:
	var spy: ActionSpy = add_child_autofree(ActionSpy.new())
	_press(&"pause")
	assert_eq(spy.seen, [&"pause"] as Array[StringName])


func test_launching_a_closed_shop_is_reported() -> void:
	_shop.launch()
	assert_push_error("the shop must be open")


func test_opening_twice_is_reported() -> void:
	_shop.open()
	_shop.open()
	assert_push_error("the shop must not already be open")


func test_a_run_starter_without_a_valid_tree_is_reported() -> void:
	var shop: ShopOverlay = SHOP_SCENE.instantiate()
	shop.warp_controller = _warp
	shop.run_starter = autofree(RunStarter.new())
	shop.progression = _progression
	add_child_autofree(shop)
	assert_push_error(
		"warp_controller and run_starter with a valid tree must be set"
	)
	assert_eq(shop.views.size(), 0)


func test_hints_are_prompts_for_the_shop_controls() -> void:
	var expected := {
		"Move": [&"ui_up", &"ui_left", &"ui_down", &"ui_right"],
		"Buy": [&"ui_accept"],
		"Zoom": [&"shop_zoom_out", &"shop_zoom_in"],
	}
	for hint: String in expected:
		var prompt := _shop.get_node("Hints/Row/" + hint) as InputPrompt
		assert_not_null(prompt, hint)
		assert_eq(Array(prompt.actions), expected[hint])


func test_warp_in_shows_the_warp_out_icon() -> void:
	var prompt_icon: ButtonPromptIcon = _shop.get_node(
		"Hints/Row/WarpButton/WarpIcon"
	)
	assert_eq(Array(prompt_icon.actions), [&"warp_out"])
	assert_not_null(_shop.warp_button.icon)


func test_views_are_styled_only_when_the_shop_opens() -> void:
	var view := _view(&"tank_1")
	assert_eq(view.slot_count, 0)
	_shop.open()
	assert_eq(view.slot_count, TREE.find(&"tank_1").max_buys)
	var node := TREE.find(&"tank_1")
	assert_eq(view.state, SkillNodeView.state_of(node, _progression))
