class_name StatusEffectData
extends Resource

@export var effect_type: Enums.StatusEffectType = Enums.StatusEffectType.SLOW
@export var duration: float = 2.0
@export var potency: float = 0.5  ## e.g. 0.5 = 50% slow, or 10 = 10 DPS for burn
@export var stack_limit: int = 1
@export var apply_chance: float = 1.0
