extends GutTest

var _events: GameEvents


func before_each() -> void:
	_events = GameEvents.new()
	add_child_autofree(_events)
	watch_signals(_events)


func test_starting_a_session_emits_session_started_once() -> void:
	_events.start_session()
	assert_signal_emit_count(_events, "session_started", 1)


func test_each_start_emits_again() -> void:
	_events.start_session()
	_events.start_session()
	assert_signal_emit_count(_events, "session_started", 2)


func test_nothing_is_emitted_until_a_session_starts() -> void:
	assert_signal_not_emitted(_events, "session_started")
