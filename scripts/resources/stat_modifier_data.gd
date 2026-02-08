class_name StatModifierData
extends Resource

## Which stat this modifier affects. Use the string name of the property
## on the tower/enemy (e.g. "base_damage", "base_range", "fire_rate").
@export var stat_name: String
@export var operation: Enums.ModifierOp = Enums.ModifierOp.MULTIPLY
@export var value: float = 1.0
