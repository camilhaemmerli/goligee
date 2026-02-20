class_name AgentProvocateur
extends Node2D
## Executive Decree #1: An undercover agent walks backward along the path.
## When he reaches enemies, he detonates a shockwave that stuns some
## and pushes others backward along the path.

const WALK_SPEED = 48.0
const BLEND_DURATION = 0.8
const STUN_DURATION = 4.5
const STUN_RADIUS = 100.0
const DETECT_RADIUS = 36.0
const STUN_DAMAGE = 15.0
const PUSHBACK_DISTANCE = 100.0  ## Pixels pushed backward along path
const PUSHBACK_CHANCE = 0.45     ## 45% of enemies get pushed back, rest get stunned

enum Phase { WALKING, BLENDING, STUNNING, DONE }

var _phase: Phase = Phase.WALKING
var _path: PackedVector2Array
var _path_index: int = 0
var _agent_sprite: Sprite2D
var _blend_timer: float = 0.0


func init(world_pos: Vector2, _tile_map: TileMapLayer) -> void:
	var result := AbilityManager.find_nearest_path_and_exit(world_pos)
	if result.is_empty():
		queue_free()
		return

	_path = result["path"]
	# Reverse path so agent walks from exit toward spawn
	var reversed := PackedVector2Array()
	for i in range(_path.size() - 1, -1, -1):
		reversed.append(_path[i])
	_path = reversed

	if _path.is_empty():
		queue_free()
		return

	global_position = _path[0]
	_path_index = 1

	# Spawn indicator at HQ (path exit = start position)
	_spawn_hq_indicator(_path[0])

	_create_agent_sprite()


func _create_agent_sprite() -> void:
	_agent_sprite = Sprite2D.new()
	var img := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	var dark := Color("#2A2A30")
	var coat := Color("#3A3A40")
	for x in range(2, 6):
		for y in range(0, 3):
			img.set_pixel(x, y, dark)
	for x in range(1, 7):
		for y in range(3, 10):
			img.set_pixel(x, y, coat)
	for y in range(10, 16):
		img.set_pixel(2, y, dark)
		img.set_pixel(3, y, dark)
		img.set_pixel(4, y, dark)
		img.set_pixel(5, y, dark)
	for x in range(1, 7):
		img.set_pixel(x, 1, Color("#1A1A1E"))

	_agent_sprite.texture = ImageTexture.create_from_image(img)
	_agent_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_agent_sprite.scale = Vector2(2.0, 2.0)
	_agent_sprite.offset.y = -16
	add_child(_agent_sprite)


func _spawn_hq_indicator(hq_pos: Vector2) -> void:
	## Brief pulsing ring at HQ showing where the agent deploys from.
	var indicator := Node2D.new()
	indicator.global_position = hq_pos
	indicator.z_index = 20
	indicator.z_as_relative = false
	get_parent().add_child(indicator)

	# Expanding ring
	var ring := _SpawnRingDraw.new()
	indicator.add_child(ring)

	var tw := ring.create_tween()
	tw.tween_property(ring, "ring_radius", 40.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(ring, "ring_alpha", 0.0, 0.5) \
		.set_ease(Tween.EASE_IN)

	# "DEPLOYING" flash label
	var label := Label.new()
	label.text = "DEPLOYING"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 0.9))
	label.add_theme_font_size_override("font_size", 8)
	label.position = Vector2(-30, -32)
	indicator.add_child(label)

	var label_tw := label.create_tween()
	label_tw.tween_property(label, "modulate:a", 0.0, 0.8)

	# Cleanup
	var cleanup := indicator.create_tween()
	cleanup.tween_interval(1.0)
	cleanup.tween_callback(indicator.queue_free)


func _process(delta: float) -> void:
	match _phase:
		Phase.WALKING:
			_process_walking(delta)
		Phase.BLENDING:
			_process_blending(delta)
		Phase.STUNNING:
			_process_stunning()
		Phase.DONE:
			pass


func _process_walking(delta: float) -> void:
	if _path_index >= _path.size():
		_finish()
		return

	var move_budget := WALK_SPEED * delta
	while move_budget > 0.0 and _path_index < _path.size():
		var target := _path[_path_index]
		var to_target := target - global_position
		var dist := to_target.length()
		if dist <= move_budget:
			global_position = target
			move_budget -= dist
			_path_index += 1
		else:
			global_position += to_target.normalized() * move_budget
			move_budget = 0.0

	# Check for nearby enemies
	var nearby := SpatialGrid.get_enemies_in_radius(global_position, DETECT_RADIUS)
	for node in nearby:
		if node is BaseEnemy and not node.health.is_dead:
			_phase = Phase.BLENDING
			_blend_timer = 0.0
			_start_blend_visual()
			return


func _start_blend_visual() -> void:
	if _agent_sprite:
		var tween := create_tween()
		tween.tween_property(_agent_sprite, "scale", Vector2(2.4, 1.6), BLEND_DURATION * 0.5)
		tween.tween_property(_agent_sprite, "scale", Vector2(2.0, 2.0), BLEND_DURATION * 0.5)


func _process_blending(delta: float) -> void:
	_blend_timer += delta
	if _blend_timer >= BLEND_DURATION:
		_phase = Phase.STUNNING
		_do_stun()


func _do_stun() -> void:
	var enemies := SpatialGrid.get_enemies_in_radius(global_position, STUN_RADIUS)
	for node in enemies:
		if not node is BaseEnemy:
			continue
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy.health.is_dead:
			continue

		var resists: Dictionary = enemy.resistances.get_all() if enemy.resistances else {}
		var vuln_mod := enemy.get_vulnerability_modifier()
		var armor_shred := enemy.get_armor_shred()
		enemy.health.take_damage(STUN_DAMAGE, Enums.DamageType.PSYCHOLOGICAL, resists, vuln_mod, 0.0, 1.0, armor_shred)

		if randf() < PUSHBACK_CHANCE and not enemy.is_flying():
			# Push back: enemy retreats along path
			var push_dist := randf_range(PUSHBACK_DISTANCE * 0.7, PUSHBACK_DISTANCE * 1.3)
			enemy.push_back_on_path(push_dist)
			# Red flash on pushed enemies
			enemy.modulate = Color(1.5, 0.6, 0.6)
			var flash_tw := enemy.create_tween()
			flash_tw.tween_property(enemy, "modulate", Color.WHITE, 0.6)
		else:
			# Stun: freeze in place
			if enemy.status_effects:
				var stun := StatusEffectData.new()
				stun.effect_type = Enums.StatusEffectType.STUN
				stun.duration = STUN_DURATION
				stun.potency = 1.0
				stun.apply_chance = 1.0
				enemy.status_effects.apply_effect(stun)
			# Yellow flash on stunned enemies
			enemy.modulate = Color(1.5, 1.4, 0.6)
			var flash_tw := enemy.create_tween()
			flash_tw.tween_property(enemy, "modulate", Color.WHITE, 0.6)

	# Screen shake
	SignalBus.screen_shake.emit(7.0, 0.3)

	# Visual: multi-ring shockwave + flash
	_spawn_shockwave()


func _spawn_shockwave() -> void:
	var container := Node2D.new()
	container.z_index = 20
	container.global_position = global_position
	get_parent().add_child(container)

	# Full-area white flash
	var flash := _FlashDraw.new()
	flash.flash_radius = STUN_RADIUS * 1.3
	container.add_child(flash)
	var flash_tw := flash.create_tween()
	flash_tw.tween_property(flash, "flash_alpha", 0.0, 0.35)

	# 4 concentric expanding rings with stagger
	for i in 4:
		var ring := _StunRingDraw.new()
		ring.ring_thickness = 3.5 - float(i) * 0.5
		container.add_child(ring)

		var delay := float(i) * 0.07
		var duration := 0.5 + float(i) * 0.12
		var target_radius := STUN_RADIUS * (0.7 + float(i) * 0.15)

		var tw := ring.create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_property(ring, "ring_radius", target_radius, duration) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(ring, "ring_alpha", 0.0, duration) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# White flash on agent
	if _agent_sprite:
		_agent_sprite.modulate = Color(4.0, 4.0, 4.0)
		var agent_tw := create_tween()
		agent_tw.tween_property(_agent_sprite, "modulate", Color.WHITE, 0.4)

	# Clean up container
	var cleanup_tw := container.create_tween()
	cleanup_tw.tween_interval(1.2)
	cleanup_tw.tween_callback(container.queue_free)


func _process_stunning() -> void:
	_finish()


func _finish() -> void:
	_phase = Phase.DONE
	SignalBus.ability_completed.emit("agent_provocateur")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


# -- Visual helpers --

class _StunRingDraw extends Node2D:
	var ring_radius: float = 0.0
	var ring_alpha: float = 0.9
	var ring_thickness: float = 3.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ring_radius <= 0.0 or ring_alpha <= 0.0:
			return
		var col := Color(1.0, 0.95, 0.7, ring_alpha)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, col, ring_thickness, true)
		var fill_col := Color(1.0, 0.95, 0.7, ring_alpha * 0.12)
		draw_circle(Vector2.ZERO, ring_radius, fill_col)


class _FlashDraw extends Node2D:
	var flash_radius: float = 0.0
	var flash_alpha: float = 0.45

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if flash_radius <= 0.0 or flash_alpha <= 0.0:
			return
		draw_circle(Vector2.ZERO, flash_radius, Color(1.0, 1.0, 0.9, flash_alpha))


class _SpawnRingDraw extends Node2D:
	var ring_radius: float = 0.0
	var ring_alpha: float = 0.8

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ring_radius <= 0.0 or ring_alpha <= 0.0:
			return
		var col := Color(0.8, 0.9, 1.0, ring_alpha)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, col, 2.0, true)
		draw_arc(Vector2.ZERO, ring_radius * 0.6, 0.0, TAU, 48, Color(col, ring_alpha * 0.4), 1.5, true)
