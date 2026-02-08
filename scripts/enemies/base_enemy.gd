class_name BaseEnemy
extends Node2D
## Base class for all enemies. Follows waypoints from PathfindingManager.
## Composed of child components: HealthComponent, ResistanceComponent,
## StatusEffectManager, LootComponent.

@export var enemy_data: EnemyData

@onready var health: HealthComponent = $HealthComponent
@onready var resistances: ResistanceComponent = $ResistanceComponent
@onready var status_effects: StatusEffectManager = $StatusEffectManager
@onready var loot: LootComponent = $LootComponent
@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

var base_speed: float = 1.0
var _movement_type: Enums.MovementType = Enums.MovementType.GROUND
var _stealth: bool = false

var _waypoints: PackedVector2Array = PackedVector2Array()
var _waypoint_index: int = 0
var _spawn_index: int = -1
var _distance_traveled: float = 0.0
var _total_path_length: float = 0.0


func _ready() -> void:
	if enemy_data:
		_init_from_data()

	# Fallback placeholder sprite when no texture is assigned
	if not sprite.texture:
		sprite.texture = PlaceholderSprites.create_diamond(16, Color("#D06070"))

	health.died.connect(_on_died)
	health.damage_taken.connect(_on_damage_taken)
	health.health_changed.connect(_on_health_changed)

	# Initialize health bar
	health_bar.max_value = health.max_hp
	health_bar.value = health.current_hp

	if not is_flying():
		PathfindingManager.path_updated.connect(_on_path_updated)


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
	if skin and skin.sprite_sheet:
		sprite.texture = skin.sprite_sheet
	if skin and skin.tint != Color.WHITE:
		sprite.modulate = skin.tint


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


func apply_wave_modifiers(modifiers: Dictionary) -> void:
	if modifiers.has("hp_multiplier"):
		health.max_hp *= modifiers["hp_multiplier"]
		health.current_hp = health.max_hp
	if modifiers.has("speed_multiplier"):
		base_speed *= modifiers["speed_multiplier"]
	if modifiers.has("armor_bonus"):
		health.armor += modifiers["armor_bonus"]


func _process(delta: float) -> void:
	# Move along waypoints
	if _waypoints.is_empty() or _waypoint_index >= _waypoints.size():
		return

	var slow_factor := status_effects.get_slow_factor()
	var current_speed := base_speed * slow_factor
	var move_budget := current_speed * 32.0 * delta

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

	# Apply DoT
	var dot_dmg := status_effects.get_dot_damage(delta)
	if dot_dmg > 0.0:
		health.current_hp -= dot_dmg
		health.current_hp = max(health.current_hp, 0.0)
		health.health_changed.emit(health.current_hp, health.max_hp)
		if health.current_hp <= 0.0 and not health.is_dead:
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

	# Find closest waypoint on new path to reroute mid-walk
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
	# Approximate distance traveled based on new path
	_distance_traveled = 0.0
	for i in range(1, closest_idx):
		_distance_traveled += new_waypoints[i - 1].distance_to(new_waypoints[i])


func _on_died() -> void:
	SignalBus.enemy_killed.emit(self, loot.gold_reward)
	# TODO: death animation and particle burst
	queue_free()


func _on_health_changed(current: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current


func _on_damage_taken(amount: float, damage_type: Enums.DamageType, is_crit: bool) -> void:
	SignalBus.enemy_damaged.emit(self, amount, damage_type)
	# TODO: damage flash shader + floating damage number


func _reached_end() -> void:
	SignalBus.enemy_reached_end.emit(self, loot.lives_cost)
	queue_free()


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


func _calculate_path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length
