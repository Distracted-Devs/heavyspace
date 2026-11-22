class_name MassTintDebug
extends Node

@export_group("Components")
@export var player: Player
@export var streamer: HierarchyStreamer

@export_group("Tint")
@export var enabled := true
@export var lighter_colour := Color(0.3, 1.0, 0.3)
@export var heavier_colour := Color(1.0, 0.3, 0.3)

var lighter_material: StandardMaterial3D
var heavier_material: StandardMaterial3D

var _drawn_tinted_for := NAN
var _drawn_tint_active := false


func _ready() -> void:
	lighter_material = _tinted(lighter_colour)
	heavier_material = _tinted(heavier_colour)
	if streamer != null:
		streamer.expanded.connect(_on_expanded)


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
	if (
		streamer != null
		and (active != _drawn_tint_active or player_mass != _drawn_tinted_for)
	):
		_drawn_tint_active = active
		_drawn_tinted_for = player_mass
		for path in streamer.expanded_paths():
			_tint_drawn(streamer.renderer_for(path))


func _on_expanded(_path: PackedInt32Array, renderer: OrbitRenderer) -> void:
	if not is_nan(_drawn_tinted_for):
		_tint_drawn(renderer)


func _tint_drawn(renderer: OrbitRenderer) -> void:
	var masses := renderer.layout.mass
	for index in renderer.count():
		var colour := OrbitRenderer.UNTINTED
		if _drawn_tint_active:
			colour = (
				heavier_colour
				if masses[index] > _drawn_tinted_for
				else lighter_colour
			)
		renderer.set_tint(index, colour)


func _tinted(colour: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = MassBody.UNIT_SPHERE.material.duplicate()
	material.albedo_color = colour
	return material
