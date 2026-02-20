class_name BaseProjectile
extends Area2D
## Base projectile that moves toward a target and deals damage on contact.
## Supports AoE, pierce, and on-hit status effects.

@export var speed: float = 300.0
@export var lifetime: float = 5.0

var target: Node2D
var damage: float
var damage_type: Enums.DamageType
var aoe_radius: float
var pierce_remaining: int
var crit_chance: float
var crit_multiplier: float
var on_hit_effects: Array[StatusEffectData]

var source_tower: Node2D

var _direction: Vector2
var _has_target: bool = false
var _timer: float = 0.0

var _trail: Line2D
var _trail_points: PackedVector2Array = PackedVector2Array()
const MAX_TRAIL_POINTS = 5

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if sprite and not sprite.texture:
		_apply_themed_sprite()

	_trail = Line2D.new()
	_trail.width = 2.0
	_trail.default_color = Color(1, 1, 1, 0.4)
	_trail.z_index = -1
	_trail.top_level = true
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.4))
	_trail.gradient = grad
	add_child(_trail)


func _apply_themed_sprite() -> void:
	match damage_type:
		Enums.DamageType.HYDRAULIC:
			sprite.texture = EntitySprites.create_ice_shard()
		Enums.DamageType.KINETIC:
			sprite.texture = EntitySprites.create_cannonball()
		_:
			var color := Color("#F0D0D8")
			if damage_type == Enums.DamageType.CHEMICAL:
				color = Color("#E08040")
			elif damage_type == Enums.DamageType.SONIC:
				color = Color("#80E060")
			elif damage_type == Enums.DamageType.ELECTRIC:
				color = Color("#E0E060")
			sprite.texture = EntitySprites.create_projectile_streak(color)


func init(
	p_target: Node2D,
	p_damage: float,
	p_damage_type: Enums.DamageType,
	p_aoe: float,
	p_pierce: int,
	p_crit_chance: float,
	p_crit_mult: float,
	p_effects: Array[StatusEffectData],
) -> void:
	target = p_target
	damage = p_damage
	damage_type = p_damage_type
	aoe_radius = p_aoe
	pierce_remaining = p_pierce
	crit_chance = p_crit_chance
	crit_multiplier = p_crit_mult
	on_hit_effects = p_effects
	_has_target = is_instance_valid(target)
	if _has_target:
		_direction = (target.global_position - global_position).normalized()

	if _trail:
		var tc := ThemeManager.get_damage_type_color(damage_type)
		_trail.default_color = Color(tc, 0.4)
		var g := Gradient.new()
		g.set_color(0, Color(tc, 0.0))
		g.set_color(1, Color(tc, 0.4))
		_trail.gradient = g


func _process(delta: float) -> void:
	if _trail:
		_trail_points.append(global_position)
		if _trail_points.size() > MAX_TRAIL_POINTS:
			_trail_points = _trail_points.slice(_trail_points.size() - MAX_TRAIL_POINTS)
		_trail.points = _trail_points

	_timer += delta
	if _timer >= lifetime:
		_fade_trail()
		queue_free()
		return

	# Track toward target if still alive
	if _has_target and is_instance_valid(target):
		_direction = (target.global_position - global_position).normalized()
		var dist := global_position.distance_to(target.global_position)
		if dist < speed * delta:
			_hit_target(target)
			return

	global_position += _direction * speed * delta


func _hit_target(hit_enemy: Node2D) -> void:
	if aoe_radius > 0.0:
		_apply_aoe_damage(global_position)
	else:
		_apply_damage_to(hit_enemy)

	pierce_remaining -= 1
	if pierce_remaining <= 0:
		_spawn_impact_particles()
		_fade_trail()
		queue_free()


func _apply_damage_to(enemy: Node2D) -> void:
	if enemy is BaseEnemy:
		var e := enemy as BaseEnemy
		if not e.health:
			return
		if is_instance_valid(source_tower):
			e.last_hit_by = source_tower
		var resists: Dictionary = e.resistances.get_all() if e.resistances else {}
		var vuln_mod := e.get_vulnerability_modifier()
		var armor_shred := e.get_armor_shred()
		e.health.take_damage(damage, damage_type, resists, vuln_mod, crit_chance, crit_multiplier, armor_shred)
		if e.status_effects:
			for effect in on_hit_effects:
				e.status_effects.apply_effect(effect)
		return

	# Fallback for non-BaseEnemy nodes
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if not health:
		return
	var resistance_comp := enemy.get_node_or_null("ResistanceComponent") as ResistanceComponent
	var resists: Dictionary = resistance_comp.get_all() if resistance_comp else {}
	health.take_damage(damage, damage_type, resists, 1.0, crit_chance, crit_multiplier, 0.0)
	var effect_mgr := enemy.get_node_or_null("StatusEffectManager") as StatusEffectManager
	if effect_mgr:
		for effect in on_hit_effects:
			effect_mgr.apply_effect(effect)


func _apply_aoe_damage(center: Vector2) -> void:
	var radius_px := aoe_radius * 32.0
	var enemies_nearby := SpatialGrid.get_enemies_in_radius(center, radius_px)
	for enemy in enemies_nearby:
		_apply_damage_to(enemy)


func _spawn_impact_particles() -> void:
	var color := ThemeManager.get_damage_type_color(damage_type)
	for i in randi_range(2, 4):
		var shard := VFXPool.acquire_rect()
		shard.size = Vector2(2, 2)
		shard.color = color
		shard.global_position = global_position + Vector2(-1, -1)
		shard.z_index = 50
		get_tree().current_scene.add_child(shard)
		var angle := randf() * TAU
		var end_pos := shard.global_position + Vector2(cos(angle), sin(angle)) * randf_range(6.0, 14.0)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", end_pos, 0.25).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "modulate:a", 0.0, 0.25)
		tween.chain().tween_callback(VFXPool.release_rect.bind(shard))


func _fade_trail() -> void:
	if not _trail:
		return
	var trail_ref := _trail
	_trail = null
	trail_ref.top_level = true
	remove_child(trail_ref)
	get_tree().current_scene.add_child(trail_ref)
	var tween := trail_ref.create_tween()
	tween.tween_property(trail_ref, "modulate:a", 0.0, 0.15)
	tween.tween_callback(trail_ref.queue_free)
