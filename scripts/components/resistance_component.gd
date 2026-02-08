class_name ResistanceComponent
extends Node
## Stores per-damage-type resistance multipliers for an enemy.
## 1.0 = normal, 0.5 = 50% resist, 0.0 = immune, 2.0 = double damage.

## Key: Enums.DamageType, Value: float multiplier
@export var resistances: Dictionary = {}


func get_resistance(damage_type: Enums.DamageType) -> float:
	if resistances.has(damage_type):
		return resistances[damage_type]
	return 1.0


func set_resistance(damage_type: Enums.DamageType, value: float) -> void:
	resistances[damage_type] = value


func get_all() -> Dictionary:
	return resistances
