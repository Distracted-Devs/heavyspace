class_name GameEvents
extends Node

signal session_started


func start_session() -> void:
	session_started.emit()
