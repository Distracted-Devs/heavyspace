class_name ProceduralGeneration
extends Node

@export_group("Setup")
@export var collectable: PackedScene
@export var player: Player
@export var centre_point := Vector3.ZERO
@export var empty_radius := 1.0

@export_group("Parameters")
@export var spawn_chance := 0.1
@export var cell_side_length := 10.0
@export var grid_side_n_cells: int = 100

var player_centre := Vector3.ZERO
@onready var half_grid_side_n_cells: int = roundi(grid_side_n_cells / 2.0)
@onready var max_grid_distance: float = cell_side_length * grid_side_n_cells


class SpawnedObject:
	var node: PackedScene


var spawn_grid: Dictionary[Vector3i, SpawnedObject]


func _process(_delta: float) -> void:
	player_centre = player.global_position
	for cell_index_x in range(-half_grid_side_n_cells, half_grid_side_n_cells):
		for cell_index_y in range(-half_grid_side_n_cells, half_grid_side_n_cells):
			for cell_index_z in range(-half_grid_side_n_cells, half_grid_side_n_cells):
				var cell_position = Vector3i(cell_index_x, cell_index_y, cell_index_z)

				if cell_position not in spawn_grid:
					create_collectable(cell_position)
				else:
					var collectable_position: Vector3 = spawn_grid[cell_position] \
							.node \
							.global_position
					var distance_from_collectable = collectable_position - player_centre
					if distance_from_collectable.length() > max_grid_distance:
						remove_collectable(cell_position)


func get_player_cell_position() -> Vector3i:
	return Vector3i(player_centre / cell_side_length)


func create_collectable(spawn_position: Vector3i) -> void:
	var player_cell_position: Vector3i = get_player_cell_position()
	var global_cell_position: Vector3 = Vector3(spawn_position * cell_side_length) + Vector3(
		player_cell_position
	)
	var new_spawn: SpawnedObject = spawn_grid[spawn_position]
	new_spawn.node.instantiate()


func remove_collectable(spawn_position: Vector3i) -> void:
	spawn_grid[spawn_position].node.free()
	spawn_grid.erase(spawn_position)
