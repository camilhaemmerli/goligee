class_name TearGasCloud
extends Node2D
## Lingering tear gas smoke cloud that damages enemies within its radius.
## Uses two CPUParticles2D layers (burst + continuous) and a ground haze sprite.

var cloud_duration := 3.0
const FADE_DURATION = 1.0
const DAMAGE_INTERVAL = 0.5
const DAMAGE_RATIO = 0.4  ## Fraction of projectile damage per tick
const CLOUD_RADIUS = 40.0  ## Pixels — enemies within this range take damage

## Colors matching CHEMICAL damage palette
const COLOR_BURST = Color("#FFD080E0")   # Bright detonation flash
const COLOR_START = Color("#E08040C0")   # Fresh chemical agent
const COLOR_MID = Color("#C0703880")     # Settling gas
const COLOR_END = Color("#8050281F")     # Dissipating haze
const COLOR_HAZE = Color("#E080404D")    # Ground haze at 30%

var damage_per_tick: float
var damage_type: Enums.DamageType = Enums.DamageType.CHEMICAL
var on_hit_effects: Array[StatusEffectData] = []
var source_tower: Node2D

var _elapsed: float = 0.0
var _damage_timer: float = 0.0
var _fading: bool = false
var _burst_particles: CPUParticles2D
var _continuous_particles: CPUParticles2D
var _ground_haze: Sprite2D
var _smoke_texture: ImageTexture


func _ready() -> void:
	_smoke_texture = _create_smoke_puff_texture()
	_setup_ground_haze()
	_setup_burst_particles()
	_setup_continuous_particles()


func init(p_damage: float, p_dtype: Enums.DamageType,
		p_effects: Array[StatusEffectData], p_source: Node2D) -> void:
	damage_per_tick = p_damage * DAMAGE_RATIO
	damage_type = p_dtype
	on_hit_effects = p_effects
	source_tower = p_source


func _process(delta: float) -> void:
	_elapsed += delta
	_damage_timer += delta

	# Periodic AoE damage
	if _damage_timer >= DAMAGE_INTERVAL and not _fading:
		_damage_timer -= DAMAGE_INTERVAL
		_apply_cloud_damage()

	# Ground haze pulse
	if _ground_haze and not _fading:
		var pulse := 0.25 + 0.1 * sin(_elapsed * 3.0)
		_ground_haze.modulate.a = pulse

	# Start fade-out
	if _elapsed >= cloud_duration and not _fading:
		_fading = true
		_continuous_particles.emitting = false
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
		tween.tween_callback(queue_free)


func _apply_cloud_damage() -> void:
	var enemies := SpatialGrid.get_enemies_in_radius(global_position, CLOUD_RADIUS)
	for node in enemies:
		if not node is BaseEnemy:
			continue
		var enemy: BaseEnemy = node as BaseEnemy
		if not enemy.health or enemy.health.is_dead:
			continue

		# Track kill attribution
		if is_instance_valid(source_tower):
			enemy.last_hit_by = source_tower

		var resists: Dictionary = enemy.resistances.get_all() if enemy.resistances else {}
		var vuln_mod := enemy.get_vulnerability_modifier()
		var armor_shred := enemy.get_armor_shred()
		enemy.health.take_damage(damage_per_tick, damage_type, resists, vuln_mod, 0.0, 1.0, armor_shred)

		# Apply status effects (slow/poison from upgrades)
		if enemy.status_effects:
			for effect in on_hit_effects:
				enemy.status_effects.apply_effect(effect)


func _setup_ground_haze() -> void:
	_ground_haze = Sprite2D.new()
	_ground_haze.z_index = -1

	# Isometric ellipse: flat oval anchoring the cloud to the ground
	var w := 24
	var h := 12
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := (x - w / 2.0) / (w / 2.0)
			var dy := (y - h / 2.0) / (h / 2.0)
			if dx * dx + dy * dy <= 1.0:
				var alpha := (1.0 - (dx * dx + dy * dy)) * 0.5
				img.set_pixel(x, y, Color(0.88, 0.5, 0.25, alpha))
	_ground_haze.texture = ImageTexture.create_from_image(img)
	_ground_haze.modulate = Color(1, 1, 1, 0.3)
	add_child(_ground_haze)


func _setup_burst_particles() -> void:
	_burst_particles = CPUParticles2D.new()
	_burst_particles.texture = _smoke_texture
	_burst_particles.emitting = true
	_burst_particles.one_shot = true
	_burst_particles.explosiveness = 1.0
	_burst_particles.amount = 12
	_burst_particles.lifetime = 0.6
	_burst_particles.initial_velocity_min = 15.0
	_burst_particles.initial_velocity_max = 30.0
	_burst_particles.direction = Vector2(0, -1)
	_burst_particles.spread = 180.0
	_burst_particles.gravity = Vector2.ZERO
	_burst_particles.damping_min = 20.0
	_burst_particles.damping_max = 40.0
	_burst_particles.scale_amount_min = 1.5
	_burst_particles.scale_amount_max = 2.5
	_burst_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_burst_particles.emission_sphere_radius = 6.0

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	grad.colors = PackedColorArray([COLOR_BURST, COLOR_START, COLOR_END])
	_burst_particles.color_ramp = grad

	add_child(_burst_particles)


func _setup_continuous_particles() -> void:
	_continuous_particles = CPUParticles2D.new()
	_continuous_particles.texture = _smoke_texture
	_continuous_particles.emitting = true
	_continuous_particles.one_shot = false
	_continuous_particles.amount = 24
	_continuous_particles.lifetime = 2.0
	_continuous_particles.initial_velocity_min = 3.0
	_continuous_particles.initial_velocity_max = 8.0
	_continuous_particles.direction = Vector2(0, -1)
	_continuous_particles.spread = 120.0
	_continuous_particles.gravity = Vector2(0, -2)  # Slight upward drift
	_continuous_particles.damping_min = 5.0
	_continuous_particles.damping_max = 15.0
	_continuous_particles.scale_amount_min = 1.0
	_continuous_particles.scale_amount_max = 2.0
	_continuous_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_continuous_particles.emission_sphere_radius = 12.0

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.4, 0.8, 1.0])
	grad.colors = PackedColorArray([COLOR_START, COLOR_MID, COLOR_END, Color(0, 0, 0, 0)])
	_continuous_particles.color_ramp = grad

	# Scale up over lifetime for billowing effect
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.5, 1.0))
	scale_curve.add_point(Vector2(1.0, 1.5))
	_continuous_particles.scale_amount_curve = scale_curve

	add_child(_continuous_particles)


func _create_smoke_puff_texture() -> ImageTexture:
	## 12x12 soft blob with lumpy pixel edges — pixel art smoke puff.
	var size := 12
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size / 2.0
	var radius := center - 1.0

	for y in size:
		for x in size:
			var dx := x - center + 0.5
			var dy := y - center + 0.5
			var dist := sqrt(dx * dx + dy * dy)
			# Lumpy edge: add angular noise
			var angle := atan2(dy, dx)
			var noise := sin(angle * 3.0) * 0.8 + sin(angle * 7.0) * 0.4
			var threshold := radius + noise
			if dist < threshold:
				var alpha := clampf(1.0 - (dist / threshold) * 0.5, 0.3, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))

	return ImageTexture.create_from_image(img)
