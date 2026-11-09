class_name ProceduralGeneration
extends Node

@export_group("Setup")
@export var collectable: PackedScene
@export var player: Player
@export var planet: Planet

@export_group("Parameters")
@export var spawn_chance := 0.2
@export var cell_side_length := 100.0
@export var grid_side_n_cells: int = 10
@export var size_scaling_mean: float = 1.0
@export var size_scaling_variance: float = 0.3
@export var position_jitter: float = 20.0
@export var n_spawns_per_cell: int = 2
@export var spawn_queue_per_frame: int = 10
@export var chance_of_much_bigger_spawn: float = 0.01
@export var big_spawn_scaling: float = 20.0

var player_centre := Vector3i.ZERO
var previous_player_centre := Vector3i.ZERO
@onready var half_grid_side_n_cells: int = roundi(grid_side_n_cells / 2.0)
@onready var max_grid_distance: float = cell_side_length * grid_side_n_cells
# 6 sides of the cube
# @onready var spawn_queue_size: int = grid_side_n_cells ** 2 * 6

var rng = RandomNumberGenerator.new()


class Cell:
	var position := Vector3i.ZERO
	var global_position := Vector3.ZERO
	var is_checked: bool = true
	var nodes: Array[Node]


var spawn_grid: Dictionary[Vector3i, Cell]
var spawn_queue: Array[Cell]


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
						new_cell.position = cell_position
						new_cell.global_position = global_cell_position
						create_collectables(new_cell)


func _process(_delta: float) -> void:
	player_centre = Vector3i((player.body.global_position / cell_side_length).floor())
	if player_centre == previous_player_centre:
		# go through cell queue
		for queue_index in range(min(spawn_queue.size(), spawn_queue_per_frame)):
			var new_cell: Cell = spawn_queue.pop_front()
			create_collectables(new_cell)
		return
	spawn_queue = []

	for cell_position: Vector3i in spawn_grid.keys():
		var cell_position_diff: Vector3i = abs(cell_position - player_centre)
		if (
			cell_position_diff.x > half_grid_side_n_cells
			or cell_position_diff.y > half_grid_side_n_cells
			or cell_position_diff.z > half_grid_side_n_cells
		):
			remove_collectable(cell_position)

	var min_spawn_grid_corner = Vector3i.ONE * -half_grid_side_n_cells + player_centre
	var max_spawn_grid_corner = Vector3i.ONE * (half_grid_side_n_cells - 1) + player_centre

	for cell_index_x in range(-half_grid_side_n_cells, half_grid_side_n_cells):
		for cell_index_y in range(-half_grid_side_n_cells, half_grid_side_n_cells):
			for cell_index_z in range(-half_grid_side_n_cells, half_grid_side_n_cells):
				var cell_position = Vector3i(cell_index_x, cell_index_y, cell_index_z) + player_centre

				# only add those on outside of cube
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
							new_cell.position = cell_position
							new_cell.global_position = global_cell_position
							spawn_queue.append(new_cell)

	previous_player_centre = player_centre


func create_collectables(new_cell: Cell) -> void:
	var new_scale = Vector3.ONE * rng.randfn(size_scaling_mean, size_scaling_variance)
	var n_spawns = n_spawns_per_cell
	if (rng.randf() < chance_of_much_bigger_spawn):
		new_scale *= big_spawn_scaling
		n_spawns = 1

	for spawn_index in range(n_spawns):
		var new_collectable: MassCollectable = collectable.instantiate()
		add_child(new_collectable)
		new_collectable.global_position = jitter_vector(new_cell.global_position, position_jitter)
		new_collectable.scale = Vector3.ONE * 0.01
		new_collectable.start_scale = Vector3.ONE * 0.01
		new_collectable.end_scale = new_scale
		spawn_grid[new_cell.position] = new_cell
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
