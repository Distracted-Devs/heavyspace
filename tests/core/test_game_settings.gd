extends GutTest

const PATH := "user://test_settings.cfg"

var _was_enabled: bool
var _settings: GameSettings


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	DirAccess.remove_absolute(PATH)
	_settings = _make()


func after_each() -> void:
	DirAccess.remove_absolute(PATH)
	Contract.enabled = _was_enabled


func _make() -> GameSettings:
	var settings := GameSettings.new()
	settings.path = PATH
	add_child_autofree(settings)
	return settings


func test_a_change_notifies_once_and_saves() -> void:
	watch_signals(_settings)
	_settings.invert_pitch = true
	assert_signal_emit_count(_settings, "changed", 1)
	assert_true(FileAccess.file_exists(PATH))


func test_setting_the_same_value_does_nothing() -> void:
	watch_signals(_settings)
	_settings.vibration = true
	assert_signal_not_emitted(_settings, "changed")
	assert_false(FileAccess.file_exists(PATH))


func test_saved_settings_load_back() -> void:
	_settings.vibration = false
	_settings.invert_pitch = true
	_settings.show_fps = true
	var reloaded := _make()
	assert_false(reloaded.vibration)
	assert_true(reloaded.invert_pitch)
	assert_true(reloaded.show_fps)


func test_changing_show_fps_notifies_once() -> void:
	watch_signals(_settings)
	_settings.show_fps = not _settings.show_fps
	assert_signal_emit_count(_settings, "changed", 1)


func test_a_value_that_isnt_a_bool_is_ignored() -> void:
	var file := ConfigFile.new()
	file.set_value(GameSettings.SECTION, "vibration", "loud")
	file.save(PATH)
	var reloaded := _make()
	assert_true(reloaded.vibration)


func test_loading_doesnt_save() -> void:
	var file := ConfigFile.new()
	file.set_value(GameSettings.SECTION, "invert_pitch", true)
	file.save(PATH)
	var before := FileAccess.get_modified_time(PATH)
	var reloaded := _make()
	assert_true(reloaded.invert_pitch)
	assert_eq(FileAccess.get_modified_time(PATH), before)


func test_an_empty_path_is_reported() -> void:
	_settings.path = ""
	_settings.save()
	assert_push_error("path must be set")
