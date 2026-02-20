class_name FogManager
extends Node2D
## Atmospheric fog/gas system that intensifies with chemical tower count.
## Fog overlay is world-space (Sprite2D, z_index=40) so PointLight2D can illuminate it.
## Explosion/impact lights use light_mask bit 2 to only affect fog elements.

const CHEMICAL_TOWERS := {
	"tear_gas": 0.06,
	"pepper_spray": 0.03,
}
const MAX_DENSITY := 0.25
const DENSITY_TWEEN_DURATION := 0.8

const WISP_PARTICLE_COUNT := 10
const WISP_LIFETIME := 3.5
const WISP_SPREAD := 40.0

const LIGHT_FADE_DURATION := 0.25
const LIGHT_TEXTURE_SIZE := 64
const LIGHT_COLOR_WARM := Color(1.0, 0.7, 0.3)
const LIGHT_ENERGY_MEDIUM := 1.5
const LIGHT_ENERGY_BIG := 2.5
const LIGHT_SCALE_MEDIUM := Vector2(1.5, 1.5)
const LIGHT_SCALE_BIG := Vector2(2.5, 2.5)
const BIG_ENEMY_HP := 500.0
const MEDIUM_ENEMY_HP := 200.0

var _camera: Camera2D
var _effects_container: Node2D
var _fog_overlay: Sprite2D
var _fog_material: ShaderMaterial
var _target_density: float = 0.0
var _current_density: float = 0.0
var _density_tween: Tween
var _wisps: Dictionary = {}  # tower instance_id -> CPUParticles2D
var _light_texture: Texture2D
var _noise_texture: NoiseTexture2D


func setup(game_node: Node2D, camera: Camera2D, effects: Node2D) -> void:
	_camera = camera
	_effects_container = effects
	_create_noise_texture()
	_create_light_texture()
	_create_fog_overlay(game_node)
	_connect_signals()


func _create_noise_texture() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	_noise_texture = NoiseTexture2D.new()
	_noise_texture.noise = noise
	_noise_texture.seamless = true
	_noise_texture.width = 256
	_noise_texture.height = 256


func _create_light_texture() -> void:
	# Radial gradient for PointLight2D
	var img := Image.create(LIGHT_TEXTURE_SIZE, LIGHT_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(LIGHT_TEXTURE_SIZE / 2.0, LIGHT_TEXTURE_SIZE / 2.0)
	var radius := LIGHT_TEXTURE_SIZE / 2.0
	for y in LIGHT_TEXTURE_SIZE:
		for x in LIGHT_TEXTURE_SIZE:
			var dist := Vector2(x, y).distance_to(center) / radius
			var alpha := clampf(1.0 - dist * dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_light_texture = ImageTexture.create_from_image(img)


func _create_fog_overlay(game_node: Node2D) -> void:
	_fog_overlay = Sprite2D.new()
	_fog_overlay.name = "FogOverlay"
	_fog_overlay.z_index = 40
	_fog_overlay.z_as_relative = false
	# Light mask bit 2 (value 2) so only fog-targeted lights affect it
	_fog_overlay.light_mask = 2

	var shader := load("res://assets/shaders/fog.gdshader") as Shader
	if not shader:
		return

	_fog_material = ShaderMaterial.new()
	_fog_material.shader = shader
	_fog_material.set_shader_parameter("noise_texture", _noise_texture)
	_fog_material.set_shader_parameter("density", 0.0)
	_fog_material.set_shader_parameter("noise_scale", 2.5)
	_fog_material.set_shader_parameter("scroll_speed", 0.012)
	_fog_material.set_shader_parameter("time_scale", 0.8)
	_fog_material.set_shader_parameter("fog_color_near", Color(0.35, 0.38, 0.28, 0.5))
	_fog_material.set_shader_parameter("fog_color_far", Color(0.45, 0.42, 0.30, 0.6))

	_fog_overlay.material = _fog_material

	# Create a white texture sized to viewport -- we'll resize each frame
	_update_fog_size()

	game_node.add_child(_fog_overlay)


func _update_fog_size() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	# Slightly oversized to cover edges during camera movement
	var padded := vp_size * 1.2
	var img := Image.create(int(padded.x), int(padded.y), false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_fog_overlay.texture = ImageTexture.create_from_image(img)
	if _fog_material:
		_fog_material.set_shader_parameter("viewport_size", padded)


func _connect_signals() -> void:
	SignalBus.tower_placed.connect(_on_tower_placed)
	SignalBus.tower_sold.connect(_on_tower_sold)
	SignalBus.enemy_killed.connect(_on_enemy_killed)
	SignalBus.chemical_impact.connect(_on_chemical_impact)


func _process(_delta: float) -> void:
	if not _camera or not _fog_overlay:
		return
	# Follow camera so fog always covers the viewport
	_fog_overlay.global_position = _camera.global_position
	# Feed camera position to shader for world-space noise
	if _fog_material:
		_fog_material.set_shader_parameter("camera_position", _camera.global_position)


# ---------------------------------------------------------------------------
# Density tracking
# ---------------------------------------------------------------------------

func _on_tower_placed(tower: Node2D, _tile_pos: Vector2i) -> void:
	if not tower is BaseTower:
		return
	var bt := tower as BaseTower
	if not bt.tower_data or not bt.tower_data.tower_id:
		return
	var tower_id: String = bt.tower_data.tower_id
	if tower_id not in CHEMICAL_TOWERS:
		return

	_target_density = clampf(_target_density + CHEMICAL_TOWERS[tower_id], 0.0, MAX_DENSITY)
	_tween_density()
	_spawn_wisp(tower)


func _on_tower_sold(tower: Node2D, _refund: int) -> void:
	if not tower is BaseTower:
		return
	var bt := tower as BaseTower
	if not bt.tower_data or not bt.tower_data.tower_id:
		return
	var tower_id: String = bt.tower_data.tower_id
	if tower_id not in CHEMICAL_TOWERS:
		return

	_target_density = clampf(_target_density - CHEMICAL_TOWERS[tower_id], 0.0, MAX_DENSITY)
	_tween_density()
	_remove_wisp(tower)


func _tween_density() -> void:
	if _density_tween and _density_tween.is_valid():
		_density_tween.kill()
	_density_tween = create_tween()
	_density_tween.tween_method(_set_density, _current_density, _target_density, DENSITY_TWEEN_DURATION)


func _set_density(value: float) -> void:
	_current_density = value
	if _fog_material:
		_fog_material.set_shader_parameter("density", value)


# ---------------------------------------------------------------------------
# Local wisps (CPUParticles2D per chemical tower)
# ---------------------------------------------------------------------------

func _spawn_wisp(tower: Node2D) -> void:
	if not _effects_container:
		return
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.amount = WISP_PARTICLE_COUNT
	particles.lifetime = WISP_LIFETIME
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 8.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.45, 0.50, 0.35, 0.15)

	# Small white circle texture for wisp particles
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	particles.texture = ImageTexture.create_from_image(img)

	particles.global_position = tower.global_position
	_effects_container.add_child(particles)
	_wisps[tower.get_instance_id()] = particles


func _remove_wisp(tower: Node2D) -> void:
	var id := tower.get_instance_id()
	if id not in _wisps:
		return
	var particles: CPUParticles2D = _wisps[id]
	_wisps.erase(id)
	if is_instance_valid(particles):
		particles.emitting = false
		# Let remaining particles finish, then free
		var tween := create_tween()
		tween.tween_interval(particles.lifetime)
		tween.tween_callback(particles.queue_free)


# ---------------------------------------------------------------------------
# Explosion / impact lights
# ---------------------------------------------------------------------------

func _on_enemy_killed(enemy: Node2D, _gold: int) -> void:
	if _current_density <= 0.0:
		return
	if not enemy is BaseEnemy:
		return
	var be := enemy as BaseEnemy
	if not be.enemy_data:
		return
	if be.enemy_data.max_hp >= BIG_ENEMY_HP:
		_spawn_light(enemy.global_position, LIGHT_ENERGY_BIG, LIGHT_SCALE_BIG)
	elif be.enemy_data.max_hp >= MEDIUM_ENEMY_HP:
		_spawn_light(enemy.global_position, LIGHT_ENERGY_MEDIUM, LIGHT_SCALE_MEDIUM)


func _on_chemical_impact(pos: Vector2, _intensity: float) -> void:
	if _current_density <= 0.0:
		return
	_spawn_light(pos, LIGHT_ENERGY_MEDIUM, LIGHT_SCALE_MEDIUM)


func _spawn_light(pos: Vector2, energy: float, light_scale: Vector2) -> void:
	var light := PointLight2D.new()
	light.texture = _light_texture
	light.color = LIGHT_COLOR_WARM
	light.energy = energy
	light.texture_scale = light_scale.x
	light.global_position = pos
	# Bit 2 only -- isolate to fog elements
	light.range_item_cull_mask = 2
	add_child(light)

	# Fade out and free
	var tween := create_tween()
	tween.tween_property(light, "energy", 0.0, LIGHT_FADE_DURATION)
	tween.tween_callback(light.queue_free)
