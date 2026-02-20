class_name GasAirstrike
extends Node2D
## Executive Decree #2: A jet flies along a strike corridor through the target,
## dropping gas canisters and dealing damage along the entire line.

const PLANE_SPEED = 220.0
const CANISTER_COUNT = 7
const CANISTER_SPREAD = 18.0
const GAS_CLOUD_DURATION = 4.5
const GAS_DAMAGE = 10.0
const SLOW_POTENCY = 0.5
const SLOW_DURATION = 2.5
const POISON_DPS = 10.0
const POISON_DURATION = 3.0

const FLIGHT_MARGIN = 350.0
const DROP_ZONE_RATIO = 0.7  ## 70% of flight path for drops (wider coverage)
const LINE_DAMAGE = 12.0     ## Direct CHEMICAL damage to enemies near the flight line
const LINE_DAMAGE_WIDTH = 32.0  ## How close to the line enemies must be to take direct hit

var _plane_sprite: Sprite2D
var _plane_shadow: Sprite2D
var _trail_particles: CPUParticles2D
var _flight_start: Vector2
var _flight_end: Vector2
var _flight_progress: float = 0.0
var _flight_length: float = 0.0
var _target_pos: Vector2
var _canister_positions: Array[Vector2] = []
var _drops_remaining: int = CANISTER_COUNT
var _next_drop_progress: float = 0.0
var _drop_interval: float = 0.0
var _tile_map: TileMapLayer
var _line_damaged: Dictionary = {}  ## Track enemies already hit by flyover


func init(world_pos: Vector2, tile_map: TileMapLayer) -> void:
	_target_pos = world_pos
	_tile_map = tile_map

	# Flight path: NW→SE diagonal through target
	var flight_dir := Vector2(1, 0.5).normalized()
	_flight_start = world_pos - flight_dir * FLIGHT_MARGIN
	_flight_end = world_pos + flight_dir * FLIGHT_MARGIN
	_flight_length = _flight_start.distance_to(_flight_end)

	# Spread canisters along the flight line (not just clustered at center)
	var drop_start_ratio := (1.0 - DROP_ZONE_RATIO) / 2.0
	for i in CANISTER_COUNT:
		var t := drop_start_ratio + DROP_ZONE_RATIO * (float(i) + 0.5) / float(CANISTER_COUNT)
		var line_pos := _flight_start.lerp(_flight_end, t)
		var offset := Vector2(
			randf_range(-CANISTER_SPREAD, CANISTER_SPREAD),
			randf_range(-CANISTER_SPREAD * 0.5, CANISTER_SPREAD * 0.5)
		)
		_canister_positions.append(line_pos + offset)

	# Drop timing
	_next_drop_progress = drop_start_ratio
	_drop_interval = DROP_ZONE_RATIO / float(CANISTER_COUNT)

	global_position = _flight_start
	_create_plane_sprite()
	_create_trail_particles()

	# Screen shake on entry
	SignalBus.screen_shake.emit(3.0, 0.2)


func _create_plane_sprite() -> void:
	_plane_sprite = Sprite2D.new()
	# Flight dir is NW→SE, so use the SE directional sprite
	var tex := load("res://assets/sprites/abilities/jet/se.png")
	if not tex:
		tex = load("res://assets/sprites/abilities/jet.png")
	if tex:
		_plane_sprite.texture = tex
	else:
		# Procedural fallback
		var img := Image.create(24, 12, false, Image.FORMAT_RGBA8)
		var body_col := Color("#4A4A52")
		var wing_col := Color("#3A3A42")
		for x in range(4, 22):
			for y in range(4, 8):
				img.set_pixel(x, y, body_col)
		for x in range(8, 18):
			for y in range(0, 12):
				if not img.get_pixel(x, y).a > 0:
					img.set_pixel(x, y, wing_col)
		_plane_sprite.texture = ImageTexture.create_from_image(img)
	_plane_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plane_sprite.z_index = 30
	_plane_sprite.z_as_relative = false
	add_child(_plane_sprite)

	# Shadow (darkened copy of plane texture)
	var shadow_tex := _plane_sprite.texture
	var shadow_img := shadow_tex.get_image().duplicate()
	if shadow_img:
		shadow_img.convert(Image.FORMAT_RGBA8)
		for x in shadow_img.get_width():
			for y in shadow_img.get_height():
				var px: Color = shadow_img.get_pixel(x, y)
				if px.a > 0:
					shadow_img.set_pixel(x, y, Color(0, 0, 0, 0.3))
	_plane_shadow = Sprite2D.new()
	_plane_shadow.texture = ImageTexture.create_from_image(shadow_img) if shadow_img else shadow_tex
	_plane_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plane_shadow.position = Vector2(10, 24)
	_plane_shadow.z_index = -1
	add_child(_plane_shadow)


func _create_trail_particles() -> void:
	_trail_particles = CPUParticles2D.new()
	_trail_particles.emitting = true
	_trail_particles.amount = 20
	_trail_particles.lifetime = 1.5
	_trail_particles.one_shot = false
	_trail_particles.explosiveness = 0.0

	# Emit from behind the plane
	_trail_particles.direction = Vector2(-1, -0.5)  # Opposite of flight dir
	_trail_particles.spread = 25.0
	_trail_particles.initial_velocity_min = 8.0
	_trail_particles.initial_velocity_max = 18.0
	_trail_particles.gravity = Vector2(0, 2)
	_trail_particles.damping_min = 5.0
	_trail_particles.damping_max = 10.0
	_trail_particles.scale_amount_min = 1.5
	_trail_particles.scale_amount_max = 3.0
	_trail_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_trail_particles.emission_sphere_radius = 4.0

	# Smoke puff texture
	_trail_particles.texture = _create_smoke_texture()

	# Color: white-gray smoke fading out
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	grad.colors = PackedColorArray([
		Color(0.9, 0.9, 0.95, 0.5),
		Color(0.7, 0.7, 0.75, 0.3),
		Color(0.5, 0.5, 0.55, 0.0),
	])
	_trail_particles.color_ramp = grad

	# Scale up over lifetime
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.5))
	scale_curve.add_point(Vector2(0.5, 1.2))
	scale_curve.add_point(Vector2(1.0, 2.0))
	_trail_particles.scale_amount_curve = scale_curve

	_trail_particles.z_index = 29
	_trail_particles.z_as_relative = false
	add_child(_trail_particles)


func _process(delta: float) -> void:
	if _flight_length <= 0.0:
		_finish()
		return

	# Move plane along flight path
	_flight_progress += (PLANE_SPEED * delta) / _flight_length
	global_position = _flight_start.lerp(_flight_end, _flight_progress)

	# Deal direct line damage to enemies near the flight path
	_apply_line_damage()

	# Drop canisters at evenly spaced intervals
	if _drops_remaining > 0 and _flight_progress >= _next_drop_progress:
		var drop_idx := CANISTER_COUNT - _drops_remaining
		if drop_idx < _canister_positions.size():
			_drop_canister(_canister_positions[drop_idx])
		_drops_remaining -= 1
		_next_drop_progress += _drop_interval

	# Plane exits screen
	if _flight_progress >= 1.0:
		_finish()


func _apply_line_damage() -> void:
	## Deal damage to enemies close to the current plane position (flyover damage)
	var nearby := SpatialGrid.get_enemies_in_radius(global_position, LINE_DAMAGE_WIDTH)
	for node in nearby:
		if not node is BaseEnemy:
			continue
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy.health.is_dead:
			continue
		# Only hit each enemy once during flyover
		var eid := enemy.get_instance_id()
		if _line_damaged.has(eid):
			continue
		_line_damaged[eid] = true

		var resists: Dictionary = enemy.resistances.get_all() if enemy.resistances else {}
		var vuln_mod := enemy.get_vulnerability_modifier()
		var armor_shred := enemy.get_armor_shred()
		enemy.health.take_damage(LINE_DAMAGE, Enums.DamageType.CHEMICAL, resists, vuln_mod, 0.0, 1.0, armor_shred)


func _drop_canister(target_pos: Vector2) -> void:
	var canister := Sprite2D.new()
	var img := Image.create(4, 6, false, Image.FORMAT_RGBA8)
	var can_col := Color("#6A7A60")
	for x in range(1, 3):
		for y in range(0, 6):
			img.set_pixel(x, y, can_col)
	img.set_pixel(0, 1, can_col)
	img.set_pixel(3, 1, can_col)
	img.set_pixel(0, 4, can_col)
	img.set_pixel(3, 4, can_col)

	canister.texture = ImageTexture.create_from_image(img)
	canister.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canister.scale = Vector2(2.0, 2.0)
	canister.global_position = global_position
	canister.z_index = 25
	canister.z_as_relative = false
	get_parent().add_child(canister)

	# Tween canister falling
	var tween := canister.create_tween()
	tween.tween_property(canister, "global_position", target_pos, 0.35) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_spawn_gas_cloud.bind(target_pos, canister))


func _spawn_gas_cloud(pos: Vector2, canister: Sprite2D) -> void:
	canister.queue_free()

	# Impact burst particles (the "boom")
	_spawn_impact_burst(pos)

	# Screen shake per canister
	SignalBus.screen_shake.emit(2.0, 0.1)

	var cloud := TearGasCloud.new()
	cloud.cloud_duration = GAS_CLOUD_DURATION

	var slow_effect := StatusEffectData.new()
	slow_effect.effect_type = Enums.StatusEffectType.SLOW
	slow_effect.duration = SLOW_DURATION
	slow_effect.potency = SLOW_POTENCY
	slow_effect.apply_chance = 1.0

	var poison_effect := StatusEffectData.new()
	poison_effect.effect_type = Enums.StatusEffectType.POISON
	poison_effect.duration = POISON_DURATION
	poison_effect.potency = POISON_DPS
	poison_effect.apply_chance = 1.0

	var effects: Array[StatusEffectData] = [slow_effect, poison_effect]
	cloud.init(GAS_DAMAGE, Enums.DamageType.CHEMICAL, effects, null)
	cloud.global_position = pos
	get_parent().add_child(cloud)


func _spawn_impact_burst(pos: Vector2) -> void:
	## Canister landing explosion — burst of orange-brown particles
	var burst := CPUParticles2D.new()
	burst.texture = _create_smoke_texture()
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 16
	burst.lifetime = 0.7
	burst.initial_velocity_min = 20.0
	burst.initial_velocity_max = 50.0
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.gravity = Vector2(0, 30)
	burst.damping_min = 15.0
	burst.damping_max = 30.0
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.0
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 6.0

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	grad.colors = PackedColorArray([
		Color("#FFD080E0"),  # Bright flash
		Color("#E08040A0"),  # Chemical orange
		Color("#80503000"),  # Fade out
	])
	burst.color_ramp = grad

	burst.global_position = pos
	burst.z_index = 22
	burst.z_as_relative = false
	get_parent().add_child(burst)

	# Auto-cleanup
	var tw := burst.create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(burst.queue_free)


func _finish() -> void:
	SignalBus.ability_completed.emit("gas_airstrike")
	if _trail_particles:
		_trail_particles.emitting = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _create_smoke_texture() -> ImageTexture:
	var size := 10
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size / 2.0
	var radius := center - 1.0
	for y in size:
		for x in size:
			var dx := x - center + 0.5
			var dy := y - center + 0.5
			var dist := sqrt(dx * dx + dy * dy)
			var angle := atan2(dy, dx)
			var noise := sin(angle * 3.0) * 0.6 + sin(angle * 5.0) * 0.3
			var threshold := radius + noise
			if dist < threshold:
				var alpha := clampf(1.0 - (dist / threshold) * 0.5, 0.3, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
