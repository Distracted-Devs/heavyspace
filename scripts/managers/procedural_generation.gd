class_name ProceduralGeneration
extends Node

@export_group("Setup")
@export var collectable: PackedScene
@export var player: Player
@export var planet: Planet

@export_group("Parameters")
@export var spawn_chance := 0.1
@export var cell_side_length := 10.0
@export var grid_side_n_cells: int = 10
@export var size_scaling_mean: float = 0.2
@export var size_scaling_variance: float = 0.1
@export var position_jitter: float = 10.0
@export var n_spawns_per_cell: int = 5

var player_centre := Vector3i.ZERO
var previous_player_centre := Vector3i.ZERO
@onready var half_grid_side_n_cells: int = roundi(grid_side_n_cells / 2.0)
@onready var max_grid_distance: float = cell_side_length * grid_side_n_cells

var rng = RandomNumberGenerator.new()


class Cell:
	var is_checked: bool = true
	var nodes: Array[Node]


var spawn_grid: Dictionary[Vector3i, Cell]


func _ready() -> void:
	for cell_index_x in range(-half_grid_side_n_cells, half_grid_side_n_cells):
		for cell_index_y in range(-half_grid_side_n_cells, half_grid_side_n_cells):
			for cell_index_z in range(-half_grid_side_n_cells, half_grid_side_n_cells):
				var cell_position = Vector3i(cell_index_x, cell_index_y, cell_index_z) + player_centre
				var global_cell_position: Vector3 = cell_position * cell_side_length
				var new_cell = Cell.new()
				spawn_grid[cell_position] = new_cell
				if (rng.randf() < spawn_chance):
					if (global_cell_position - planet.global_position).length() > planet.radius:
						create_collectables(new_cell, cell_position, global_cell_position)


func _process(_delta: float) -> void:
	player_centre = Vector3i((player.body.global_position / cell_side_length).floor())
	if player_centre == previous_player_centre:
		return

	var min_spawn_grid_corner = Vector3i.ONE * -half_grid_side_n_cells + player_centre
	var max_spawn_grid_corner = Vector3i.ONE * (half_grid_side_n_cells - 1) + player_centre

	for cell_index_x in range(-half_grid_side_n_cells, half_grid_side_n_cells):
		for cell_index_y in range(-half_grid_side_n_cells, half_grid_side_n_cells):
			for cell_index_z in range(-half_grid_side_n_cells, half_grid_side_n_cells):
				var cell_position = Vector3i(cell_index_x, cell_index_y, cell_index_z) + player_centre
				if !is_point_on_outside_of_cube(
					cell_position,
					min_spawn_grid_corner,
					max_spawn_grid_corner,
				):
					continue

				# TODO add collectables removal
				# remove_collectable....
				var global_cell_position: Vector3 = cell_position * cell_side_length
				if cell_position not in spawn_grid:
					var new_cell = Cell.new()
					spawn_grid[cell_position] = new_cell
					if (rng.randf() < spawn_chance):
						if (global_cell_position - planet.global_position).length() > planet.radius:
							create_collectables(new_cell, cell_position, global_cell_position)

	previous_player_centre = player_centre


func create_collectables(
	new_cell: Cell,
	cell_position: Vector3i,
	global_cell_position: Vector3,
) -> void:
	var new_scale = rng.randfn(size_scaling_mean, size_scaling_variance)

	for spawn_index in range(n_spawns_per_cell):
		var new_collectable: MassCollectable = collectable.instantiate()
		add_child(new_collectable)
		new_collectable.global_position = jitter_vector(global_cell_position, position_jitter)
		new_collectable.scale *= new_scale
		spawn_grid[cell_position] = new_cell
		new_cell.nodes.append(new_collectable)


func jitter_vector(v: Vector3, jitter: float):
	return v + (Vector3(rng.randf(), rng.randf(), rng.randf()) - Vector3.ONE * 0.5) * jitter


func remove_collectable(spawn_position: Vector3i) -> void:
	for node in spawn_grid[spawn_position].nodes:
		node.queue_free()
	spawn_grid.erase(spawn_position)


func is_point_on_outside_of_cube(point: Vector3i, min_corner: Vector3i, max_corner: Vector3i):
	return (
		point.x == min_corner.x or point.x == max_corner.x or point.y == min_corner.y
		or point.y == max_corner.y or point.z == min_corner.z or point.z == max_corner.z
	)
