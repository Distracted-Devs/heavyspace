extends GutTest

const LIST_SCENE := preload("res://scenes/ui/options_list.tscn")

var _was_enabled: bool
var _settings: GameSettings
var _mixer: RumbleMixer
var _list: OptionsList


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_settings = GameSettings.new()
	_settings.path = "user://test_options_settings.cfg"
	_settings.load_on_ready = false
	add_child_autofree(_settings)
	_mixer = RumbleMixer.new()
	_mixer.set_process(false)
	add_child_autofree(_mixer)
	_list = LIST_SCENE.instantiate()
	_list.settings = _settings
	_list.rumble = _mixer
	add_child_autofree(_list)


func after_each() -> void:
	DirAccess.remove_absolute(_settings.path)
	Contract.enabled = _was_enabled


func test_each_option_flips_its_setting() -> void:
	_list.invert_pitch_button.pressed.emit()
	assert_true(_settings.invert_pitch)
	_list.vibration_button.pressed.emit()
	assert_false(_settings.vibration)
	_list.vibration_button.pressed.emit()
	assert_true(_settings.vibration)
	_list.show_fps_button.pressed.emit()
	assert_true(_settings.show_fps)


func test_flipping_an_option_relabels_it() -> void:
	var before := _list.invert_pitch_button.text
	_list.invert_pitch_button.pressed.emit()
	assert_ne(_list.invert_pitch_button.text, before)


func test_a_change_made_elsewhere_relabels_it_too() -> void:
	var before := _list.show_fps_button.text
	_settings.show_fps = true
	assert_ne(_list.show_fps_button.text, before)


func test_turning_vibration_on_gives_a_test_pulse() -> void:
	_settings.vibration = false
	_list.vibration_button.pressed.emit()
	assert_true(_settings.vibration)
	assert_almost_eq(_mixer.strong(), _list.pulse_strong, 1e-5)


func test_the_first_button_is_the_first_option() -> void:
	assert_eq(_list.first_button(), _list.vibration_button)


func test_it_defaults_to_the_settings_autoload() -> void:
	var plain: OptionsList = add_child_autofree(LIST_SCENE.instantiate())
	assert_eq(plain.settings, get_node(^"/root/Settings"))
