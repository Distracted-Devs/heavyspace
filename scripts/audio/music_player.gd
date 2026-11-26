class_name MusicPlayer
extends Node

const MIX_MARGIN := 0.02

@export var stream: AudioStream = preload(
	"res://resources/audio/music/heavyspace_music.tres"
):
	set(value):
		stream = value
		if player != null:
			player.stream = value
@export var bus := &"Music":
	set(value):
		if not Contract.require(
			AudioServer.get_bus_index(value) != -1,
			"bus must exist in the bus layout",
		):
			return
		bus = value
		if player != null:
			player.bus = value
@export_range(-40.0, 6.0, 0.5) var volume_db := -6.0:
	set(value):
		if not Contract.require(is_finite(value), "volume_db must be finite"):
			return
		volume_db = value
		if player != null:
			player.volume_db = value
@export var play_while_paused := true:
	set(value):
		play_while_paused = value
		process_mode = (
			Node.PROCESS_MODE_ALWAYS
			if value
			else Node.PROCESS_MODE_PAUSABLE
		)

@export_group("Events")
@export var events: GameEvents

var player := AudioStreamPlayer.new()

var _started := false


func _init() -> void:
	play_while_paused = play_while_paused


func _ready() -> void:
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	if events == null:
		events = get_node_or_null(^"/root/Events") as GameEvents
	if events != null:
		events.session_started.connect(restart)


func _exit_tree() -> void:
	if not _started:
		return
	player.stop()
	# The audio server only releases a stopped playback on its next mix, and
	# never at shutdown, so wait for that mix or the stream leaks at exit.
	# The player has usually stopped itself by now, as children leave first.
	var wait := AudioServer.get_time_to_next_mix() + MIX_MARGIN
	OS.delay_usec(int(wait * 1e6))


func restart() -> void:
	if not Contract.require(stream != null, "stream must be set"):
		return
	player.stop()
	player.play()
	_started = true
	Contract.ensure(player.playing, "the music must be playing")


func is_playing() -> bool:
	return player.playing
