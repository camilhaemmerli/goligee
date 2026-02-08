class_name EnemyData
extends Resource

@export var enemy_name: String
@export var description: String
@export var scene: PackedScene

@export_group("Stats")
@export var max_hp: float = 100.0
@export var base_speed: float = 1.0
@export var armor: float = 0.0
@export var armor_type: Enums.ArmorType = Enums.ArmorType.UNARMORED
@export var shield: float = 0.0
@export var movement_type: Enums.MovementType = Enums.MovementType.GROUND

@export_group("Resistances")
## Multiplier per damage type. 1.0 = normal, 0.5 = 50% resist, 0.0 = immune, 2.0 = double damage.
@export var resistances: Dictionary = {}

@export_group("Rewards")
@export var gold_reward: int = 5
@export var lives_cost: int = 1

@export_group("Abilities")
@export var abilities: Array[StatusEffectData] = []
@export var is_stealth: bool = false
@export var splits_on_death: bool = false
@export var split_count: int = 0
@export var split_enemy: EnemyData
