class_name SpawnSequenceData
extends Resource

@export var enemy_data: EnemyData
@export var count: int = 10
@export var spawn_interval: float = 0.8
@export var start_delay: float = 0.0
@export var spawn_point_index: int = 0

@export_group("Modifiers")
@export var hp_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var armor_bonus: float = 0.0
