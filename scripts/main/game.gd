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

var _camera: CameraController
var _govt_sprite: Sprite2D = null
var _govt_textures: Array[Texture2D] = []
var _govt_damage_state: int = 0
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
var _tile_source_id: int = 0
var _barrel_nodes: Array[Node2D] = []
var _debug_label: Label = null
var _debug_enabled: bool = false
var _music_player: AudioStreamPlayer
var _fog_manager: FogManager
var _spawn_indicator: SpawnIndicator
var _waves_started: bool = false
var _intro_cover: CanvasLayer


func _ready() -> void:
	# Black overlay immediately to prevent map flash before intro comic
	_intro_cover = CanvasLayer.new()
	_intro_cover.layer = 19
	var cover_rect := ColorRect.new()
	cover_rect.color = Color.BLACK
	cover_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_cover.add_child(cover_rect)
	add_child(_intro_cover)

	# Set up groups for lookups
	projectile_container.add_to_group("projectiles")
	effects_container.add_to_group("effects")

	# Build the map programmatically and get spawn/goal tiles
	var map_result := MapBuilder.build_map(tile_map)
	spawn_tiles = map_result["spawn_tiles"]
	goal_tiles = map_result["goal_tiles"]
	_tile_source_id = map_result["source_id"]

	# Center camera on the map
	var center_tile := Vector2i(MapBuilder.MAP_W / 2, MapBuilder.MAP_H / 2)
	_camera = CameraController.new()
	_set_camera_pos(tile_map.map_to_local(center_tile))
	_camera_origin = _camera.position
	add_child(_camera)

	# Compute world-space map bounds for camera clamping
	var tl := tile_map.map_to_local(Vector2i(-MapBuilder.BORDER, -MapBuilder.BORDER))
	var br := tile_map.map_to_local(Vector2i(
		MapBuilder.MAP_W + MapBuilder.BORDER,
		MapBuilder.MAP_H + MapBuilder.BORDER))
	# Isometric — need all four corners to find actual bounding box
	var tr := tile_map.map_to_local(Vector2i(MapBuilder.MAP_W + MapBuilder.BORDER, -MapBuilder.BORDER))
	var bl := tile_map.map_to_local(Vector2i(-MapBuilder.BORDER, MapBuilder.MAP_H + MapBuilder.BORDER))
	var min_pt := Vector2(
		min(tl.x, min(tr.x, min(bl.x, br.x))),
		min(tl.y, min(tr.y, min(bl.y, br.y))))
	var max_pt := Vector2(
		max(tl.x, max(tr.x, max(bl.x, br.x))),
		max(tl.y, max(tr.y, max(bl.y, br.y))))
	_camera.setup_bounds(Rect2(min_pt, max_pt - min_pt))

	# City background scenery (sky gradient, buildings, animated lights)
	_setup_city_background()

	# Grid overlay on buildable tiles
	var grid_overlay := GridOverlay.new()
	$World.add_child(grid_overlay)
	grid_overlay.setup(tile_map, MapBuilder.MAP_W, MapBuilder.MAP_H)

	# Obstacle props (burning barrels, barricades, rubble, etc.)
	var obstacle_tiles: Dictionary = map_result.get("obstacle_tiles", {})
	if not obstacle_tiles.is_empty():
		var props_container := Node2D.new()
		props_container.name = "Props"
		props_container.y_sort_enabled = true
		$World.add_child(props_container)
		$World.move_child(props_container, $World/TileMapLayer.get_index() + 1)
		_barrel_nodes = EnvironmentBuilder.build_obstacle_props(
			props_container, tile_map, obstacle_tiles)
		_animate_barrels()

	# Initialize pathfinding
	PathfindingManager.initialize(tile_map, spawn_tiles, goal_tiles)

	# Initialize abilities
	var ability_list: Array[SpecialAbilityData] = [
		load("res://data/abilities/agent_provocateur.tres") as SpecialAbilityData,
		load("res://data/abilities/gas_airstrike.tres") as SpecialAbilityData,
		load("res://data/abilities/water_cannon_truck.tres") as SpecialAbilityData,
	]
	AbilityManager.initialize(ability_list, tile_map, effects_container)
	SignalBus.ability_activated.connect(_on_ability_activated)

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
		load("res://data/waves/wave_11.tres") as WaveData,
		load("res://data/waves/wave_12.tres") as WaveData,
		load("res://data/waves/wave_13.tres") as WaveData,
		load("res://data/waves/wave_14.tres") as WaveData,
		load("res://data/waves/wave_15.tres") as WaveData,
		load("res://data/waves/wave_16.tres") as WaveData,
		load("res://data/waves/wave_17.tres") as WaveData,
		load("res://data/waves/wave_18.tres") as WaveData,
		load("res://data/waves/wave_19.tres") as WaveData,
		load("res://data/waves/wave_20.tres") as WaveData,
		load("res://data/waves/wave_21.tres") as WaveData,
		load("res://data/waves/wave_22.tres") as WaveData,
		load("res://data/waves/wave_23.tres") as WaveData,
		load("res://data/waves/wave_24.tres") as WaveData,
		load("res://data/waves/wave_25.tres") as WaveData,
		load("res://data/waves/wave_26.tres") as WaveData,
		load("res://data/waves/wave_27.tres") as WaveData,
		load("res://data/waves/wave_28.tres") as WaveData,
		load("res://data/waves/wave_29.tres") as WaveData,
		load("res://data/waves/wave_30.tres") as WaveData,
		load("res://data/waves/wave_31.tres") as WaveData,
		load("res://data/waves/wave_32.tres") as WaveData,
		load("res://data/waves/wave_33.tres") as WaveData,
		load("res://data/waves/wave_34.tres") as WaveData,
		load("res://data/waves/wave_35.tres") as WaveData,
		load("res://data/waves/wave_36.tres") as WaveData,
		load("res://data/waves/wave_37.tres") as WaveData,
		load("res://data/waves/wave_38.tres") as WaveData,
		load("res://data/waves/wave_39.tres") as WaveData,
		load("res://data/waves/wave_40.tres") as WaveData,
		load("res://data/waves/wave_41.tres") as WaveData,
		load("res://data/waves/wave_42.tres") as WaveData,
		load("res://data/waves/wave_43.tres") as WaveData,
		load("res://data/waves/wave_44.tres") as WaveData,
		load("res://data/waves/wave_45.tres") as WaveData,
		load("res://data/waves/wave_46.tres") as WaveData,
		load("res://data/waves/wave_47.tres") as WaveData,
		load("res://data/waves/wave_48.tres") as WaveData,
		load("res://data/waves/wave_49.tres") as WaveData,
		load("res://data/waves/wave_50.tres") as WaveData,
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
		ThemeManager.populate_enemy_skins_from_assets(theme)
		ThemeManager.apply_theme(theme)

	tower_menu._build_buttons()

	# Connect wave manager spawn signal
	WaveManager.spawn_enemy_requested.connect(_on_spawn_enemy)

	# Wire up tower placer
	tower_placer.tile_map = tile_map
	tower_placer.tower_container = tower_container

	# Camera shake on enemy kills
	SignalBus.enemy_killed.connect(_on_enemy_killed_shake)
	SignalBus.screen_shake.connect(_shake_camera)

	SignalBus.enemy_damaged.connect(_on_enemy_damaged_stats)
	SignalBus.enemy_killed.connect(_on_enemy_killed_stats)
	SignalBus.enemy_reached_end.connect(_on_enemy_leaked_stats)
	SignalBus.wave_completed.connect(_on_wave_completed_stats)

	# Restart handler
	SignalBus.restart_requested.connect(_on_restart)

	# Manifestation flow: briefing → spawn indicator → wave start
	SignalBus.manifestation_ready.connect(_on_manifestation_ready)

	# Government building damage states tied to approval rating
	SignalBus.lives_changed.connect(_on_lives_changed_building)
	_setup_govt_damage_textures()

	# Spawn indicator at first spawn tile
	_spawn_indicator = SpawnIndicator.new()
	if not spawn_tiles.is_empty():
		_spawn_indicator.position = tile_map.map_to_local(spawn_tiles[0]) + Vector2(0, -16)
	$World.add_child(_spawn_indicator)
	_spawn_indicator.clicked.connect(_on_spawn_indicator_clicked)

	# Vignette overlay
	var vignette_layer := CanvasLayer.new()
	vignette_layer.layer = 5  # Above world, below HUD
	add_child(vignette_layer)
	var vignette_rect := ColorRect.new()
	vignette_rect.anchors_preset = Control.PRESET_FULL_RECT
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_shader := load("res://assets/shaders/vignette.gdshader") as Shader
	if vignette_shader:
		var mat := ShaderMaterial.new()
		mat.shader = vignette_shader
		vignette_rect.material = mat
	vignette_layer.add_child(vignette_rect)

	# Atmospheric fog/gas overlay (intensifies with chemical towers)
	_fog_manager = FogManager.new()
	add_child(_fog_manager)
	_fog_manager.setup(self, _camera, effects_container)

	# Background music — starts during intro comic
	_setup_bgm()

	# Intro comic → briefing → spawn indicator → waves
	GameManager.start_game()
	var intro := IntroComic.new()
	add_child(intro)
	intro.finished.connect(func():
		_intro_cover.queue_free()
		_show_manifestation_briefing(1)
	)


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

	# Debug tile coord overlay (F3 toggle)
	if _debug_enabled and _debug_label:
		var mouse_world := get_global_mouse_position()
		var tile_pos := tile_map.local_to_map(tile_map.to_local(mouse_world))
		_debug_label.text = "Tile: (%d, %d)" % [tile_pos.x, tile_pos.y]

	# Camera shake update — applied via shake_offset on top of pan position
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var shake_amount := _shake_intensity * (_shake_timer / _shake_duration)
		_camera.shake_offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount))
		if _shake_timer <= 0.0:
			_camera.shake_offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_debug_enabled = not _debug_enabled
		if _debug_label:
			_debug_label.visible = _debug_enabled
		if not _debug_label:
			_debug_label = Label.new()
			_debug_label.add_theme_font_size_override("font_size", 14)
			_debug_label.position = Vector2(4, 20)
			$HUD.add_child(_debug_label)

	# DEBUG: F5 = spawn flying enemy test wave (press_drone + news_helicopter)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		EconomyManager.add_gold(9999)
		var drone_data := load("res://data/enemies/press_drone.tres") as EnemyData
		var heli_data := load("res://data/enemies/news_helicopter.tres") as EnemyData
		if drone_data:
			for i in 5:
				var t := create_tween()
				t.tween_interval(i * 0.6)
				t.tween_callback(func(): WaveManager.spawn_enemy_requested.emit(drone_data, 0, {"hp_multiplier": 3.0}))
				WaveManager.enemies_alive += 1
		if heli_data:
			for i in 2:
				var t := create_tween()
				t.tween_interval(1.0 + i * 3.0)
				t.tween_callback(func(): WaveManager.spawn_enemy_requested.emit(heli_data, 0, {"hp_multiplier": 2.0}))
				WaveManager.enemies_alive += 1


func _shake_camera(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration


func _set_camera_pos(pos: Vector2) -> void:
	if not _camera:
		return
	_camera.position = pos.round()


func _on_restart() -> void:
	Engine.time_scale = 1.0
	SpatialGrid.clear()
	VFXPool.reset_pool()
	get_tree().reload_current_scene()


func _on_ability_activated(ability_id: String, world_pos: Vector2) -> void:
	var ability_scene: Node2D
	match ability_id:
		"agent_provocateur":
			ability_scene = AgentProvocateur.new()
		"gas_airstrike":
			ability_scene = GasAirstrike.new()
		"water_cannon_truck":
			ability_scene = WaterCannonTruck.new()
		_:
			return
	effects_container.add_child(ability_scene)
	ability_scene.init(world_pos, tile_map)


func _show_manifestation_briefing(wave_number: int) -> void:
	var briefing := ManifestationBriefing.new()
	add_child(briefing)
	briefing.show_briefing(wave_number)
	# When dismissed, show the spawn indicator
	SignalBus.presidential_briefing_dismissed.connect(
		_on_briefing_dismissed_show_indicator, CONNECT_ONE_SHOT)


func _on_briefing_dismissed_show_indicator() -> void:
	_spawn_indicator.show_indicator()


func _on_spawn_indicator_clicked() -> void:
	_spawn_indicator.hide_indicator()
	if not _waves_started:
		_waves_started = true
		WaveManager.start_waves()
	else:
		WaveManager.advance_wave()


func _on_manifestation_ready(next_wave_number: int) -> void:
	_show_manifestation_briefing(next_wave_number)


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


# ---------------------------------------------------------------------------
# City background scenery
# ---------------------------------------------------------------------------

func _setup_city_background() -> void:
	var bg := $CityBackground

	# --- Sky gradient (behind everything) ---
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color("#181820"),  # Top: dark night sky
		Color("#252530"),  # Mid: dark blue-grey smog
		Color("#353040"),  # Bottom: warm polluted horizon
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])

	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	grad_tex.width = 1600
	grad_tex.height = 900

	var sky := Sprite2D.new()
	sky.texture = grad_tex
	sky.z_index = -2
	sky.position = _camera_origin
	bg.add_child(sky)
	bg.move_child(sky, 0)

	# --- Extended ground plane (city streets around playing field) ---
	# Separate TileMapLayer in CityBackground so buildings draw ON TOP of it
	var ground_layer := TileMapLayer.new()
	ground_layer.tile_set = tile_map.tile_set  # share the same TileSet
	ground_layer.z_index = -1  # behind buildings (z=0) within CityBackground
	bg.add_child(ground_layer)

	var source_id: int = _tile_source_id
	for ey in range(-MapBuilder.BORDER, MapBuilder.MAP_H + MapBuilder.BORDER):
		for ex in range(-MapBuilder.BORDER, MapBuilder.MAP_W + MapBuilder.BORDER):
			if ex >= 0 and ex < MapBuilder.MAP_W and ey >= 0 and ey < MapBuilder.MAP_H:
				continue  # skip playable area (painted by main TileMapLayer)
			ground_layer.set_cell(Vector2i(ex, ey), source_id, MapBuilder.WALL)

	# --- Buildings are placed as ScenerySprite nodes in the scene tree ---
	# To add/move/remove buildings, edit the scene in the Godot editor:
	#   CityBackground/Buildings  — backdrop buildings (drag to reposition)
	#   CityBackground/GovernmentBuilding — foreground government dome
	#   CityBackground/Decorations — manually placed props and decorations
	# Use the PlayfieldGuide node to see where the playfield will render.

	# --- Animated details ---
	_setup_flickering_windows()
	_setup_govt_glow()


func _setup_flickering_windows() -> void:
	var details := $CityBackground/AnimatedDetails

	# Scatter flickering yellow lights near tall building positions
	var building_tiles := [
		Vector2i(-5, -3), Vector2i(-6, 3), Vector2i(-7, 8),  # left panelkas
		Vector2i(12, -4), Vector2i(20, -3),                    # back panelkas
		Vector2i(28, 1), Vector2i(28, -4),                     # right panelkas
	]
	var window_positions: Array[Vector2] = []
	for tile in building_tiles:
		var base := tile_map.map_to_local(tile)
		# 2-3 lights per building at various heights
		window_positions.append(base + Vector2(randf_range(-15, 15), randf_range(-120, -50)))
		window_positions.append(base + Vector2(randf_range(-15, 15), randf_range(-90, -40)))
		if randf() > 0.4:
			window_positions.append(base + Vector2(randf_range(-10, 10), randf_range(-140, -70)))

	var light_img := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	light_img.fill(Color("#C8A040"))
	var light_tex := ImageTexture.create_from_image(light_img)

	for i in window_positions.size():
		var light := Sprite2D.new()
		light.texture = light_tex
		light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		light.position = window_positions[i]
		details.add_child(light)

		var timer := Timer.new()
		timer.wait_time = randf_range(1.5, 4.0)
		timer.autostart = true
		timer.timeout.connect(_on_window_flicker.bind(light, timer))
		light.add_child(timer)


func _on_window_flicker(light: Sprite2D, timer: Timer) -> void:
	light.visible = not light.visible
	timer.wait_time = randf_range(1.0, 3.5)


func _setup_govt_glow() -> void:
	var container := $CityBackground/GovernmentBuilding
	if container.get_child_count() == 0:
		return
	var govt_sprite := container.get_child(0) as Sprite2D
	if not govt_sprite:
		return

	_govt_sprite = govt_sprite

	var bright := Color(1.3, 1.25, 1.1)
	var dim := Color(1.1, 1.05, 0.95)
	var tween := create_tween().set_loops()
	tween.tween_property(govt_sprite, "self_modulate", dim, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(govt_sprite, "self_modulate", bright, 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------------
# Government building damage states
# ---------------------------------------------------------------------------

func _setup_govt_damage_textures() -> void:
	# 6 states: pristine, graffiti, cracked, heavy damage, half destroyed, rubble
	var paths: PackedStringArray = [
		"res://assets/sprites/buildings/building_government_dome.png",
		"res://assets/sprites/buildings/building_government_dome_dmg1.png",
		"res://assets/sprites/buildings/building_government_dome_dmg2.png",
		"res://assets/sprites/buildings/building_government_dome_dmg3.png",
		"res://assets/sprites/buildings/building_government_dome_dmg4.png",
		"res://assets/sprites/buildings/building_government_dome_dmg5.png",
	]
	for p in paths:
		if ResourceLoader.exists(p):
			_govt_textures.append(load(p) as Texture2D)
		else:
			_govt_textures.append(null)
	_govt_damage_state = 0


func _on_lives_changed_building(lives: int) -> void:
	if not _govt_sprite or _govt_textures.is_empty():
		return

	# Map approval to damage state (20 starting lives, 6 states)
	var state: int
	if lives >= 17:
		state = 0  # pristine
	elif lives >= 13:
		state = 1  # graffiti
	elif lives >= 9:
		state = 2  # cracks
	elif lives >= 5:
		state = 3  # heavy damage
	elif lives >= 2:
		state = 4  # half destroyed
	else:
		state = 5  # rubble

	if state == _govt_damage_state:
		return
	_govt_damage_state = state

	if state < _govt_textures.size() and _govt_textures[state]:
		_govt_sprite.texture = _govt_textures[state]


# ---------------------------------------------------------------------------
# Burning barrel fire animation
# ---------------------------------------------------------------------------

func _animate_barrels() -> void:
	for barrel in _barrel_nodes:
		if barrel.get_child_count() < 4:
			continue
		# Children: [0] glow, [1] barrel_sprite, [2] fire_a, [3] fire_b
		var glow: Sprite2D = barrel.get_child(0) as Sprite2D
		var fire_a: Sprite2D = barrel.get_child(2) as Sprite2D
		var fire_b: Sprite2D = barrel.get_child(3) as Sprite2D

		# Glow alpha pulse
		var glow_tween := create_tween().set_loops()
		glow_tween.tween_property(glow, "modulate:a", 0.12, 0.8) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		glow_tween.tween_property(glow, "modulate:a", 0.25, 0.8) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

		# Fire A — scale oscillation + alpha flicker + vertical bob
		_animate_fire_sprite(fire_a, 0.6, 0.0)
		# Fire B — offset phase
		_animate_fire_sprite(fire_b, 0.7, 0.35)


func _setup_bgm() -> void:
	var path := "res://assets/audio/music/game_bgm.mp3"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if not stream:
		return
	if "loop" in stream:
		stream.loop = true
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = stream
	_music_player.bus = &"Master"
	_music_player.volume_db = -40.0
	add_child(_music_player)
	_music_player.play()
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -8.0, 3.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _animate_fire_sprite(fire: Sprite2D, period: float, phase: float) -> void:
	var base_y := fire.position.y

	# Scale oscillation
	var scale_tween := create_tween().set_loops()
	if phase > 0.0:
		scale_tween.tween_interval(phase)
	scale_tween.tween_property(fire, "scale", Vector2(1.15, 1.25), period) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	scale_tween.tween_property(fire, "scale", Vector2(0.9, 0.85), period) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Alpha flicker
	var alpha_tween := create_tween().set_loops()
	if phase > 0.0:
		alpha_tween.tween_interval(phase * 0.7)
	alpha_tween.tween_property(fire, "modulate:a", 0.6, period * 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	alpha_tween.tween_property(fire, "modulate:a", 1.0, period * 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Vertical bob
	var bob_tween := create_tween().set_loops()
	if phase > 0.0:
		bob_tween.tween_interval(phase * 1.2)
	bob_tween.tween_property(fire, "position:y", base_y - 2.0, period * 1.1) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob_tween.tween_property(fire, "position:y", base_y + 1.0, period * 1.1) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
