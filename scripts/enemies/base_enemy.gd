class_name BaseEnemy
extends Node2D
## Base class for all enemies. Follows waypoints from PathfindingManager.
## Composed of child components: HealthComponent, ResistanceComponent,
## StatusEffectManager, LootComponent.
## Supports 8-direction walk animation via AnimatedSprite2D.

@export var enemy_data: EnemyData

@onready var health: HealthComponent = $HealthComponent
@onready var resistances: ResistanceComponent = $ResistanceComponent
@onready var status_effects: StatusEffectManager = $StatusEffectManager
@onready var loot: LootComponent = $LootComponent
@onready var sprite: Sprite2D = $Sprite2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite
@onready var health_bar: ProgressBar = $HealthBar

var base_speed: float = 1.0
var _movement_type: Enums.MovementType = Enums.MovementType.GROUND
var _stealth: bool = false

var _waypoints: PackedVector2Array = PackedVector2Array()
var _waypoint_index: int = 0
var _spawn_index: int = -1
var _distance_traveled: float = 0.0
var _total_path_length: float = 0.0

var last_hit_by: Node2D  ## Tower that last dealt damage (for kill attribution)
var velocity: Vector2 = Vector2.ZERO  ## Last frame movement direction (for crossfire calc)

## Corpse cleanup: track lingering corpses globally, cap at 30
static var _corpses: Array[Node2D] = []
const MAX_CORPSES := 30

## Whether this enemy uses AnimatedSprite2D for walk cycles
var _use_animated: bool = false
## Current animation direction suffix
var _current_dir: String = "se"
## Speed burst: fires once when HP drops below threshold
var _speed_burst_triggered: bool = false

# 8-direction animation: snap movement angle to nearest direction
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

# Damage type color map for floating numbers
const DAMAGE_COLORS := {
	Enums.DamageType.KINETIC: Color("#E0D0C8"),
	Enums.DamageType.CHEMICAL: Color("#E08040"),
	Enums.DamageType.HYDRAULIC: Color("#80C0E0"),
	Enums.DamageType.ELECTRIC: Color("#E0E060"),
	Enums.DamageType.SONIC: Color("#80E060"),
	Enums.DamageType.DIRECTED_ENERGY: Color("#C080E0"),
	Enums.DamageType.CYBER: Color("#F0F0A0"),
	Enums.DamageType.PSYCHOLOGICAL: Color("#9060A0"),
}

var _flash_material: ShaderMaterial

## Flying enemy rotor animation
var _rotor_sprite: Sprite2D
var _rotor_textures: Array[Texture2D] = []
var _rotor_frame: int = 0
var _rotor_timer: float = 0.0
const ROTOR_FRAME_TIME := 0.06

## Drone zig-zag (press_drone only)
var _zigzag_enabled: bool = false
var _zigzag_perpendicular: Vector2 = Vector2.ZERO
var _zigzag_time: float = 0.0
var _zigzag_current_offset: float = 0.0
const ZIGZAG_AMPLITUDE := 12.0
const ZIGZAG_FREQUENCY := 3.5

## Shadow reference for breathing animation
var _shadow_sprite: Sprite2D

## News helicopter camera zone
var _camera_zone: Area2D
var _camera_beam_node: Node2D
var _suppressed_towers: Array[Node2D] = []
const CAMERA_ZONE_RADIUS := 32.0  # ~1 tile
const CAMERA_ORBIT_RADIUS := 32.0  # Offset from helicopter center
const CAMERA_ORBIT_SPEED := 0.25  # Rotations per second
const CAMERA_BEAM_COLOR := Color("#E0C060", 0.15)
const CAMERA_BEAM_OUTLINE := Color("#E0C060", 0.35)
var _camera_orbit_angle: float = 0.0


func _ready() -> void:
	if enemy_data:
		_init_from_data()

	# Themed fallback sprite based on enemy type
	if not _use_animated and not sprite.texture:
		if enemy_data and enemy_data.enemy_id:
			match enemy_data.enemy_id:
				"rioter", "masked_protestor", "blonde_protestor":
					sprite.texture = EntitySprites.create_protestor()
				"shield_wall":
					sprite.texture = EntitySprites.create_agitator_elite()
				"press_drone":
					sprite.texture = EntitySprites.create_press_drone()
				"news_helicopter":
					sprite.texture = EntitySprites.create_news_helicopter()
				_:
					sprite.texture = EntitySprites.create_protestor()
		else:
			sprite.texture = EntitySprites.create_protestor()

	# Set up damage flash shader material on the active visual node
	var shader := load("res://assets/shaders/damage_flash.gdshader") as Shader
	if shader:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = shader
		if _use_animated:
			animated_sprite.material = _flash_material
		else:
			sprite.material = _flash_material

	health.died.connect(_on_died)
	health.damage_taken.connect(_on_damage_taken)
	health.health_changed.connect(_on_health_changed)

	# Initialize health bar
	health_bar.max_value = health.max_hp
	health_bar.value = health.current_hp

	if is_flying():
		_setup_flying_visuals()
	else:
		PathfindingManager.path_updated.connect(_on_path_updated)


func _setup_flying_visuals() -> void:
	const FLY_OFFSET := -16.0
	z_index = 10

	# Shift visual nodes up to simulate altitude (position stays at ground level)
	var visual: CanvasItem = animated_sprite if _use_animated else sprite
	visual.position.y += FLY_OFFSET
	health_bar.position.y += FLY_OFFSET

	# Ground shadow: semi-transparent dark ellipse at ground level
	var shadow_img := Image.create(20, 10, false, Image.FORMAT_RGBA8)
	var shadow_color := Color(0, 0, 0, 0.3)
	for y in 10:
		for x in 20:
			var dx := (x - 10.0) / 10.0
			var dy := (y - 5.0) / 5.0
			if dx * dx + dy * dy <= 1.0:
				shadow_img.set_pixel(x, y, shadow_color)
	_shadow_sprite = Sprite2D.new()
	_shadow_sprite.texture = ImageTexture.create_from_image(shadow_img)
	_shadow_sprite.z_index = -1
	add_child(_shadow_sprite)

	# Shadow breathing: scale synced with bob (grows when high, shrinks when low)
	var shadow_tween := create_tween()
	shadow_tween.set_loops()
	shadow_tween.tween_property(_shadow_sprite, "scale", Vector2(1.08, 1.08), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shadow_tween.tween_property(_shadow_sprite, "scale", Vector2(0.92, 0.92), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Rotor overlay animation (child of visual so it inherits bob + offset)
	if enemy_data and enemy_data.enemy_id:
		match enemy_data.enemy_id:
			"press_drone":
				_rotor_textures = [
					EntitySprites.create_press_drone_rotors(0),
					EntitySprites.create_press_drone_rotors(1),
				]
			"news_helicopter":
				_rotor_textures = [
					EntitySprites.create_news_helicopter_rotor(0),
					EntitySprites.create_news_helicopter_rotor(1),
				]
	if not _rotor_textures.is_empty():
		_rotor_sprite = Sprite2D.new()
		_rotor_sprite.texture = _rotor_textures[0]
		_rotor_sprite.z_index = 1
		visual.add_child(_rotor_sprite)

	# Gentle bobbing tween on the visual node
	_setup_flying_bob(visual)

	# News helicopter camera zone
	if enemy_data and enemy_data.enemy_id == "news_helicopter":
		_setup_camera_zone()


func _setup_flying_bob(visual: CanvasItem) -> void:
	var base_y: float = visual.position.y
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(visual, "position:y", base_y - 3.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(visual, "position:y", base_y + 3.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _init_from_data() -> void:
	health.max_hp = enemy_data.max_hp
	health.current_hp = enemy_data.max_hp
	health.armor = enemy_data.armor
	health.armor_type = enemy_data.armor_type
	health.shield = enemy_data.shield
	health.max_shield = enemy_data.shield

	base_speed = enemy_data.base_speed
	_movement_type = enemy_data.movement_type
	_stealth = enemy_data.is_stealth

	resistances.resistances = enemy_data.resistances.duplicate()

	loot.gold_reward = enemy_data.gold_reward
	loot.lives_cost = enemy_data.lives_cost

	_apply_theme_skin()


func _apply_theme_skin() -> void:
	if not enemy_data or not enemy_data.enemy_id:
		return
	var skin = ThemeManager.get_enemy_skin(enemy_data.enemy_id)
	if not skin:
		return

	# Check for animated sprite frames (walk cycles)
	if skin.animation_frames and skin.animation_frames.get_animation_names().size() > 0:
		_use_animated = true
		animated_sprite.sprite_frames = skin.animation_frames
		animated_sprite.visible = true
		sprite.visible = false
		# Start with SE walk animation if available
		if animated_sprite.sprite_frames.has_animation("walk_se"):
			animated_sprite.play("walk_se")
		elif animated_sprite.sprite_frames.has_animation("walk_s"):
			animated_sprite.play("walk_s")
	elif skin.sprite_sheet:
		sprite.texture = skin.sprite_sheet
	if skin.tint != Color.WHITE:
		if _use_animated:
			animated_sprite.modulate = skin.tint
		else:
			sprite.modulate = skin.tint


func _update_animation_direction(move_dir: Vector2) -> void:
	"""Update walk animation based on movement direction."""
	if not _use_animated or move_dir.is_zero_approx():
		return
	var angle := move_dir.angle()  # radians, 0=right, PI/2=down
	var idx := wrapi(roundi(angle / (TAU / 8.0)), 0, 8)
	var dir_name: String = DIR_NAMES[idx]

	if dir_name == _current_dir:
		return
	_current_dir = dir_name

	var anim_name := "walk_" + dir_name
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


func setup_path(spawn_index: int) -> void:
	_spawn_index = spawn_index
	if is_flying():
		_waypoints = PathfindingManager.get_flying_path(spawn_index)
	else:
		_waypoints = PathfindingManager.get_path_for_spawn(spawn_index)

	if not _waypoints.is_empty():
		global_position = _waypoints[0]
		_waypoint_index = 1
	_total_path_length = _calculate_path_length(_waypoints)
	_distance_traveled = 0.0

	# Zig-zag for press_drone: compute perpendicular to overall flight direction
	if enemy_data and enemy_data.enemy_id == "press_drone" and _waypoints.size() >= 2:
		_zigzag_enabled = true
		var flight_dir := (_waypoints[_waypoints.size() - 1] - _waypoints[0]).normalized()
		_zigzag_perpendicular = Vector2(-flight_dir.y, flight_dir.x)


func apply_wave_modifiers(modifiers: Dictionary) -> void:
	if modifiers.has("hp_multiplier"):
		health.max_hp *= modifiers["hp_multiplier"]
		health.current_hp = health.max_hp
	if modifiers.has("speed_multiplier"):
		base_speed *= modifiers["speed_multiplier"]
	if modifiers.has("armor_bonus"):
		health.armor += modifiers["armor_bonus"]
	health_bar.max_value = health.max_hp
	health_bar.value = health.current_hp


func _process(delta: float) -> void:
	# Animate rotor blades for flying enemies
	if _rotor_sprite and not _rotor_textures.is_empty():
		_rotor_timer += delta
		if _rotor_timer >= ROTOR_FRAME_TIME:
			_rotor_timer -= ROTOR_FRAME_TIME
			_rotor_frame = (_rotor_frame + 1) % _rotor_textures.size()
			_rotor_sprite.texture = _rotor_textures[_rotor_frame]

	# Move along waypoints
	if _waypoints.is_empty() or _waypoint_index >= _waypoints.size():
		return

	var slow_factor := status_effects.get_slow_factor()
	var current_speed := base_speed * slow_factor
	var move_budget := current_speed * 32.0 * delta

	# Remove previous zig-zag offset before moving along path
	if _zigzag_enabled:
		global_position -= _zigzag_perpendicular * _zigzag_current_offset

	# Track movement direction for animation
	var prev_pos := global_position

	while move_budget > 0.0 and _waypoint_index < _waypoints.size():
		var target_pos := _waypoints[_waypoint_index]
		var to_target := target_pos - global_position
		var dist_to_target := to_target.length()

		if dist_to_target <= move_budget:
			global_position = target_pos
			move_budget -= dist_to_target
			_distance_traveled += dist_to_target
			_waypoint_index += 1
		else:
			global_position += to_target.normalized() * move_budget
			_distance_traveled += move_budget
			move_budget = 0.0

	# Apply zig-zag offset after movement
	if _zigzag_enabled:
		_zigzag_time += delta
		_zigzag_current_offset = sin(_zigzag_time * ZIGZAG_FREQUENCY * TAU) * ZIGZAG_AMPLITUDE
		global_position += _zigzag_perpendicular * _zigzag_current_offset

	# Update walk animation direction and velocity for crossfire
	var move_dir := global_position - prev_pos
	velocity = move_dir
	_update_animation_direction(move_dir)

	# Orbit camera zone around helicopter and redraw beam
	if _camera_zone and is_instance_valid(_camera_zone):
		_camera_orbit_angle += CAMERA_ORBIT_SPEED * TAU * delta
		_camera_zone.position = Vector2(
			cos(_camera_orbit_angle),
			sin(_camera_orbit_angle) * 0.5  # Isometric Y squash
		) * CAMERA_ORBIT_RADIUS
	if _camera_beam_node and is_instance_valid(_camera_beam_node):
		_camera_beam_node.queue_redraw()

	# Apply DoT (raw damage, bypasses armor but uses proper death handling)
	var dot_dmg := status_effects.get_dot_damage(delta)
	if dot_dmg > 0.0 and not health.is_dead:
		health.current_hp -= dot_dmg
		health.current_hp = max(health.current_hp, 0.0)
		health.health_changed.emit(health.current_hp, health.max_hp)
		if health.current_hp <= 0.0:
			health.is_dead = true
			health.died.emit()

	# Check if reached end of path
	if _waypoint_index >= _waypoints.size():
		_reached_end()


func _on_path_updated(spawn_index: int) -> void:
	if spawn_index != _spawn_index or is_flying():
		return

	var new_waypoints := PathfindingManager.get_path_for_spawn(spawn_index)
	if new_waypoints.is_empty():
		return

	var closest_idx := 0
	var closest_dist := INF
	for i in new_waypoints.size():
		var dist := global_position.distance_squared_to(new_waypoints[i])
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i

	_waypoints = new_waypoints
	_waypoint_index = closest_idx
	_total_path_length = _calculate_path_length(new_waypoints)
	_distance_traveled = 0.0
	for i in range(1, closest_idx):
		_distance_traveled += new_waypoints[i - 1].distance_to(new_waypoints[i])


func _on_died() -> void:
	_cleanup_camera_zone()
	SignalBus.enemy_killed.emit(self, loot.gold_reward)
	_spawn_gold_coins()
	set_process(false)

	var hit_area := get_node_or_null("HitArea") as Area2D
	if hit_area:
		hit_area.set_deferred("monitorable", false)
		hit_area.set_deferred("monitoring", false)
	health_bar.visible = false

	var visual: CanvasItem = animated_sprite if _use_animated else sprite

	# Play death animation if available
	if _use_animated and animated_sprite.sprite_frames:
		var death_anim := "death_" + _current_dir
		if not animated_sprite.sprite_frames.has_animation(death_anim):
			death_anim = "death_se"
		if animated_sprite.sprite_frames.has_animation(death_anim):
			animated_sprite.play(death_anim)
			await animated_sprite.animation_finished

	# Flying enemies: stop rotors, drop visual to ground level on death
	if is_flying():
		visual.position.y = 0.0
		_zigzag_enabled = false
		if _rotor_sprite:
			_rotor_sprite.queue_free()
			_rotor_sprite = null
		if _shadow_sprite and is_instance_valid(_shadow_sprite):
			_shadow_sprite.queue_free()
			_shadow_sprite = null

	# Show corpse: tint dark, lower z-index so living enemies walk over
	visual.modulate = Color("#3A3A3E")
	z_index = -1

	# Enforce corpse cap: fade oldest if over limit
	_corpses.append(self)
	while _corpses.size() > MAX_CORPSES:
		var oldest := _corpses.pop_front() as Node2D
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Linger 2.5s then fade out
	var corpse_tween := create_tween()
	corpse_tween.tween_interval(2.5)
	corpse_tween.tween_property(visual, "modulate:a", 0.0, 0.5)
	corpse_tween.tween_callback(_remove_corpse_and_free)


func _remove_corpse_and_free() -> void:
	_corpses.erase(self)
	queue_free()


func _on_health_changed(current: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current

	# Speed burst: one-time speed increase when HP drops below threshold
	if not _speed_burst_triggered and enemy_data and enemy_data.speed_burst_threshold > 0.0:
		var ratio := current / max_hp if max_hp > 0.0 else 1.0
		if ratio <= enemy_data.speed_burst_threshold and ratio > 0.0:
			_speed_burst_triggered = true
			base_speed *= enemy_data.speed_burst_multiplier
			_flash_speed_burst()


func _on_damage_taken(amount: float, damage_type: Enums.DamageType, is_crit: bool) -> void:
	SignalBus.enemy_damaged.emit(self, amount, damage_type)
	_spawn_damage_number(amount, damage_type, is_crit)
	_spawn_impact_sparks(damage_type)
	_flash_damage()
	_play_hit_reaction()


func _play_hit_reaction() -> void:
	if health.is_dead:
		return
	var visual: CanvasItem = animated_sprite if _use_animated else sprite

	# Micro-knockback in opposite direction of movement
	var knockback_dir := Vector2.ZERO
	if _waypoint_index < _waypoints.size():
		knockback_dir = -(_waypoints[_waypoint_index] - global_position).normalized()
	var tween := create_tween()
	tween.tween_property(visual, "position", visual.position + knockback_dir * 1.5, 0.05)
	tween.tween_property(visual, "position", Vector2.ZERO, 0.05)

	# If AnimatedSprite has hit animation for current direction, flash it
	if _use_animated and animated_sprite.sprite_frames:
		var hit_anim := "hit_" + _current_dir
		if animated_sprite.sprite_frames.has_animation(hit_anim):
			animated_sprite.play(hit_anim)
			await animated_sprite.animation_finished
			if not health.is_dead:
				animated_sprite.play("walk_" + _current_dir)


func _reached_end() -> void:
	_cleanup_camera_zone()
	var hp_ratio := health.current_hp / health.max_hp if health.max_hp > 0.0 else 1.0
	if hp_ratio < 0.1 and hp_ratio > 0.0:
		SignalBus.near_miss.emit(self, health.current_hp)
		_spawn_near_miss_label()

	SignalBus.enemy_reached_end.emit(self, loot.lives_cost)
	queue_free()


# -- Game Juice Effects --

func _spawn_damage_number(amount: float, damage_type: Enums.DamageType, is_crit: bool) -> void:
	var label := Label.new()
	var text := str(int(amount))
	if is_crit:
		text += "!"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var color: Color = DAMAGE_COLORS.get(damage_type, Color.WHITE)
	label.add_theme_color_override("font_color", color)

	if is_crit:
		label.add_theme_font_size_override("font_size", 14)
	else:
		label.add_theme_font_size_override("font_size", 10)

	label.global_position = global_position + Vector2(-12, -20)
	label.z_index = 100

	get_tree().current_scene.add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 20.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)


func _flash_damage() -> void:
	if not _flash_material:
		return
	_flash_material.set_shader_parameter("flash_amount", 1.0)
	var tween := create_tween()
	tween.tween_property(_flash_material, "shader_parameter/flash_amount", 0.0, 0.15)


func _flash_speed_burst() -> void:
	var visual: CanvasItem = animated_sprite if _use_animated else sprite
	var original_modulate := visual.modulate
	visual.modulate = Color(1.5, 1.2, 0.8)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", original_modulate, 0.3)


func _spawn_impact_sparks(damage_type: Enums.DamageType) -> void:
	var spark_color: Color = DAMAGE_COLORS.get(damage_type, Color("#C8A040"))
	var spark_count := 3
	for i in spark_count:
		var spark := ColorRect.new()
		spark.size = Vector2(2, 2)
		spark.color = spark_color
		spark.global_position = global_position + Vector2(-1, -1)
		spark.z_index = 80
		get_tree().current_scene.add_child(spark)
		var dir := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var target_pos := spark.global_position + dir * randf_range(6, 14)
		var tween := spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", target_pos, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(spark.queue_free)


func _spawn_gold_coins() -> void:
	var coin_count := clampi(loot.gold_reward / 5, 3, 5)
	for i in coin_count:
		var coin := ColorRect.new()
		coin.size = Vector2(4, 4)
		coin.color = Color("#E0C060")
		coin.global_position = global_position + Vector2(-2, -2)
		coin.z_index = 100

		get_tree().current_scene.add_child(coin)

		var target_pos := Vector2(40, 12)
		var arc_offset := Vector2(randf_range(-30, 30), randf_range(-40, -10))
		var mid_point := coin.global_position + arc_offset

		var tween := coin.create_tween()
		var delay := i * 0.05
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_property(coin, "global_position", mid_point, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "global_position", target_pos, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_callback(coin.queue_free)


func _spawn_near_miss_label() -> void:
	var label := Label.new()
	var hp_left := int(health.current_hp)
	label.text = "Almost! " + str(hp_left) + " HP left!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#C87878"))
	label.add_theme_font_size_override("font_size", 11)
	label.global_position = global_position + Vector2(-40, -24)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 28.0, 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.chain().tween_callback(label.queue_free)


# -- Public API for targeting system --

func get_path_progress() -> float:
	if _total_path_length <= 0.0:
		return 0.0
	return _distance_traveled / _total_path_length


func is_flying() -> bool:
	return _movement_type == Enums.MovementType.FLYING


func is_stealthed() -> bool:
	return _stealth


func get_vulnerability_modifier() -> float:
	return status_effects.get_vulnerability_modifier()


func get_armor_shred() -> float:
	return status_effects.get_armor_shred()


# -- News Helicopter Camera Zone --

func _setup_camera_zone() -> void:
	# Area2D at ground level (child of root, not visual offset) that detects tower bodies
	_camera_zone = Area2D.new()
	_camera_zone.name = "CameraZone"
	_camera_zone.collision_layer = 0
	_camera_zone.collision_mask = 0
	_camera_zone.set_collision_mask_value(6, true)  # Detect tower bodies on layer 6
	_camera_zone.monitoring = true
	_camera_zone.monitorable = false
	var zone_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = CAMERA_ZONE_RADIUS
	zone_shape.shape = circle
	_camera_zone.add_child(zone_shape)
	add_child(_camera_zone)

	_camera_zone.area_entered.connect(_on_tower_entered_camera)
	_camera_zone.area_exited.connect(_on_tower_exited_camera)

	# Camera beam visual node (custom draw)
	_camera_beam_node = Node2D.new()
	_camera_beam_node.name = "CameraBeam"
	_camera_beam_node.z_index = 5
	add_child(_camera_beam_node)
	_camera_beam_node.draw.connect(_draw_camera_beam)
	_camera_beam_node.queue_redraw()


func _on_tower_entered_camera(area: Area2D) -> void:
	var tower := area.get_parent()
	if tower is BaseTower:
		tower.suppress()
		if not _suppressed_towers.has(tower):
			_suppressed_towers.append(tower)


func _on_tower_exited_camera(area: Area2D) -> void:
	var tower := area.get_parent()
	if tower is BaseTower:
		tower.unsuppress()
		_suppressed_towers.erase(tower)


func _cleanup_camera_zone() -> void:
	# Unsuppress all tracked towers
	for tower in _suppressed_towers:
		if is_instance_valid(tower) and tower is BaseTower:
			tower.unsuppress()
	_suppressed_towers.clear()

	if _camera_zone and is_instance_valid(_camera_zone):
		_camera_zone.queue_free()
		_camera_zone = null
	if _camera_beam_node and is_instance_valid(_camera_beam_node):
		_camera_beam_node.queue_free()
		_camera_beam_node = null


func _draw_camera_beam() -> void:
	if not _camera_beam_node or not _camera_zone:
		return
	# Visual node is offset up; beam goes from helicopter to orbiting ground zone
	var visual: CanvasItem = animated_sprite if _use_animated else sprite
	var top_y: float = visual.position.y  # Negative (above ground)
	var zone_pos: Vector2 = _camera_zone.position  # Orbiting offset from helicopter

	# Triangular cone: narrow at helicopter, wide at orbiting ground zone
	var top_half_w := 4.0
	var bottom_half_w := CAMERA_ZONE_RADIUS * 0.4
	# Perpendicular to beam direction for cone width
	var beam_dir := (zone_pos - Vector2(0, top_y))
	var perp := Vector2(-beam_dir.y, beam_dir.x).normalized()

	var beam_points := PackedVector2Array([
		Vector2(-perp.x * top_half_w, top_y - perp.y * top_half_w),
		Vector2(perp.x * top_half_w, top_y + perp.y * top_half_w),
		zone_pos + perp * bottom_half_w,
		zone_pos - perp * bottom_half_w,
	])
	_camera_beam_node.draw_colored_polygon(beam_points, CAMERA_BEAM_COLOR)

	# Ground ellipse at orbiting zone position
	var ellipse_hw := CAMERA_ZONE_RADIUS * 0.6
	var ellipse_hh := CAMERA_ZONE_RADIUS * 0.3
	var segments := 32
	# Fill
	var ellipse_fill := PackedVector2Array()
	for i in segments:
		var angle := float(i) / float(segments) * TAU
		ellipse_fill.append(zone_pos + Vector2(cos(angle) * ellipse_hw, sin(angle) * ellipse_hh))
	_camera_beam_node.draw_colored_polygon(ellipse_fill, CAMERA_BEAM_COLOR)
	# Outline
	for i in segments:
		var a0 := float(i) / float(segments) * TAU
		var a1 := float(i + 1) / float(segments) * TAU
		var p0 := zone_pos + Vector2(cos(a0) * ellipse_hw, sin(a0) * ellipse_hh)
		var p1 := zone_pos + Vector2(cos(a1) * ellipse_hw, sin(a1) * ellipse_hh)
		_camera_beam_node.draw_line(p0, p1, CAMERA_BEAM_OUTLINE, 1.0)


func _calculate_path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length
