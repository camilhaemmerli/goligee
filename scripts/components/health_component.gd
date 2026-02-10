class_name HealthComponent
extends Node
## Attach to any entity that can take damage.
## Manages HP, armor, shield, and death.

signal health_changed(current: float, maximum: float)
signal shield_changed(current: float)
signal died()
signal damage_taken(amount: float, damage_type: Enums.DamageType, is_crit: bool)

@export var max_hp: float = 100.0
@export var armor: float = 0.0
@export var armor_type: Enums.ArmorType = Enums.ArmorType.UNARMORED
@export var shield: float = 0.0
@export var max_shield: float = 0.0
@export var shield_regen_rate: float = 0.0

var current_hp: float
var current_shield: float
var is_dead: bool = false


func _ready() -> void:
	current_hp = max_hp
	current_shield = shield
	max_shield = shield


func take_damage(
	base_damage: float,
	damage_type: Enums.DamageType,
	elemental_resistances: Dictionary = {},
	vulnerability_mod: float = 1.0,
	crit_chance: float = 0.0,
	crit_mult: float = 2.0,
	armor_shred: float = 0.0,
) -> void:
	if is_dead:
		return

	var effective_armor := armor * (1.0 - clampf(armor_shred, 0.0, 1.0))
	var result := DamageCalculator.calculate_damage(
		base_damage, damage_type, armor_type, effective_armor,
		elemental_resistances, vulnerability_mod,
		crit_chance, crit_mult,
	)
	var dmg: float = result["damage"]
	var is_crit: bool = result["is_crit"]

	# Shield absorbs first
	if current_shield > 0.0:
		var absorbed: float = min(current_shield, dmg)
		current_shield -= absorbed
		dmg -= absorbed
		shield_changed.emit(current_shield)

	current_hp -= dmg
	current_hp = max(current_hp, 0.0)
	health_changed.emit(current_hp, max_hp)
	damage_taken.emit(dmg, damage_type, is_crit)

	if current_hp <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead:
		return
	current_hp = min(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)


func add_shield(amount: float) -> void:
	current_shield = min(current_shield + amount, max_shield if max_shield > 0.0 else amount)
	shield_changed.emit(current_shield)


func _process(delta: float) -> void:
	if shield_regen_rate > 0.0 and current_shield < max_shield and not is_dead:
		current_shield = min(current_shield + shield_regen_rate * delta, max_shield)
		shield_changed.emit(current_shield)


func get_hp_ratio() -> float:
	return current_hp / max_hp if max_hp > 0.0 else 0.0
