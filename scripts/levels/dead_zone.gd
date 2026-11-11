@tool
class_name DeadZone
extends Node3D
## Spherical play area around a body (normally the big central planet).
##
## When the ship leaves the sphere a countdown starts; if it isn't back inside
## before it reaches zero the player dies. The OrbitMinimap draws the boundary
## as a red ring and a DeadZoneWarning (red screen + countdown) listens to the
## signals below.
##
## Usage: add dead_zone.tscn to a level and set `center` to the planet.

## Emitted when the ship leaves the sphere (countdown starts).
signal player_exited
## Emitted when the ship comes back inside in time.
signal player_returned
## Emitted when the countdown hits zero (the player is killed).
signal time_ran_out

## The zone stays centred on this node. Leave empty to keep the node's own position.
@export var center: Node3D:
	set(value):
		center = value
		_follow_center()
## Radius of the play area, in world units.
@export var radius: float = 6000.0:
	set(value):
		radius = maxf(value, 1.0)
		_update_preview()
## Seconds the player has to get back inside before dying.
@export var return_time: float = 5.0
## Leave empty to use the first Player in the "player" group.
@export var player: Player

@export_group("Editor preview")
## Draws a translucent sphere in the editor so you can see the radius.
@export var show_in_editor: bool = true:
	set(value):
		show_in_editor = value
		_update_preview()
@export var preview_colour: Color = Color(1.0, 0.15, 0.1, 0.08):
	set(value):
		preview_colour = value
		_update_preview()

var _outside := false
var _time_left := 0.0
var _preview: MeshInstance3D


func _ready() -> void:
	add_to_group(&"dead_zone")
	_follow_center()
	_update_preview()


func _process(delta: float) -> void:
	_follow_center()
	if Engine.is_editor_hint():
		return
	if not _find_player() or player.is_dead():
		return

	var outside := not contains(player.ship.global_position)
	if outside and not _outside:
		_outside = true
		_time_left = return_time
		player_exited.emit()
	elif not outside and _outside:
		_outside = false
		player_returned.emit()

	if _outside:
		_time_left = maxf(0.0, _time_left - delta)
		if _time_left <= 0.0:
			_outside = false
			time_ran_out.emit()
			player.on_dead()


## True if the world point is inside the play area.
func contains(world_point: Vector3) -> bool:
	return world_point.distance_squared_to(global_position) <= radius * radius


func is_player_outside() -> bool:
	return _outside


## Seconds left to return (only meaningful while outside).
func get_time_left() -> float:
	return _time_left


func _follow_center() -> void:
	if is_instance_valid(center) and center.is_inside_tree() and is_inside_tree():
		global_position = center.global_position


func _find_player() -> bool:
	if is_instance_valid(player) and is_instance_valid(player.ship):
		return true
	player = get_tree().get_first_node_in_group(&"player") as Player
	return is_instance_valid(player) and is_instance_valid(player.ship)


func _update_preview() -> void:
	if not is_inside_tree():
		return
	var wanted := Engine.is_editor_hint() and show_in_editor
	if not wanted:
		if _preview:
			_preview.queue_free()
			_preview = null
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_preview.material_override = material
		_preview.mesh = SphereMesh.new()
		add_child(_preview) # not owned: never saved into the scene
	var sphere := _preview.mesh as SphereMesh
	sphere.radius = radius
	sphere.height = radius * 2.0
	(_preview.material_override as StandardMaterial3D).albedo_color = preview_colour
