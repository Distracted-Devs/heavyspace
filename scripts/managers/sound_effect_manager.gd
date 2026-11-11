class_name SoundEffectManager
extends Node

const THRUST := 0
const PLAYER_DESTROY := 2
const MISSION_DESTROY := 3

const GROUP := &"sound_effect_manager"

## 0 = thrust, 1 = , 2 = player destroy, 3 = mission destroy
@export var sound_effects: Array[AudioStream] = [null, null, null, null]
## Audio bus every effect is sent to.
@export var bus: StringName = &"Master"
@export var pool_size := 16

var _players: Array[AudioStreamPlayer] = []


static func find(tree: SceneTree) -> SoundEffectManager:
	return tree.get_first_node_in_group(GROUP) as SoundEffectManager


func _ready() -> void:
	add_to_group(GROUP)
	for i in pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)


func play_sound_effect(index: int) -> AudioStreamPlayer:
	if index < 0 or index >= sound_effects.size() or sound_effects[index] == null:
		return null
	var p := _get_free_player()
	p.stream = sound_effects[index]
	p.play()
	return p

func _get_free_player() -> AudioStreamPlayer:
	var oldest := _players[0]
	for p in _players:
		if not p.playing:
			return p
		if p.get_playback_position() > oldest.get_playback_position():
			oldest = p
	return oldest
