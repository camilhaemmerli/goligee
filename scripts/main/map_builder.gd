class_name MapBuilder
extends RefCounted
## Programmatically builds a TileSet and paints a 14x10 isometric map at runtime.
## Called from game.gd before PathfindingManager init.

const TILE_W := 64
const TILE_H := 32
const MAP_W := 14
const MAP_H := 10

# Atlas tile IDs (columns in the 3-tile atlas)
const GROUND := Vector2i(0, 0)
const PATH := Vector2i(1, 0)
const WALL := Vector2i(2, 0)

# Twilight palette colors
const COLOR_GROUND := Color("#2A2D4E")   # Deep blue-gray ground
const COLOR_PATH := Color("#D06070")     # Warm pink path
const COLOR_WALL := Color("#1A1B30")     # Dark violet wall
const COLOR_GROUND_SHADE := Color("#22254A")
const COLOR_PATH_SHADE := Color("#B04858")
const COLOR_WALL_SHADE := Color("#141528")


static func build_map(tile_map: TileMapLayer) -> Dictionary:
	# 1. Create TileSet
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = Vector2i(TILE_W, TILE_H)

	# Add custom data layers
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "buildable")
	tile_set.set_custom_data_layer_type(0, TYPE_BOOL)

	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(1, "walkable")
	tile_set.set_custom_data_layer_type(1, TYPE_BOOL)

	# 2. Generate atlas image (3 tiles wide, 1 tile tall)
	var atlas_img := Image.create(TILE_W * 3, TILE_H, false, Image.FORMAT_RGBA8)
	_draw_isometric_tile(atlas_img, 0, COLOR_GROUND, COLOR_GROUND_SHADE)
	_draw_isometric_tile(atlas_img, 1, COLOR_PATH, COLOR_PATH_SHADE)
	_draw_isometric_tile(atlas_img, 2, COLOR_WALL, COLOR_WALL_SHADE)

	var atlas_tex := ImageTexture.create_from_image(atlas_img)

	# 3. Create TileSetAtlasSource
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(TILE_W, TILE_H)

	# Create the 3 atlas tiles
	source.create_tile(GROUND)   # (0,0) = ground
	source.create_tile(PATH)     # (1,0) = path
	source.create_tile(WALL)     # (2,0) = wall

	var source_id := tile_set.add_source(source)

	# 4. Set custom data on tiles
	# Ground: walkable + buildable
	var ground_data := source.get_tile_data(GROUND, 0)
	ground_data.set_custom_data("walkable", true)
	ground_data.set_custom_data("buildable", true)

	# Path: walkable, not buildable
	var path_data := source.get_tile_data(PATH, 0)
	path_data.set_custom_data("walkable", true)
	path_data.set_custom_data("buildable", false)

	# Wall: neither
	var wall_data := source.get_tile_data(WALL, 0)
	wall_data.set_custom_data("walkable", false)
	wall_data.set_custom_data("buildable", false)

	# 5. Assign TileSet to TileMapLayer
	tile_map.tile_set = tile_set

	# 6. Paint the map (maze-style: all interior is buildable ground)
	# Map legend:  W=wall  G=ground  S=spawn(path)  E=goal(path)
	#
	#  Row 0: W W W W W W W W W W W W W W
	#  Row 1: W G G G G G G G G G G G G W
	#  Row 2: W G G G G G G G G G G G G W
	#  Row 3: W G G G G G G G G G G G G W
	#  Row 4: S G G G G G G G G G G G G E
	#  Row 5: W G G G G G G G G G G G G W
	#  Row 6: W G G G G G G G G G G G G W
	#  Row 7: W G G G G G G G G G G G G W
	#  Row 8: W G G G G G G G G G G G G W
	#  Row 9: W W W W W W W W W W W W W W

	var spawn_tiles: Array[Vector2i] = []
	var goal_tiles: Array[Vector2i] = []

	for y in MAP_H:
		for x in MAP_W:
			var pos := Vector2i(x, y)
			var tile := GROUND

			# Walls: top/bottom rows, left/right columns
			if y == 0 or y == MAP_H - 1 or x == 0 or x == MAP_W - 1:
				tile = WALL

			# Spawn point (left edge, row 4) -- walkable, not buildable
			if y == 4 and x == 0:
				tile = PATH
				spawn_tiles.append(pos)

			# Goal point (right edge, row 4) -- walkable, not buildable
			if y == 4 and x == MAP_W - 1:
				tile = PATH
				goal_tiles.append(pos)

			tile_map.set_cell(pos, source_id, tile)

	return {"spawn_tiles": spawn_tiles, "goal_tiles": goal_tiles}


static func _draw_isometric_tile(img: Image, tile_index: int, top_color: Color, shade_color: Color) -> void:
	var ox := tile_index * TILE_W
	var cx := TILE_W / 2.0
	var cy := TILE_H / 2.0

	for y in TILE_H:
		for x in TILE_W:
			# Isometric diamond: |x - cx| / cx + |y - cy| / cy <= 1
			var dx := absf(x - cx + 0.5) / cx
			var dy := absf(y - cy + 0.5) / cy
			if dx + dy <= 1.0:
				var color := top_color if y <= int(cy) else shade_color
				# Add 1px outline for definition
				if dx + dy > 0.9:
					color = color.darkened(0.3)
				img.set_pixel(ox + x, y, color)
