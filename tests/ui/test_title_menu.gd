extends GutTest

const MENU_SCENE := preload("res://scenes/ui/title_menu.tscn")

var _was_enabled: bool
var _settings: GameSettings
var _menu: TitleMenu


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_settings = GameSettings.new()
	_settings.path = "user://test_title_settings.cfg"
	_settings.load_on_ready = false
	add_child_autofree(_settings)
	_menu = MENU_SCENE.instantiate()
	_menu.options_list.settings = _settings
	add_child_autofree(_menu)
	watch_signals(_menu)


func after_each() -> void:
	DirAccess.remove_absolute(_settings.path)
	Contract.enabled = _was_enabled


func test_it_opens_on_the_main_page() -> void:
	assert_true(_menu.main_page.visible)
	assert_false(_menu.options_page.visible)


func test_start_and_exit_are_signalled() -> void:
	_menu.start_button.pressed.emit()
	_menu.exit_button.pressed.emit()
	assert_signal_emitted(_menu, "start_pressed")
	assert_signal_emitted(_menu, "exit_pressed")


func test_options_open_and_back_returns() -> void:
	_menu.options_button.pressed.emit()
	assert_true(_menu.options_page.visible)
	assert_false(_menu.main_page.visible)
	_menu.back_button.pressed.emit()
	assert_true(_menu.main_page.visible)
	assert_false(_menu.options_page.visible)


func test_the_options_page_holds_the_options() -> void:
	assert_true(_menu.options_page.is_ancestor_of(_menu.options_list))
	_menu.options_list.show_fps_button.pressed.emit()
	assert_true(_settings.show_fps)
