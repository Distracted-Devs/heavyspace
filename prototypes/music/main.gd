extends Node
# Entry point: adds the music player to the root so it survives scene
# changes, then hands over to the real title screen.

const Music := preload("res://prototypes/music/music.gd")

@export var title_scene := "res://scenes/title/title_screen.tscn"


func _ready() -> void:
	var music := Music.new()
	music.name = "PrototypeMusic"
	get_tree().root.add_child.call_deferred(music)
	get_tree().change_scene_to_file.call_deferred(title_scene)
