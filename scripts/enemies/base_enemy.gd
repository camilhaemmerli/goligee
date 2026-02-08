class_name BaseEnemy
extends PathFollow2D
## Base class for all enemies. Follows a Path2D and takes damage.
## Composed of child components: HealthComponent, ResistanceComponent,
## StatusEffectManager, LootComponent.

@export var enemy_data: EnemyData

@onready var health: HealthComponent = $HealthComponent
@onready var resistances: ResistanceComponent = $ResistanceComponent
@onready var status_effects: StatusEffectManager = $StatusEffectManager
@onready var loot: LootComponent = $LootComponent
@onready var sprite: Sprite2D = $Sprite2D

var base_speed: float = 1.0
var _movement_type: Enums.MovementType = Enums.MovementType.GROUND
var _stealth: bool = false


func _ready() -> void:
	if enemy_data:
		_init_from_data()

	health.died.connect(_on_died)
	health.damage_taken.connect(_on_damage_taken)


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


func apply_wave_modifiers(modifiers: Dictionary) -> void:
	if modifiers.has("hp_multiplier"):
		health.max_hp *= modifiers["hp_multiplier"]
		health.current_hp = health.max_hp
	if modifiers.has("speed_multiplier"):
		base_speed *= modifiers["speed_multiplier"]
	if modifiers.has("armor_bonus"):
		health.armor += modifiers["armor_bonus"]


func _process(delta: float) -> void:
	# Move along path
	var slow_factor := status_effects.get_slow_factor()
	var current_speed := base_speed * slow_factor
	# Convert tile speed to pixel speed (32px per tile)
	progress += current_speed * 32.0 * delta

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
	if progress_ratio >= 1.0:
		_reached_end()


func _on_died() -> void:
	SignalBus.enemy_killed.emit(self, loot.gold_reward)
	# TODO: death animation and particle burst
	queue_free()


func _on_damage_taken(amount: float, damage_type: Enums.DamageType, is_crit: bool) -> void:
	SignalBus.enemy_damaged.emit(self, amount, damage_type)
	# TODO: damage flash shader + floating damage number


func _reached_end() -> void:
	SignalBus.enemy_reached_end.emit(self, loot.lives_cost)
	queue_free()


# -- Public API for targeting system --

func get_path_progress() -> float:
	return progress_ratio


func is_flying() -> bool:
	return _movement_type == Enums.MovementType.FLYING


func is_stealthed() -> bool:
	return _stealth


func get_vulnerability_modifier() -> float:
	return status_effects.get_vulnerability_modifier()
