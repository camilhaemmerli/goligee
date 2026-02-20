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
## Optional firing-pose turret textures (same 8 directions)
var _fire_turret_textures: Array[Texture2D] = []
var _current_dir_idx: int = 7  # Track current aim direction for fire frame swap
## Direction names matching _turret_textures indices
const DIRS = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]

const KILL_MILESTONES = [25, 50, 100, 250, 500, 1000]
const TOWER_SCALE = 0.75

# Rank badge constants
const BADGE_COLORS = [Color("#B08040"), Color("#A0A8B8"), Color("#FFD060")]  # bronze, silver, gold
const BADGE_OUTLINE = Color("#1A1A1E")
const CHEVRON_W = 6.0   # half-width of chevron V
const CHEVRON_H = 3.0   # depth of V
const CHEVRON_SPACING = 4.0
var _badge_node: Node2D
var _total_upgrades: int = 0

# Synergy glow
var _synergy_node: Node2D
var _synergy_color: Color = Color.TRANSPARENT
var _synergy_pulse: float = 0.0
var _synergy_rate_mult: float = 1.0

# Taser tower-to-tower electric links
var _taser_links: Dictionary = {}  # neighbor instance_id -> Line2D
const TASER_LINK_RANGE = 3  # Chebyshev tile distance
const TASER_LINK_COLOR = Color("#E0E060", 0.3)
const TASER_LINK_JITTER = 4.0
const TASER_LINK_SEGMENTS = 4
const TASER_LINK_FLICKER_INTERVAL = 0.15
var _link_flicker_timer: float = 0.0
var _is_taser: bool = false

# Camera zone suppression (news helicopter ability)
var _suppression_count: int = 0
var _rec_dot: Node2D
const REC_DOT_COLOR = Color("#E04040")
const SUPPRESSED_MODULATE = Color(0.5, 0.5, 0.5, 1.0)


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

	_badge_node = Node2D.new()
	_badge_node.z_index = 1
	add_child(_badge_node)
	_badge_node.draw.connect(_draw_rank_badge)

	_synergy_node = Node2D.new()
	_synergy_node.z_index = -1  # Behind tower sprites, visible on tiles
	add_child(_synergy_node)
	_synergy_node.draw.connect(_draw_synergy_glow)

	range_area.area_entered.connect(_on_enemy_entered_range)
	range_area.area_exited.connect(_on_enemy_exited_range)
	attack_timer.timeout.connect(_on_attack_timer)
	upgrade.upgraded.connect(_on_upgraded)
	SignalBus.enemy_killed.connect(_on_enemy_killed)
	SignalBus.tower_selected.connect(_on_tower_selected)
	SignalBus.tower_deselected.connect(_on_tower_deselected)
	SynergyManager.synergy_changed.connect(_on_synergy_changed)

	# Taser tower-to-tower electric links
	_is_taser = tower_data and tower_data.tower_id == "taser_grid"
	if _is_taser:
		SignalBus.tower_placed.connect(_on_taser_neighbor_changed)
		SignalBus.tower_sold.connect(_on_taser_neighbor_sold)
		# Defer initial link refresh so our tile_pos is set by the placer first
		_refresh_taser_links.call_deferred()

	# Tower body for camera zone detection (layer 6)
	var tower_body := Area2D.new()
	tower_body.name = "TowerBody"
	tower_body.collision_layer = 0
	tower_body.collision_mask = 0
	tower_body.set_collision_layer_value(6, true)
	tower_body.monitorable = true
	tower_body.monitoring = false
	var body_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	body_shape.shape = circle
	tower_body.add_child(body_shape)
	add_child(tower_body)

	set_process(false)  # Only enable when synergy glow or taser links are active


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

	targeting.can_target_flying = tower_data.can_target_flying
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
		sprite.scale = Vector2(TOWER_SCALE, TOWER_SCALE)
		turret_sprite.visible = true
		turret_sprite.scale = Vector2(TOWER_SCALE, TOWER_SCALE)
		turret_sprite.position.y = (skin.turret_y_offset + sprite.offset.y) * TOWER_SCALE
		muzzle_point.position.y = turret_sprite.position.y - (4.0 * TOWER_SCALE)
		if skin.turret_textures.size() == 8:
			_turret_textures = skin.turret_textures
			turret_sprite.texture = _turret_textures[7]  # Default: SE
			_current_dir_idx = 7
		elif skin.turret_textures.size() > 0:
			turret_sprite.texture = skin.turret_textures[0]
		if skin.fire_turret_textures.size() == 8:
			_fire_turret_textures = skin.fire_turret_textures
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
	_current_dir_idx = idx
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
	if is_suppressed():
		return
	var target := targeting.update_target(global_position, attack_timer.wait_time)
	if target:
		_aim_at(target.global_position)
		_fire_at(target)


func _fire_at(target: Node2D) -> void:
	# Crossfire bonus: perpendicular shots deal extra damage
	var crossfire_mult := 1.0
	if tower_data and tower_data.crossfire_bonus > 0.0 and target is BaseEnemy:
		var enemy_dir: Vector2 = target.velocity.normalized() if target.velocity.length_squared() > 0.01 else Vector2.ZERO
		if enemy_dir != Vector2.ZERO:
			var tower_to_enemy := (target.global_position - global_position).normalized()
			var dot := absf(enemy_dir.dot(tower_to_enemy))
			# dot=1.0 → parallel (no bonus), dot=0.0 → perpendicular (full bonus)
			crossfire_mult = 1.0 + tower_data.crossfire_bonus * (1.0 - dot)
			if crossfire_mult > 1.1:
				_spawn_crossfire_popup(target)

	if weapon.projectile_scene:
		var proj: Node2D = weapon.projectile_scene.instantiate()
		# Spawn from muzzle point if turret is active, otherwise tower center
		if _turret_textures.size() == 8:
			proj.global_position = muzzle_point.global_position
		else:
			proj.global_position = global_position
		if proj is BaseProjectile:
			proj.source_tower = self
		var final_dmg := weapon.final_damage * crossfire_mult
		if proj.has_method("init"):
			proj.init(
				target,
				final_dmg,
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
	_play_fire_frame()
	_play_recoil(target)
	_spawn_muzzle_flash()


func _on_upgraded(path_index: int, tier: int) -> void:
	_total_upgrades = 0
	for t in upgrade.path_tiers:
		_total_upgrades += t
	_badge_node.queue_redraw()

	weapon.apply_stat_modifiers(upgrade.active_modifiers)

	var combined_effects: Array[StatusEffectData] = []
	combined_effects.append_array(tower_data.on_hit_effects)
	combined_effects.append_array(upgrade.unlocked_effects)
	weapon.on_hit_effects = combined_effects

	_recalculate_attack_timer()

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


## Apply synergy fire rate multiplier to the attack timer.
func apply_synergy_rate(rate_mult: float) -> void:
	_synergy_rate_mult = rate_mult
	_recalculate_attack_timer()


func _recalculate_attack_timer() -> void:
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
	final_rate *= _synergy_rate_mult
	attack_timer.wait_time = 1.0 / max(final_rate, 0.1)


func _on_enemy_killed(enemy: Node2D, _gold: int) -> void:
	if enemy is BaseEnemy and enemy.last_hit_by == self:
		kill_count += 1
		if kill_count in KILL_MILESTONES:
			SignalBus.tower_kill_milestone.emit(self, kill_count)
			var tween := create_tween()
			tween.tween_property(sprite, "modulate", Color("#F0F0F0"), 0.15)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
			if turret_sprite.visible:
				var t2 := create_tween()
				t2.tween_property(turret_sprite, "modulate", Color("#F0F0F0"), 0.15)
				t2.tween_property(turret_sprite, "modulate", Color.WHITE, 0.3)


func _draw() -> void:
	if not _show_range or not tower_data:
		return
	var radius := _get_current_range() * 32.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color("#A0F0F0F0"), 1.0)
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


func _play_fire_frame() -> void:
	if _fire_turret_textures.size() != 8:
		return
	turret_sprite.texture = _fire_turret_textures[_current_dir_idx]
	get_tree().create_timer(0.15).timeout.connect(func():
		if _turret_textures.size() == 8:
			turret_sprite.texture = _turret_textures[_current_dir_idx]
	)


func _play_recoil(target: Node2D) -> void:
	var dir := (global_position - target.global_position).normalized()
	# Recoil on the turret sprite if available, otherwise base sprite
	var recoil_node: Sprite2D = turret_sprite if _turret_textures.size() == 8 else sprite
	var tween := create_tween()
	tween.tween_property(recoil_node, "position",
		recoil_node.position + dir * 1.0, 0.033)
	tween.tween_property(recoil_node, "position",
		recoil_node.position, 0.033)


func _spawn_crossfire_popup(target: Node2D) -> void:
	var label := VFXPool.acquire_label()
	label.text = "CROSSFIRE"
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("#F0F0F0"))
	label.add_theme_color_override("font_outline_color", Color("#1A1A1E"))
	label.add_theme_constant_override("outline_size", 2)
	label.global_position = target.global_position + Vector2(-20, -24)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 16.0, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tween.tween_callback(VFXPool.release_label.bind(label))


func _spawn_muzzle_flash() -> void:
	var flash := VFXPool.acquire_rect()
	flash.size = Vector2(4, 4)
	flash.color = ThemeManager.get_damage_type_color(weapon.damage_type)
	# Position flash at muzzle point
	flash.position = muzzle_point.position + Vector2(-2, -2)
	flash.z_index = 60
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(VFXPool.release_rect.bind(flash))


func _draw_rank_badge() -> void:
	if _total_upgrades <= 0:
		return
	var tier_idx := clampi((_total_upgrades - 1) / 2, 0, 2)
	var count := ((_total_upgrades - 1) % 2) + 1
	var color: Color = BADGE_COLORS[tier_idx]
	var anchor := Vector2(12, -20)
	for i in count:
		_draw_chevron(anchor + Vector2(0, -i * CHEVRON_SPACING), color)


func _draw_chevron(center: Vector2, color: Color) -> void:
	var left := center + Vector2(-CHEVRON_W, -CHEVRON_H)
	var tip := center
	var right := center + Vector2(CHEVRON_W, -CHEVRON_H)
	# Outline
	_badge_node.draw_line(left, tip, BADGE_OUTLINE, 2.0)
	_badge_node.draw_line(tip, right, BADGE_OUTLINE, 2.0)
	# Fill
	_badge_node.draw_line(left, tip, color, 1.0)
	_badge_node.draw_line(tip, right, color, 1.0)


func _on_synergy_changed(tower: Node2D) -> void:
	if tower != self:
		return
	var synergies := SynergyManager.get_tower_synergies(self)
	if synergies.is_empty():
		_synergy_color = Color.TRANSPARENT
		if _taser_links.is_empty():
			set_process(false)
	else:
		# Green for buff, red for debuff
		var has_buff := false
		var has_debuff := false
		for s in synergies:
			if s["is_buff"]:
				has_buff = true
			else:
				has_debuff = true
		if has_buff and has_debuff:
			_synergy_color = Color("#E0C040")  # amber for mixed
		elif has_debuff:
			_synergy_color = Color("#C04040")  # red for debuff
		else:
			_synergy_color = Color("#40C060")  # green for buff
		set_process(true)
	_synergy_node.queue_redraw()


func _process(delta: float) -> void:
	if _synergy_color.a > 0.0:
		_synergy_pulse += delta * 2.5
		_synergy_node.queue_redraw()

	if _is_taser and not _taser_links.is_empty():
		_link_flicker_timer += delta
		if _link_flicker_timer >= TASER_LINK_FLICKER_INTERVAL:
			_link_flicker_timer -= TASER_LINK_FLICKER_INTERVAL
			_rerandomize_link_bolts()


func _draw_synergy_glow() -> void:
	if _synergy_color == Color.TRANSPARENT:
		return
	var pulse_alpha := 0.35 + 0.25 * sin(_synergy_pulse)
	var glow_color := Color(_synergy_color, pulse_alpha * 0.4)
	var outline_color := Color(_synergy_color, pulse_alpha)
	# Pulsing diamond matching the isometric tile footprint
	var hw := 32.0
	var hh := 16.0
	var pts := PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0), Vector2(0, -hh),
	])
	_synergy_node.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], pts[3]]), glow_color)
	for i in 4:
		_synergy_node.draw_line(pts[i], pts[i + 1], outline_color, 2.0)


# -- Camera zone suppression API --

func is_suppressed() -> bool:
	return _suppression_count > 0


func suppress() -> void:
	# Surveillance hub is immune — the watchers watch back
	if tower_data and tower_data.tower_id == "surveillance_hub":
		return
	_suppression_count += 1
	if _suppression_count == 1:
		_apply_suppression_visuals()
		attack_timer.paused = true
		SignalBus.tower_suppressed.emit(self)


func unsuppress() -> void:
	if tower_data and tower_data.tower_id == "surveillance_hub":
		return
	_suppression_count = max(_suppression_count - 1, 0)
	if _suppression_count == 0:
		_remove_suppression_visuals()
		attack_timer.paused = false
		SignalBus.tower_unsuppressed.emit(self)


func _apply_suppression_visuals() -> void:
	modulate = SUPPRESSED_MODULATE
	# Pulsing REC dot indicator
	_rec_dot = Node2D.new()
	_rec_dot.z_index = 100
	add_child(_rec_dot)
	_rec_dot.draw.connect(_draw_rec_dot)
	# Pulse the REC dot alpha
	var tween := _rec_dot.create_tween()
	tween.set_loops()
	tween.tween_property(_rec_dot, "modulate:a", 0.3, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_rec_dot, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	_rec_dot.queue_redraw()


func _remove_suppression_visuals() -> void:
	modulate = Color.WHITE
	if _rec_dot and is_instance_valid(_rec_dot):
		_rec_dot.queue_free()
		_rec_dot = null


func _draw_rec_dot() -> void:
	# Red circle + "REC" text above the tower
	_rec_dot.draw_circle(Vector2(10, -28), 3.0, REC_DOT_COLOR)
	_rec_dot.draw_string(ThemeDB.fallback_font, Vector2(15, -24), "REC",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, REC_DOT_COLOR)


func sell() -> void:
	_suppression_count = 0
	_remove_suppression_visuals()
	_clear_taser_links()
	var refund := get_sell_value()
	EconomyManager.add_gold(refund)
	PathfindingManager.remove_tower(_tile_pos)
	SignalBus.tower_sold.emit(self, refund)
	queue_free()


# -- Taser tower-to-tower electric links --

func _on_taser_neighbor_changed(_tower: Node2D, _tile_pos_arg: Vector2i) -> void:
	_refresh_taser_links()


func _on_taser_neighbor_sold(_tower: Node2D, _refund: int) -> void:
	# Defer so the sold tower is removed from _tower_grid first
	_refresh_taser_links.call_deferred()


func _refresh_taser_links() -> void:
	_clear_taser_links()

	if not _is_taser:
		return

	for tile_pos_key in SynergyManager._tower_grid:
		var neighbor: BaseTower = SynergyManager._tower_grid[tile_pos_key]
		if neighbor == self:
			continue
		if not is_instance_valid(neighbor) or not neighbor.tower_data:
			continue
		if neighbor.tower_data.tower_id != "taser_grid":
			continue

		# Check Chebyshev distance
		var dx := absi(tile_pos_key.x - _tile_pos.x)
		var dy := absi(tile_pos_key.y - _tile_pos.y)
		if maxi(dx, dy) > TASER_LINK_RANGE:
			continue

		# Only draw from lower instance_id to higher (one link per pair)
		if get_instance_id() >= neighbor.get_instance_id():
			continue

		var bolt := _build_link_bolt(global_position, neighbor.global_position)
		get_tree().current_scene.add_child(bolt)
		_taser_links[neighbor.get_instance_id()] = bolt

	# Enable processing if we have links or synergy glow
	if not _taser_links.is_empty() or _synergy_color.a > 0.0:
		set_process(true)


func _build_link_bolt(from: Vector2, to: Vector2) -> Line2D:
	var bolt := Line2D.new()
	bolt.width = 1.0
	bolt.default_color = TASER_LINK_COLOR
	bolt.z_index = 5
	bolt.top_level = true
	bolt.points = _build_link_jagged_points(from, to)
	return bolt


func _build_link_jagged_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(from)

	var diff := to - from
	var perp := Vector2(-diff.y, diff.x).normalized()

	for i in range(1, TASER_LINK_SEGMENTS):
		var t := float(i) / float(TASER_LINK_SEGMENTS)
		var base_pt := from.lerp(to, t)
		var offset := perp * randf_range(-TASER_LINK_JITTER, TASER_LINK_JITTER)
		points.append(base_pt + offset)

	points.append(to)
	return points


func _rerandomize_link_bolts() -> void:
	for nid in _taser_links:
		var bolt: Line2D = _taser_links[nid]
		if not is_instance_valid(bolt):
			continue
		if bolt.points.size() < 2:
			continue
		var from: Vector2 = bolt.points[0]
		var to: Vector2 = bolt.points[bolt.points.size() - 1]
		bolt.points = _build_link_jagged_points(from, to)


func _clear_taser_links() -> void:
	for nid in _taser_links:
		var bolt: Line2D = _taser_links[nid]
		if is_instance_valid(bolt):
			bolt.queue_free()
	_taser_links.clear()
