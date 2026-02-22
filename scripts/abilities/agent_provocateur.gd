class_name AgentProvocateur
extends Node2D
## Executive Decree #1: An undercover agent walks backward along the path.
## When he reaches enemies, he incites a riot — creating a persistent red
## blockade zone that freezes all protestors who walk into it.

const WALK_SPEED = 48.0
const BLEND_DURATION = 0.8
const ZONE_RADIUS = 80.0
const ZONE_DURATION = 8.0
const DETECT_RADIUS = 36.0
const STUN_REAPPLY = 1.5  ## Duration of each stun tick (re-applied while in zone)

enum Phase { WALKING, BLENDING, ZONE_ACTIVE, DONE }

var _phase: Phase = Phase.WALKING
var _path: PackedVector2Array
var _path_index: int = 0
var _agent_sprite: Sprite2D
var _blend_timer: float = 0.0
var _zone_timer: float = 0.0
var _zone_pos: Vector2
var _zone_draw: _ZoneDraw
var _stunned_enemies: Dictionary = {}  ## instance_id -> true (track who's inside)


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
	var indicator := Node2D.new()
	indicator.global_position = hq_pos
	indicator.z_index = 20
	indicator.z_as_relative = false
	get_parent().add_child(indicator)

	var ring := _SpawnRingDraw.new()
	indicator.add_child(ring)

	var tw := ring.create_tween()
	tw.tween_property(ring, "ring_radius", 40.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(ring, "ring_alpha", 0.0, 0.5) \
		.set_ease(Tween.EASE_IN)

	var label := Label.new()
	label.text = "DEPLOYING"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 0.9))
	label.add_theme_font_size_override("font_size", 8)
	label.position = Vector2(-30, -32)
	indicator.add_child(label)

	var label_tw := label.create_tween()
	label_tw.tween_property(label, "modulate:a", 0.0, 0.8)

	var cleanup := indicator.create_tween()
	cleanup.tween_interval(1.0)
	cleanup.tween_callback(indicator.queue_free)


func _process(delta: float) -> void:
	match _phase:
		Phase.WALKING:
			_process_walking(delta)
		Phase.BLENDING:
			_process_blending(delta)
		Phase.ZONE_ACTIVE:
			_process_zone(delta)
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
		_phase = Phase.ZONE_ACTIVE
		_activate_zone()


func _activate_zone() -> void:
	_zone_pos = global_position
	_zone_timer = ZONE_DURATION

	# Fade out the agent sprite
	if _agent_sprite:
		var fade := create_tween()
		fade.tween_property(_agent_sprite, "modulate:a", 0.0, 0.4)
		fade.tween_callback(_agent_sprite.queue_free)
		_agent_sprite = null

	# Create the persistent red zone visual
	_zone_draw = _ZoneDraw.new()
	_zone_draw.zone_radius = ZONE_RADIUS
	_zone_draw.z_index = 5
	_zone_draw.global_position = _zone_pos
	get_parent().add_child(_zone_draw)

	# Expanding deploy ring
	var deploy_ring := _DeployRingDraw.new()
	deploy_ring.global_position = _zone_pos
	deploy_ring.z_index = 6
	get_parent().add_child(deploy_ring)

	var ring_tw := deploy_ring.create_tween()
	ring_tw.tween_property(deploy_ring, "ring_radius", ZONE_RADIUS * 1.3, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ring_tw.parallel().tween_property(deploy_ring, "ring_alpha", 0.0, 0.4)
	ring_tw.tween_callback(deploy_ring.queue_free)

	# Small screen shake on deploy
	SignalBus.screen_shake.emit(4.0, 0.2)

	# Immediately stun anyone already in the zone
	_apply_zone_stun()


func _process_zone(delta: float) -> void:
	_zone_timer -= delta

	if _zone_timer <= 0.0:
		_end_zone()
		return

	# Update zone alpha for fade-out in the last 1.5s
	if _zone_draw and is_instance_valid(_zone_draw):
		var fade_start := 1.5
		if _zone_timer < fade_start:
			_zone_draw.zone_alpha = _zone_timer / fade_start
		# Pulse the glow
		_zone_draw.pulse_time += delta

	_apply_zone_stun()


func _apply_zone_stun() -> void:
	var enemies := SpatialGrid.get_enemies_in_radius(_zone_pos, ZONE_RADIUS)
	var in_zone_now: Dictionary = {}

	for node in enemies:
		if not node is BaseEnemy:
			continue
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy.health.is_dead or enemy.is_flying():
			continue

		var eid := enemy.get_instance_id()
		in_zone_now[eid] = true

		# Apply/refresh stun
		if enemy.status_effects:
			# Only re-apply if not already stunned or stun is about to expire
			if not enemy.status_effects.has_effect(Enums.StatusEffectType.STUN):
				var stun := StatusEffectData.new()
				stun.effect_type = Enums.StatusEffectType.STUN
				stun.duration = STUN_REAPPLY
				stun.potency = 1.0
				stun.apply_chance = 1.0
				enemy.status_effects.apply_effect(stun)

		# Red tint on enemies inside zone
		if eid not in _stunned_enemies:
			enemy.modulate = Color(1.4, 0.5, 0.5)

	# Enemies that left the zone — restore tint (stun will expire naturally)
	for eid in _stunned_enemies:
		if eid not in in_zone_now:
			# Find the enemy and reset modulate
			var enemies_all := SpatialGrid.get_enemies_in_radius(_zone_pos, ZONE_RADIUS * 2.0)
			for node in enemies_all:
				if is_instance_valid(node) and node.get_instance_id() == eid:
					var tw := node.create_tween()
					tw.tween_property(node, "modulate", Color.WHITE, 0.3)
					break

	_stunned_enemies = in_zone_now


func _end_zone() -> void:
	# Clean up zone visual
	if _zone_draw and is_instance_valid(_zone_draw):
		_zone_draw.queue_free()
		_zone_draw = null

	# Restore modulate on any remaining stunned enemies
	var enemies := SpatialGrid.get_enemies_in_radius(_zone_pos, ZONE_RADIUS * 1.5)
	for node in enemies:
		if not is_instance_valid(node):
			continue
		var eid := node.get_instance_id()
		if eid in _stunned_enemies:
			var tw := node.create_tween()
			tw.tween_property(node, "modulate", Color.WHITE, 0.3)

	_stunned_enemies.clear()
	_finish()


func _finish() -> void:
	_phase = Phase.DONE
	SignalBus.ability_completed.emit("agent_provocateur")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


# -- Visual helpers --

class _ZoneDraw extends Node2D:
	## Persistent red glowing circle on the ground.
	var zone_radius: float = 0.0
	var zone_alpha: float = 1.0
	var pulse_time: float = 0.0

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if zone_radius <= 0.0 or zone_alpha <= 0.0:
			return
		# Pulsing glow factor
		var pulse := 0.8 + sin(pulse_time * 3.0) * 0.2

		# Filled red circle (translucent)
		var fill_alpha := 0.12 * zone_alpha * pulse
		draw_circle(Vector2.ZERO, zone_radius, Color(0.9, 0.15, 0.1, fill_alpha))

		# Inner glow ring
		var inner_col := Color(1.0, 0.2, 0.15, 0.5 * zone_alpha * pulse)
		draw_arc(Vector2.ZERO, zone_radius * 0.7, 0.0, TAU, 64, inner_col, 1.5, true)

		# Outer border ring
		var outer_col := Color(1.0, 0.25, 0.2, 0.7 * zone_alpha * pulse)
		draw_arc(Vector2.ZERO, zone_radius, 0.0, TAU, 64, outer_col, 2.5, true)

		# Faint outer halo
		var halo_col := Color(1.0, 0.1, 0.05, 0.08 * zone_alpha * pulse)
		draw_circle(Vector2.ZERO, zone_radius * 1.15, halo_col)


class _DeployRingDraw extends Node2D:
	## Expanding ring on zone activation.
	var ring_radius: float = 0.0
	var ring_alpha: float = 0.8

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ring_radius <= 0.0 or ring_alpha <= 0.0:
			return
		var col := Color(1.0, 0.3, 0.2, ring_alpha)
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, col, 2.5, true)


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
