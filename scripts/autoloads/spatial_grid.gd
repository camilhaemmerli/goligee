extends Node
## Spatial hash grid for efficient radius queries on enemies.
## Divides the world into cells and tracks which enemies occupy each cell.

const CELL_SIZE = 64.0  # 2 tiles

var _grid: Dictionary = {}  # Vector2i -> Array[Node2D]
var _entity_cells: Dictionary = {}  # instance_id -> Vector2i


func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.y / CELL_SIZE))


func register(enemy: Node2D) -> void:
	var cell := _world_to_cell(enemy.global_position)
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append(enemy)
	_entity_cells[enemy.get_instance_id()] = cell


func unregister(enemy: Node2D) -> void:
	var eid := enemy.get_instance_id()
	if _entity_cells.has(eid):
		var old_cell: Vector2i = _entity_cells[eid]
		if _grid.has(old_cell):
			_grid[old_cell].erase(enemy)
			if _grid[old_cell].is_empty():
				_grid.erase(old_cell)
		_entity_cells.erase(eid)


func update_position(enemy: Node2D) -> void:
	var eid := enemy.get_instance_id()
	var new_cell := _world_to_cell(enemy.global_position)
	if _entity_cells.has(eid) and _entity_cells[eid] == new_cell:
		return  # Same cell, nothing to do

	# Remove from old cell
	if _entity_cells.has(eid):
		var old_cell: Vector2i = _entity_cells[eid]
		if _grid.has(old_cell):
			_grid[old_cell].erase(enemy)
			if _grid[old_cell].is_empty():
				_grid.erase(old_cell)

	# Add to new cell
	if not _grid.has(new_cell):
		_grid[new_cell] = []
	_grid[new_cell].append(enemy)
	_entity_cells[eid] = new_cell


func get_enemies_in_radius(center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var radius_sq := radius * radius

	# Compute AABB of the query circle in cell coordinates
	var min_cell := _world_to_cell(center - Vector2(radius, radius))
	var max_cell := _world_to_cell(center + Vector2(radius, radius))

	for cx in range(min_cell.x, max_cell.x + 1):
		for cy in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(cx, cy)
			if not _grid.has(cell):
				continue
			for enemy in _grid[cell]:
				if is_instance_valid(enemy):
					if center.distance_squared_to(enemy.global_position) <= radius_sq:
						result.append(enemy)

	return result


func clear() -> void:
	_grid.clear()
	_entity_cells.clear()
