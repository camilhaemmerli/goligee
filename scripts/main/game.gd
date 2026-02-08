extends Node2D
## Main game scene controller. Wires up spawning, pathfinding, and the
## connection between WaveManager and the game world.

@export var spawn_tiles: Array[Vector2i] = []
@export var goal_tiles: Array[Vector2i] = []

@onready var tile_map: TileMapLayer = $World/TileMapLayer
@onready var tower_container: Node2D = $World/Towers
@onready var enemy_container: Node2D = $World/Enemies
@onready var projectile_container: Node2D = $World/Projectiles
@onready var tower_placer: TowerPlacer = $TowerPlacer


func _ready() -> void:
	# Set up groups for lookups
	projectile_container.add_to_group("projectiles")

	# Initialize pathfinding
	PathfindingManager.initialize(tile_map, spawn_tiles, goal_tiles)

	# Connect wave manager spawn signal
	WaveManager.spawn_enemy_requested.connect(_on_spawn_enemy)

	# Wire up tower placer
	tower_placer.tile_map = tile_map
	tower_placer.tower_container = tower_container

	# Apply theme shader params
	_apply_theme_shaders()
	ThemeManager.theme_changed.connect(_apply_theme_shaders)

	# Start the game
	GameManager.start_game()
	WaveManager.start_waves()


func _apply_theme_shaders() -> void:
	var palette = ThemeManager.get_palette()
	if not palette:
		return

	# Apply fog colors
	var fog_rect := get_node_or_null("FogLayer/FogRect")
	if fog_rect and fog_rect.material is ShaderMaterial:
		ThemeManager.apply_shader_params(fog_rect.material, "fog")

	# Apply atmosphere colors
	ThemeManager.apply_clear_color()


func _on_spawn_enemy(enemy_data: EnemyData, spawn_point_index: int, modifiers: Dictionary) -> void:
	if not enemy_data or not enemy_data.scene:
		return

	if spawn_tiles.is_empty():
		return

	var enemy: BaseEnemy = enemy_data.scene.instantiate()
	enemy.enemy_data = enemy_data
	enemy.apply_wave_modifiers(modifiers)
	enemy.add_to_group("enemies")

	enemy_container.add_child(enemy)
	enemy.setup_path(spawn_point_index % spawn_tiles.size())
	SignalBus.enemy_spawned.emit(enemy)
