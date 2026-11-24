extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PROMPT_SCENE := preload("res://scenes/ui/warp_prompt.tscn")
const LEVEL_PATH := "res://scenes/levels/generated_level.tscn"

var _was_enabled: bool
var _player: Player
var _lose: LoseController
var _warp: WarpController
var _prompt: WarpPrompt


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_player = PLAYER_SCENE.instantiate()
	_player.flight_input.capture_mouse = false
	add_child_autofree(_player)
	_lose = LoseController.new()
	_lose.player = _player
	add_child_autofree(_lose)
	_warp = WarpController.new()
	_warp.player = _player
	_warp.lose_controller = _lose
	_warp.progression = Progression.new()
	add_child_autofree(_warp)
	_prompt = PROMPT_SCENE.instantiate()
	_prompt.warp_controller = _warp
	_prompt.set_process(false)
	add_child_autofree(_prompt)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _fill() -> void:
	_player.cargo.add(_player.cargo.capacity())


func test_hidden_until_the_quota_is_met() -> void:
	_prompt.refresh()
	assert_false(_prompt.visible)
	_fill()
	_prompt.refresh()
	assert_true(_prompt.visible)


func test_hidden_once_warping() -> void:
	_fill()
	_warp.warp_out()
	_prompt.refresh()
	assert_false(_prompt.visible)


func test_hidden_after_a_crash() -> void:
	_fill()
	_player.contact_component.heavier_contact.emit(_player, 100.0)
	_prompt.refresh()
	assert_false(_prompt.visible)


func test_it_prompts_the_warp_with_a_pulse() -> void:
	var prompt: InputPrompt = _prompt.get_node("Stack/Centre/Panel/Rows/Warp")
	assert_eq(Array(prompt.actions), [&"warp_out"])
	assert_eq(prompt.text, "WARP OUT >>")
	var pulse: PulseEffect = _prompt.get_node("Pulse")
	assert_eq(pulse.target, _prompt.get_node("Stack/Centre/Panel"))


func test_it_runs_by_itself_each_frame() -> void:
	_prompt.set_process(true)
	_fill()
	await wait_process_frames(2)
	assert_true(_prompt.visible)


func test_missing_controller_is_reported() -> void:
	var prompt: WarpPrompt = PROMPT_SCENE.instantiate()
	prompt.set_process(false)
	add_child_autofree(prompt)
	assert_push_error(
		"[Contract] Pre-condition broken: warp_controller must be set"
	)


func test_the_level_has_a_warp_prompt() -> void:
	var level: Node = autofree(load(LEVEL_PATH).instantiate())
	var prompt := level.get_node("WarpPrompt") as WarpPrompt
	assert_not_null(prompt)
	assert_eq(prompt.warp_controller, level.get_node("WarpController"))
