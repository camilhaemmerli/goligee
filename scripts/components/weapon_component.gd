class_name WeaponComponent
extends Node
## Defines how a tower deals damage. Attach as a child of a tower scene.

signal fired(target: Node2D)

@export var base_damage: float = 10.0
@export var damage_type: Enums.DamageType = Enums.DamageType.KINETIC
@export var projectile_type: Enums.ProjectileType = Enums.ProjectileType.ARROW
@export var projectile_scene: PackedScene
@export var area_of_effect: float = 0.0
@export var pierce_count: int = 1
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
@export var chain_targets: int = 0
@export var chain_damage_falloff: float = 0.5

## Status effects applied on hit
@export var on_hit_effects: Array[StatusEffectData] = []

## Computed final values after upgrade modifiers
var final_damage: float
var final_aoe: float
var final_pierce: int
var final_crit_chance: float
var final_crit_multiplier: float

## Synergy multiplier applied on top of upgrade-modified damage
var synergy_damage_mult: float = 1.0


func _ready() -> void:
	_recalculate()


func _recalculate() -> void:
	final_damage = base_damage
	final_aoe = area_of_effect
	final_pierce = pierce_count
	final_crit_chance = crit_chance
	final_crit_multiplier = crit_multiplier


func apply_stat_modifiers(modifiers: Array[StatModifierData]) -> void:
	final_damage = base_damage
	final_aoe = area_of_effect
	final_pierce = pierce_count
	final_crit_chance = crit_chance
	final_crit_multiplier = crit_multiplier

	for mod in modifiers:
		match mod.stat_name:
			"base_damage":
				final_damage = _apply_mod(final_damage, mod)
			"area_of_effect":
				final_aoe = _apply_mod(final_aoe, mod)
			"pierce_count":
				final_pierce = int(_apply_mod(float(final_pierce), mod))
			"crit_chance":
				final_crit_chance = _apply_mod(final_crit_chance, mod)
			"crit_multiplier":
				final_crit_multiplier = _apply_mod(final_crit_multiplier, mod)
			"chain_targets":
				chain_targets = int(_apply_mod(float(chain_targets), mod))


## Called by SynergyManager to apply/update the synergy damage multiplier.
func apply_synergy(damage_mult: float) -> void:
	synergy_damage_mult = damage_mult
	# Re-apply: final_damage already holds upgrade-modified value; layer synergy on top
	# We need to strip old synergy first, so recompute from base + upgrades
	var tower: BaseTower = get_parent() as BaseTower
	if tower and tower.upgrade:
		apply_stat_modifiers(tower.upgrade.active_modifiers)
	else:
		_recalculate()
	final_damage *= synergy_damage_mult


func _apply_mod(base: float, mod: StatModifierData) -> float:
	match mod.operation:
		Enums.ModifierOp.ADD:
			return base + mod.value
		Enums.ModifierOp.MULTIPLY:
			return base * mod.value
		Enums.ModifierOp.SET:
			return mod.value
	return base
