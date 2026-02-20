class_name WaterStreamProjectile
extends BaseProjectile
## Pressure stream projectile for the Water Cannon tower.
## Draws a Line2D water jet from muzzle to target that extends outward,
## damages all enemies along the line, then fades out.

const EXTEND_DURATION = 0.15
const LINGER_DURATION = 0.1
const FADE_DURATION = 0.15
const LINE_HIT_WIDTH = 14.0  # Perpendicular distance for line sweep (px)

const COLOR_CORE = Color("#80C0E0")
const COLOR_EDGE = Color("#4080B0")
const COLOR_SPRAY = Color("#A0D8F0", 0.6)
const COLOR_SPLASH = Color("#B0E0F0")

var _start_pos: Vector2
var _end_pos: Vector2
var _stream: Line2D
var _phase: int = 0  # 0=extend, 1=linger, 2=fade
var _phase_timer: float = 0.0
var _has_dealt_damage: bool = false
var _spray: CPUParticles2D


func _ready() -> void:
	# Capture positions
	_start_pos = global_position
	if is_instance_valid(target):
		_end_pos = target.global_position
	else:
		_end_pos = global_position + _direction * 150.0

	# Hide the bullet sprite — the Line2D IS the visual
	if sprite:
		sprite.visible = false

	# Don't create base trail
	if _trail:
		_trail.queue_free()
		_trail = null

	# Build the stream line
	_stream = Line2D.new()
	_stream.top_level = true
	_stream.z_index = 20
	_stream.width = 3.0
	_stream.width_curve = Curve.new()
	_stream.width_curve.add_point(Vector2(0.0, 1.0))
	_stream.width_curve.add_point(Vector2(1.0, 0.66))
	_stream.default_color = COLOR_CORE
	var grad := Gradient.new()
	grad.set_color(0, COLOR_CORE)
	grad.set_color(1, COLOR_EDGE)
	_stream.gradient = grad
	_stream.points = PackedVector2Array([_start_pos, _start_pos])
	add_child(_stream)

	# Spray particles along the stream
	_spray = CPUParticles2D.new()
	_spray.top_level = true
	_spray.z_index = 21
	_spray.emitting = true
	_spray.amount = 8
	_spray.lifetime = 0.3
	_spray.one_shot = false
	_spray.explosiveness = 0.3
	_spray.global_position = _start_pos
	_spray.direction = (_end_pos - _start_pos).normalized()
	_spray.spread = 25.0
	_spray.initial_velocity_min = 20.0
	_spray.initial_velocity_max = 50.0
	_spray.gravity = Vector2(0, 40)
	_spray.scale_amount_min = 0.5
	_spray.scale_amount_max = 1.5
	_spray.color = COLOR_SPRAY
	add_child(_spray)


func _apply_themed_sprite() -> void:
	# No sprite needed — stream is the visual
	pass


func _process(delta: float) -> void:
	# Skip base class movement entirely
	_timer += delta
	_phase_timer += delta

	match _phase:
		0:  # Extend
			var t := clampf(_phase_timer / EXTEND_DURATION, 0.0, 1.0)
			var tip := _start_pos.lerp(_end_pos, t)
			_stream.points = PackedVector2Array([_start_pos, tip])
			_spray.global_position = tip

			if t >= 1.0:
				_deal_line_damage()
				_spawn_splash_particles()
				_phase = 1
				_phase_timer = 0.0

		1:  # Linger
			if _phase_timer >= LINGER_DURATION:
				_spray.emitting = false
				_phase = 2
				_phase_timer = 0.0

		2:  # Fade
			var t := clampf(_phase_timer / FADE_DURATION, 0.0, 1.0)
			_stream.modulate.a = 1.0 - t
			if t >= 1.0:
				queue_free()


func _deal_line_damage() -> void:
	if _has_dealt_damage:
		return
	_has_dealt_damage = true

	var line_dir := (_end_pos - _start_pos)
	var line_len := line_dir.length()
	if line_len < 1.0:
		return
	var line_norm := line_dir / line_len

	var query_center := (_start_pos + _end_pos) * 0.5
	var query_radius := line_len * 0.5 + LINE_HIT_WIDTH
	var enemies := SpatialGrid.get_enemies_in_radius(query_center, query_radius)
	for enemy in enemies:
		if not enemy is Node2D:
			continue
		# Project enemy position onto the line segment
		var to_enemy: Vector2 = enemy.global_position - _start_pos
		var proj: float = to_enemy.dot(line_norm)
		# Must be within the line segment (with small tolerance)
		if proj < -4.0 or proj > line_len + 4.0:
			continue
		# Perpendicular distance
		var closest := _start_pos + line_norm * clampf(proj, 0.0, line_len)
		var perp_dist: float = enemy.global_position.distance_to(closest)
		if perp_dist <= LINE_HIT_WIDTH:
			_apply_damage_to(enemy)


func _spawn_splash_particles() -> void:
	for i in randi_range(3, 5):
		var drop := VFXPool.acquire_rect()
		drop.size = Vector2(2, 2)
		drop.color = COLOR_SPLASH
		drop.global_position = _end_pos + Vector2(-1, -1)
		drop.z_index = 50
		get_tree().current_scene.add_child(drop)
		var angle := randf() * TAU
		var end_pos := drop.global_position + Vector2(cos(angle), sin(angle)) * randf_range(5.0, 12.0)
		var tween := drop.create_tween()
		tween.set_parallel(true)
		tween.tween_property(drop, "global_position", end_pos, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(drop, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(VFXPool.release_rect.bind(drop))
