extends Node
# Persistent music player. Plays the intro once, then loops the loop track
# forever. Starts again from the intro only when the title screen loads.

@export var intro_path := "res://resources/audio/music/heavyspace_intro.wav"
@export var loop_path := "res://resources/audio/music/heavyspace_loop.wav"
@export var title_scene := "res://scenes/title/title_screen.tscn"
@export_range(-40.0, 6.0, 0.5) var volume_db := -6.0:
	set(value):
		volume_db = value
		if player:
			player.volume_db = value
@export var play_while_paused := true

var player: AudioStreamPlayer


func _ready() -> void:
	process_mode = (
		Node.PROCESS_MODE_ALWAYS if play_while_paused
		else Node.PROCESS_MODE_PAUSABLE
	)
	player = AudioStreamPlayer.new()
	player.volume_db = volume_db
	player.stream = _build_stream()
	add_child(player)
	get_tree().scene_changed.connect(_on_scene_changed)


func _build_stream() -> AudioStream:
	# Loaded straight from the .wav so the prototype doesn't need imports.
	var intro := AudioStreamWAV.load_from_file(
		ProjectSettings.globalize_path(intro_path)
	)
	var loop := AudioStreamWAV.load_from_file(
		ProjectSettings.globalize_path(loop_path)
	)
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(round(loop.get_length() * loop.mix_rate))
	var music := AudioStreamInteractive.new()
	music.clip_count = 2
	music.set_clip_stream(0, intro)
	music.set_clip_auto_advance(0, AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
	music.set_clip_auto_advance_next_clip(0, 1)
	music.set_clip_stream(1, loop)
	music.initial_clip = 0
	return music


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == title_scene:
		player.stop()
		player.play()
		print("music: title reached, restarting from the intro")
