extends GutTest

var _was_enabled: bool
var _settings: GameSettings
var _overlay: FpsOverlay


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_settings = GameSettings.new()
	_settings.path = "user://test_fps_settings.cfg"
	_settings.load_on_ready = false
	add_child_autofree(_settings)
	_overlay = FpsOverlay.new()
	_overlay.settings = _settings
	_overlay.set_process(false)
	add_child_autofree(_overlay)


func after_each() -> void:
	DirAccess.remove_absolute(_settings.path)
	Contract.enabled = _was_enabled


func test_hidden_while_the_setting_is_off() -> void:
	assert_false(_overlay.visible)


func test_it_follows_the_setting() -> void:
	_settings.show_fps = true
	assert_true(_overlay.visible)
	_settings.show_fps = false
	assert_false(_overlay.visible)


func test_it_shows_the_engines_frame_rate() -> void:
	_settings.show_fps = true
	_overlay.update(_overlay.refresh_interval)
	assert_eq(_overlay.shown_fps, roundi(Engine.get_frames_per_second()))


func test_it_only_refreshes_every_interval() -> void:
	_settings.show_fps = true
	_overlay.update(_overlay.refresh_interval)
	_overlay.shown_fps = -1
	_overlay.update(_overlay.refresh_interval * 0.5)
	assert_eq(_overlay.shown_fps, -1)


func test_a_bad_interval_is_reported_and_ignored() -> void:
	var refresh_interval := _overlay.refresh_interval
	_overlay.refresh_interval = 0.0
	assert_push_error("refresh_interval must be positive")
	assert_eq(_overlay.refresh_interval, refresh_interval)
