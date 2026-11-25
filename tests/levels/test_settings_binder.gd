extends GutTest

var _was_enabled: bool
var _settings: GameSettings
var _input: PlayerInputComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_settings = GameSettings.new()
	_settings.path = "user://test_binder_settings.cfg"
	_settings.load_on_ready = false
	add_child_autofree(_settings)
	_input = PlayerInputComponent.new()
	_input.capture_mouse = false
	_input.set_process(false)
	_input.set_physics_process(false)
	add_child_autofree(_input)


func after_each() -> void:
	DirAccess.remove_absolute(_settings.path)
	Contract.enabled = _was_enabled


func _bind() -> SettingsBinder:
	var binder := SettingsBinder.new()
	binder.settings = _settings
	binder.player_input = _input
	add_child_autofree(binder)
	return binder


func test_pitch_follows_the_setting_on_ready() -> void:
	_settings.invert_pitch = true
	_bind()
	assert_true(_input.invert_pitch)


func test_pitch_follows_a_later_change() -> void:
	_bind()
	_settings.invert_pitch = true
	assert_true(_input.invert_pitch)
	_settings.invert_pitch = false
	assert_false(_input.invert_pitch)


func test_missing_player_input_is_reported() -> void:
	var binder := SettingsBinder.new()
	binder.settings = _settings
	add_child_autofree(binder)
	assert_push_error("settings and player_input must be set")
