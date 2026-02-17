class_name TowerData
extends Resource

@export var tower_id: String
@export var tower_name: String
@export var description: String
@export var icon: Texture2D
@export var scene: PackedScene

@export_group("Cost")
@export var build_cost: int = 100
@export var sell_ratio: float = 0.65

@export_group("Combat")
@export var base_damage: float = 10.0
@export var damage_type: Enums.DamageType = Enums.DamageType.KINETIC
@export var base_range: float = 4.0
@export var fire_rate: float = 1.0
@export var projectile_type: Enums.ProjectileType = Enums.ProjectileType.ARROW
@export var projectile_scene: PackedScene
@export var area_of_effect: float = 0.0
@export var pierce_count: int = 1
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
@export var chain_targets: int = 0
@export var chain_damage_falloff: float = 0.5
@export var crossfire_bonus: float = 0.0
@export var can_target_flying: bool = true
@export var on_hit_effects: Array[StatusEffectData] = []

@export_group("Upgrades")
@export var upgrade_paths: Array[UpgradePathData] = []


func get_display_name() -> String:
	var skin := ThemeManager.get_tower_skin(tower_id) if tower_id else null
	if skin and skin.display_name:
		return skin.display_name
	return tower_name


func get_icon() -> Texture2D:
	var skin := ThemeManager.get_tower_skin(tower_id) if tower_id else null
	if skin and skin.icon:
		return skin.icon
	return icon


func get_description() -> String:
	var skin := ThemeManager.get_tower_skin(tower_id) if tower_id else null
	if skin and skin.description:
		return skin.description
	return description
