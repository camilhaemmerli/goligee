class_name UpgradeTierData
extends Resource

@export var tier_name: String
@export var description: String
@export var cost: int = 100
@export var stat_modifiers: Array[StatModifierData] = []
@export var unlocks_ability: StatusEffectData
@export var visual_override: Texture2D
