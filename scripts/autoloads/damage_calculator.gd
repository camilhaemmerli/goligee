extends Node
## Centralized damage formula. All damage goes through here so that
## resistances, armor, modifiers, and crits are applied consistently.

const ARMOR_CONSTANT = 100.0

## Armor-type multiplier matrix: ARMOR_MATRIX[damage_type][armor_type] -> float
## Row = DamageType enum index, Column = ArmorType enum index
## Order: Unarmored, Light, Medium, Heavy, Fortified, Boss
var ARMOR_MATRIX := {
	Enums.DamageType.KINETIC:         [1.0, 1.0,  1.0,  0.7,  0.5,  0.8],
	Enums.DamageType.CHEMICAL:        [1.25, 1.5, 1.0,  0.75, 0.5,  0.9],
	Enums.DamageType.HYDRAULIC:       [1.0, 1.25, 1.0,  1.0,  0.75, 0.85],
	Enums.DamageType.ELECTRIC:        [1.5, 1.0,  0.75, 1.25, 0.35, 0.9],
	Enums.DamageType.SONIC:           [1.5, 1.25, 1.0,  1.0,  1.0,  0.7],
	Enums.DamageType.DIRECTED_ENERGY: [1.0, 1.25, 0.75, 1.5,  0.35, 0.85],
	Enums.DamageType.CYBER:           [1.0, 1.0,  1.0,  1.0,  1.0,  1.0],
	Enums.DamageType.PSYCHOLOGICAL:   [1.25, 1.0, 1.0,  0.5,  0.5,  0.75],
}


func calculate_damage(
	base_damage: float,
	damage_type: Enums.DamageType,
	armor_type: Enums.ArmorType,
	armor_value: float,
	elemental_resistances: Dictionary,
	vulnerability_modifier: float,
	crit_chance: float,
	crit_multiplier: float,
) -> Dictionary:
	## Returns {"damage": float, "is_crit": bool}

	# Armor type multiplier
	var armor_type_mult: float = ARMOR_MATRIX[damage_type][armor_type]

	# Elemental resistance (per-enemy override)
	var elemental_mult: float = 1.0
	if elemental_resistances.has(damage_type):
		elemental_mult = elemental_resistances[damage_type]

	# Flat armor reduction (diminishing returns)
	var armor_reduction: float = armor_value / (armor_value + ARMOR_CONSTANT)

	# Crit roll
	var is_crit := randf() < crit_chance
	var crit_mult: float = crit_multiplier if is_crit else 1.0

	var final_damage: float = (
		base_damage
		* armor_type_mult
		* elemental_mult
		* (1.0 - armor_reduction)
		* vulnerability_modifier
		* crit_mult
	)

	return {"damage": max(final_damage, 0.0), "is_crit": is_crit}
