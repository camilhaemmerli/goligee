class_name MapBuilder
extends RefCounted
## Programmatically builds a TileSet and paints an isometric map at runtime.
## Called from game.gd before PathfindingManager init.

const TILE_W = 64
const TILE_H = 32
const MAP_W = 24
const MAP_H = 14
const BORDER = 12  # extended ground tiles around the playable area

# Atlas tile IDs — 5 functional types, 3 visuals
const GROUND_A = Vector2i(0, 0)   # walkable + buildable
const GROUND_B = Vector2i(1, 0)   # walkable + buildable
const GROUND_C = Vector2i(2, 0)   # walkable + buildable
const NOBUILD  := Vector2i(3, 0)   # walkable + NOT buildable (path / obstacles)
const WALL     := Vector2i(4, 0)   # NOT walkable + NOT buildable (border)

const TILE_COUNT = 5

# Map atlas index → generated PNG filename. Slots 3,4 reuse ground visuals.
const TILE_NAMES = [
	"concrete_a", "concrete_b", "concrete_c",
	"concrete_a", "concrete_b",
]

# Procedural fallback colors (all concrete grey, subtle variation)
const CONCRETE_A = [Color("#4A4A52"), Color("#28282C"), Color("#3A3A3E")]
const CONCRETE_B = [Color("#505058"), Color("#2C2C30"), Color("#3E3E42")]
const CONCRETE_C = [Color("#464650"), Color("#26262A"), Color("#38383C")]

const EDGE_THICKNESS_PX = 1.0
const EDGE_DARKEN = 0.15


static func build_map(tile_map: TileMapLayer) -> Dictionary:
	# 1. Create TileSet
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = Vector2i(TILE_W, TILE_H)

	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "buildable")
	tile_set.set_custom_data_layer_type(0, TYPE_BOOL)

	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(1, "walkable")
	tile_set.set_custom_data_layer_type(1, TYPE_BOOL)

	# 2. Generate atlas image
	var atlas_img := Image.create(TILE_W * TILE_COUNT, TILE_H, false, Image.FORMAT_RGBA8)
	var _fallback := [
		[CONCRETE_A, 0],
		[CONCRETE_B, 101],
		[CONCRETE_C, 202],
		[CONCRETE_A, 303],
		[CONCRETE_B, 404],
	]
	for i in TILE_COUNT:
		if not _try_load_tile(atlas_img, i, TILE_NAMES[i]):
			_draw_isometric_tile(atlas_img, i, _fallback[i][0], _fallback[i][1])

	var atlas_tex := ImageTexture.create_from_image(atlas_img)

	# 3. Create TileSetAtlasSource
	var source := TileSetAtlasSource.new()
	source.texture = atlas_tex
	source.texture_region_size = Vector2i(TILE_W, TILE_H)

	for i in TILE_COUNT:
		source.create_tile(Vector2i(i, 0))

	var source_id := tile_set.add_source(source)

	# 4. Custom data per tile type
	for tid in [GROUND_A, GROUND_B, GROUND_C]:
		var data := source.get_tile_data(tid, 0)
		data.set_custom_data("walkable", true)
		data.set_custom_data("buildable", true)

	var nobuild_data := source.get_tile_data(NOBUILD, 0)
	nobuild_data.set_custom_data("walkable", true)
	nobuild_data.set_custom_data("buildable", false)

	var wall_data := source.get_tile_data(WALL, 0)
	wall_data.set_custom_data("walkable", false)
	wall_data.set_custom_data("buildable", false)

	# 5. Assign TileSet
	tile_map.tile_set = tile_set

	# 6. Paint the map — open grid, no predefined path.
	# Players build towers freely; A* finds the enemy route dynamically.
	# Only rule: at least one path from spawn to goal must remain open.
	var spawn_tiles: Array[Vector2i] = []
	var goal_tiles: Array[Vector2i] = []
	var obstacle_tiles: Dictionary = {}  # Vector2i → true
	var ground_variants := [GROUND_A, GROUND_B, GROUND_C]

	for y in MAP_H:
		for x in MAP_W:
			var pos := Vector2i(x, y)
			var tile: Vector2i
			var hash_val := _tile_hash(x, y, 42)
			var is_border := y == 0 or y == MAP_H - 1 or x == 0 or x == MAP_W - 1
			var is_spawn := (x == 0 and y == 6)
			var is_goal := (x == MAP_W - 1 and y == 8)

			if is_spawn or is_goal:
				tile = NOBUILD  # walkable opening, not buildable
			elif is_border:
				tile = WALL
			else:
				# ~14% of interior tiles become NOBUILD obstacles
				var obs_hash := _tile_hash(x, y, 777)
				if obs_hash % 100 < 14:
					tile = NOBUILD
					obstacle_tiles[pos] = true
				else:
					tile = ground_variants[hash_val % ground_variants.size()]

			if is_spawn:
				spawn_tiles.append(pos)
			if is_goal:
				goal_tiles.append(pos)

			tile_map.set_cell(pos, source_id, tile)

	return {
		"spawn_tiles": spawn_tiles,
		"goal_tiles": goal_tiles,
		"obstacle_tiles": obstacle_tiles,
		"source_id": source_id,
	}


static func _try_load_tile(atlas_img: Image, tile_index: int, tile_name: String) -> bool:
	var path := "res://assets/sprites/tiles/tile_%s.png" % tile_name
	if not ResourceLoader.exists(path):
		return false
	var tex := load(path) as Texture2D
	if tex == null:
		return false
	var tile_img := tex.get_image()
	if tile_img == null:
		return false
	if tile_img.get_format() != Image.FORMAT_RGBA8:
		tile_img.convert(Image.FORMAT_RGBA8)
	var dst_x := tile_index * TILE_W
	var src_rect := Rect2i(0, 0, mini(tile_img.get_width(), TILE_W), mini(tile_img.get_height(), TILE_H))
	atlas_img.blit_rect(tile_img, src_rect, Vector2i(dst_x, 0))
	return true


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
			var color: Color = base_color
			if dx + dy > edge_threshold:
				color = color.darkened(EDGE_DARKEN)
			img.set_pixel(ox + x, y, color)


static func _tile_hash(x: int, y: int, seed_val: int) -> int:
	var v := (x * 73856093 + y * 19349663 + seed_val) & 0xFFFFFF
	return absi(v)
