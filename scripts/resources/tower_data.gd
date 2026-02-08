class_name TowerData
extends Resource

@export var tower_name: String
@export var description: String
@export var icon: Texture2D
@export var scene: PackedScene

@export_group("Cost")
@export var build_cost: int = 100
@export var sell_ratio: float = 0.6

@export_group("Combat")
@export var base_damage: float = 10.0
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var base_range: float = 4.0
@export var fire_rate: float = 1.0
@export var projectile_type: Enums.ProjectileType = Enums.ProjectileType.ARROW
@export var projectile_scene: PackedScene
@export var area_of_effect: float = 0.0
@export var pierce_count: int = 1
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0

@export_group("Upgrades")
@export var upgrade_paths: Array[UpgradePathData] = []
