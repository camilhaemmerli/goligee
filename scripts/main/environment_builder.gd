class_name EnvironmentBuilder
extends RefCounted
## Places environmental props (barricades, debris, graffiti, vehicles, etc.)
## across the playing field to sell the post-apocalyptic atmosphere.

const TILE_W := 64
const TILE_H := 32


static func build_environment(container: Node2D, tile_map: TileMapLayer) -> void:
	_place_rubble_on_walls(container, tile_map)
	_place_barricades(container, tile_map)
	_place_spawn_area_props(container, tile_map)
	_place_goal_area_props(container, tile_map)
	_place_graffiti(container, tile_map)
	_place_puddles(container, tile_map)
	_place_burned_vehicle(container, tile_map)
	_place_wire_coils(container, tile_map)
	_place_sandbags(container, tile_map)


static func _place_rubble_on_walls(container: Node2D, tile_map: TileMapLayer) -> void:
	# ~30% of wall tiles get rubble overlay
	var wall_positions: Array[Vector2i] = []
	for x in MapBuilder.MAP_W:
		wall_positions.append(Vector2i(x, 0))
		wall_positions.append(Vector2i(x, MapBuilder.MAP_H - 1))
	for y in range(1, MapBuilder.MAP_H - 1):
		wall_positions.append(Vector2i(0, y))
		wall_positions.append(Vector2i(MapBuilder.MAP_W - 1, y))

	for pos in wall_positions:
		var h := _tile_hash(pos.x, pos.y, 111)
		if h % 10 < 3:  # 30% chance
			var sprite := Sprite2D.new()
			sprite.texture = EnvironmentSprites.create_rubble(h)
			sprite.position = tile_map.map_to_local(pos) + Vector2(0, -2)
			sprite.z_index = 3
			container.add_child(sprite)


static func _place_barricades(container: Node2D, tile_map: TileMapLayer) -> void:
	# Jersey barriers along inner edges
	var positions := [
		Vector2i(3, 1), Vector2i(7, 1), Vector2i(11, 1),
		Vector2i(4, 8), Vector2i(8, 8), Vector2i(12, 8),
	]
	for pos in positions:
		var sprite := Sprite2D.new()
		sprite.texture = EnvironmentSprites.create_barricade()
		sprite.position = tile_map.map_to_local(pos) + Vector2(0, -4)
		sprite.z_index = 4
		container.add_child(sprite)


static func _place_spawn_area_props(container: Node2D, tile_map: TileMapLayer) -> void:
	# Near spawn (left side): scattered protest signs, burned tires

	# Overturned dumpster (reuse barricade but darker)
	var dumpster := Sprite2D.new()
	dumpster.texture = EnvironmentSprites.create_barricade()
	dumpster.modulate = Color(0.7, 0.7, 0.7, 1.0)
	dumpster.position = tile_map.map_to_local(Vector2i(1, 5)) + Vector2(4, -4)
	dumpster.z_index = 4
	dumpster.rotation_degrees = 12.0
	container.add_child(dumpster)

	# Rubble around spawn
	for i in range(3):
		var sprite := Sprite2D.new()
		sprite.texture = EnvironmentSprites.create_rubble(500 + i)
		var offset := Vector2(
			(i - 1) * 16.0,
			(i % 2) * 8.0 - 4.0
		)
		sprite.position = tile_map.map_to_local(Vector2i(1, 3 + i)) + offset
		sprite.z_index = 3
		container.add_child(sprite)


static func _place_goal_area_props(container: Node2D, tile_map: TileMapLayer) -> void:
	# Near goal (right side): flag poles, spotlight stands

	# Sandbag fortification near the government building
	var sb := Sprite2D.new()
	sb.texture = EnvironmentSprites.create_sandbag_stack()
	sb.position = tile_map.map_to_local(Vector2i(13, 3)) + Vector2(0, -4)
	sb.z_index = 4
	container.add_child(sb)

	var sb2 := Sprite2D.new()
	sb2.texture = EnvironmentSprites.create_sandbag_stack()
	sb2.position = tile_map.map_to_local(Vector2i(13, 5)) + Vector2(0, -4)
	sb2.z_index = 4
	container.add_child(sb2)


static func _place_graffiti(container: Node2D, tile_map: TileMapLayer) -> void:
	# Graffiti tags on wall tile surfaces
	var graffiti_positions := [
		Vector2i(2, 0), Vector2i(6, 0), Vector2i(10, 0), Vector2i(14, 0),
		Vector2i(3, 9), Vector2i(9, 9), Vector2i(13, 9),
	]
	for i in graffiti_positions.size():
		var pos: Vector2i = graffiti_positions[i]
		var sprite := Sprite2D.new()
		sprite.texture = EnvironmentSprites.create_graffiti_tag(i * 7 + 13)
		sprite.position = tile_map.map_to_local(pos) + Vector2(0, -1)
		sprite.z_index = 2
		container.add_child(sprite)


static func _place_puddles(container: Node2D, tile_map: TileMapLayer) -> void:
	# Dark reflective puddles on ground tiles
	var puddle_positions := [
		Vector2i(3, 3), Vector2i(6, 5), Vector2i(9, 7),
		Vector2i(5, 2), Vector2i(10, 4), Vector2i(7, 6),
	]
	for pos in puddle_positions:
		var sprite := Sprite2D.new()
		sprite.texture = EnvironmentSprites.create_puddle()
		sprite.position = tile_map.map_to_local(pos) + Vector2(0, 2)
		sprite.z_index = 1
		container.add_child(sprite)


static func _place_burned_vehicle(container: Node2D, tile_map: TileMapLayer) -> void:
	# Burned-out vehicle skeleton near mid-map
	var sprite := Sprite2D.new()
	sprite.texture = EnvironmentSprites.create_burned_vehicle()
	sprite.position = tile_map.map_to_local(Vector2i(4, 6)) + Vector2(0, -8)
	sprite.z_index = 5
	container.add_child(sprite)


static func _place_wire_coils(container: Node2D, tile_map: TileMapLayer) -> void:
	# Concertina wire along edges
	var wire_positions := [
		Vector2i(2, 1), Vector2i(5, 1), Vector2i(9, 1),
		Vector2i(6, 8), Vector2i(10, 8),
	]
	for pos in wire_positions:
		var sprite := Sprite2D.new()
		sprite.texture = EnvironmentSprites.create_wire_coil()
		sprite.position = tile_map.map_to_local(pos) + Vector2(0, -2)
		sprite.z_index = 3
		container.add_child(sprite)


static func _place_sandbags(container: Node2D, tile_map: TileMapLayer) -> void:
	# Scattered sandbag stacks
	var positions := [
		Vector2i(2, 2), Vector2i(11, 7),
	]
	for pos in positions:
		var sprite := Sprite2D.new()
		sprite.texture = EnvironmentSprites.create_sandbag_stack()
		sprite.position = tile_map.map_to_local(pos) + Vector2(0, -4)
		sprite.z_index = 4
		container.add_child(sprite)


static func _tile_hash(x: int, y: int, seed_val: int) -> int:
	var v := (x * 73856093 + y * 19349663 + seed_val) & 0xFFFFFF
	return absi(v)
