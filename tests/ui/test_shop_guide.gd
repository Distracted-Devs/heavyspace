extends GutTest

const SHOP_SCENE := preload("res://scenes/ui/shop_overlay.tscn")
const TREE := preload("res://resources/progression/skill_tree.tres")
const RICH := 1.0e6

var _was_enabled: bool
var _progression: Progression
var _shop: ShopOverlay
var _guide: ShopGuide


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
	_guide = _shop.get_node("ShopGuide")
	_guide.set_process(false)


func after_each() -> void:
	get_tree().paused = false
	Contract.enabled = _was_enabled


func _first_buyable() -> SkillNodeView:
	for view in _shop.views:
		if _progression.can_buy(view.node):
			return view
	return null


func test_a_closed_shop_highlights_nothing() -> void:
	_progression.bank_mass(RICH)
	_guide.refresh()
	assert_null(_guide.buy_target())
	assert_false(_guide.is_highlighting_warp_in())
	assert_false(_guide.buy_tag.visible)
	assert_false(_guide.warp_arrow.visible)


func test_the_first_buy_is_pointed_at() -> void:
	_progression.bank_mass(RICH)
	_shop.open()
	_guide.refresh()
	var target := _first_buyable()
	assert_eq(_guide.buy_target(), target)
	assert_true(_guide.buy_tag.visible)
	assert_eq(_guide.buy_tag.get_parent(), target)
	assert_true(_guide.buy_hint_pulse.active)
	assert_true(_guide.buy_tag_bounce.active)


func test_the_tag_sits_centred_above_its_node() -> void:
	_progression.bank_mass(RICH)
	_shop.open()
	_guide.refresh()
	var target := _first_buyable()
	var tag := _guide.buy_tag
	var base := _guide.buy_tag_bounce.base_position
	assert_almost_eq(base.x + tag.size.x * 0.5, target.size.x * 0.5, 1.0)
	assert_lt(base.y + tag.size.y, 0.0)


func test_no_tag_once_anything_has_been_bought() -> void:
	_progression.bank_mass(RICH)
	_progression.buy(_first_buyable().node)
	_shop.open()
	_guide.refresh()
	assert_not_null(_first_buyable())
	assert_null(_guide.buy_target())
	assert_false(_guide.buy_tag.visible)
	assert_false(_guide.buy_hint_pulse.active)


func test_warp_in_is_highlighted_when_nothing_can_be_bought() -> void:
	_shop.open()
	_guide.refresh()
	assert_null(_first_buyable())
	assert_true(_guide.is_highlighting_warp_in())
	assert_true(_guide.warp_arrow.visible)
	assert_true(_guide.warp_pulse.active)
	assert_true(_guide.warp_arrow_bounce.active)
	assert_null(_guide.buy_target())


func test_warp_in_is_not_highlighted_while_something_can_be_bought() -> void:
	_progression.bank_mass(RICH)
	_shop.open()
	_guide.refresh()
	assert_false(_guide.is_highlighting_warp_in())
	assert_false(_guide.warp_arrow.visible)
	assert_false(_guide.warp_pulse.active)


func test_effects_keep_their_time_between_frames() -> void:
	_shop.open()
	_guide.refresh()
	_guide.warp_pulse.advance(0.2)
	var level := _guide.warp_pulse.level()
	_guide.refresh()
	assert_eq(_guide.warp_pulse.level(), level)


func test_the_tag_is_a_buy_prompt() -> void:
	var prompt: InputPrompt = _guide.buy_tag.get_node("Prompt")
	assert_eq(Array(prompt.actions), [&"ui_accept"])


func test_switching_either_off_hides_it() -> void:
	_guide.show_warp_in = false
	_shop.open()
	_guide.refresh()
	assert_false(_guide.is_highlighting_warp_in())
	assert_false(_guide.warp_arrow.visible)
