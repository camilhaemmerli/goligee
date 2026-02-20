class_name PepperSprayProjectile
extends BaseProjectile
## Widening orange mist cone for the Pepper Spray Emitter tower.
## Draws a cone-shaped Line2D spray from muzzle to target that fans out,
## damages all enemies along the cone, then fades with drifting mist.

const EXTEND_DURATION = 0.08
const LINGER_DURATION = 0.1
const FADE_DURATION = 0.15
const LINE_HIT_WIDTH = 12.0  # Perpendicular distance for line sweep (px)

const COLOR_CORE = Color("#F0A030")
const COLOR_EDGE = Color("#E07020", 0.6)
const COLOR_MIST = Color("#E09030", 0.4)
const COLOR_DROP = Color("#F0B040")

var _start_pos: Vector2
var _end_pos: Vector2
var _spray: Line2D
var _core_line: Line2D
var _phase: int = 0  # 0=extend, 1=linger, 2=fade
var _phase_timer: float = 0.0
var _has_dealt_damage: bool = false
var _mist: CPUParticles2D


func _ready() -> void:
	_start_pos = global_position
	if is_instance_valid(target):
		_end_pos = target.global_position
	else:
		_end_pos = global_position + _direction * 150.0

	if sprite:
		sprite.visible = false
	if _trail:
		_trail.queue_free()
		_trail = null

	# Spray cone (wider, gradient orange)
	_spray = Line2D.new()
	_spray.top_level = true
	_spray.z_index = 20
	_spray.width = 5.0
	var cone_curve := Curve.new()
	cone_curve.add_point(Vector2(0.0, 0.3))  # narrow at nozzle
	cone_curve.add_point(Vector2(1.0, 1.0))  # wide at target
	_spray.width_curve = cone_curve
	var spray_grad := Gradient.new()
	spray_grad.set_color(0, COLOR_CORE)
	spray_grad.set_color(1, COLOR_EDGE)
	_spray.gradient = spray_grad
	_spray.points = PackedVector2Array([_start_pos, _start_pos])
	add_child(_spray)

	# Core line (thin bright center inside the cone)
	_core_line = Line2D.new()
	_core_line.top_level = true
	_core_line.z_index = 21
	_core_line.width = 1.5
	_core_line.default_color = COLOR_CORE
	_core_line.points = PackedVector2Array([_start_pos, _start_pos])
	add_child(_core_line)

	# Mist particles drifting from spray path
	_mist = CPUParticles2D.new()
	_mist.top_level = true
	_mist.z_index = 22
	_mist.emitting = true
	_mist.amount = 8
	_mist.lifetime = 0.35
	_mist.one_shot = false
	_mist.explosiveness = 0.3
	_mist.global_position = _start_pos
	_mist.direction = (_end_pos - _start_pos).normalized()
	_mist.spread = 60.0
	_mist.initial_velocity_min = 8.0
	_mist.initial_velocity_max = 20.0
	_mist.gravity = Vector2(0, -10)  # mist rises
	_mist.scale_amount_min = 0.5
	_mist.scale_amount_max = 1.5
	_mist.color = COLOR_MIST
	add_child(_mist)


func _apply_themed_sprite() -> void:
	pass


func _process(delta: float) -> void:
	_timer += delta
	_phase_timer += delta

	match _phase:
		0:  # Extend
			var t := clampf(_phase_timer / EXTEND_DURATION, 0.0, 1.0)
			var tip := _start_pos.lerp(_end_pos, t)
			_spray.points = PackedVector2Array([_start_pos, tip])
			_core_line.points = PackedVector2Array([_start_pos, tip])
			_mist.global_position = tip

			if t >= 1.0:
				_deal_line_damage()
				_spawn_droplets()
				_mist.global_position = (_start_pos + _end_pos) * 0.5
				_phase = 1
				_phase_timer = 0.0

		1:  # Linger
			if _phase_timer >= LINGER_DURATION:
				_mist.emitting = false
				_phase = 2
				_phase_timer = 0.0

		2:  # Fade
			var t := clampf(_phase_timer / FADE_DURATION, 0.0, 1.0)
			_spray.modulate.a = 1.0 - t
			_core_line.modulate.a = 1.0 - t
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
		var to_enemy: Vector2 = enemy.global_position - _start_pos
		var proj: float = to_enemy.dot(line_norm)
		if proj < -4.0 or proj > line_len + 4.0:
			continue
		var closest := _start_pos + line_norm * clampf(proj, 0.0, line_len)
		var perp_dist: float = enemy.global_position.distance_to(closest)
		if perp_dist <= LINE_HIT_WIDTH:
			_apply_damage_to(enemy)


func _spawn_droplets() -> void:
	for i in randi_range(3, 5):
		var drop := VFXPool.acquire_rect()
		drop.size = Vector2(2, 2)
		drop.color = COLOR_DROP
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
