class_name SonicWaveProjectile
extends BaseProjectile
## Instant AoE sonic blast for the LRAD Cannon tower.
## Applies damage immediately, then draws expanding concentric ring arcs
## and a screen-space distortion shader that warps the background.

const EFFECT_DURATION := 0.6
const EXPAND_SPEED := 200.0       # px/s — reaches ~120px in 0.6s (~4 tiles)
const MAX_RADIUS := 120.0

const ARC_COLOR := Color("#80E060", 0.6)
const FILL_COLOR := Color("#80E060", 0.05)
const PARTICLE_COLOR := Color("#A0E080")
const ARC_WIDTH := 2.0
const NUM_RINGS := 3
const RING_SPACING := 12.0

# Shader uniforms
const SHADER_STRENGTH_START := 0.012
const SHADER_WAVE_WIDTH := 0.12
const SHADER_RING_FREQ := 3.0

var _elapsed: float = 0.0
var _current_radius: float = 0.0
var _origin: Vector2  # local origin for _draw()
var _overlay: ColorRect
var _shader_mat: ShaderMaterial
var _screen_center: Vector2  # center in screen UV coords

static var _sonic_shader: Shader


func _ready() -> void:
	# Hide sprite and skip trail (same pattern as chain lightning)
	if sprite:
		sprite.visible = false
	if _trail:
		_trail.queue_free()
		_trail = null

	# Capture origin (muzzle position = our spawn point)
	_origin = Vector2.ZERO  # _draw() uses local coords

	# Apply AoE damage immediately
	if is_instance_valid(target):
		_apply_aoe_damage(global_position)
	elif aoe_radius > 0.0:
		_apply_aoe_damage(global_position)

	# Set up distortion shader overlay
	_setup_distortion_overlay()

	# Spawn pressure-wave debris particles
	_spawn_pressure_particles()


func _setup_distortion_overlay() -> void:
	var viewport := get_viewport()
	if not viewport:
		return

	# Compute tower position in screen UV (0-1)
	var canvas_xform := viewport.get_canvas_transform()
	var screen_pos := canvas_xform * global_position
	var vp_size := viewport.get_visible_rect().size
	if vp_size.x < 1.0 or vp_size.y < 1.0:
		return
	_screen_center = screen_pos / vp_size

	# Load shader once (static cache)
	if not _sonic_shader:
		_sonic_shader = load("res://assets/shaders/sonic_wave.gdshader")

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = _sonic_shader
	_shader_mat.set_shader_parameter("center", _screen_center)
	_shader_mat.set_shader_parameter("radius", 0.0)
	_shader_mat.set_shader_parameter("strength", SHADER_STRENGTH_START)
	_shader_mat.set_shader_parameter("wave_width", SHADER_WAVE_WIDTH)
	_shader_mat.set_shader_parameter("ring_freq", SHADER_RING_FREQ)

	_overlay = ColorRect.new()
	_overlay.material = _shader_mat
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 100
	_overlay.size = get_viewport_rect().size
	_overlay.top_level = true
	_overlay.position = Vector2.ZERO

	get_tree().current_scene.add_child(_overlay)


func _spawn_pressure_particles() -> void:
	for i in randi_range(6, 8):
		var spec := ColorRect.new()
		spec.size = Vector2(2, 2)
		spec.color = PARTICLE_COLOR
		spec.global_position = global_position + Vector2(-1, -1)
		spec.z_index = 50
		get_tree().current_scene.add_child(spec)

		var angle := randf() * TAU
		var dist := randf_range(40.0, 80.0)
		var end_pos := spec.global_position + Vector2(cos(angle), sin(angle)) * dist
		var tween := spec.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spec, "global_position", end_pos, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(spec, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(spec.queue_free)


func _process(delta: float) -> void:
	# Skip base class movement — this projectile stays in place
	_elapsed += delta
	_current_radius = minf(_elapsed * EXPAND_SPEED, MAX_RADIUS)

	# Update shader distortion
	if _shader_mat:
		var viewport := get_viewport()
		if viewport:
			var vp_size := viewport.get_visible_rect().size
			# Convert pixel radius to UV radius (approximate using viewport width)
			var uv_radius := _current_radius / maxf(vp_size.x, 1.0)
			var life_t := _elapsed / EFFECT_DURATION
			var strength := SHADER_STRENGTH_START * (1.0 - life_t)
			_shader_mat.set_shader_parameter("radius", uv_radius)
			_shader_mat.set_shader_parameter("strength", strength)

	# Redraw arcs every frame
	queue_redraw()

	# Clean up after effect duration
	if _elapsed >= EFFECT_DURATION:
		_cleanup()
		queue_free()


func _draw() -> void:
	if _current_radius <= 0.0:
		return

	var life_t := _elapsed / EFFECT_DURATION
	var base_alpha := (1.0 - life_t) * 0.6

	# Inner fill — subtle pressure zone
	if _current_radius > 4.0:
		draw_circle(_origin, _current_radius, FILL_COLOR)

	# Concentric ring arcs expanding outward
	for i in NUM_RINGS:
		var ring_radius := _current_radius - float(i) * RING_SPACING
		if ring_radius < 2.0:
			continue
		# Outer rings slightly dimmer
		var ring_alpha := base_alpha * (1.0 - float(i) * 0.25)
		var color := Color(ARC_COLOR, ring_alpha)
		# Full circle arc
		draw_arc(_origin, ring_radius, 0.0, TAU, 32, color, ARC_WIDTH)


func _cleanup() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	_shader_mat = null
