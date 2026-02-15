class_name SurveillancePulseProjectile
extends BaseProjectile
## Eerie 360° surveillance pulse for the Surveillance Hub tower.
## Expanding ring of cold blue light that marks and damages all enemies in range.
## Applies damage immediately, then draws expanding concentric scan-rings
## with drifting data-spec particles.

const EFFECT_DURATION := 0.9
const EXPAND_SPEED := 180.0   # px/s — reaches ~160px in 0.9s
const MAX_RADIUS := 160.0     # 5.0 range * 32px

# Colors — cold surveillance blue, eerie glow
const RING_COLOR := Color("#80A8D0", 0.6)
const FILL_COLOR := Color("#4060A0", 0.05)
const INNER_GLOW := Color("#6090C0", 0.08)
const PARTICLE_COLOR := Color("#90B8E0")
const ARC_WIDTH := 1.5
const NUM_RINGS := 4
const RING_SPACING := 10.0

var _elapsed: float = 0.0
var _current_radius: float = 0.0
var _origin: Vector2


func _ready() -> void:
	if sprite:
		sprite.visible = false
	if _trail:
		_trail.queue_free()
		_trail = null

	_origin = Vector2.ZERO  # _draw() uses local coords

	# Apply 360° AoE damage immediately
	_apply_aoe_damage(global_position)

	# Spawn drifting data-spec particles
	_spawn_data_particles()


func _apply_themed_sprite() -> void:
	pass


func _spawn_data_particles() -> void:
	for i in randi_range(8, 12):
		var spec := ColorRect.new()
		# Rectangular "data bit" specs — 1x1 or 2x1
		spec.size = Vector2(2, 1) if randf() > 0.5 else Vector2(1, 1)
		spec.color = PARTICLE_COLOR
		spec.global_position = global_position + Vector2(-1, -1)
		spec.z_index = 50
		get_tree().current_scene.add_child(spec)

		var angle := randf() * TAU
		var dist := randf_range(30.0, 70.0)
		var end_pos := spec.global_position + Vector2(cos(angle), sin(angle)) * dist
		var dur := randf_range(0.5, 0.8)
		var tween := spec.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spec, "global_position", end_pos, dur).set_ease(Tween.EASE_OUT)
		tween.tween_property(spec, "modulate:a", 0.0, dur)
		tween.chain().tween_callback(spec.queue_free)


func _process(delta: float) -> void:
	# Skip base class movement — stays in place
	_elapsed += delta
	_current_radius = minf(_elapsed * EXPAND_SPEED, MAX_RADIUS)

	queue_redraw()

	if _elapsed >= EFFECT_DURATION:
		queue_free()


func _draw() -> void:
	if _current_radius <= 0.0:
		return

	var life_t := _elapsed / EFFECT_DURATION
	var base_alpha := (1.0 - life_t) * 0.6

	# Inner fill — eerie surveillance glow dome
	if _current_radius > 4.0:
		draw_circle(_origin, _current_radius, FILL_COLOR)
		# Brighter inner core glow (smaller radius)
		var inner_r := _current_radius * 0.4
		draw_circle(_origin, inner_r, INNER_GLOW)

	# Expanding concentric scan-rings
	for i in NUM_RINGS:
		var ring_radius := _current_radius - float(i) * RING_SPACING
		if ring_radius < 2.0:
			continue
		# Outer rings dimmer — scan fades at edges
		var ring_alpha := base_alpha * (1.0 - float(i) * 0.2)
		var color := Color(RING_COLOR, ring_alpha)
		draw_arc(_origin, ring_radius, 0.0, TAU, 32, color, ARC_WIDTH)
