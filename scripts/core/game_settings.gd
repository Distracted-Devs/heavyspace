class_name GameSettings
extends Node

signal changed

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"

@export var path := DEFAULT_PATH
@export var load_on_ready := true

var vibration := true:
	set(value):
		if value == vibration:
			return
		vibration = value
		_changed()
var invert_pitch := false:
	set(value):
		if value == invert_pitch:
			return
		invert_pitch = value
		_changed()

var _loading := false


func _ready() -> void:
	if load_on_ready:
		load_saved()


func load_saved() -> void:
	if not Contract.require(not path.is_empty(), "path must be set"):
		return
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	_loading = true
	vibration = _read_bool(file, "vibration", vibration)
	invert_pitch = _read_bool(file, "invert_pitch", invert_pitch)
	_loading = false


func save() -> void:
	if not Contract.require(not path.is_empty(), "path must be set"):
		return
	var file := ConfigFile.new()
	file.set_value(SECTION, "vibration", vibration)
	file.set_value(SECTION, "invert_pitch", invert_pitch)
	var saved := file.save(path)
	Contract.ensure(saved == OK, "settings must save to %s" % path)


func _read_bool(file: ConfigFile, key: String, fallback: bool) -> bool:
	var value: Variant = file.get_value(SECTION, key, fallback)
	return value if value is bool else fallback


func _changed() -> void:
	if not _loading:
		save()
	changed.emit()
