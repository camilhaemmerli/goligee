extends Node2D
## Main game scene controller. Wires up spawning, pathfinding, and the
## connection between WaveManager and the game world.

@export var spawn_tiles: Array[Vector2i] = []
@export var goal_tiles: Array[Vector2i] = []

@onready var tile_map: TileMapLayer = $World/TileMapLayer
@onready var tower_container: Node2D = $World/Towers
@onready var enemy_container: Node2D = $World/Enemies
@onready var projectile_container: Node2D = $World/Projectiles
@onready var effects_container: Node2D = $World/Effects
@onready var tower_placer: TowerPlacer = $TowerPlacer
@onready var tower_menu: TowerMenu = $HUD/TowerMenu

var _camera: Camera2D
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _camera_origin: Vector2

var _stats := {
	"total_damage": 0.0,
	"total_kills": 0,
	"peak_dps": 0.0,
	"waves_survived": 0,
	"zero_tolerance_waves": 0,
	"time_played": 0.0,
	"leaking_enemies": [],
}
var _dps_window: Array[float] = []
var _dps_timer: float = 0.0


func _ready() -> void:
	# Set up groups for lookups
	projectile_container.add_to_group("projectiles")

	# Build the map programmatically and get spawn/goal tiles
	var map_result := MapBuilder.build_map(tile_map)
	spawn_tiles = map_result["spawn_tiles"]
	goal_tiles = map_result["goal_tiles"]

	# Center camera on the map
	var center_tile := Vector2i(MapBuilder.MAP_W / 2, MapBuilder.MAP_H / 2)
	_camera = Camera2D.new()
	_set_camera_pos(tile_map.map_to_local(center_tile))
	_camera.zoom = Vector2(1.0, 1.0)
	_camera_origin = _camera.position
	add_child(_camera)

	# Initialize pathfinding
	PathfindingManager.initialize(tile_map, spawn_tiles, goal_tiles)

	# Load and assign wave data
	WaveManager.waves = [
		load("res://data/waves/wave_01.tres") as WaveData,
		load("res://data/waves/wave_02.tres") as WaveData,
		load("res://data/waves/wave_03.tres") as WaveData,
		load("res://data/waves/wave_04.tres") as WaveData,
		load("res://data/waves/wave_05.tres") as WaveData,
		load("res://data/waves/wave_06.tres") as WaveData,
		load("res://data/waves/wave_07.tres") as WaveData,
		load("res://data/waves/wave_08.tres") as WaveData,
		load("res://data/waves/wave_09.tres") as WaveData,
		load("res://data/waves/wave_10.tres") as WaveData,
	]

	# Load and assign tower data to the build menu
	tower_menu.tower_list = [
		load("res://data/towers/arrow_tower.tres") as TowerData,       # 50
		load("res://data/towers/ice_tower.tres") as TowerData,          # 75
		load("res://data/towers/cannon_tower.tres") as TowerData,       # 100
		load("res://data/towers/lrad_cannon.tres") as TowerData,        # 150
		load("res://data/towers/taser_grid.tres") as TowerData,         # 175
		load("res://data/towers/pepper_spray.tres") as TowerData,       # 175
		load("res://data/towers/microwave_emitter.tres") as TowerData,  # 225
		load("res://data/towers/surveillance_hub.tres") as TowerData,   # 250
	]

	# Apply theme and auto-wire tower skins if asset sprites exist
	var theme := load("res://data/themes/riot_control/theme.tres") as ThemeData
	if theme:
		ThemeManager.populate_tower_skins_from_assets(theme, tower_menu.tower_list)
		ThemeManager.apply_theme(theme)

	tower_menu._build_buttons()

	# Connect wave manager spawn signal
	WaveManager.spawn_enemy_requested.connect(_on_spawn_enemy)

	# Wire up tower placer
	tower_placer.tile_map = tile_map
	tower_placer.tower_container = tower_container

	# Camera shake on enemy kills
	SignalBus.enemy_killed.connect(_on_enemy_killed_shake)

	SignalBus.enemy_damaged.connect(_on_enemy_damaged_stats)
	SignalBus.enemy_killed.connect(_on_enemy_killed_stats)
	SignalBus.enemy_reached_end.connect(_on_enemy_leaked_stats)
	SignalBus.wave_completed.connect(_on_wave_completed_stats)

	# Restart handler
	SignalBus.restart_requested.connect(_on_restart)

	# Start the game
	GameManager.start_game()
	WaveManager.start_waves()


func _process(delta: float) -> void:
	_stats["time_played"] += delta
	_dps_timer += delta
	if _dps_timer >= 1.0:
		_dps_timer -= 1.0
		var window_sum := 0.0
		for d in _dps_window:
			window_sum += d
		if window_sum > _stats["peak_dps"]:
			_stats["peak_dps"] = window_sum
		_dps_window.clear()

	# Camera shake update
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var shake_amount := _shake_intensity * (_shake_timer / _shake_duration)
		_set_camera_pos(_camera_origin + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount),
		))
		if _shake_timer <= 0.0:
			_set_camera_pos(_camera_origin)


func _shake_camera(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration


func _set_camera_pos(pos: Vector2) -> void:
	if not _camera:
		return
	# Snap to integer pixels to avoid subpixel sampling artifacts.
	_camera.position = pos.round()


func _on_restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _on_enemy_killed_shake(enemy: Node2D, _gold: int) -> void:
	if enemy is BaseEnemy and enemy.enemy_data:
		if enemy.enemy_data.max_hp >= 500.0:
			_shake_camera(4.0, 0.15)
		elif enemy.enemy_data.max_hp >= 200.0:
			_shake_camera(2.5, 0.1)
		else:
			_shake_camera(1.5, 0.08)
	else:
		_shake_camera(1.5, 0.08)


func _on_spawn_enemy(enemy_data: EnemyData, spawn_point_index: int, modifiers: Dictionary) -> void:
	if not enemy_data or not enemy_data.scene:
		return

	if spawn_tiles.is_empty():
		return

	var enemy: BaseEnemy = enemy_data.scene.instantiate()
	enemy.enemy_data = enemy_data
	enemy.add_to_group("enemies")

	enemy_container.add_child(enemy)
	# Apply modifiers AFTER add_child so _ready()/_init_from_data() has run first
	enemy.apply_wave_modifiers(modifiers)
	enemy.setup_path(spawn_point_index % spawn_tiles.size())
	SignalBus.enemy_spawned.emit(enemy)


func _on_enemy_damaged_stats(_enemy: Node2D, amount: float, _dtype: Enums.DamageType) -> void:
	_stats["total_damage"] += amount
	_dps_window.append(amount)


func _on_enemy_killed_stats(_enemy: Node2D, _gold: int) -> void:
	_stats["total_kills"] += 1


func _on_enemy_leaked_stats(enemy: Node2D, _lives_cost: int) -> void:
	if enemy is BaseEnemy:
		_stats["leaking_enemies"].append({
			"name": enemy.enemy_data.get_display_name() if enemy.enemy_data else "agitator",
			"remaining_hp": enemy.health.current_hp,
		})


func _on_wave_completed_stats(_wave_number: int) -> void:
	_stats["waves_survived"] += 1
	if not WaveManager._wave_had_leak:
		_stats["zero_tolerance_waves"] += 1
