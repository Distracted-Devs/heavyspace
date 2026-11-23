class_name LoseController
extends Node

signal lost_game(other: Node3D)

@export_group("Components")
@export var player: Player

var lost := false
var armed := true


func _ready() -> void:
	player.contact_component.heavier_contact.connect(_on_heavier_contact)


func _on_heavier_contact(other: Node3D, _other_mass: float) -> void:
	if lost or not armed:
		return
	lost = true
	player.stop_flight()
	if OS.is_debug_build():
		print("[Debug] Lost: crashed into %s" % other.name)
	lost_game.emit(other)


func disarm() -> void:
	if not Contract.require(not lost, "a lost run can't be disarmed"):
		return
	armed = false
