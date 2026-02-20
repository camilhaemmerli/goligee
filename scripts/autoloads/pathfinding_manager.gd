extends Node
## Manages enemy pathfinding on the isometric grid using AStarGrid2D.
## All ground enemies sharing a spawn point use the same cached path,
## recalculated only when towers are placed or sold.

signal path_updated(spawn_index: int)

var _astar: AStarGrid2D
var _tile_map: TileMapLayer
var _spawn_tiles: Array[Vector2i] = []
var _goal_tiles: Array[Vector2i] = []
var _cached_paths: Dictionary = {}  # spawn_index -> PackedVector2Array (world coords)
var _cached_tile_paths: Dictionary = {}  # spawn_index -> Array[Vector2i] (tile coords)


func initialize(tile_map: TileMapLayer, spawn_tiles: Array[Vector2i], goal_tiles: Array[Vector2i]) -> void:
	_tile_map = tile_map
	_spawn_tiles = spawn_tiles
	_goal_tiles = goal_tiles

	_astar = AStarGrid2D.new()
	_astar.cell_shape = AStarGrid2D.CELL_SHAPE_ISOMETRIC_DOWN
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER

	var rect := tile_map.get_used_rect()
	_astar.region = rect
	_astar.cell_size = Vector2(tile_map.tile_set.tile_size)
	_astar.update()

	# Mark unwalkable tiles as solid
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var pos := Vector2i(x, y)
			var tile_data := tile_map.get_cell_tile_data(pos)
			if not tile_data:
				_astar.set_point_solid(pos, true)
				continue
			var walkable = tile_data.get_custom_data("walkable") if tile_data.get_custom_data("walkable") != null else true
			if not walkable:
				_astar.set_point_solid(pos, true)

	_recalculate_all_paths()


func can_place_tower(tile_pos: Vector2i) -> bool:
	if not _astar or _astar.is_point_solid(tile_pos):
		return false

	# Temporarily block this tile
	_astar.set_point_solid(tile_pos, true)

	# Check that all spawn-to-goal paths still exist
	var all_valid := true
	for i in _spawn_tiles.size():
		var found := false
		for goal in _goal_tiles:
			var path := _astar.get_id_path(_spawn_tiles[i], goal)
			if not path.is_empty():
				found = true
				break
		if not found:
			all_valid = false
			break

	# Restore the tile
	_astar.set_point_solid(tile_pos, false)
	return all_valid


func place_tower(tile_pos: Vector2i) -> void:
	if not _astar:
		return
	_astar.set_point_solid(tile_pos, true)
	_recalculate_affected_paths(tile_pos)


func remove_tower(tile_pos: Vector2i) -> void:
	if not _astar:
		return
	_astar.set_point_solid(tile_pos, false)
	_recalculate_affected_paths(tile_pos)


func get_path_for_spawn(index: int) -> PackedVector2Array:
	if _cached_paths.has(index):
		return _cached_paths[index]
	return PackedVector2Array()


func get_flying_path(index: int) -> PackedVector2Array:
	if not _tile_map or _spawn_tiles.is_empty() or _goal_tiles.is_empty():
		return PackedVector2Array()

	var spawn_world := _tile_map.map_to_local(_spawn_tiles[index % _spawn_tiles.size()])
	var goal_world := _tile_map.map_to_local(_goal_tiles[0])
	return PackedVector2Array([spawn_world, goal_world])


func _recalculate_all_paths() -> void:
	for i in _spawn_tiles.size():
		_recalculate_path(i)


func _recalculate_affected_paths(changed_tile: Vector2i) -> void:
	for i in _spawn_tiles.size():
		# Check if changed tile is on or adjacent to any tile in the cached path
		if _cached_tile_paths.has(i):
			var tile_path: Array = _cached_tile_paths[i]
			var affected := false
			for tp in tile_path:
				var dx := absi(changed_tile.x - tp.x)
				var dy := absi(changed_tile.y - tp.y)
				if maxi(dx, dy) <= 1:  # Chebyshev distance
					affected = true
					break
			if not affected:
				continue
		# No cached path or path is affected — recalculate
		_recalculate_path(i)


func _recalculate_path(spawn_index: int) -> void:
	if not _astar or not _tile_map:
		return

	var spawn := _spawn_tiles[spawn_index]
	var best_path: PackedVector2Array = PackedVector2Array()
	var best_tile_path: Array[Vector2i] = []

	# Find shortest path to any goal tile
	for goal in _goal_tiles:
		var tile_path := _astar.get_id_path(spawn, goal)
		if not tile_path.is_empty():
			if best_path.is_empty() or tile_path.size() < best_path.size():
				# Convert tile coords to world coords
				var world_path := PackedVector2Array()
				best_tile_path = []
				for tile_pos in tile_path:
					world_path.append(_tile_map.map_to_local(tile_pos))
					best_tile_path.append(Vector2i(tile_pos))
				best_path = world_path

	# Only emit if path actually changed
	var prev_tile_path: Array = _cached_tile_paths.get(spawn_index, [])
	_cached_tile_paths[spawn_index] = best_tile_path
	_cached_paths[spawn_index] = best_path

	if best_tile_path.size() != prev_tile_path.size():
		path_updated.emit(spawn_index)
		return
	for j in best_tile_path.size():
		if best_tile_path[j] != prev_tile_path[j]:
			path_updated.emit(spawn_index)
			return
