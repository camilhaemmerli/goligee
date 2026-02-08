class_name BaseTower
extends Node2D
## Base class for all tower types. Composed of child components:
##   WeaponComponent, TargetingComponent, UpgradeComponent
## Subclass scenes override exported data and can add extra nodes.

@export var tower_data: TowerData

@onready var weapon: WeaponComponent = $WeaponComponent
@onready var targeting: TargetingComponent = $TargetingComponent
@onready var upgrade: UpgradeComponent = $UpgradeComponent
@onready var range_area: Area2D = $RangeArea
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer: Timer = $AttackTimer

var _tile_pos: Vector2i


func _ready() -> void:
	if tower_data:
		_init_from_data()

	# Fallback placeholder sprite when no texture is assigned
	if not sprite.texture:
		sprite.texture = PlaceholderSprites.create_diamond(20, Color("#90A0B8"))

	range_area.area_entered.connect(_on_enemy_entered_range)
	range_area.area_exited.connect(_on_enemy_exited_range)
	attack_timer.timeout.connect(_on_attack_timer)
	upgrade.upgraded.connect(_on_upgraded)


func _init_from_data() -> void:
	weapon.base_damage = tower_data.base_damage
	weapon.damage_type = tower_data.damage_type
	weapon.projectile_type = tower_data.projectile_type
	weapon.projectile_scene = tower_data.projectile_scene
	weapon.area_of_effect = tower_data.area_of_effect
	weapon.pierce_count = tower_data.pierce_count
	weapon.crit_chance = tower_data.crit_chance
	weapon.crit_multiplier = tower_data.crit_multiplier
	weapon.on_hit_effects = tower_data.on_hit_effects
	weapon._recalculate()

	attack_timer.wait_time = 1.0 / tower_data.fire_rate
	attack_timer.start()

	_update_range_shape(tower_data.base_range)
	upgrade.init(tower_data)
	_apply_theme_skin()


func _apply_theme_skin() -> void:
	if not tower_data or not tower_data.tower_id:
		return
	var skin = ThemeManager.get_tower_skin(tower_data.tower_id)
	if skin and skin.sprite_sheet:
		sprite.texture = skin.sprite_sheet
	if skin and skin.icon:
		tower_data.icon = skin.icon


func _update_range_shape(range_val: float) -> void:
	var collision := range_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		var shape := CircleShape2D.new()
		# Convert tile range to pixel range (32px per tile width)
		shape.radius = range_val * 32.0
		collision.shape = shape


func _on_enemy_entered_range(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy is BaseEnemy:
		targeting.add_enemy(enemy)


func _on_enemy_exited_range(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy is BaseEnemy:
		targeting.remove_enemy(enemy)


func _on_attack_timer() -> void:
	var target := targeting.update_target(global_position)
	if target:
		_fire_at(target)


func _fire_at(target: Node2D) -> void:
	if weapon.projectile_scene:
		var proj: Node2D = weapon.projectile_scene.instantiate()
		proj.global_position = global_position
		if proj.has_method("init"):
			proj.init(
				target,
				weapon.final_damage,
				weapon.damage_type,
				weapon.final_aoe,
				weapon.final_pierce,
				weapon.final_crit_chance,
				weapon.final_crit_multiplier,
				weapon.on_hit_effects,
			)
		# Add to the projectile container in the game scene
		var proj_container := get_tree().get_first_node_in_group("projectiles")
		if proj_container:
			proj_container.add_child(proj)
		else:
			get_parent().add_child(proj)

	weapon.fired.emit(target)


func _on_upgraded(path_index: int, tier: int) -> void:
	# Reapply all accumulated modifiers to weapon and range
	weapon.apply_stat_modifiers(upgrade.active_modifiers)

	# Recompute fire rate
	var final_rate := tower_data.fire_rate
	for mod in upgrade.active_modifiers:
		if mod.stat_name == "fire_rate":
			match mod.operation:
				Enums.ModifierOp.ADD:
					final_rate += mod.value
				Enums.ModifierOp.MULTIPLY:
					final_rate *= mod.value
				Enums.ModifierOp.SET:
					final_rate = mod.value
	attack_timer.wait_time = 1.0 / max(final_rate, 0.1)

	# Recompute range
	var final_range := tower_data.base_range
	for mod in upgrade.active_modifiers:
		if mod.stat_name == "base_range":
			match mod.operation:
				Enums.ModifierOp.ADD:
					final_range += mod.value
				Enums.ModifierOp.MULTIPLY:
					final_range *= mod.value
				Enums.ModifierOp.SET:
					final_range = mod.value
	_update_range_shape(final_range)


func get_sell_value() -> int:
	return int(upgrade.get_total_invested() * tower_data.sell_ratio)


func sell() -> void:
	var refund := get_sell_value()
	EconomyManager.add_gold(refund)
	PathfindingManager.remove_tower(_tile_pos)
	SignalBus.tower_sold.emit(self, refund)
	queue_free()
