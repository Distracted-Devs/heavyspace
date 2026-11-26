extends GutTest

const MUSIC := preload("res://resources/audio/music/heavyspace_music.tres")

var _was_enabled: bool
var _events: GameEvents
var _music: MusicPlayer


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_events = GameEvents.new()
	add_child_autofree(_events)
	_music = MusicPlayer.new()
	_music.events = _events
	_music.stream = MUSIC
	add_child_autofree(_music)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_silent_until_a_session_starts() -> void:
	assert_false(_music.is_playing())


func test_a_session_start_plays_from_the_start() -> void:
	_events.start_session()
	assert_true(_music.is_playing())
	assert_eq(_music.player.get_playback_position(), 0.0)


func test_playing_on_keeps_the_same_playback() -> void:
	_events.start_session()
	var playback := _music.player.get_stream_playback()
	await wait_process_frames(5)
	assert_true(_music.is_playing())
	assert_same(_music.player.get_stream_playback(), playback)


func test_a_second_session_start_restarts_it() -> void:
	_events.start_session()
	var playback := _music.player.get_stream_playback()
	await wait_process_frames(2)
	_events.start_session()
	assert_true(_music.is_playing())
	assert_not_same(_music.player.get_stream_playback(), playback)


func test_it_follows_the_pause_setting() -> void:
	_music.play_while_paused = true
	assert_eq(_music.process_mode, Node.PROCESS_MODE_ALWAYS)
	_music.play_while_paused = false
	assert_eq(_music.process_mode, Node.PROCESS_MODE_PAUSABLE)


func test_restarting_without_a_stream_is_reported() -> void:
	_music.stream = null
	_music.restart()
	assert_push_error("stream must be set")
	assert_false(_music.is_playing())


func test_an_unknown_bus_is_reported_and_ignored() -> void:
	var bus := _music.bus
	_music.bus = &"NoSuchBus"
	assert_push_error("bus must exist")
	assert_eq(_music.bus, bus)


func test_a_non_finite_volume_is_reported_and_ignored() -> void:
	var volume := _music.volume_db
	_music.volume_db = NAN
	assert_push_error("volume_db must be finite")
	assert_eq(_music.volume_db, volume)
