class_name MicrowaveBeamProjectile
extends BaseProjectile
## Concentrated heat beam for the Microwave Emitter tower.
## Draws a hot orange/yellow Line2D ray from muzzle to target,
## damages all enemies along the line, then fades out.

const EXTEND_DURATION := 0.1
const LINGER_DURATION := 0.15
const FADE_DURATION := 0.2
const LINE_HIT_WIDTH := 10.0  # Perpendicular distance for line sweep (px)

const COLOR_CORE := Color("#FFF0A0")
const COLOR_GLOW := Color("#E06020")
const COLOR_GLOW_EDGE := Color("#C04010")
const COLOR_SHIMMER := Color("#F0A040", 0.5)
const COLOR_EMBER := Color("#F08030")

var _start_pos: Vector2
var _end_pos: Vector2
var _core: Line2D
var _glow: Line2D
var _phase: int = 0  # 0=extend, 1=linger, 2=fade
var _phase_timer: float = 0.0
var _has_dealt_damage: bool = false
var _shimmer: CPUParticles2D


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

	# Glow beam (wider, orange/red, behind core)
	_glow = Line2D.new()
	_glow.top_level = true
	_glow.z_index = 19
	_glow.width = 6.0
	_glow.default_color = COLOR_GLOW
	var glow_grad := Gradient.new()
	glow_grad.set_color(0, COLOR_GLOW)
	glow_grad.set_color(1, COLOR_GLOW_EDGE)
	_glow.gradient = glow_grad
	_glow.points = PackedVector2Array([_start_pos, _start_pos])
	add_child(_glow)

	# Core beam (narrow, bright white-yellow)
	_core = Line2D.new()
	_core.top_level = true
	_core.z_index = 20
	_core.width = 2.0
	_core.default_color = COLOR_CORE
	_core.points = PackedVector2Array([_start_pos, _start_pos])
	add_child(_core)

	# Heat shimmer particles rising from beam
	_shimmer = CPUParticles2D.new()
	_shimmer.top_level = true
	_shimmer.z_index = 21
	_shimmer.emitting = true
	_shimmer.amount = 6
	_shimmer.lifetime = 0.4
	_shimmer.one_shot = false
	_shimmer.explosiveness = 0.2
	_shimmer.global_position = _start_pos
	_shimmer.direction = Vector2(0, -1)
	_shimmer.spread = 35.0
	_shimmer.initial_velocity_min = 10.0
	_shimmer.initial_velocity_max = 25.0
	_shimmer.gravity = Vector2.ZERO
	_shimmer.scale_amount_min = 0.5
	_shimmer.scale_amount_max = 1.5
	_shimmer.color = COLOR_SHIMMER
	add_child(_shimmer)


func _apply_themed_sprite() -> void:
	pass


func _process(delta: float) -> void:
	_timer += delta
	_phase_timer += delta

	match _phase:
		0:  # Extend
			var t := clampf(_phase_timer / EXTEND_DURATION, 0.0, 1.0)
			var tip := _start_pos.lerp(_end_pos, t)
			_core.points = PackedVector2Array([_start_pos, tip])
			_glow.points = PackedVector2Array([_start_pos, tip])
			_shimmer.global_position = tip

			if t >= 1.0:
				_deal_line_damage()
				_spawn_ember_burst()
				_shimmer.global_position = (_start_pos + _end_pos) * 0.5
				_phase = 1
				_phase_timer = 0.0

		1:  # Linger
			if _phase_timer >= LINGER_DURATION:
				_shimmer.emitting = false
				_phase = 2
				_phase_timer = 0.0

		2:  # Fade
			var t := clampf(_phase_timer / FADE_DURATION, 0.0, 1.0)
			_core.modulate.a = 1.0 - t
			_glow.modulate.a = 1.0 - t
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

	var enemies := get_tree().get_nodes_in_group("enemies")
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


func _spawn_ember_burst() -> void:
	for i in randi_range(4, 6):
		var ember := ColorRect.new()
		ember.size = Vector2(2, 2)
		ember.color = COLOR_EMBER
		ember.global_position = _end_pos + Vector2(-1, -1)
		ember.z_index = 50
		get_tree().current_scene.add_child(ember)
		var angle := randf() * TAU
		var end_pos := ember.global_position + Vector2(cos(angle), sin(angle)) * randf_range(5.0, 12.0)
		var tween := ember.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ember, "global_position", end_pos, 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(ember, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(ember.queue_free)
