extends Node2D
## Main game scene controller. Wires up spawning, paths, and the
## connection between WaveManager and the game world.

@onready var tile_map: TileMapLayer = $World/TileMapLayer
@onready var tower_container: Node2D = $World/Towers
@onready var enemy_container: Node2D = $World/Enemies
@onready var projectile_container: Node2D = $World/Projectiles
@onready var paths: Node2D = $World/Paths
@onready var tower_placer: TowerPlacer = $TowerPlacer

var _spawn_points: Array[PathFollow2D] = []


func _ready() -> void:
	# Set up groups for lookups
	projectile_container.add_to_group("projectiles")

	# Connect wave manager spawn signal
	WaveManager.spawn_enemy_requested.connect(_on_spawn_enemy)

	# Collect path spawn points
	for path_node in paths.get_children():
		if path_node is Path2D:
			_spawn_points.append(path_node)

	# Wire up tower placer
	tower_placer.tile_map = tile_map
	tower_placer.tower_container = tower_container

	# Start the game
	GameManager.start_game()
	WaveManager.start_waves()


func _on_spawn_enemy(enemy_data: EnemyData, spawn_point_index: int, modifiers: Dictionary) -> void:
	if not enemy_data or not enemy_data.scene:
		return

	var path_node: Path2D = _spawn_points[spawn_point_index % _spawn_points.size()] if not _spawn_points.is_empty() else null
	if not path_node:
		return

	var enemy: BaseEnemy = enemy_data.scene.instantiate()
	enemy.enemy_data = enemy_data
	enemy.apply_wave_modifiers(modifiers)
	enemy.add_to_group("enemies")

	path_node.add_child(enemy)
	SignalBus.enemy_spawned.emit(enemy)
