extends GutTest

const TREE := preload("res://resources/progression/skill_tree.tres")

var _was_enabled: bool
var _build: EndgameBuild


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_build = EndgameBuild.new()
	_build.reload_scene = false
	add_child_autofree(_build)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_it_starts_off() -> void:
	assert_false(_build.enabled)


func test_apply_maxes_the_whole_tree() -> void:
	var progression := Progression.new()
	_build.apply(progression, TutorialProgress.new())
	for node in TREE.nodes:
		assert_true(progression.is_maxed(node), node.id)
	assert_gte(progression.bank, 0.0)


func test_apply_finishes_the_tutorial() -> void:
	var tutorial := TutorialProgress.new()
	_build.apply(Progression.new(), tutorial)
	assert_true(tutorial.is_done(TutorialProgress.Part.CONTROLS))
	assert_true(tutorial.is_done(TutorialProgress.Part.OBJECTIVE))


func test_toggling_on_and_off_flips_the_run_progress() -> void:
	var saved := RunProgress.progression
	var saved_tutorial := RunProgress.tutorial
	RunProgress.progression = Progression.new()
	RunProgress.tutorial = TutorialProgress.new()
	_build.toggle()
	assert_true(_build.enabled)
	assert_eq(RunProgress.progression.player_level(), _max_level())
	_build.toggle()
	assert_false(_build.enabled)
	assert_eq(RunProgress.progression.player_level(), 0)
	RunProgress.progression = saved
	RunProgress.tutorial = saved_tutorial


func test_it_shows_no_text_on_screen() -> void:
	assert_eq(_build.find_children("*", "CanvasItem", true, false).size(), 0)


func test_missing_progress_is_reported() -> void:
	_build.apply(null, TutorialProgress.new())
	assert_push_error("progression and tutorial must be set")


func _max_level() -> int:
	var level := 0
	for node in TREE.nodes:
		level += node.max_buys
	return level
