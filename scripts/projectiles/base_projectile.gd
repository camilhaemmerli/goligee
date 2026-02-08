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

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if sprite and not sprite.texture:
		sprite.texture = PlaceholderSprites.create_circle(6, Color("#F0D0D8"))


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


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
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
		# TODO: impact particle effect
		queue_free()


func _apply_damage_to(enemy: Node2D) -> void:
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if not health:
		return

	# Track kill attribution
	if enemy is BaseEnemy and is_instance_valid(source_tower):
		enemy.last_hit_by = source_tower

	var resistance_comp := enemy.get_node_or_null("ResistanceComponent") as ResistanceComponent
	var resists: Dictionary = resistance_comp.get_all() if resistance_comp else {}

	var vuln_mod := 1.0
	if enemy.has_method("get_vulnerability_modifier"):
		vuln_mod = enemy.get_vulnerability_modifier()

	health.take_damage(damage, damage_type, resists, vuln_mod, crit_chance, crit_multiplier)

	# Apply on-hit status effects
	var effect_mgr := enemy.get_node_or_null("StatusEffectManager") as StatusEffectManager
	if effect_mgr:
		for effect in on_hit_effects:
			effect_mgr.apply_effect(effect)


func _apply_aoe_damage(center: Vector2) -> void:
	var enemies_group := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies_group:
		if enemy is Node2D:
			var dist := center.distance_to(enemy.global_position)
			if dist <= aoe_radius * 32.0:  # Convert tile radius to pixels
				_apply_damage_to(enemy)
