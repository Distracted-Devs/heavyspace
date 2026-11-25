extends Node

# Puts every piece of UI text in Orbitron at runtime, without touching the
# production theme or scenes: the holo theme's default font (in memory only,
# never saved), the engine fallback, and any per-control font override as
# each control enters the tree. Sits first in main.tscn so it runs before
# anything else is added.

@export var enabled := true
@export var font: Font = preload("res://prototypes/game_feel/fonts/orbitron.ttf")
## Orbitron is a variable font; 400 = regular, 700 = bold, 900 = black.
@export_range(400, 900, 100) var weight := 500

var _font: Font


func _enter_tree() -> void:
	if not enabled:
		return
	var variation := FontVariation.new()
	variation.base_font = font
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_font = variation
	ThemeDB.fallback_font = _font
	var holo: Theme = load("res://resources/ui/holo_theme.tres")
	holo.default_font = _font
	var project := ThemeDB.get_project_theme()
	if project:
		project.default_font = _font
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


# Swap the font once each control is ready: changing it while the control
# is still entering the tree trips the text server.
func _on_node_added(node: Node) -> void:
	var control := node as Control
	if control == null:
		return
	if control.is_node_ready():
		_reapply.call_deferred(control)
	else:
		control.ready.connect(_reapply.bind(control), CONNECT_ONE_SHOT)


func _reapply(control: Control) -> void:
	if not is_instance_valid(control):
		return
	for font_name in ["font", "normal_font", "bold_font", "title_font"]:
		if control.has_theme_font_override(font_name):
			control.add_theme_font_override(font_name, _font)
