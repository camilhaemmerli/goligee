class_name StructureBuilder
extends RefCounted
## Places procedurally generated isometric building sprites at specific tile
## positions around the playing field to frame the scene.

const TILE_W := 64
const TILE_H := 32


static func build_structures(container: Node2D, tile_map: TileMapLayer) -> void:
	_place_government_building(container, tile_map)
	_place_guard_booth(container, tile_map)
	_place_apartment_blocks(container, tile_map)
	_place_wall_segments(container, tile_map)


static func _place_government_building(container: Node2D, tile_map: TileMapLayer) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = BuildingSprites.create_government_building()
	# Place at right side of map, centered on path row
	var pos := tile_map.map_to_local(Vector2i(14, 4))
	sprite.position = pos + Vector2(24, -56)  # Offset up so building rises above tiles
	sprite.z_index = 5
	sprite.name = "GovernmentBuilding"
	container.add_child(sprite)


static func _place_guard_booth(container: Node2D, tile_map: TileMapLayer) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = BuildingSprites.create_guard_booth()
	# Place near left spawn
	var pos := tile_map.map_to_local(Vector2i(0, 3))
	sprite.position = pos + Vector2(-8, -16)
	sprite.z_index = 4
	sprite.name = "GuardBooth"
	container.add_child(sprite)


static func _place_apartment_blocks(container: Node2D, tile_map: TileMapLayer) -> void:
	# Left apartment block (back-left corner)
	var left := Sprite2D.new()
	left.texture = BuildingSprites.create_apartment_block()
	var left_pos := tile_map.map_to_local(Vector2i(1, 0))
	left.position = left_pos + Vector2(0, -36)
	left.z_index = 2
	left.name = "ApartmentBlock_L"
	container.add_child(left)

	# Right apartment block (back-right corner)
	var right := Sprite2D.new()
	right.texture = BuildingSprites.create_apartment_block()
	var right_pos := tile_map.map_to_local(Vector2i(13, 0))
	right.position = right_pos + Vector2(0, -36)
	right.z_index = 2
	right.name = "ApartmentBlock_R"
	container.add_child(right)


static func _place_wall_segments(container: Node2D, tile_map: TileMapLayer) -> void:
	var wall_tex := BuildingSprites.create_wall_segment()

	# Top edge wall segments (row 0, scattered positions)
	for x in [3, 5, 7, 9, 11]:
		var sprite := Sprite2D.new()
		sprite.texture = wall_tex
		var pos := tile_map.map_to_local(Vector2i(x, 0))
		sprite.position = pos + Vector2(0, -10)
		sprite.z_index = 1
		sprite.name = "WallSeg_Top_%d" % x
		container.add_child(sprite)

	# Bottom edge wall segments (row 9, scattered positions)
	for x in [4, 6, 8, 10, 12]:
		var sprite := Sprite2D.new()
		sprite.texture = wall_tex
		var pos := tile_map.map_to_local(Vector2i(x, 9))
		sprite.position = pos + Vector2(0, -10)
		sprite.z_index = 1
		sprite.name = "WallSeg_Bot_%d" % x
		container.add_child(sprite)
