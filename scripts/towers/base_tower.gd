class_name BaseTower
extends Node2D
## Base class for all tower types. Composed of child components:
##   WeaponComponent, TargetingComponent, UpgradeComponent
## Uses base+turret architecture: static base sprite + rotating turret sprite.

@export var tower_data: TowerData

@onready var weapon: WeaponComponent = $WeaponComponent
@onready var targeting: TargetingComponent = $TargetingComponent
@onready var upgrade: UpgradeComponent = $UpgradeComponent
@onready var range_area: Area2D = $RangeArea
@onready var sprite: Sprite2D = $Sprite2D
@onready var turret_sprite: Sprite2D = $TurretSprite
@onready var muzzle_point: Marker2D = $MuzzlePoint
@onready var attack_timer: Timer = $AttackTimer

var _tile_pos: Vector2i
var kill_count: int = 0
var _show_range: bool = false

## Turret textures for 8 directions: S, SW, W, NW, N, NE, E, SE
var _turret_textures: Array[Texture2D] = []
## Direction names matching _turret_textures indices
const DIRS := ["s", "sw", "w", "nw", "n", "ne", "e", "se"]

const KILL_MILESTONES := [25, 50, 100, 250, 500, 1000]


func _ready() -> void:
	if tower_data:
		_init_from_data()

	# Themed fallback sprite based on tower_id
	if not sprite.texture:
		if tower_data and tower_data.tower_id:
			match tower_data.tower_id:
				"rubber_bullet":
					sprite.texture = EntitySprites.create_arrow_tower()
				"tear_gas":
					sprite.texture = EntitySprites.create_cannon_tower()
				"water_cannon":
					sprite.texture = EntitySprites.create_ice_tower()
				"taser_grid":
					sprite.texture = EntitySprites.create_tower_turret(Color("#505060"), Color("#E0E060"))
				"surveillance_hub":
					sprite.texture = EntitySprites.create_tower_turret(Color("#303040"), Color("#A0A0C0"))
				"pepper_spray":
					sprite.texture = EntitySprites.create_tower_turret(Color("#585050"), Color("#E08040"))
				"lrad_cannon":
					sprite.texture = EntitySprites.create_tower_turret(Color("#405040"), Color("#80E060"))
				"microwave_emitter":
					sprite.texture = EntitySprites.create_tower_turret(Color("#504058"), Color("#C080E0"))
				_:
					sprite.texture = EntitySprites.create_tower_turret(Color("#606068"), Color("#90A0B8"))
		else:
			sprite.texture = EntitySprites.create_tower_turret(Color("#606068"), Color("#90A0B8"))

	range_area.area_entered.connect(_on_enemy_entered_range)
	range_area.area_exited.connect(_on_enemy_exited_range)
	attack_timer.timeout.connect(_on_attack_timer)
	upgrade.upgraded.connect(_on_upgraded)
	SignalBus.enemy_killed.connect(_on_enemy_killed)
	SignalBus.tower_selected.connect(_on_tower_selected)
	SignalBus.tower_deselected.connect(_on_tower_deselected)


func _init_from_data() -> void:
	weapon.base_damage = tower_data.base_damage
	weapon.damage_type = tower_data.damage_type
	weapon.projectile_type = tower_data.projectile_type
	weapon.projectile_scene = tower_data.projectile_scene
	weapon.area_of_effect = tower_data.area_of_effect
	weapon.pierce_count = tower_data.pierce_count
	weapon.crit_chance = tower_data.crit_chance
	weapon.crit_multiplier = tower_data.crit_multiplier
	weapon.chain_targets = tower_data.chain_targets
	weapon.chain_damage_falloff = tower_data.chain_damage_falloff
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
	if not skin:
		return

	# Base+turret architecture: separate base and turret sprites
	if skin.base_texture:
		sprite.texture = skin.base_texture
		# Align the diamond ground (bottom of 64x64) with the tile center
		sprite.offset.y = -16
		turret_sprite.visible = true
		turret_sprite.position.y = skin.turret_y_offset + sprite.offset.y
		muzzle_point.position.y = skin.turret_y_offset + sprite.offset.y - 4.0
		if skin.turret_textures.size() == 8:
			_turret_textures = skin.turret_textures
			turret_sprite.texture = _turret_textures[7]  # Default: SE
		elif skin.turret_textures.size() > 0:
			turret_sprite.texture = skin.turret_textures[0]
	elif skin.sprite_sheet:
		# Legacy single-sprite mode
		sprite.texture = skin.sprite_sheet
		turret_sprite.visible = false

	if skin.icon:
		tower_data.icon = skin.icon


func _aim_at(target_pos: Vector2) -> void:
	"""Point turret toward target using 8-direction sprite swap."""
	if _turret_textures.size() != 8:
		return
	var angle := global_position.angle_to_point(target_pos)
	# angle_to_point: 0=right, PI/2=down. Map to 8 sectors.
	# Our DIRS order: S(0), SW(1), W(2), NW(3), N(4), NE(5), E(6), SE(7)
	# Offset so south=0: subtract PI/2 to rotate, then divide into 8 sectors
	var adjusted := angle - PI / 2.0  # Now 0=south
	var idx := wrapi(roundi(adjusted / (TAU / 8.0)), 0, 8)
	turret_sprite.texture = _turret_textures[idx]


func _update_range_shape(range_val: float) -> void:
	var collision := range_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		var shape := CircleShape2D.new()
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
		_aim_at(target.global_position)
		_fire_at(target)


func _fire_at(target: Node2D) -> void:
	if weapon.projectile_scene:
		var proj: Node2D = weapon.projectile_scene.instantiate()
		# Spawn from muzzle point if turret is active, otherwise tower center
		if _turret_textures.size() == 8:
			proj.global_position = muzzle_point.global_position
		else:
			proj.global_position = global_position
		if proj is BaseProjectile:
			proj.source_tower = self
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
		var proj_container := get_tree().get_first_node_in_group("projectiles")
		if proj_container:
			proj_container.add_child(proj)
		else:
			get_parent().add_child(proj)

	weapon.fired.emit(target)
	_play_recoil(target)
	_spawn_muzzle_flash()


func _on_upgraded(path_index: int, tier: int) -> void:
	weapon.apply_stat_modifiers(upgrade.active_modifiers)

	var combined_effects: Array[StatusEffectData] = []
	combined_effects.append_array(tower_data.on_hit_effects)
	combined_effects.append_array(upgrade.unlocked_effects)
	weapon.on_hit_effects = combined_effects

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


func _on_enemy_killed(enemy: Node2D, _gold: int) -> void:
	if enemy is BaseEnemy and enemy.last_hit_by == self:
		kill_count += 1
		if kill_count in KILL_MILESTONES:
			SignalBus.tower_kill_milestone.emit(self, kill_count)
			var tween := create_tween()
			tween.tween_property(sprite, "modulate", Color("#D8A040"), 0.15)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)


func _draw() -> void:
	if not _show_range or not tower_data:
		return
	var radius := _get_current_range() * 32.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color("#A0D8A040"), 1.0)
	draw_circle(Vector2.ZERO, radius, Color("#A0D8A010"))


func _get_current_range() -> float:
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
	return final_range


func _on_tower_selected(tower: Node2D) -> void:
	_show_range = (tower == self)
	queue_redraw()


func _on_tower_deselected() -> void:
	_show_range = false
	queue_redraw()


func _play_recoil(target: Node2D) -> void:
	var dir := (global_position - target.global_position).normalized()
	# Recoil on the turret sprite if available, otherwise base sprite
	var recoil_node: Sprite2D = turret_sprite if _turret_textures.size() == 8 else sprite
	var tween := create_tween()
	tween.tween_property(recoil_node, "position",
		recoil_node.position + dir * 2.0, 0.033)
	tween.tween_property(recoil_node, "position",
		recoil_node.position, 0.033)


func _spawn_muzzle_flash() -> void:
	var flash := ColorRect.new()
	flash.size = Vector2(6, 6)
	flash.color = ThemeManager.get_damage_type_color(weapon.damage_type)
	# Position flash at muzzle point
	flash.position = muzzle_point.position + Vector2(-3, -3)
	flash.z_index = 60
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)


func sell() -> void:
	var refund := get_sell_value()
	EconomyManager.add_gold(refund)
	PathfindingManager.remove_tower(_tile_pos)
	SignalBus.tower_sold.emit(self, refund)
	queue_free()
