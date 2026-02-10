class_name TowerPlacer
extends Node2D
## Handles tower placement on the isometric grid.
## Attach to the main game scene. Listens for build_mode signals.

@export var tile_map: TileMapLayer
@export var tower_container: Node2D

var _placing: bool = false
var _current_tower_data: TowerData
var _ghost: Node2D  ## Preview container snapped to tile
var _ghost_base: Sprite2D
var _ghost_turret: Sprite2D
var _tile_highlight: Polygon2D
var _tile_outline: Line2D
var _ghost_tile: Vector2i
var _ghost_valid: bool = false


func _ready() -> void:
	SignalBus.build_mode_entered.connect(_on_build_mode_entered)
	SignalBus.build_mode_exited.connect(_on_build_mode_exited)


func _on_build_mode_entered(tower_data: TowerData) -> void:
	_placing = true
	_current_tower_data = tower_data

	_ghost = Node2D.new()
	_ghost.z_index = 50  # Above all game objects
	_ghost.z_as_relative = false
	add_child(_ghost)

	# Tile diamond highlight (on ground, below tower sprites)
	var hw := 32.0
	var hh := 16.0
	var diamond_pts := PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0),
	])
	_tile_highlight = Polygon2D.new()
	_tile_highlight.polygon = diamond_pts
	_tile_highlight.color = Color("#40A0D8A0")
	_ghost.add_child(_tile_highlight)

	_tile_outline = Line2D.new()
	_tile_outline.points = PackedVector2Array([
		diamond_pts[0], diamond_pts[1], diamond_pts[2], diamond_pts[3], diamond_pts[0],
	])
	_tile_outline.width = 1.0
	_tile_outline.default_color = Color("#80A0D8A0")
	_ghost.add_child(_tile_outline)

	# Base sprite (above highlight)
	_ghost_base = Sprite2D.new()
	_ghost_base.modulate = Color(1, 1, 1, 0.45)
	_ghost_base.z_index = 1
	var skin: TowerSkinData = ThemeManager.get_tower_skin(tower_data.tower_id) if tower_data.tower_id else null
	if skin and skin.base_texture:
		_ghost_base.texture = skin.base_texture
		_ghost_base.offset.y = -16
		# Turret sprite (above base)
		_ghost_turret = Sprite2D.new()
		_ghost_turret.modulate = Color(1, 1, 1, 0.45)
		if skin.turret_textures.size() > 0:
			_ghost_turret.texture = skin.turret_textures[7]  # SE default
		_ghost_turret.position.y = skin.turret_y_offset
		_ghost_turret.z_index = 2
		_ghost.add_child(_ghost_turret)
	else:
		var icon := tower_data.get_icon()
		if icon:
			_ghost_base.texture = icon
		else:
			_ghost_base.texture = PlaceholderSprites.create_diamond(20, Color("#90A0B8"))
	_ghost.add_child(_ghost_base)


func _on_build_mode_exited() -> void:
	_placing = false
	_current_tower_data = null
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_ghost_base = null
	_ghost_turret = null
	_tile_highlight = null
	_tile_outline = null


func _unhandled_input(event: InputEvent) -> void:
	if not _placing:
		if event.is_action_pressed("select"):
			_try_select(get_global_mouse_position())
		return

	if event is InputEventMouseMotion and _ghost and tile_map:
		var mouse_pos := get_global_mouse_position()
		var tile_pos := tile_map.local_to_map(tile_map.to_local(mouse_pos))
		_ghost_tile = tile_pos
		_ghost.global_position = tile_map.to_global(tile_map.map_to_local(tile_pos))
		_ghost_valid = _is_tile_buildable(tile_pos)
		if _tile_highlight:
			_tile_highlight.color = Color("#40A0D8A0") if _ghost_valid else Color("#40D04040")
		if _tile_outline:
			_tile_outline.default_color = Color("#80A0D8A0") if _ghost_valid else Color("#80D04040")

	if event.is_action_pressed("select"):
		_try_place(get_global_mouse_position())

	if event.is_action_pressed("cancel"):
		SignalBus.build_mode_exited.emit()



func _is_tile_buildable(tile_pos: Vector2i) -> bool:
	if not tile_map:
		return false
	var td := tile_map.get_cell_tile_data(tile_pos)
	if not td:
		return false
	var buildable: bool = td.get_custom_data("buildable") if td.get_custom_data("buildable") != null else false
	if not buildable:
		return false
	for tower in tower_container.get_children():
		if tower is BaseTower and tower._tile_pos == tile_pos:
			return false
	return true


func _try_place(world_pos: Vector2) -> void:
	if not tile_map or not _current_tower_data:
		return

	var tile_pos := tile_map.local_to_map(tile_map.to_local(world_pos))

	# Check if tile is buildable
	var tile_data := tile_map.get_cell_tile_data(tile_pos)
	if not tile_data:
		return

	var is_buildable: bool = tile_data.get_custom_data("buildable") if tile_data.get_custom_data("buildable") != null else false
	if not is_buildable:
		return

	# Check if already occupied
	for tower in tower_container.get_children():
		if tower is BaseTower and tower._tile_pos == tile_pos:
			return

	# Check pathfinding -- placement must not block all enemy paths
	if not PathfindingManager.can_place_tower(tile_pos):
		SignalBus.path_blocked.emit()
		return

	# Check cost
	if not EconomyManager.spend_gold(_current_tower_data.build_cost):
		return

	# Place the tower
	var tower_scene := _current_tower_data.scene
	if not tower_scene:
		return

	var tower: BaseTower = tower_scene.instantiate()
	tower.tower_data = _current_tower_data
	tower._tile_pos = tile_pos
	tower.global_position = tile_map.to_global(tile_map.map_to_local(tile_pos))
	tower_container.add_child(tower)

	PathfindingManager.place_tower(tile_pos)
	SignalBus.tower_placed.emit(tower, tile_pos)
	SignalBus.build_mode_exited.emit()


func _try_select(world_pos: Vector2) -> void:
	if not tile_map or not tower_container:
		return

	var tile_pos := tile_map.local_to_map(tile_map.to_local(world_pos))

	for tower in tower_container.get_children():
		if tower is BaseTower and tower._tile_pos == tile_pos:
			SignalBus.tower_selected.emit(tower)
			return

	SignalBus.tower_deselected.emit()
