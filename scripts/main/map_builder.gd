class_name MapBuilder
extends RefCounted
## Programmatically builds a TileSet and paints a 16x10 isometric map at runtime.
## Called from game.gd before PathfindingManager init.

const TILE_W := 64
const TILE_H := 32
const MAP_W := 16
const MAP_H := 10

# Atlas tile IDs — expanded with variants
const GROUND := Vector2i(0, 0)
const GROUND_B := Vector2i(1, 0)
const GROUND_C := Vector2i(2, 0)
const PATH := Vector2i(3, 0)
const PATH_WORN := Vector2i(4, 0)
const WALL := Vector2i(5, 0)
const WALL_RUBBLE := Vector2i(6, 0)

const TILE_COUNT := 7
const NOISE_STRENGTH := 0.0  # disabled for clean, flat tiles
const EDGE_THICKNESS_PX := 1.0
const EDGE_DARKEN := 0.2

# 3-face isometric colors per tile type
# [top_face, left_face, right_face]
const GROUND_FACES := [Color("#585860"), Color("#28282C"), Color("#3A3A3E")]
const PATH_FACES := [Color("#C8A040"), Color("#9A7830"), Color("#B09038")]
const WALL_FACES := [Color("#28282C"), Color("#1E1E22"), Color("#242428")]


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

	# 2. Generate atlas image (TILE_COUNT tiles wide, 1 tile tall)
	var atlas_img := Image.create(TILE_W * TILE_COUNT, TILE_H, false, Image.FORMAT_RGBA8)
	_draw_isometric_tile(atlas_img, 0, GROUND_FACES, 0)     # GROUND
	_draw_isometric_tile(atlas_img, 1, GROUND_FACES, 101)    # GROUND_B
	_draw_isometric_tile(atlas_img, 2, GROUND_FACES, 202)    # GROUND_C
	_draw_isometric_tile(atlas_img, 3, PATH_FACES, 303)      # PATH
	_draw_isometric_tile(atlas_img, 4, PATH_FACES, 404)      # PATH_WORN
	_draw_isometric_tile(atlas_img, 5, WALL_FACES, 505)      # WALL
	_draw_isometric_tile(atlas_img, 6, WALL_FACES, 606)      # WALL_RUBBLE (with cracks)

	var atlas_tex := ImageTexture.create_from_image(atlas_img)

	# 3. Create TileSetAtlasSource
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(TILE_W, TILE_H)

	# Create all atlas tiles
	for i in TILE_COUNT:
		source.create_tile(Vector2i(i, 0))

	var source_id := tile_set.add_source(source)

	# 4. Set custom data on tiles
	# Ground variants: walkable + buildable
	for tid in [GROUND, GROUND_B, GROUND_C]:
		var data := source.get_tile_data(tid, 0)
		data.set_custom_data("walkable", true)
		data.set_custom_data("buildable", true)

	# Path variants: walkable, not buildable
	for tid in [PATH, PATH_WORN]:
		var data := source.get_tile_data(tid, 0)
		data.set_custom_data("walkable", true)
		data.set_custom_data("buildable", false)

	# Wall variants: neither
	for tid in [WALL, WALL_RUBBLE]:
		var data := source.get_tile_data(tid, 0)
		data.set_custom_data("walkable", false)
		data.set_custom_data("buildable", false)

	# 5. Assign TileSet to TileMapLayer
	tile_map.tile_set = tile_set

	# 6. Paint the map
	var spawn_tiles: Array[Vector2i] = []
	var goal_tiles: Array[Vector2i] = []

	var ground_variants := [GROUND, GROUND_B, GROUND_C]
	var wall_variants := [WALL, WALL, WALL, WALL_RUBBLE]  # 25% rubble chance

	# Build a set of path tile positions (zigzag route from spawn to goal)
	var path_tiles: Dictionary = {}  # Vector2i -> true
	# Spawn(0,4) → east to (4,4)
	for x in range(0, 5):
		path_tiles[Vector2i(x, 4)] = true
	# North to (4,2)
	for y in range(2, 4):
		path_tiles[Vector2i(4, y)] = true
	# East to (8,2)
	for x in range(5, 9):
		path_tiles[Vector2i(x, 2)] = true
	# South to (8,6)
	for y in range(3, 7):
		path_tiles[Vector2i(8, y)] = true
	# East to (12,6)
	for x in range(9, 13):
		path_tiles[Vector2i(x, 6)] = true
	# North to (12,4)
	for y in range(4, 6):
		path_tiles[Vector2i(12, y)] = true
	# East to goal (15,4)
	for x in range(13, 16):
		path_tiles[Vector2i(x, 4)] = true

	for y in MAP_H:
		for x in MAP_W:
			var pos := Vector2i(x, y)
			var tile := GROUND

			# Walls: top/bottom rows, left/right columns (skip path at edges)
			if (y == 0 or y == MAP_H - 1 or x == 0 or x == MAP_W - 1) and not path_tiles.has(pos):
				var hash_val := _tile_hash(x, y, 77)
				tile = wall_variants[hash_val % wall_variants.size()]

			# Path tiles: alternate between PATH and PATH_WORN for visual variety
			elif path_tiles.has(pos):
				var hash_val := _tile_hash(x, y, 55)
				tile = PATH_WORN if hash_val % 3 == 0 else PATH

			# Ground: random variant based on position
			elif tile == GROUND:
				var hash_val := _tile_hash(x, y, 42)
				tile = ground_variants[hash_val % ground_variants.size()]

			# Spawn point (left edge, row 4)
			if y == 4 and x == 0:
				spawn_tiles.append(pos)

			# Goal point (right edge, row 4)
			if y == 4 and x == MAP_W - 1:
				goal_tiles.append(pos)

			tile_map.set_cell(pos, source_id, tile)

	return {"spawn_tiles": spawn_tiles, "goal_tiles": goal_tiles}


static func _draw_isometric_tile(img: Image, tile_index: int, face_colors: Array, noise_seed: int) -> void:
	var ox := tile_index * TILE_W
	var cx := TILE_W / 2.0
	var cy := TILE_H / 2.0
	var base_color: Color = face_colors[0]
	var min_axis: float = minf(cx, cy)
	var edge_threshold: float = 1.0 - (EDGE_THICKNESS_PX / min_axis)

	for y in TILE_H:
		for x in TILE_W:
			var dx := absf(x - cx + 0.5) / cx
			var dy := absf(y - cy + 0.5) / cy
			if dx + dy > 1.0:
				continue

			# Flat tile fill (no faceted triangles)
			var color: Color = base_color

			# Surface noise disabled for simple, clean tiles.
			var brightness_offset := 0.0
			color = Color(
				clampf(color.r + brightness_offset, 0.0, 1.0),
				clampf(color.g + brightness_offset, 0.0, 1.0),
				clampf(color.b + brightness_offset, 0.0, 1.0),
				1.0
			)

			# Thin edge lines between diamonds.
			if dx + dy > edge_threshold:
				color = color.darkened(EDGE_DARKEN)

			img.set_pixel(ox + x, y, color)


static func _is_crack_pixel(x: int, y: int, seed_val: int) -> bool:
	# Deterministic crack lines — thin diagonal lines at specific positions
	var h := _pixel_hash(seed_val + 999, x, y)
	# Only ~3% of pixels are cracks
	if h % 33 != 0:
		return false
	# Cracks tend to follow diagonal patterns
	var diag := (x + y * 2) % 7
	return diag < 2


static func _pixel_hash(seed_val: int, x: int, y: int) -> int:
	# Deterministic hash for per-pixel variation with better mixing
	var h := seed_val
	h ^= x * 0x27d4eb2d
	h ^= y * 0x165667b1
	h = (h ^ (h >> 15)) * 0x85ebca6b
	h = (h ^ (h >> 13)) * 0xc2b2ae35
	h = h ^ (h >> 16)
	return absi(h)


static func _tile_hash(x: int, y: int, seed_val: int) -> int:
	var v := (x * 73856093 + y * 19349663 + seed_val) & 0xFFFFFF
	return absi(v)
