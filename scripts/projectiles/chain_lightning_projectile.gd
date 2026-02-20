class_name ChainLightningProjectile
extends BaseProjectile
## Instant chain lightning for the Taser Grid tower.
## Hits primary target immediately, then arcs to nearby enemies.
## Each hop draws a jagged Line2D bolt that fades out.

const CHAIN_RADIUS = 48.0  # px — enemy-to-enemy jump range
const BOLT_FADE_TIME = 0.35
const BOLT_SEGMENTS = 5  # midpoints per bolt
const BOLT_JITTER = 6.0  # perpendicular pixel offset for zigzag
const BOLT_WIDTH = 2.0
const BOLT_COLOR = Color("#F0F080")  # bright electric yellow
const HOP_ALPHA_DECAY = 0.7  # alpha multiplied per hop
const SPARK_COLOR = Color("#FFFFFF", 0.8)

var _bolts: Array[Line2D] = []
var _fade_elapsed: float = 0.0
var _chain_done: bool = false


func _ready() -> void:
	# Hide the default sprite and skip trail
	if sprite:
		sprite.visible = false
	if _trail:
		_trail.queue_free()
		_trail = null

	# Execute chain immediately on spawn
	_execute_chain()


func _execute_chain() -> void:
	var chain_targets_count: int = 3
	var chain_falloff: float = 0.5

	if is_instance_valid(source_tower) and source_tower.weapon:
		chain_targets_count = source_tower.weapon.chain_targets
		chain_falloff = source_tower.weapon.chain_damage_falloff

	if not is_instance_valid(target):
		queue_free()
		return

	# Track hit enemies to avoid double-hits
	var hit_set: Dictionary = {}  # instance_id -> true

	# -- Primary hit (effects already applied inside _apply_damage_to) --
	var muzzle_pos := global_position
	_apply_damage_to(target)
	_spawn_bolt(muzzle_pos, target.global_position, 1.0)
	_spawn_spark(target.global_position)
	hit_set[target.get_instance_id()] = true

	# -- Chain hops --
	var current_pos: Vector2 = target.global_position
	var current_damage: float = damage
	var hop_alpha: float = 1.0

	for i in chain_targets_count:
		current_damage *= chain_falloff
		hop_alpha *= HOP_ALPHA_DECAY

		var next_target := _find_nearest_unhit(current_pos, hit_set)
		if not next_target:
			break

		# Apply reduced damage
		if next_target is BaseEnemy:
			var e := next_target as BaseEnemy
			if e.health:
				if is_instance_valid(source_tower):
					e.last_hit_by = source_tower
				var resists: Dictionary = e.resistances.get_all() if e.resistances else {}
				var vuln_mod := e.get_vulnerability_modifier()
				var armor_shred := e.get_armor_shred()
				e.health.take_damage(current_damage, damage_type, resists, vuln_mod, crit_chance, crit_multiplier, armor_shred)

		_apply_effects_to(next_target)
		_spawn_bolt(current_pos, next_target.global_position, hop_alpha)
		_spawn_spark(next_target.global_position)

		hit_set[next_target.get_instance_id()] = true
		current_pos = next_target.global_position

	_chain_done = true


func _find_nearest_unhit(from_pos: Vector2, hit_set: Dictionary) -> Node2D:
	var best: Node2D = null
	var best_dist := CHAIN_RADIUS + 1.0

	for node in SpatialGrid.get_enemies_in_radius(from_pos, CHAIN_RADIUS):
		if not node is BaseEnemy:
			continue
		var enemy: BaseEnemy = node as BaseEnemy
		if hit_set.has(enemy.get_instance_id()):
			continue
		if not enemy.health or enemy.health.is_dead:
			continue
		var dist := from_pos.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy

	return best


func _apply_effects_to(enemy: Node2D) -> void:
	if enemy is BaseEnemy:
		var e := enemy as BaseEnemy
		if e.status_effects:
			for effect in on_hit_effects:
				e.status_effects.apply_effect(effect)
		return
	var effect_mgr := enemy.get_node_or_null("StatusEffectManager") as StatusEffectManager
	if effect_mgr:
		for effect in on_hit_effects:
			effect_mgr.apply_effect(effect)


func _spawn_bolt(from: Vector2, to: Vector2, alpha: float) -> void:
	var bolt := Line2D.new()
	bolt.width = BOLT_WIDTH
	bolt.default_color = Color(BOLT_COLOR, alpha)
	bolt.z_index = 25
	bolt.top_level = true

	bolt.points = _build_jagged_points(from, to)

	# Glow layer (slightly wider, dimmer)
	var glow := Line2D.new()
	glow.width = BOLT_WIDTH + 2.0
	glow.default_color = Color("#E0E060", alpha * 0.3)
	glow.z_index = 24
	glow.top_level = true
	glow.points = bolt.points

	get_tree().current_scene.add_child(glow)
	get_tree().current_scene.add_child(bolt)
	_bolts.append(bolt)
	_bolts.append(glow)


func _build_jagged_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(from)

	var diff := to - from
	var perp := Vector2(-diff.y, diff.x).normalized()

	for i in range(1, BOLT_SEGMENTS):
		var t := float(i) / float(BOLT_SEGMENTS)
		var base_pt := from.lerp(to, t)
		var offset := perp * randf_range(-BOLT_JITTER, BOLT_JITTER)
		points.append(base_pt + offset)

	points.append(to)
	return points


func _spawn_spark(pos: Vector2) -> void:
	for i in randi_range(2, 3):
		var spark := VFXPool.acquire_rect()
		spark.size = Vector2(2, 2)
		spark.color = SPARK_COLOR
		spark.global_position = pos + Vector2(-1, -1)
		spark.z_index = 50
		get_tree().current_scene.add_child(spark)

		var angle := randf() * TAU
		var end_pos := spark.global_position + Vector2(cos(angle), sin(angle)) * randf_range(4.0, 10.0)
		var tween := spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", end_pos, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(VFXPool.release_rect.bind(spark))


func _process(delta: float) -> void:
	if not _chain_done:
		return

	_fade_elapsed += delta
	var alpha := 1.0 - (_fade_elapsed / BOLT_FADE_TIME)

	if alpha <= 0.0:
		for bolt in _bolts:
			if is_instance_valid(bolt):
				bolt.queue_free()
		_bolts.clear()
		queue_free()
		return

	for bolt in _bolts:
		if is_instance_valid(bolt):
			bolt.modulate.a = alpha
