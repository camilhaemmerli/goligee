class_name TowerPlacer
extends Node2D
## Handles tower placement on the isometric grid.
## Attach to the main game scene. Listens for build_mode signals.

@export var tile_map: TileMapLayer
@export var tower_container: Node2D

var _placing: bool = false
var _current_tower_data: TowerData
var _ghost: Sprite2D  ## Preview sprite following mouse


func _ready() -> void:
	SignalBus.build_mode_entered.connect(_on_build_mode_entered)
	SignalBus.build_mode_exited.connect(_on_build_mode_exited)


func _on_build_mode_entered(tower_data: TowerData) -> void:
	_placing = true
	_current_tower_data = tower_data

	# Create ghost preview
	_ghost = Sprite2D.new()
	if tower_data.icon:
		_ghost.texture = tower_data.icon
	else:
		_ghost.texture = PlaceholderSprites.create_diamond(20, Color("#90A0B8"))
	_ghost.modulate = Color(1, 1, 1, 0.5)
	add_child(_ghost)


func _on_build_mode_exited() -> void:
	_placing = false
	_current_tower_data = null
	if _ghost:
		_ghost.queue_free()
		_ghost = null


func _unhandled_input(event: InputEvent) -> void:
	if not _placing:
		# Click-to-select placed towers when not in build mode
		if event.is_action_pressed("select"):
			_try_select(get_global_mouse_position())
		return

	if event is InputEventMouseMotion and _ghost:
		_ghost.global_position = get_global_mouse_position()

	if event.is_action_pressed("select"):
		_try_place(get_global_mouse_position())

	if event.is_action_pressed("cancel"):
		SignalBus.build_mode_exited.emit()


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
