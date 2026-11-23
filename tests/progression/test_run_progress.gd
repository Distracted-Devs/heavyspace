extends GutTest


func test_the_autoload_holds_a_progression() -> void:
	var run_progress := get_tree().root.get_node_or_null("RunProgress")
	assert_not_null(run_progress)
	assert_true(run_progress.progression is Progression)
