class_name MassTintDebug
extends Node

@export_group("Components")
@export var player: Player

@export_group("Tint")
@export var enabled := true
@export var lighter_colour := Color(0.3, 1.0, 0.3)
@export var heavier_colour := Color(1.0, 0.3, 0.3)

var lighter_material: StandardMaterial3D
var heavier_material: StandardMaterial3D


func _ready() -> void:
	lighter_material = _tinted(lighter_colour)
	heavier_material = _tinted(heavier_colour)


func _process(_delta: float) -> void:
	var active := enabled and OS.is_debug_build()
	var player_mass := player.mass_component.current_mass
	for node in get_tree().get_nodes_in_group(MassBody.GROUP):
		var body := node as MassBody
		var material: Material = null
		if active:
			material = (
				heavier_material
				if body.mass > player_mass
				else lighter_material
			)
		if body.mesh.material_override != material:
			body.set_material_override(material)


func _tinted(colour: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = MassBody.UNIT_SPHERE.material.duplicate()
	material.albedo_color = colour
	return material
