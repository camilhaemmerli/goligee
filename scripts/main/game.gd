extends Node2D
## Main game scene controller. Wires up spawning, pathfinding, and the
## connection between WaveManager and the game world.

@export var spawn_tiles: Array[Vector2i] = []
@export var goal_tiles: Array[Vector2i] = []

@onready var tile_map: TileMapLayer = $World/TileMapLayer
@onready var platform_renderer: PlatformRenderer = $World/PlatformRenderer
@onready var structures: Node2D = $World/Structures
@onready var environment_props: Node2D = $World/EnvironmentProps
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
	# Load the riot control theme
	ThemeManager.apply_theme(load("res://data/themes/riot_control/theme.tres"))

	# Set up groups for lookups
	projectile_container.add_to_group("projectiles")

	# Build the map programmatically and get spawn/goal tiles
	var map_result := MapBuilder.build_map(tile_map)
	spawn_tiles = map_result["spawn_tiles"]
	goal_tiles = map_result["goal_tiles"]

	# Phase 1: Set up raised platform with depth
	platform_renderer.setup(tile_map, MapBuilder.MAP_W, MapBuilder.MAP_H)

	# Phase 3: Build isometric structures
	StructureBuilder.build_structures(structures, tile_map)

	# Phase 4: Place environmental props
	EnvironmentBuilder.build_environment(environment_props, tile_map)

	# Center camera on the map
	var center_tile := Vector2i(MapBuilder.MAP_W / 2, MapBuilder.MAP_H / 2)
	_camera = Camera2D.new()
	_camera.position = tile_map.map_to_local(center_tile)
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
	tower_menu._build_buttons()

	# Connect wave manager spawn signal
	WaveManager.spawn_enemy_requested.connect(_on_spawn_enemy)

	# Wire up tower placer
	tower_placer.tile_map = tile_map
	tower_placer.tower_container = tower_container

	# Phase 5: Fog, lighting, and atmosphere
	_setup_lighting()
	_setup_fog()
	_setup_ground_smoke()
	_setup_atmosphere()

	# Apply theme shader params
	_apply_theme_shaders()
	ThemeManager.theme_changed.connect(_apply_theme_shaders)

	# Phase 6: Ambient particles
	_setup_ambient_particles()

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
		_camera.position = _camera_origin + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount),
		)
		if _shake_timer <= 0.0:
			_camera.position = _camera_origin


func _shake_camera(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration


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


# -- Phase 5: Lighting --

func _setup_lighting() -> void:
	# Night baseline via CanvasModulate
	var canvas_mod := CanvasModulate.new()
	canvas_mod.color = Color(0.45, 0.45, 0.5, 1.0)
	$World.add_child(canvas_mod)

	# Generate radial light texture
	var light_tex := _create_radial_gradient(256)

	# Floodlight from government building (right side)
	var flood := PointLight2D.new()
	flood.texture = light_tex
	flood.color = Color("#D89050")
	flood.energy = 0.4
	flood.texture_scale = 3.0
	flood.position = tile_map.map_to_local(Vector2i(14, 4))
	$World.add_child(flood)

	# Streetlight near spawn (left side)
	var street := PointLight2D.new()
	street.texture = light_tex
	street.color = Color("#C8A040")
	street.energy = 0.3
	street.texture_scale = 2.0
	street.position = tile_map.map_to_local(Vector2i(2, 4))
	$World.add_child(street)

	# Secondary accent light (top center for subtle fill)
	var accent := PointLight2D.new()
	accent.texture = light_tex
	accent.color = Color("#8090A0")
	accent.energy = 0.15
	accent.texture_scale = 4.0
	accent.position = tile_map.map_to_local(Vector2i(8, 2))
	$World.add_child(accent)


func _create_radial_gradient(tex_size: int) -> ImageTexture:
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var center := tex_size / 2.0
	var radius := center
	for y in tex_size:
		for x in tex_size:
			var dist := Vector2(x - center, y - center).length()
			var alpha := clampf(1.0 - (dist / radius), 0.0, 1.0)
			alpha = alpha * alpha  # Quadratic falloff
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)


# -- Phase 5: Fog --

func _setup_fog() -> void:
	var fog_rect := get_node_or_null("FogLayer/FogRect") as ColorRect
	if not fog_rect:
		return
	fog_rect.visible = true

	var shader := load("res://assets/shaders/fog.gdshader") as Shader
	if not shader:
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader

	# Create noise texture for fog
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true

	mat.set_shader_parameter("noise_texture", noise_tex)
	mat.set_shader_parameter("fog_color_near", Color(0.18, 0.18, 0.2, 0.4))
	mat.set_shader_parameter("fog_color_far", Color(0.25, 0.23, 0.2, 0.6))
	mat.set_shader_parameter("scroll_speed", 0.012)
	mat.set_shader_parameter("density", 0.3)
	mat.set_shader_parameter("noise_scale", 2.5)
	mat.set_shader_parameter("vertical_fade_start", 0.2)
	mat.set_shader_parameter("vertical_fade_end", 0.85)
	fog_rect.material = mat


# -- Phase 5: Ground Smoke --

func _setup_ground_smoke() -> void:
	var smoke_rect := get_node_or_null("GroundSmokeLayer/SmokeRect") as ColorRect
	if not smoke_rect:
		return

	var shader := load("res://assets/shaders/ground_smoke.gdshader") as Shader
	if not shader:
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_octaves = 2
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true

	mat.set_shader_parameter("noise_texture", noise_tex)
	mat.set_shader_parameter("smoke_color", Color(0.28, 0.25, 0.25, 0.35))
	mat.set_shader_parameter("scroll_speed", 0.025)
	mat.set_shader_parameter("density", 0.25)
	mat.set_shader_parameter("noise_scale", 3.0)
	smoke_rect.material = mat


# -- Phase 5: Atmosphere (vignette + color grade) --

func _setup_atmosphere() -> void:
	var atmos_rect := get_node_or_null("AtmosphereLayer/AtmosphereRect") as ColorRect
	if not atmos_rect:
		return

	var shader := load("res://assets/shaders/atmosphere.gdshader") as Shader
	if not shader:
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint_color", Color(0.16, 0.16, 0.18, 1.0))
	mat.set_shader_parameter("tint_strength", 0.08)
	mat.set_shader_parameter("vignette_strength", 0.7)
	mat.set_shader_parameter("vignette_radius", 0.75)
	mat.set_shader_parameter("brightness", 1.0)
	mat.set_shader_parameter("contrast", 1.05)
	atmos_rect.material = mat


# -- Phase 6: Ambient particles --

func _setup_ambient_particles() -> void:
	# Ambient embers — slow rising orange particles
	var embers := GPUParticles2D.new()
	embers.amount = 12
	embers.lifetime = 4.0
	embers.z_index = 50

	var embers_mat := ParticleProcessMaterial.new()
	embers_mat.direction = Vector3(0, -1, 0)
	embers_mat.initial_velocity_min = 8.0
	embers_mat.initial_velocity_max = 16.0
	embers_mat.gravity = Vector3(0, -2, 0)
	embers_mat.spread = 45.0
	embers_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	embers_mat.emission_box_extents = Vector3(240, 20, 0)
	embers_mat.scale_min = 0.5
	embers_mat.scale_max = 1.5
	embers_mat.color = Color("#D06030")
	var embers_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	embers_curve.curve = curve
	embers_mat.alpha_curve = embers_curve

	embers.process_material = embers_mat
	embers.position = tile_map.map_to_local(Vector2i(8, 8))
	effects_container.add_child(embers)

	# Ambient ash — falling gray particles
	var ash := GPUParticles2D.new()
	ash.amount = 16
	ash.lifetime = 5.0
	ash.z_index = 50

	var ash_mat := ParticleProcessMaterial.new()
	ash_mat.direction = Vector3(0.3, 1, 0)
	ash_mat.initial_velocity_min = 4.0
	ash_mat.initial_velocity_max = 8.0
	ash_mat.gravity = Vector3(1, 3, 0)
	ash_mat.spread = 30.0
	ash_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ash_mat.emission_box_extents = Vector3(280, 10, 0)
	ash_mat.scale_min = 0.3
	ash_mat.scale_max = 1.0
	ash_mat.color = Color("#383838")
	var ash_curve_tex := CurveTexture.new()
	var ash_curve := Curve.new()
	ash_curve.add_point(Vector2(0, 0))
	ash_curve.add_point(Vector2(0.15, 0.6))
	ash_curve.add_point(Vector2(0.7, 0.6))
	ash_curve.add_point(Vector2(1, 0))
	ash_curve_tex.curve = ash_curve
	ash_mat.alpha_curve = ash_curve_tex

	ash.process_material = ash_mat
	ash.position = tile_map.map_to_local(Vector2i(8, 2))
	effects_container.add_child(ash)


func _apply_theme_shaders() -> void:
	var palette = ThemeManager.get_palette()
	if not palette:
		return

	# Apply fog colors
	var fog_rect := get_node_or_null("FogLayer/FogRect")
	if fog_rect and fog_rect.material is ShaderMaterial:
		ThemeManager.apply_shader_params(fog_rect.material, "fog")

	# Apply ground smoke colors
	var smoke_rect := get_node_or_null("GroundSmokeLayer/SmokeRect")
	if smoke_rect and smoke_rect.material is ShaderMaterial:
		ThemeManager.apply_shader_params(smoke_rect.material, "ground_smoke")

	# Apply atmosphere colors
	var atmos_rect := get_node_or_null("AtmosphereLayer/AtmosphereRect")
	if atmos_rect and atmos_rect.material is ShaderMaterial:
		ThemeManager.apply_shader_params(atmos_rect.material, "atmosphere")

	# Apply atmosphere colors
	ThemeManager.apply_clear_color()


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
