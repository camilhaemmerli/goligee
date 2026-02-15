class_name GridOverlay
extends Node2D
## Draws subtle diamond outlines on buildable tiles to show the grid.

var _tile_map: TileMapLayer
var _map_w: int
var _map_h: int
var _buildable_positions: Array[Vector2] = []
var _diamond_half_w := 32.0
var _diamond_half_h := 16.0


func setup(tile_map: TileMapLayer, map_w: int, map_h: int) -> void:
	_tile_map = tile_map
	_map_w = map_w
	_map_h = map_h
	z_index = -1  # Below towers and enemies

	# Cache buildable tile positions
	for y in _map_h:
		for x in _map_w:
			var pos := Vector2i(x, y)
			var td := _tile_map.get_cell_tile_data(pos)
			if td and td.get_custom_data("buildable"):
				_buildable_positions.append(_tile_map.map_to_local(pos))
	queue_redraw()


func _draw() -> void:
	var color := Color("#30A0D8A0")  # Subtle cyan, ~19% opacity
	var hw := _diamond_half_w
	var hh := _diamond_half_h
	for center in _buildable_positions:
		var pts := PackedVector2Array([
			center + Vector2(0, -hh),
			center + Vector2(hw, 0),
			center + Vector2(0, hh),
			center + Vector2(-hw, 0),
			center + Vector2(0, -hh),
		])
		draw_polyline(pts, color, 1.0)
