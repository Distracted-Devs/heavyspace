extends GutTest

const SHOP_SCENE := preload("res://scenes/ui/shop_overlay.tscn")
const TREE := preload("res://resources/progression/skill_tree.tres")

var _was_enabled: bool
var _progression: Progression
var _shop: ShopOverlay
var _mixer: RumbleMixer
var _juice: ShopJuice


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_progression = Progression.new()
	var starter: RunStarter = autofree(RunStarter.new())
	starter.tree = TREE
	_shop = SHOP_SCENE.instantiate()
	_shop.warp_controller = autofree(WarpController.new())
	_shop.run_starter = starter
	_shop.progression = _progression
	_shop.reload_on_launch = false
	add_child_autofree(_shop)
	_mixer = RumbleMixer.new()
	_mixer.set_process(false)
	add_child_autofree(_mixer)
	_juice = ShopJuice.new()
	_juice.shop = _shop
	_juice.rumble = _mixer
	add_child_autofree(_juice)


func after_each() -> void:
	get_tree().paused = false
	Contract.enabled = _was_enabled


func _view(id: StringName) -> SkillNodeView:
	return _shop.views[TREE.nodes.find(TREE.find(id))]


func _step(seconds: float) -> void:
	for tween in get_tree().get_processed_tweens():
		tween.custom_step(seconds)


func _buy_first() -> void:
	_progression.bank_mass(20.0)
	_shop.open()
	_progression.buy(TREE.find(&"tank_1"))


func test_a_purchase_punches_the_bought_node() -> void:
	_buy_first()
	var bought := _view(&"tank_1")
	assert_eq(_juice.last_bought, bought)
	assert_gt(bought.modulate.r, 1.0, "it flashes")
	assert_eq(bought.slots.get_child_count(), 1, "its new slot pops")
	assert_gt(_mixer.strong(), 0.0)


func test_the_punch_settles_and_tidies_up() -> void:
	_buy_first()
	var bought := _view(&"tank_1")
	_step(_juice.punch_time + 0.1)
	assert_eq(bought.modulate, Color.WHITE)
	var left := bought.slots.get_children().filter(
		func(child: Node) -> bool:
			return not child.is_queued_for_deletion(),
	)
	assert_true(left.is_empty())


func test_the_bank_settles_on_its_new_value() -> void:
	_buy_first()
	assert_eq(_juice.bank_shown, _progression.bank)
	_step(_juice.bank_tick_time + 0.1)
	assert_almost_eq(_shop.bank_label.scale, Vector2.ONE, Vector2.ONE * 1e-3)


func test_newly_unlocked_nodes_are_revealed_nearest_first() -> void:
	_buy_first()
	var revealed := _juice.revealed
	assert_eq(revealed.size(), 3)
	var from := _view(&"tank_1").position
	var distances := revealed.map(
		func(view: Control) -> float:
			return view.position.distance_to(from),
	)
	var sorted := distances.duplicate()
	sorted.sort()
	assert_eq(distances, sorted)
	assert_lt(revealed[0].scale.x, 1.0, "it starts small")


func test_the_reveal_grows_to_full_size() -> void:
	_buy_first()
	var last: Control = _juice.revealed[-1]
	var stagger := _juice.reveal_stagger * _juice.revealed.size()
	_step(_juice.punch_time + stagger + _juice.reveal_time)
	assert_almost_eq(last.scale, Vector2.ONE, Vector2.ONE * 1e-3)
	assert_eq(last.modulate, Color.WHITE)


func test_nothing_plays_while_the_shop_is_closed() -> void:
	_progression.bank_mass(20.0)
	_progression.buy(TREE.find(&"tank_1"))
	assert_null(_juice.last_bought)
	assert_true(_juice.revealed.is_empty())
	assert_eq(_juice.bank_shown, _progression.bank)


func test_a_missing_shop_is_reported() -> void:
	var lonely := ShopJuice.new()
	add_child_autofree(lonely)
	assert_push_error("shop with a progression must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	_juice.slot_punch_scale = 0.5
	assert_push_error("slot_punch_scale must be at least 1")
	_juice.punch_time = 0.0
	assert_push_error("punch_time must be positive")
	_juice.reveal_from_scale = 0.0
	assert_push_error("reveal_from_scale must be within (0, 1]")
	_juice.rumble_strong = 2.0
	assert_push_error("rumble_strong must be within [0, 1]")
	assert_eq(_juice.punch_time, 0.35)
